import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/business.dart';
import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../utils/business_icon_helper.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import '../../widgets/design/cash_icon_button.dart';
import 'business_detail_screen.dart';
import 'business_form_screen.dart';

/// Lista de negocios: centro de operaciones.
///
/// Muestra de un vistazo qué negocios existen, cuál está activo y cómo entrar,
/// editar o crear uno. El toque sobre una tarjeta activa ese negocio
/// (misma lógica de `setActiveBusiness`) y abre su detalle.
class BusinessListScreen extends StatelessWidget {
  const BusinessListScreen({super.key});

  void _openForm(BuildContext context, {Business? business}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessFormScreen(business: business),
      ),
    );
  }

  void _openDetail(BuildContext context, BusinessProvider provider, Business business) {
    provider.setActiveBusiness(business.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessDetailScreen(business: business),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          body: SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(context),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : provider.businesses.isEmpty
                          ? _buildEmptyState(context)
                          : _buildList(context, provider),
                ),
              ],
            ),
          ),
          floatingActionButton: provider.isLoading || provider.businesses.isEmpty
              ? null
              : CashFloatingButton(
                  heroTag: 'business_create_fab',
                  icon: Icons.add_rounded,
                  label: context.t('business_create_btn'),
                  onPressed: () => _openForm(context),
                ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('business_my_businesses'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.t('business_list_subtitle'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CashIconButton(
            icon: Icons.add_rounded,
            size: 44,
            iconSize: 22,
            tooltip: context.t('business_create_btn'),
            onPressed: () => _openForm(context),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LISTA
  // ---------------------------------------------------------------------------

  Widget _buildList(BuildContext context, BusinessProvider provider) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.sm,
        AppSpacing.xl,
        96,
      ),
      itemCount: provider.businesses.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.md),
      itemBuilder: (context, index) {
        return _buildBusinessCard(context, provider, provider.businesses[index]);
      },
    );
  }

  String _currencySymbol(BuildContext context, String code) {
    final appProvider = context.read<AppProvider>();
    for (final currency in appProvider.availableCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  Widget _buildBusinessCard(
    BuildContext context,
    BusinessProvider provider,
    Business business,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isActive = provider.activeBusiness?.id == business.id;
    final Color color = Color(business.colorValue);

    return CashCard(
      onTap: () => _openDetail(context, provider, business),
      padding: const EdgeInsets.all(AppSpacing.lg),
      border: Border.all(
        color: isActive
            ? color.withValues(alpha: 0.8)
            : isDark
            ? AppColors.borderDark
            : AppColors.borderLight,
        width: isActive ? 1.5 : 1,
      ),
      boxShadow: isActive
          ? [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.30 : 0.18),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ]
          : AppShadows.soft,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.20 : 0.12),
              borderRadius: AppRadius.radiusLg,
            ),
            child: Icon(
              BusinessIconHelper.getIcon(business.iconCode),
              color: color,
              size: 27,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        business.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (isActive) ...[
                      const SizedBox(width: AppSpacing.sm),
                      _ActiveBadge(),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${business.type} · ${business.currency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
                if (business.initialCapital > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    '${_currencySymbol(context, business.currency)}'
                    '${business.initialCapital.toFormattedString(2)}',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CashIconButton(
            icon: Icons.edit_outlined,
            size: 40,
            iconSize: 18,
            bordered: true,
            iconColor: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
            tooltip: context.t('edit'),
            onPressed: () => _openForm(context, business: business),
          ),
          const SizedBox(width: AppSpacing.xxs),
          Icon(
            Icons.chevron_right_rounded,
            size: 22,
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ESTADO VACÍO
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: CashEmptyState(
          icon: Icons.storefront_rounded,
          title: context.t('empty_business_title'),
          message: context.t('empty_business_desc'),
          buttonLabel: context.t('business_create_btn'),
          onButtonPressed: () => _openForm(context),
        ),
      ),
    );
  }
}

/// Insignia de negocio activo (no depende sólo del color).
class _ActiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 13,
            color: AppColors.primaryDark,
          ),
          const SizedBox(width: 4),
          Text(
            context.t('active'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}