import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:apklis_license_validator/apklis_license_payment_status.dart';
import 'package:apklis_license_validator/apklis_license_validator.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'license_type.dart';

/// Servicio para validar licencias mediante la plataforma Apklis
///
/// Apklis es una tienda de aplicaciones cubana que permite la compra
/// de licencias dentro de la aplicación.
///
/// ## UUIDs de Licencias Disponibles:
/// - Semanales (7 días): Personal, Pro, Enterprise
/// - Mensuales (30 días): Personal, Pro, Enterprise
/// - Anuales (365 días): Personal, Pro, Enterprise
class ApklisService {
  // Package ID para CashRapido en Apklis
  static const String _packageId = 'cu.lenier.cashrapido';

  // ========================================
  // UUIDS DE PRODUCTO PARA APKLIS
  // ========================================

  // Licencias Semanales (7 días)
  static const String _weeklyPersonalUuid =
      'UUID_WEEKLY_PERSONAL_AQUI'; // 15 CUP
  static const String _weeklyProUuid = 'UUID_WEEKLY_PRO_AQUI'; // 25 CUP
  static const String _weeklyEnterpriseUuid =
      'UUID_WEEKLY_ENTERPRISE_AQUI'; // 35 CUP

  // Licencias Mensuales (30 días)
  static const String _monthlyPersonalUuid =
      'ef115f45-8736-4a21-a619-2d2f7b1d8781'; // 50 CUP
  static const String _monthlyProUuid =
      '1c6fa982-48e8-4b85-8bbb-56be3bb628c3'; // 75 CUP
  static const String _monthlyEnterpriseUuid =
      '3a72b071-a327-4336-9df9-4aebf04bd0e5'; // 110 CUP

  // Licencias Anuales (365 días)
  static const String _annualPersonalUuid =
      'UUID_ANNUAL_PERSONAL_AQUI'; // 500 CUP
  static const String _annualProUuid = 'UUID_ANNUAL_PRO_AQUI'; // 750 CUP
  static const String _annualEnterpriseUuid =
      'UUID_ANNUAL_ENTERPRISE_AQUI'; // 1000 CUP

  /// Obtiene el UUID para un tipo de licencia específico
  static String _getLicenseId(LicenseType licenseType) {
    switch (licenseType) {
      // Semanales
      case LicenseType.weeklyPersonal:
        return _weeklyPersonalUuid;
      case LicenseType.weeklyPro:
        return _weeklyProUuid;
      case LicenseType.weeklyEnterprise:
        return _weeklyEnterpriseUuid;

      // Mensuales
      case LicenseType.monthlyPersonal:
        return _monthlyPersonalUuid;
      case LicenseType.monthlyPro:
        return _monthlyProUuid;
      case LicenseType.monthlyEnterprise:
        return _monthlyEnterpriseUuid;

      // Anuales
      case LicenseType.annualPersonal:
        return _annualPersonalUuid;
      case LicenseType.annualPro:
        return _annualProUuid;
      case LicenseType.annualEnterprise:
        return _annualEnterpriseUuid;

      // Gratuita no tiene UUID
      case LicenseType.free:
        return '';
    }
  }

  /// Triggers the purchase flow for the specified license type.
  /// [licenseType] debe ser un tipo de licencia válido (no free)
  /// Returns [ApklisLicensePaymentStatus] para manejar errores/mensajes específicos.
  static Future<ApklisLicensePaymentStatus> purchase(
    LicenseType licenseType,
  ) async {
    if (licenseType == LicenseType.free) {
      return ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'No se puede comprar una licencia gratuita',
      );
    }

    final licenseId = _getLicenseId(licenseType);

