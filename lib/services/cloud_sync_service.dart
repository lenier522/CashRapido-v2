import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'cloud_codec.dart';
import 'supabase_service.dart';

/// Copia de los datos del usuario en Supabase.
///
/// La app sigue siendo local-first: Hive manda y esta capa solo replica el
/// paquete completo en la nube, aislado por usuario con RLS. Se sube todo el
/// snapshot con una sola llamada atómica (`cloud_replace_data`) y se recupera
/// con otra (`cloud_export_data`), así que no hay estados intermedios ni
/// registros duplicados.
abstract final class CloudSyncService {
  /// Mismas colecciones que respalda la app en local.
  static const List<String> tables = <String>[
    'transactions',
    'categories',
    'cards',
    'recurring_transactions',
    'notifications',
    'businesses',
    'products',
    'sales',
    'business_expenses',
    'closings',
    'product_categories',
    'sellers',
    'seller_inventory',
    'loans',
    'loan_payments',
    'borrowers',
    'loan_activities',
    'ai_chats',
  ];

  static const String _autoKey = 'cloud_auto_sync';
  static const String _lastSyncKey = 'cloud_last_sync';

  static bool _autoSync = true;
  static bool _running = false;
  static bool _attached = false;
  static DateTime? _lastSync;
  static String? _lastError;
  static Timer? _debounce;
  static final List<Listenable> _sources = <Listenable>[];

  /// Comprobación de licencia de la app. La nube es de pago: si el plan no
  /// está vigente, ni la subida automática ni las manuales deben ejecutarse.
  static bool Function()? _licenseCheck;

  /// Vincula la sincronización a la licencia actual.
  ///
  /// Sin este enlace (por ejemplo en pruebas) se permite sincronizar, para no
  /// acoplar el servicio a la UI ni romper los tests existentes.
  static void bindLicenseCheck(bool Function() check) {
    _licenseCheck = check;
  }

  static bool get _canUseCloud => _licenseCheck?.call() ?? true;

  /// Cajas abiertas por los proveedores. Se guardan aquí porque Hive no deja
  /// obtener una caja ya abierta con otro tipo genérico (`Box<dynamic>`).
  static final Map<String, Box<dynamic>> _boxes = <String, Box<dynamic>>{};

  /// Registra cajas ya abiertas para poder leerlas y reemplazarlas.
  static void registerBoxes(Map<String, Box<dynamic>> boxes) {
    _boxes.addAll(boxes);
  }

  @visibleForTesting
  static Box<dynamic>? boxFor(String name) => _openBox(name);

  /// `true` si hay una cuenta conectada y se puede hablar con la nube.
  static bool get isSignedIn => SupabaseService.isSignedIn;

  static bool get isSyncing => _running;

  static bool get autoSyncEnabled => _autoSync;

  static DateTime? get lastSync => _lastSync;

  static String? get lastError => _lastError;

  /// Prepara la sincronización automática y escucha los cambios de la app.
  static Future<void> attach(List<Listenable> sources) async {
    if (_attached) return;
    _attached = true;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    _autoSync = prefs.getBool(_autoKey) ?? true;
    final String? raw = prefs.getString(_lastSyncKey);
    _lastSync = raw == null ? null : DateTime.tryParse(raw);
    _sources.addAll(sources);
    for (final Listenable source in _sources) {
      source.addListener(_schedulePush);
    }
  }

