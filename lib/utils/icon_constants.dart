import 'package:material_ui/material_ui.dart';

import 'category_icon_registry.dart';

/// Resolución de iconos de categoría.
///
/// Este archivo sigue existiendo por compatibilidad, pero ya NO es la fuente
/// de verdad: todos los iconos viven en [CategoryIconRegistry] (con nombre,
/// keywords, grupo y codePoint). Mantener dos catálogos en paralelo provocaría
/// iconos rotos, así que [getCategoryIcon] delega en el registro único, que a
/// su vez conserva los alias de los catálogos antiguos.
class IconConstants {
  IconConstants._();

  /// Resuelve el icono de un `iconCode` guardado, con fallback seguro.
  ///
  /// Compatible con todos los iconos antiguos y con las categorías por
  /// defecto; nunca lanza.
  static IconData getCategoryIcon(int codePoint) =>
      CategoryIconRegistry.resolve(codePoint);
}