    if (licenseId.isEmpty || licenseId.contains('UUID_')) {
      return ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error:
            'UUID de producto no configurado para ${_getLicenseName(licenseType)}',
      );
    }

    try {
      debugPrint(
        'ApklisService: Iniciando compra de ${licenseType.name} con UUID: $licenseId',
      );
      final status = await ApklisLicenseValidator.purchaseLicense(licenseId);
      debugPrint(
        'ApklisService: Respuesta recibida - paid: ${status.paid}, error: ${status.error}, statusCode: ${status.statusCode}',
      );
      return status;
    } on PlatformException catch (e) {
      debugPrint('PlatformException purchaseLicense: $e');
      return ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'Error al iniciar compra: ${e.message ?? e}',
      );
    } catch (e) {
      debugPrint('Error purchaseLicense: $e');
      return const ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'Error inesperado al comprar',
      );
    }
  }

  /// Verifies if the user has purchased the license.
  /// Returns [ApklisLicensePaymentStatus] for detailed info.
  static Future<ApklisLicensePaymentStatus> verify() async {
    try {
      final status = await ApklisLicenseValidator.verifyUserLicense(_packageId);
      return status;
    } on PlatformException catch (e) {
      debugPrint('PlatformException verifyUserLicense: $e');
      return ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'Error al verificar licencia: ${e.message ?? e}',
      );
    } catch (e) {
      debugPrint('Error verifyUserLicense: $e');
      return const ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'Error inesperado al verificar',
      );
    }
  }

  /// Simple boolean check for quick validation
  static Future<bool> isPurchased() async {
    final status = await verify();
    return status.paid;
  }

  /// Maps a license UUID to its corresponding LicenseType
  /// Returns null if UUID doesn't match any known license
  static LicenseType? getLicenseTypeFromUUID(String? uuid) {
    if (uuid == null) return null;

    // Semanales
    if (uuid == _weeklyPersonalUuid) return LicenseType.weeklyPersonal;
    if (uuid == _weeklyProUuid) return LicenseType.weeklyPro;
    if (uuid == _weeklyEnterpriseUuid) return LicenseType.weeklyEnterprise;

    // Mensuales
    if (uuid == _monthlyPersonalUuid) return LicenseType.monthlyPersonal;
    if (uuid == _monthlyProUuid) return LicenseType.monthlyPro;
    if (uuid == _monthlyEnterpriseUuid) return LicenseType.monthlyEnterprise;

    // Anuales
    if (uuid == _annualPersonalUuid) return LicenseType.annualPersonal;
    if (uuid == _annualProUuid) return LicenseType.annualPro;
    if (uuid == _annualEnterpriseUuid) return LicenseType.annualEnterprise;

    return null;
  }

  /// Obtiene el nombre legible del tipo de licencia
  static String _getLicenseName(LicenseType licenseType) {
    return licenseType.name.toUpperCase();
  }

  /// Verifica si un UUID está configurado (no es placeholder)
  static bool isUuidConfigured(LicenseType licenseType) {
    final uuid = _getLicenseId(licenseType);
    return uuid.isNotEmpty && !uuid.contains('UUID_') && !uuid.contains('AQUI');
  }

  /// Convierte los errores devueltos por Apklis a mensajes legibles
  static String humanizeError(String? rawError) {
    if (rawError == null || rawError.isEmpty) {
      return 'Error desconocido de Apklis';
    }

    String errorMsg = rawError;

    // Intentar interpretar como JSON
    try {
      if (errorMsg.trim().startsWith('{')) {
        final Map<String, dynamic> decoded = jsonDecode(errorMsg);
        
        // Traducir por el código de error PRIMERO si es posible
        if (decoded.containsKey('code')) {
          final code = decoded['code'].toString();
          if (code == 'already_paid') {
             return 'Ya posees una licencia activa.';
          } else if (code == 'not_paid') {
             return 'No se ha registrado el pago para esta licencia.';
          } else if (code == 'timeout') {
             return 'Tiempo de espera agotado al conectar con Apklis.';
          }
        }

        // Si no capturó el code, extraer el texto base de detail
        if (decoded.containsKey('detail')) {
          errorMsg = decoded['detail'].toString();
        }
      }
    } catch (_) {
      // Ignorar fallo de parseo JSON
    }

    // Traducciones genéricas heurísticas
    final lower = errorMsg.toLowerCase();
    
    if (lower.contains('already paid') || lower.contains('already_paid')) {
      return 'Ya posees una licencia activa.';
    }
    if (lower.contains('timeout')) {
      return 'Problemas de conexión con Apklis, intenta de nuevo.';
    }
    if (lower.contains('unauthorized') || lower.contains('credentials') || lower.contains('403')) {
      return 'Error de autenticación. Abre Apklis, asegúrate de haber iniciado sesión y vuelve a intentarlo.';
    }
    if (lower.contains('no se encontró') || lower.contains('not found')) {
      return 'No se ha registrado ningún pago para esta licencia.';
    }
    if (lower.contains('not published')) {
      return 'La licencia no se encuentra publicada en Apklis.';
    }
    
    // Si era algo en inglés (ejemplo un detail de la api no cazado genéricamente por "code")
    if (lower.contains('token is invalid') || lower.contains('signature')) {
      return 'Error validando la autenticidad con Apklis.';
    }

    // Limpieza final de restos de JSON si no logró decodificarse
    errorMsg = errorMsg
        .replaceAll('"}"', '')
        .replaceAll('{"', '')
        .replaceAll('"', '');

    return errorMsg;
  }
}
