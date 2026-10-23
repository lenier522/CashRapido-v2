import 'package:material_ui/material_ui.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Selector de tipo de categoría: Gasto / Ingreso / Ambos.
///
/// Presentacional: no guarda estado ni decide nada; informa del valor
/// seleccionado y delega el cambio en [onChanged]. El estado seleccionado no
/// depende sólo del color: incluye borde e icono de verificación.
class CashCategoryTypeSelector extends StatelessWidget {
  /// `CategoryTypes.expense`, `CategoryTypes.income` o `CategoryTypes.both`.
  final String selected;
  final ValueChanged<String> onChanged;

  const CashCategoryTypeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  String _label(BuildContext context, String type) {
    switch (type) {
      case 'expense':
        return context.t('type_expense');
      case 'income':
        return context.t('type_income');
      default:
        return context.t('type_both');
    }
  }

  IconData _icon(String type) {
    switch (type) {
      case 'expense':
        return Icons.arrow_upward_rounded;
      case 'income':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.swap_horiz_rounded;
    }
  }

  Color _accent(String type) {
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

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xxs + AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceVariantLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          for (final String type in const <String>[
            'expense',
            'income',
            'both',
          ]) ...[
            if (type != 'expense') const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _Segment(
                type: type,
                label: _label(context, type),
                icon: _icon(type),
                accent: _accent(type),
                isSelected: type == selected,
                onTap: () => onChanged(type),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  final String type;
  final String label;
  final IconData icon;
  final Color accent;
  final bool isSelected;
  final VoidCallback onTap;

  const _Segment({
    required this.type,
    required this.label,
    required this.icon,
    required this.accent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fg = isSelected
        ? accent
        : isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? accent.withValues(alpha: isDark ? 0.20 : 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.sm),
            border: isSelected
                ? Border.all(color: accent.withValues(alpha: 0.55))
                : Border.all(color: Colors.transparent),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: AppSpacing.xs),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.check_rounded, size: 14, color: fg),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
