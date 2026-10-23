import 'package:material_ui/material_ui.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_shadows.dart';
import '../../utils/category_color_options.dart';

/// Vista previa en tiempo real de la categoría.
///
/// Reacciona a nombre, tipo, icono y color. El foreground del icono se calcula
/// con [CategoryColorOptions.contrastForeground] para mantener contraste sobre
/// cualquier color de fondo, claro u oscuro.
class CashCategoryPreview extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color color;

  /// `CategoryTypes.expense`, `CategoryTypes.income` o `CategoryTypes.both`.
  final String type;

  const CashCategoryPreview({
    super.key,
    required this.name,
    required this.icon,
    required this.color,
    required this.type,
  });

  String _typeLabel(BuildContext context) {
    switch (type) {
      case 'expense':
        return context.t('type_expense');
      case 'income':
        return context.t('type_income');
      default:
        return context.t('type_both');
    }
  }

  IconData _typeIcon() {
    switch (type) {
      case 'expense':
        return Icons.arrow_upward_rounded;
      case 'income':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _typeAccent() {
    switch (type) {
      case 'expense':
        return AppColors.expense;
      case 'income':
        return AppColors.income;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surface = isDark
        ? AppColors.surfaceDark2
        : AppColors.surfaceLight;
    final Color bodyColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final Color fore = CategoryColorOptions.contrastForeground(color);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, size: 44, color: fore),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            name.trim().isEmpty ? context.t('cat_name_hint') : name.trim(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: _typeAccent().withValues(alpha: isDark ? 0.18 : 0.10),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(_typeIcon(), size: 14, color: _typeAccent()),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  _typeLabel(context),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: _typeAccent(),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.t('cat_preview_label'),
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: bodyColor),
          ),
        ],
      ),
    );
  }
}
