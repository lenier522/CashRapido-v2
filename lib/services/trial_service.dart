import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../licences/license_type.dart';

/// Prueba gratuita de 7 días y bloqueo de cuentas adicionales.
///
/// Reglas del producto:
///
/// - Al instalar la app, el usuario dispone de **7 días** con todas las
///   funciones desbloqueadas, **excepto** IA, copias en Google Drive y copias
///   de seguridad locales, que siguen requiriendo un plan de pago.
/// - Si dentro de esos 7 días adquiere un plan, sus datos se conservan y se
///   desbloquean las funciones de ese plan.
/// - Si la prueba termina y no hay un plan activo, **no se borra ningún dato**.
///   La cuenta principal sigue disponible y las cuentas adicionales quedan
///   bloqueadas hasta que el usuario active una licencia.
///
/// Todas las comprobaciones se basan en `SharedPreferences`, de modo que el
/// estado puede consultarse en `main()` antes de que los providers abran Hive.
class TrialService {
  const TrialService._();

  /// Duración de la prueba gratuita.
  static const Duration duration = Duration(days: 7);

  /// Fecha de inicio de la prueba (ISO-8601).
  static const String startKey = 'trial_start_date';

  /// Marca que el aviso de fin de prueba ya se mostró.
  static const String lockedNoticeKey = 'trial_lock_notice_shown';

  /// Instalaciones anteriores a la prueba: se mantienen sin bloqueo para no
  /// retirar cuentas que ya existían antes de esta política.
  static const String exemptKey = 'trial_exempt';

  /// El usuario adquirió un plan durante la prueba. Se conserva por
  /// compatibilidad con versiones anteriores; el bloqueo de cuentas depende de
  /// que exista un plan **vigente**, no de esta marca.
  static const String convertedKey = 'trial_converted';

  /// Cajas Hive que contienen datos del usuario.
  static const List<String> dataBoxes = <String>[
    // Cartera
    'transactions',
    'categories',
    'cards',
    'recurring_transactions',
    'notifications',
    // Negocio
    'businesses',
    'products',
    'sales',
    'business_expenses',
    'closings',
    'product_categories',
    'sellers',
    'seller_inventory',
    // Préstamos
    'loans',
    'loan_payments',
    'borrowers',
    'loan_activities',
    // Chat IA
    'ai_chats',
  ];

  /// En Windows la app se considera completamente desbloqueada tras la
  /// activación del equipo, así que no aplica la prueba.
  static bool get isDesktopUnlocked => !kIsWeb && Platform.isWindows;

  /// Devuelve la fecha de inicio de la prueba, creándola si es la primera vez.
  ///
  /// Si la app ya tenía datos antes de existir esta función, la instalación se
  /// marca como exenta: actualizar la app no debe bloquear cuentas de un
  /// usuario que ya la usaba.
  static Future<DateTime> startIfNeeded(SharedPreferences prefs) async {
    final String? raw = prefs.getString(startKey);
    final DateTime? stored = raw == null ? null : DateTime.tryParse(raw);
    if (stored != null) return stored;

    final DateTime now = DateTime.now();
    final bool returningUser =
        (prefs.getBool('seenOnboarding') ?? false) || await _hasStoredData();
    if (returningUser) {
      await prefs.setBool(exemptKey, true);
    }
    await prefs.setString(startKey, now.toIso8601String());
    return now;
  }

  /// Indica si la prueba está dentro de su ventana de 7 días.
  static bool isWithinWindow(DateTime start, [DateTime? now]) {
    return (now ?? DateTime.now()).isBefore(start.add(duration));
  }

  /// Fin de la prueba a partir de su fecha de inicio.
  static DateTime endsAt(DateTime start) => start.add(duration);

  /// Tiempo restante de prueba (nunca negativo).
  static Duration remaining(DateTime start) {
    final Duration left = endsAt(start).difference(DateTime.now());
    return left.isNegative ? Duration.zero : left;
  }

