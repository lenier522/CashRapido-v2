import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class CashStatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color? iconColor;
  final String? trend;
  final bool? trendPositive;

  /// Cuando es `true`, una bajada se considera una buena noticia.
  ///
  /// En un gasto, reducir el importe es algo positivo aunque la métrica baje,
  /// así que el distintivo se pinta en verde aunque la flecha apunte hacia
  /// abajo. Sin este distintivo el componente mantiene su lectura literal: una
  /// bajada es mala noticia.
  final bool trendGoodWhenDown;

  final VoidCallback? onTap;
  final double? width;

  const CashStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    this.iconColor,
    this.trend,
    this.trendPositive,
    this.trendGoodWhenDown = false,
    this.onTap,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color primaryText = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;

    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final Color accent = iconColor ?? AppColors.primary;

    final Widget content = Container(
      width: width,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: AppRadius.radiusMd,
            ),
            child: Icon(icon, color: accent, size: 21),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: secondaryText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: primaryText,
              fontWeight: FontWeight.w700,
            ),
          ),
          // El distintivo va debajo de la cifra y no junto al icono: en una
          // tarjeta estrecha la fila se queda sin espacio y el importe, que es
          // lo que más importa, se recortaba antes que el porcentaje.
          if (trend != null) ...[
            const SizedBox(height: AppSpacing.sm),
            _TrendBadge(
              value: trend!,
              positive: trendPositive ?? true,
              goodWhenDown: trendGoodWhenDown,
            ),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return content;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: content,
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final String value;

  /// Sentido literal de la variación: `false` significa que la métrica bajó.
  final bool positive;

  final bool goodWhenDown;

  const _TrendBadge({
    required this.value,
    required this.positive,
    required this.goodWhenDown,
  });

  @override
  Widget build(BuildContext context) {
    final bool isGood = positive || (goodWhenDown && !positive);
    final Color color = isGood ? AppColors.income : AppColors.expense;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.full == 999
            ? BorderRadius.circular(999)
            : AppRadius.radiusSm,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            value,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
