import 'package:package_info_plus/package_info_plus.dart';

/// Datos identificativos de la aplicación, centralizados.
///
/// Obtiene dinámicamente la información real del paquete mediante
/// `package_info_plus`, manteniéndose siempre sincronizado con `pubspec.yaml`
/// y con el archivo APK instalado.
abstract final class AppInfo {
  static String _name = 'CashRapido';
  static String _packageId = 'cu.lenier.cashrapido';
  static String _version = '2.8.45';
  static String _buildNumber = '40000000';

  /// Autor de la aplicación.
  static const String developer = 'Lenier Cruz Perez';

  /// Inicializa los datos de versión dinámicamente desde la plataforma.
  static Future<void> initialize() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (info.appName.isNotEmpty) _name = info.appName;
      if (info.packageName.isNotEmpty) _packageId = info.packageName;
      if (info.version.isNotEmpty) _version = info.version;
      if (info.buildNumber.isNotEmpty) _buildNumber = info.buildNumber;
    } catch (_) {
      // Si falla (ej. entorno de pruebas o escritorio), mantiene los valores por defecto
    }
  }

  /// Nombre comercial de la aplicación.
  static String get name => _name;

  /// Identificador del paquete en las tiendas.
  static String get packageId => _packageId;

  /// Versión visible (debe coincidir con la instalada).
  static String get version => _version;

  /// Número de compilación.
  static String get buildNumber => _buildNumber;

  /// Versión completa lista para mostrar.
  static String get fullVersion => '$_version+$_buildNumber';
}
