import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'cash_card.dart';

/// Superficie visual para un gráfico dentro del Design System.
///
/// El gráfico nunca se dibuja directamente sobre el `Scaffold`: siempre vive
/// sobre una `CashCard`, con título, subtítulo y acción opcional. Además
/// centraliza el estilo de `fl_chart` (rejilla, ejes, tooltip) para que todos
/// los gráficos de la aplicación se vean igual y respondan al modo claro y
/// oscuro.
class CashChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget chart;

  /// Alto del gráfico. Si se omite se calcula con [heightFor].
  final double? height;

  const CashChartCard({
    super.key,
    required this.title,
    required this.chart,
    this.subtitle,
    this.action,
    this.height,
  });

  /// Alto adaptsivo: más alto cuanto más espacio hay, sin llegar nunca a
  /// comprimir el gráfico ni a Stretcharlo en tablets.
  static double heightFor(double availableWidth) {
    if (availableWidth >= 720) return 260;
    if (availableWidth >= 480) return 230;
    if (availableWidth >= 340) return 205;
    return 185;
  }

  /// Color de la rejilla: presente pero casi imperceptible.
  static Color gridColor(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary)
        .withValues(alpha: 0.06);
  }

  /// Color del texto de los ejes.
  static Color axisColor(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textTertiaryDark : AppColors.textTertiary;
  }

  /// Fondo del tooltip al tocar el gráfico.
  static Color tooltipColor(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.surfaceDark3 : AppColors.textPrimary;
  }

  /// Color del texto dentro del tooltip.
  static Color tooltipTextColor(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textPrimaryDark : AppColors.backgroundLight;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (action != null) ...[
                const SizedBox(width: AppSpacing.sm),
                action!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            height: height ?? heightFor(MediaQuery.sizeOf(context).width),
            width: double.infinity,
            child: chart,
          ),
        ],
      ),
    );
  }
}
