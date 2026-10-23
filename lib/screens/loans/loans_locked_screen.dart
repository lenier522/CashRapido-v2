import 'package:material_ui/material_ui.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../licenses_screen.dart';

/// Pantalla que se muestra cuando la licencia no permite acceder al módulo de
/// préstamos. Conserva exactamente las condiciones del [LoansGatekeeper]; aquí
/// sólo se explica la situación y se ofrece la vía de mejora existente.
class LoansLockedScreen extends StatelessWidget {
  const LoansLockedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final Color primaryText = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(context.t('loans_module_title'))),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xl,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(
                        alpha: isDark ? 0.16 : 0.10,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.real_estate_agent_outlined,
                      size: 44,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  Text(
                    context.t('loans_locked_title'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.t('loans_locked_desc'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondaryText,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  CashCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.xs,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildFeature(
                          context,
                          Icons.people_outline_rounded,
                          context.t('loans_feature_debtors'),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.dividerColor,
                        ),
                        _buildFeature(
                          context,
                          Icons.percent_rounded,
                          context.t('loans_feature_interest_rates'),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.dividerColor,
                        ),
                        _buildFeature(
                          context,
                          Icons.notifications_active_outlined,
                          context.t('loans_feature_alerts'),
                        ),
                        Divider(
                          height: 1,
                          thickness: 1,
                          color: theme.dividerColor,
                        ),
                        _buildFeature(
                          context,
                          Icons.account_balance_wallet_outlined,
                          context.t('loans_feature_integration'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  CashButton(
                    label: context.t('upgrade_to_enterprise'),
                    icon: const Icon(Icons.workspace_premium_rounded, size: 20),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LicensesScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeature(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.14 : 0.10),
              borderRadius: AppRadius.radiusMd,
            ),
            child: Icon(icon, size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
