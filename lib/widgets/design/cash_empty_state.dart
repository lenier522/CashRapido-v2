import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'cash_button.dart';

class CashEmptyState extends StatelessWidget {
  final Widget? illustration;
  final IconData? icon;
  final String title;
  final String? message;
  final String? buttonLabel;
  final VoidCallback? onButtonPressed;
  final Widget? action;

  const CashEmptyState({
    super.key,
    this.illustration,
    this.icon,
    required this.title,
    this.message,
    this.buttonLabel,
    this.onButtonPressed,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (illustration != null)
              SizedBox(width: 150, height: 150, child: illustration!)
            else if (icon != null)
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark2
                      : AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 40, color: AppColors.primary),
              ),
            if (illustration != null || icon != null)
              const SizedBox(height: AppSpacing.xxl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: secondaryText),
                ),
              ),
            ],
            if (buttonLabel != null && onButtonPressed != null) ...[
              const SizedBox(height: AppSpacing.xxl),
              CashButton(
                label: buttonLabel!,
                onPressed: onButtonPressed,
                fullWidth: false,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
