/// Datos identificativos de la aplicación, centralizados.
///
/// La versión debe coincidir con `version` de `pubspec.yaml`. Antes vivía
/// repetida en distintas pantallas; aquí queda una sola fuente de verdad para
/// los pies de página, «Acerca de», licencias e información legal.
abstract final class AppInfo {
  /// Nombre comercial de la aplicación.
  static const String name = 'CashRapido';

  /// Identificador del paquete en las tiendas.
  static const String packageId = 'cu.lenier.cashrapido';

  /// Versión visible (debe coincidir con `pubspec.yaml`).
  static const String version = '1.26.60';

  /// Número de compilación (debe coincidir con `pubspec.yaml`).
  static const String buildNumber = '34070185';

  /// Autor de la aplicación.
  static const String developer = 'Lenier Cruz Perez';

  /// Versión completa lista para mostrar.
  static const String fullVersion = '$version+$buildNumber';
}
