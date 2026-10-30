import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Iconos disponibles para la app.
///
/// [halloween] y [navidad] son **estacionales**: se aplican automáticamente
/// en sus fechas y nunca se muestran en el selector. El resto ([default],
/// [playa], [mar]) son los que el usuario con licencia Empresarial puede
/// elegir.
enum AppIconVariant {
  defaultIcon('default'),
  playa('playa'),
  mar('mar'),
  halloween('halloween'),
  navidad('navidad');

  const AppIconVariant(this.key);

  /// Clave que se envía al lado nativo (alias del launcher).
  final String key;

  /// Nombre de la vista previa en `assets/icons/app_icons/`.
  ///
  /// Solo los iconos visibles tienen imagen; los estacionales se resuelven
  /// en el lado nativo y no necesitan preview en el selector.
  String get previewAsset => 'assets/icons/app_icons/$key.png';
}

/// Servicio que cambia el icono de la app en la pantalla de inicio.
///
/// Android no permite reescribir `android:icon` en tiempo de ejecución; en su
/// lugar se declara un `<activity-alias>` por icono en el `AndroidManifest`
/// y se activa el alias elegido mediante `PackageManager`. Esta clase expone
/// ese mecanismo por un [MethodChannel] y aplica las reglas de negocio:
///
/// * Se puede cambiar de icono **solo** con licencia Empresarial activa.
/// * Al expirar la licencia se vuelve al icono por defecto.
/// * En fechas concretas (Halloween y Navidad) se fuerza el icono estacional
///   para todos los usuarios, sin mostrarlo en el selector.
class AppIconService {
  AppIconService._();

  static const MethodChannel _channel = MethodChannel('cashrapido/app_icon');
  static const String _selectedKey = 'app_icon_selected';

  /// Aplica el icono que corresponde según licencia y fecha.
  ///
  /// [isEnterpriseActive] debe reflejar si la licencia Empresarial sigue
  /// vigente. Se llama al arrancar y cada vez que cambia la licencia.
  ///
  /// Devuelve `true` si el lado nativo pudo aplicar el icono. En los builds de
  /// desarrollo (debug/profile) los aliases no existen en el manifest y
  /// devuelve `false`: el icono solo se cambia en la versión instalada.
  static Future<bool> applyForLicense({
    required bool isEnterpriseActive,
    String? selectedKey,
  }) async {
    // En depuración se fuerza siempre el icono por defecto.
    //
    // Además, los manifests de `src/debug` y `src/profile` eliminan los
    // aliases y convierten a `MainActivity` en el lanzador: `flutter run`
    // elige el componente MAIN/LAUNCHER de forma estática a partir del
    // manifest, de modo que así arranca siempre, aunque otra elección o una
    // ventana estacional hubieran dejado un alias deshabilitado (de lo
    // contrario el arranque fallaría con "Activity class ... does not exist"
    // antes de que la app pudiera ejecutarse).
    //
    // Esta llamada queda como red de seguridad por si los aliases volvieran
    // a existir en un build de desarrollo: el lado nativo ignora los
    // componentes ausentes, así que en debug es un simple no-op.
    if (kDebugMode) {
      await apply(AppIconVariant.defaultIcon);
      return false;
    }

    final AppIconVariant target = resolve(
      now: DateTime.now(),
      isEnterpriseActive: isEnterpriseActive,
      selectedKey: selectedKey,
    );
    return apply(target);
  }

  /// Determina el icono objetivo sin tocar el canal.
  ///
  /// Orden de prioridad:
  /// 1. Icono estacional de la fecha (si aplica), para cualquier usuario.
  /// 2. Icono elegido por el usuario, solo si la licencia Empresarial está
  ///    activa.
  /// 3. Icono por defecto.
  static AppIconVariant resolve({
    required DateTime now,
    required bool isEnterpriseActive,
    String? selectedKey,
  }) {
    final AppIconVariant? seasonal = seasonalFor(now);
    if (seasonal != null) return seasonal;

    if (isEnterpriseActive && selectedKey != null) {
      final AppIconVariant? selected = byKey(selectedKey);
      if (selected != null) return selected;
    }
    return AppIconVariant.defaultIcon;
  }

  /// Icono estacional correspondiente a [now], o `null` si no hay ninguno.
  ///
  /// Halloween: del 25 al 31 de octubre.
  /// Navidad: del 20 de diciembre al 6 de enero.
  static AppIconVariant? seasonalFor(DateTime now) {
    final int month = now.month;
    final int day = now.day;

    // Halloween: 25–31 de octubre.
    if (month == 10 && day >= 25) return AppIconVariant.halloween;

    // Navidad: 20 de diciembre (incluido) hasta el 6 de enero.
    if ((month == 12 && day >= 20) || (month == 1 && day <= 6)) {
      return AppIconVariant.navidad;
    }
    return null;
  }

  /// Traduce una clave guardada a su variante; `null` si no existe.
  static AppIconVariant? byKey(String? key) {
    if (key == null) return null;
    for (final AppIconVariant variant in AppIconVariant.values) {
      if (variant.key == key) return variant;
    }
    return null;
  }

  /// Icono actualmente elegido (persistido), o el por defecto.
  static Future<String?> selectedKey() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_selectedKey);
  }

  /// Persiste la elección del usuario. No aplica el icono: eso lo decide
  /// [applyForLicense] para respetar la licencia y las fechas estacionales.
  static Future<void> saveSelected(AppIconVariant variant) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_selectedKey, variant.key);
  }

  /// Notifica al lado nativo que debe mostrarse [variant].
  ///
  /// Devuelve `true` si el alias existe en este build y se aplicó. En
  /// debug/profile los aliases se eliminan del manifest, por lo que devuelve
  /// `false` (no es un error: el icono solo se cambia en release).
  static Future<bool> apply(AppIconVariant variant) async {
    try {
      final bool? applied = await _channel.invokeMethod<bool>('setIcon', {
        'key': variant.key,
      });
      return applied ?? false;
    } on MissingPluginException {
      // Plataformas sin el alias nativo (p. ej. escritorio): se ignora.
      return false;
    } on PlatformException {
      // Un fallo del PackageManager no debe romper la app.
      return false;
    }
  }
}