  /// Comprueba si existe un plan de pago **vigente**.
  ///
  /// A diferencia de [hasPaidPlan], ignora la marca histórica
  /// [convertedKey]: un plan caducado no desbloquea las cuentas adicionales.
  static bool hasActivePlan(SharedPreferences prefs) {
    if (isDesktopUnlocked) return true;

    final int index = prefs.getInt('license_type') ?? LicenseType.free.index;
    if (index < 0 || index >= LicenseType.values.length) return false;

    final LicenseType type = LicenseType.values[index];
    if (type == LicenseType.free) return false;

    DateTime? expires;
    final String? exact = prefs.getString('license_expiration_date');
    if (exact != null) {
      expires = DateTime.tryParse(exact);
    } else {
      final String? activation = prefs.getString('license_activation_date');
      final DateTime? parsed = activation == null
          ? null
          : DateTime.tryParse(activation);
      if (parsed != null) {
        final int days = type.durationDays > 0 ? type.durationDays : 30;
        expires = parsed.add(Duration(days: days));
      }
    }

    // Plan de pago sin fecha conocida: se conserva por seguridad.
    if (expires == null) return true;
    return !DateTime.now().isAfter(expires);
  }

  /// Comprueba si existe un plan de pago o si el usuario ya convirtió alguna
  /// vez. Se conserva para decidir la conservación histórica de datos.
  static bool hasPaidPlan(SharedPreferences prefs) {
    if (isDesktopUnlocked) return true;
    if (prefs.getBool(convertedKey) ?? false) return true;
    return hasActivePlan(prefs);
  }

  /// `true` si la prueba terminó sin un plan vigente.
  static Future<bool> isExpiredWithoutPlan() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(exemptKey) ?? false) return false;
    if (hasActivePlan(prefs)) return false;

    final DateTime start = await startIfNeeded(prefs);
    return !isWithinWindow(start);
  }

  /// Comprueba el estado al arrancar y marca el aviso de fin de prueba.
  ///
  /// No borra datos. Devuelve `true` si acaba de detectarse el vencimiento y
  /// corresponde mostrar el aviso al usuario.
  static Future<bool> enforceAtStartup() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await startIfNeeded(prefs);
    return _markLockNoticeIfNeeded(prefs);
  }

  /// Comprueba el vencimiento en caliente (por ejemplo, al reanudar la app).
  ///
  /// Devuelve `true` solo la primera vez que se detecta el fin de prueba.
  static Future<bool> lockIfExpired() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return _markLockNoticeIfNeeded(prefs);
  }

  static Future<bool> _markLockNoticeIfNeeded(SharedPreferences prefs) async {
    if (prefs.getBool(exemptKey) ?? false) return false;
    if (hasActivePlan(prefs)) return false;

    final DateTime? start = DateTime.tryParse(prefs.getString(startKey) ?? '');
    if (start == null || isWithinWindow(start)) return false;

    final bool alreadyShown = prefs.getBool(lockedNoticeKey) ?? false;
    if (!alreadyShown) {
      await prefs.setBool(lockedNoticeKey, true);
    }
    return !alreadyShown;
  }

  /// Limpia la marca de aviso para que un nuevo vencimiento vuelva a avisar.
  static Future<void> resetLockNotice() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(lockedNoticeKey);
  }

  /// `true` si alguna caja existente ya contiene datos.
  ///
  /// Las cajas se abren y se cierran de inmediato: los providers las abren más
  /// tarde con su tipo concreto y Hive no permite reabrir una caja ya abierta
  /// con otro parámetro genérico.
  static Future<bool> _hasStoredData() async {
    for (final String name in dataBoxes) {
      try {
        if (!await Hive.boxExists(name)) continue;
        final Box<dynamic> box = await Hive.openBox<dynamic>(name);
        final bool hasData = box.isNotEmpty;
        await box.close();
        if (hasData) return true;
      } catch (_) {
        // Caja ilegible: se ignora para no bloquear el arranque.
      }
    }
    return false;
  }
}
