import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Catálogo ÚNICO de colores para categorías.
///
/// De aquí salen los 64 colores del selector (grid de 8×8) y también el color
/// de las categorías por defecto. No existe otra lista de colores en la
/// aplicación: `AddCategoryScreen` y cualquier picker futuro deben consumir
/// este catálogo.
class CategoryColorOptions {
  CategoryColorOptions._();

  /// 64 colores diferenciables, distribuidos por familias (rojos, rosas,
  /// corales, naranjas, ámbares, amarillos, verdes CashRapido, esmeraldas,
  /// turquesas, cianes, azules, azul oscuro, índigos, morados, violetas,
  /// magentas, marrones, grises, negros y semánticos).
  ///
  /// Es una cuadrícula de 8 columnas × 8 filas en la UI.
  static const List<Color> colors = <Color>[
    // Rojos
    Color(0xFFE53935), // Red 600
    Color(0xFFEF5350), // Red 400
    Color(0xFFC62828), // Red 800
    Color(0xFFB71C1C), // Red 900
    // Rosas
    Color(0xFFEC407A), // Pink 400
    Color(0xFFD81B60), // Pink 600
    Color(0xFFC2185B), // Pink 700
    // Corales
    Color(0xFFF44336), // Red 500
    Color(0xFFFF7043), // Deep Orange 400
    Color(0xFFFF5722), // Deep Orange 500
    // Naranjas
    Color(0xFFFF6E40), // Deep Orange 300
    Color(0xFFFF9800), // Orange 500
    Color(0xFFF57C00), // Orange 700
    // Ámbares
    Color(0xFFFFA000), // Amber 700
    Color(0xFFFFC107), // Amber 500
    // Amarillos
    Color(0xFFFFEB3B), // Yellow 500
    Color(0xFFFDD835), // Yellow 600
    Color(0xFFFBC02D), // Yellow 700
    // Gama verde CashRapido
    Color(0xFF65E69B), // rampa clara
    Color(0xFF18C96E), // AppColors.primary
    Color(0xFF0FAE5B), // AppColors.primaryDark
    Color(0xFF087A40), // AppColors.primaryDeep
    // Verdes
    Color(0xFF66BB6A), // Green 400
    Color(0xFF43A047), // Green 600
    Color(0xFF2E7D32), // Green 800
    // Verdes claros
    Color(0xFF8BC34A), // Light Green 500
    Color(0xFF9CCC65), // Light Green 400
    // Limas
    Color(0xFFCDDC39), // Lime 500
    Color(0xFFD4E157), // Lime 400
    // Esmeraldas
    Color(0xFF1FAF78), // AppColors.secondary
    Color(0xFF26A69A), // Teal 400
    Color(0xFF009688), // Teal 500
    // Turquesas / cianes
    Color(0xFF26C6DA), // Cyan 400
    Color(0xFF00BCD4), // Cyan 500
    Color(0xFF00ACC1), // Cyan 600
    // Azules
    Color(0xFF42A5F5), // Blue 400
    Color(0xFF2196F3), // Blue 500
    Color(0xFF1E88E5), // Blue 600
    Color(0xFF1976D2), // Blue 700
    // Azules profundos
    Color(0xFF1565C0), // Blue 800
    Color(0xFF0D47A1), // Blue 900
    Color(0xFF01579B), // Light Blue 900
    // Índigos
    Color(0xFF5C6BC0), // Indigo 400
    Color(0xFF3F51B5), // Indigo 500
    Color(0xFF303F9F), // Indigo 700
    // Morados
    Color(0xFF7E57C2), // Deep Purple 400
    Color(0xFF673AB7), // Deep Purple 500
    Color(0xFF5E35B1), // Deep Purple 600
    // Violetas
    Color(0xFF512DA8), // Deep Purple 700
    Color(0xFF6A1B9A), // Purple 800
    Color(0xFF4A148C), // Purple 900
    // Magentas
    Color(0xFFBA68C8), // Purple 300
    Color(0xFFAB47BC), // Purple 400
    Color(0xFF9C27B0), // Purple 500
    // Marrones
    Color(0xFFA1887F), // Brown 300
    Color(0xFF8D6E63), // Brown 400
    Color(0xFF6D4C41), // Brown 600
    // Grises y negro
    Color(0xFF90A4AE), // Blue Grey 300
    Color(0xFF607D8B), // Blue Grey 500
    Color(0xFF455A64), // Blue Grey 700
    Color(0xFF263238), // Blue Grey 900
    // Semánticos CashRapido
    Color(0xFF16A765), // AppColors.income
    Color(0xFFE45757), // AppColors.expense
    Color(0xFFF59E0B), // AppColors.warning
  ];

  /// Número exacto de colores disponibles (>= 50 por diseño).
  static int get count => colors.length;

  /// Color legible (claro u oscuro) sobre un fondo dado.
  ///
  /// Usa la luminancia para garantizar contraste suficiente: fondos claros
  /// obtienen icono oscuro y fondos oscuros icono claro.
  static Color contrastForeground(Color background) =>
      background.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;

  /// Gama CashRapido, útil para sugerencias o para el selector futuro de color
  /// personalizado (hue normalizado sobre la identidad de marca).
  static const List<Color> brandRamp = <Color>[
    AppColors.primaryLight,
    AppColors.primary,
    AppColors.primaryDark,
    AppColors.primaryDeep,
  ];
}
