import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

class CashTransactionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String amount;
  final bool isIncome;
  final Color? iconColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  const CashTransactionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.amount,
    this.subtitle,
    this.isIncome = false,
    this.iconColor,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color accent =
        iconColor ?? (isIncome ? AppColors.income : AppColors.expense);

    final Color titleColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;

    final Color subtitleColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.11),
              borderRadius: AppRadius.radiusMd,
            ),
            child: Icon(icon, color: accent, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: subtitleColor),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          if (trailing != null)
            trailing!
          else
            Text(
              '${isIncome ? '+' : '-'}$amount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: isIncome ? AppColors.income : titleColor,
                fontWeight: FontWeight.w700,
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
        borderRadius: AppRadius.radiusLg,
        child: content,
      ),
    );
  }
}
