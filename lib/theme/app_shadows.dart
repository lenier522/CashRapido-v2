import 'package:material_ui/material_ui.dart';

import 'app_colors.dart';

abstract final class AppShadows {
  // ---------------------------------------------------------------------------
  // LIGHT
  // ---------------------------------------------------------------------------

  /// Sombra muy suave.
  static const List<BoxShadow> soft = [
    BoxShadow(color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  /// Sombra estándar para tarjetas.
  static const List<BoxShadow> card = [
    BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, 6)),
  ];

  /// Sombra más evidente para tarjetas principales.
  static const List<BoxShadow> elevated = [
    BoxShadow(color: Color(0x18000000), blurRadius: 24, offset: Offset(0, 10)),
  ];

  /// Sombra para elementos verdes.
  static List<BoxShadow> primary = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.22),
      blurRadius: 18,
      offset: const Offset(0, 7),
    ),
  ];

  /// Sombra para botones.
  static List<BoxShadow> primaryButton = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.24),
      blurRadius: 14,
      offset: const Offset(0, 6),
    ),
  ];

  // ---------------------------------------------------------------------------
  // DARK
  // ---------------------------------------------------------------------------

  static const List<BoxShadow> darkSoft = [
    BoxShadow(color: Color(0x50000000), blurRadius: 10, offset: Offset(0, 3)),
  ];

  static const List<BoxShadow> darkCard = [
    BoxShadow(color: Color(0x66000000), blurRadius: 18, offset: Offset(0, 7)),
  ];

  static List<BoxShadow> darkPrimary = [
    BoxShadow(
      color: AppColors.primary.withValues(alpha: 0.16),
      blurRadius: 20,
      offset: const Offset(0, 7),
    ),
  ];
}
