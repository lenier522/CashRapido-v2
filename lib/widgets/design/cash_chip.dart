import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class CashChip extends StatelessWidget {
  final String label;
  final bool selected;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;

  const CashChip({
    super.key,
    required this.label,
    this.selected = false,
    this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color accent = color ?? AppColors.primary;

    final Color backgroundColor;

    if (selected) {
      backgroundColor = isDark
          ? accent.withValues(alpha: 0.18)
          : accent.withValues(alpha: 0.10);
    } else {
      backgroundColor = isDark
          ? AppColors.surfaceDark2
          : AppColors.surfaceVariantLight;
    }

    final Color foregroundColor = selected
        ? accent
        : isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final Widget content = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: selected
            ? Border.all(color: accent.withValues(alpha: 0.25))
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: AppSpacing.xs),
          ],
          // `Flexible` es imprescindible: sin él, una etiqueta larga deja el
          // chip más ancho que la pantalla en lugar de recortarse.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: foregroundColor,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
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
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: content,
      ),
    );
  }
}