  /// Activa o desactiva el guardado automático tras cada cambio.
  static Future<void> setAutoSync(bool enabled) async {
    _autoSync = enabled;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoKey, enabled);
    if (enabled) _schedulePush();
  }

  static void _schedulePush() {
    if (!_autoSync || !isSignedIn || !_canUseCloud) return;
    _debounce?.cancel();
    // Se espera a que el usuario termine de editar para no subir en cada tecla.
    _debounce = Timer(const Duration(seconds: 6), () {
      pushNow().catchError((Object e) {
        debugPrint('Copia automática fallida: $e');
        return false;
      });
    });
  }

  /// Sube el paquete completo del usuario. Devuelve `false` si no hay sesión
  /// o si la nube rechazó la operación (el detalle queda en [lastError]).
  static Future<bool> pushNow() async {
    if (!isSignedIn) {
      _lastError = 'no_session';
      return false;
    }
    if (!_canUseCloud) {
      _lastError = 'license_required';
      return false;
    }
    if (_running) return false;
    _running = true;
    try {
      final Map<String, List<Map<String, dynamic>>> payload =
          <String, List<Map<String, dynamic>>>{};

      for (final String table in tables) {
        final Box<dynamic>? box = _openBox(table);
        if (box == null) continue;
        final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
        for (final dynamic value in box.values) {
          final String? id = CloudCodec.idOf(value);
          if (id == null) continue;
          rows.add(<String, dynamic>{
            'id': id,
            'data': CloudCodec.toJson(value),
          });
        }
        payload[table] = rows;
      }

      if (payload.isEmpty) {
        _lastError = 'no_boxes';
        return false;
      }

      await SupabaseService.client.rpc(
        'cloud_replace_data',
        params: <String, dynamic>{'payload': payload},
      );

      _lastSync = DateTime.now();
      _lastError = null;
      await _persistLastSync();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error subiendo a Supabase: $e');
      return false;
    } finally {
      _running = false;
    }
  }

  /// Reemplaza los datos locales por los de la nube.
  ///
  /// Devuelve `false` si no hay sesión, si la nube no responde o si la cuenta
  /// todavía no tiene ninguna copia.
  static Future<bool> pullNow() async {
    if (!isSignedIn) {
      _lastError = 'no_session';
      return false;
    }
    if (!_canUseCloud) {
      _lastError = 'license_required';
      return false;
    }
    if (_running) return false;
    _running = true;
    try {
      final dynamic raw = await SupabaseService.client.rpc('cloud_export_data');
      if (raw is! Map) {
        _lastError = 'bad_response';
        return false;
      }

      // Primero se decodifica todo. Las cajas locales no se tocan hasta saber
      // que la cuenta tiene una copia real: así una cuenta vacía o una
      // respuesta incompleta nunca borra los datos del dispositivo.
      final Map<String, List<Object>> decoded = <String, List<Object>>{};
      bool anyData = false;

      for (final String table in tables) {
        if (_openBox(table) == null) continue;

        final List<dynamic> rows = (raw[table] as List?) ?? const <dynamic>[];
        final List<Object> values = <Object>[];
        for (final dynamic row in rows) {
          if (row is! Map) continue;
          final Map<String, dynamic> data = Map<String, dynamic>.from(
            (row['data'] as Map?) ?? const <String, dynamic>{},
          );
          try {
            values.add(CloudCodec.fromJson(table, data));
          } catch (e) {
            debugPrint('Registro ignorado en $table: $e');
          }
        }

        // Si la nube trae filas pero ninguna se pudo leer (versión distinta),
        // se deja la colección local intacta en vez de vaciarla.
        if (rows.isNotEmpty && values.isEmpty) {
          debugPrint('Se omite $table: ningún registro legible');
          continue;
        }

        if (values.isNotEmpty) anyData = true;
        decoded[table] = values;
      }

      if (!anyData) {
        _lastError = 'empty_cloud';
        return false;
      }

      for (final MapEntry<String, List<Object>> entry in decoded.entries) {
        final Box<dynamic>? box = _openBox(entry.key);
        if (box == null) continue;
        await box.clear();
        if (entry.value.isNotEmpty) await box.addAll(entry.value);
      }

      _lastSync = DateTime.now();
      _lastError = null;
      await _persistLastSync();
      return true;
    } catch (e) {
      _lastError = e.toString();
      debugPrint('Error recuperando de Supabase: $e');
      return false;
    } finally {
      _running = false;
    }
  }

  static Box<dynamic>? _openBox(String name) {
    final Box<dynamic>? box = _boxes[name];
    if (box == null || !box.isOpen) return null;
    return box;
  }

  static Future<void> _persistLastSync() async {
    if (_lastSync == null) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastSyncKey, _lastSync!.toIso8601String());
  }
}
