import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../licences/license_type.dart';

/// Error controlado del flujo de pago con QvaPay.
class QvaPayException implements Exception {
  const QvaPayException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Factura recién creada en QvaPay.
class QvaPayInvoice {
  const QvaPayInvoice({
    required this.orderId,
    required this.accessToken,
    required this.status,
    this.paymentUrl,
  });

  /// Identificador local del pedido (también es el `remote_id` de QvaPay).
  final String orderId;

  /// Token privado para consultar el pedido sin exponer el `order_id` solo.
  final String accessToken;

  /// Estado guardado en el servidor al crear la factura.
  final String status;

  /// URL de pago de QvaPay. Puede ser nula si QvaPay no la devuelve.
  final String? paymentUrl;
}

/// Estado de un pedido consultado en el servidor de CashRapido.
class QvaPayOrderStatus {
  const QvaPayOrderStatus({
    required this.status,
    this.licenseCode,
    this.planId,
    this.expiresAt,
    this.licenseReady = false,
  });

  final String status;
  final String? licenseCode;
  final String? planId;
  final String? expiresAt;
  final bool licenseReady;

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
}

/// Integración con la API de pagos QvaPay de CashRapido.
///
/// La app no habla directamente con QvaPay ni guarda secretos: crea una
/// factura en el backend (`crear-factura.php`), abre la URL de pago y consulta
/// el estado (`consultar-pedido.php`). La licencia solo se activa cuando el
/// webhook firmado de QvaPay ya marcó el pedido como pagado.
abstract final class QvaPayService {
  /// Base de la API alojada en la web oficial.
  static const String baseUrl = 'https://www.cashrapidoapp.cu/api';

  /// La creación de factura puede tardar mientras QvaPay responde.
  static const Duration requestTimeout = Duration(seconds: 45);

  static const String _clientIdKey = 'qvapay_client_id';

  /// Planes que entiende `website/private/qvapay-config.php`.
  ///
  /// Deben coincidir exactamente con las claves de `LICENSE_PLANS`; un cambio
  /// aquí sin cambiar el servidor haría que la factura fuera rechazada.
  static const Map<LicenseType, String> _planIds = <LicenseType, String>{
    LicenseType.weeklyPersonal: 'weekly_personal',
    LicenseType.weeklyPro: 'weekly_pro',
    LicenseType.weeklyEnterprise: 'weekly_enterprise',
    LicenseType.monthlyPersonal: 'monthly_personal',
    LicenseType.monthlyPro: 'monthly_pro',
    LicenseType.monthlyEnterprise: 'monthly_enterprise',
    LicenseType.annualPersonal: 'annual_personal',
    LicenseType.annualPro: 'annual_pro',
    LicenseType.annualEnterprise: 'annual_enterprise',
  };

  /// Identificador de plan que se envía al backend para [licenseType].
  static String planIdFor(LicenseType licenseType) {
    final String? planId = _planIds[licenseType];
    if (planId == null) {
      throw const QvaPayException(
        'La licencia gratuita no se puede comprar con QvaPay.',
      );
    }
    return planId;
  }

  /// Convierte el `plan` devuelto por el servidor en un [LicenseType].
  static LicenseType? licenseTypeForPlanId(String planId) {
    for (final MapEntry<LicenseType, String> entry in _planIds.entries) {
      if (entry.value == planId) return entry.key;
    }
    return null;
  }

  /// Identificador estable de este dispositivo para asociar sus pedidos.
  ///
  /// Se genera una sola vez y se guarda en `SharedPreferences`. El backend
  /// exige entre 8 y 128 caracteres `[A-Za-z0-9._:-]`; un UUID encaja.
  static Future<String> clientId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? saved = prefs.getString(_clientIdKey);
    if (saved != null && saved.length >= 8) return saved;

    final String created = const Uuid().v4();
    await prefs.setString(_clientIdKey, created);
    return created;
  }

  /// Crea una factura para [licenseType].
  static Future<QvaPayInvoice> createInvoice(LicenseType licenseType) async {
    final String clientIdValue = await clientId();
    final Map<String, dynamic> data = await _post(
      '/crear-factura.php',
      <String, dynamic>{
        'plan': planIdFor(licenseType),
        'client_id': clientIdValue,
      },
    );

    if (data['success'] != true) {
      throw QvaPayException(
        (data['error'] as String?) ??
            'El servidor no pudo crear la factura de QvaPay.',
      );
    }

    final String? orderId = data['order_id'] as String?;
    final String? accessToken = data['access_token'] as String?;

    if (orderId == null ||
        orderId.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      throw const QvaPayException(
        'El servidor no devolvió los datos necesarios del pedido.',
      );
    }

    final String? paymentUrl = data['payment_url'] as String?;

    return QvaPayInvoice(
      orderId: orderId,
      accessToken: accessToken,
      status: (data['status'] as String?) ?? 'pending',
      paymentUrl: paymentUrl != null && paymentUrl.trim().isNotEmpty
          ? paymentUrl.trim()
          : null,
    );
  }

  /// Consulta el estado del pedido y, si está pagado, sus datos de licencia.
  static Future<QvaPayOrderStatus> checkOrder({
    required String orderId,
    required String accessToken,
  }) async {
    final Map<String, dynamic> data = await _post(
      '/consultar-pedido.php',
      <String, dynamic>{'order_id': orderId, 'access_token': accessToken},
    );

    final String? status = data['status'] as String?;
    if (status == null || status.isEmpty) {
      throw const QvaPayException(
        'El servidor no devolvió el estado del pedido.',
      );
    }

    final String? licenseCode = _textOrNull(data['license_code']);

    return QvaPayOrderStatus(
      status: status,
      licenseCode: licenseCode,
      planId: _textOrNull(data['plan']),
      expiresAt: _textOrNull(data['expires_at']),
      // Compatibilidad con versiones anteriores del backend que no
      // devolvían `license_ready`: si hay código, la licencia está lista.
      licenseReady: data['license_ready'] == true || licenseCode != null,
    );
  }

  /// Convierte la fecha UTC de MySQL (`YYYY-MM-DD HH:MM:SS`) a hora local.
  static DateTime? parseExpiresAt(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final String normalized = raw.trim().replaceFirst(' ', 'T');
    final String withZone =
        normalized.endsWith('Z') ||
            normalized.contains('+') ||
            RegExp(r'-\d{2}:\d{2}$').hasMatch(normalized)
        ? normalized
        : '${normalized}Z';
    return DateTime.tryParse(withZone)?.toLocal();
  }

  static String? _textOrNull(dynamic value) {
    if (value is! String) return null;
    final String text = value.trim();
    return text.isEmpty ? null : text;
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> payload,
  ) async {
    final Uri uri = Uri.parse('$baseUrl$path');

    late http.Response response;
    try {
      response = await http
          .post(
            uri,
            headers: const <String, String>{
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payload),
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const QvaPayException(
        'La conexión con QvaPay tardó demasiado. Revisa tu internet e inténtalo de nuevo.',
      );
    } catch (_) {
      throw const QvaPayException(
        'No se pudo conectar con el servidor de pagos. Revisa tu internet.',
      );
    }

    Map<String, dynamic>? data;
    try {
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        data = decoded;
      } else if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      // Se maneja abajo con el código HTTP.
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw QvaPayException(
        (data?['error'] as String?) ??
            'El servidor de pagos respondió con un error (${response.statusCode}).',
      );
    }

    if (data == null) {
      throw const QvaPayException(
        'El servidor de pagos devolvió una respuesta no válida.',
      );
    }

    return data;
  }
}
