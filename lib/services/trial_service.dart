import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../licences/license_type.dart';

/// Prueba gratuita de 48 horas y política de conservación de datos.
///
/// Reglas del producto:
///
/// - Al instalar la app, el usuario dispone de **48 horas** con todas las
///   funciones desbloqueadas, **excepto** IA, copias en Google Drive y copias
///   de seguridad locales, que siguen requiriendo un plan de pago.
/// - Si dentro de esas 48 horas adquiere un plan, sus datos se conservan y se
///   desbloquean las funciones de ese plan.
/// - Si la prueba termina y no hay plan activo, los datos financieros del
///   dispositivo se eliminan automáticamente **una sola vez**: después el
///   usuario puede seguir usando el plan gratuito con datos nuevos.
///
/// Todas las comprobaciones se basan en `SharedPreferences`, de modo que el
/// borrado puede ejecutarse en `main()` antes de que los providers abran Hive.
class TrialService {
  const TrialService._();

  /// Duración de la prueba gratuita.
  static const Duration duration = Duration(hours: 48);

  /// Fecha de inicio de la prueba (ISO-8601).
  static const String startKey = 'trial_start_date';

  /// Marca que los datos ya se borraron al terminar la prueba.
  static const String wipedKey = 'trial_data_wiped';

  /// Instalaciones anteriores a la prueba: nunca se les borran los datos.
  static const String exemptKey = 'trial_exempt';

  /// El usuario adquirió un plan durante la prueba: sus datos se conservan
  /// aunque el plan caduque más adelante.
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

  /// Preferencias que forman parte de los datos del usuario y se borran junto
  /// con las cajas. Se conservan el tema, el idioma, la licencia, la prueba,
  /// las credenciales de acceso y la configuración de notificaciones.
  static const List<String> userDataPrefs = <String>[
    'custom_banks',
    'custom_currencies',
    'exchange_rates',
    'exchange_rate',
    'google_user_display_name',
    'google_user_email',
    'google_user_photo_url',
    'google_user_is_connected',
    'streak_days',
    'login_dates',
    'last_login_date',
    'available_random_plans',
    'ads_watched',
    'transfermovil_enabled',
  ];

  /// En Windows la app se considera completamente desbloqueada tras la
  /// activación del equipo, así que no aplica la prueba.
  static bool get isDesktopUnlocked => !kIsWeb && Platform.isWindows;

  /// Devuelve la fecha de inicio de la prueba, creándola si es la primera vez.
  ///
  /// Si la app ya tenía datos antes de existir esta función, la instalación se
  /// marca como exenta: actualizar la app no debe borrar los datos de un
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

  /// Indica si la prueba está dentro de su ventana de 48 horas.
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

  /// Comprueba en `SharedPreferences` si existe un plan de pago vigente.
  ///
  /// Si el usuario ya convirtió durante la prueba, se considera pagado para
  /// siempre: la caducidad posterior del plan no borra sus datos.
  static bool hasPaidPlan(SharedPreferences prefs) {
    if (isDesktopUnlocked) return true;
    if (prefs.getBool(convertedKey) ?? false) return true;

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

  /// `true` si la prueba terminó sin plan y los datos aún no se han borrado.
  static Future<bool> shouldWipe() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(exemptKey) ?? false) return false;
    if (prefs.getBool(wipedKey) ?? false) return false;
    if (hasPaidPlan(prefs)) return false;

    final DateTime start = await startIfNeeded(prefs);
    return !isWithinWindow(start);
  }

  /// Ejecuta el borrado antes de que los providers abran Hive.
  ///
  /// Debe llamarse en `main()` después de registrar los adaptadores y antes de
  /// crear los providers, para que estos arranquen con las cajas vacías.
  /// Devuelve `true` si acaba de eliminar los datos.
  static Future<bool> enforceAtStartup() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await startIfNeeded(prefs);

    if (prefs.getBool(exemptKey) ?? false) return false;
    if (prefs.getBool(wipedKey) ?? false) return false;
    if (hasPaidPlan(prefs)) return false;

    final DateTime? start = DateTime.tryParse(
      prefs.getString(startKey) ?? '',
    );
    if (start == null || isWithinWindow(start)) return false;

    await wipeStorage(prefs);
    await markWiped();
    return true;
  }

  /// Borra las cajas y las preferencias de datos del usuario.
  ///
  /// Se usa desde [enforceAtStartup] (cajas cerradas) y desde el borrado en
  /// caliente al reanudar la app (cajas abiertas: en ese caso se vacían).
  static Future<void> wipeStorage(SharedPreferences prefs) async {
    for (final String name in dataBoxes) {
      try {
        if (Hive.isBoxOpen(name)) {
          await Hive.box<dynamic>(name).clear();
        } else if (await Hive.boxExists(name)) {
          await Hive.deleteBoxFromDisk(name);
        }
      } catch (_) {
        // Mejor esfuerzo: una caja dañada no debe impedir limpiar el resto.
      }
    }

    for (final String key in userDataPrefs) {
      await prefs.remove(key);
    }
  }

  /// Registra que el borrado por fin de prueba ya se realizó.
  static Future<void> markWiped() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(wipedKey, true);
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
