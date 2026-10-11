import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/business.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../utils/business_icon_helper.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart' show CashButton, CashButtonType;
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_icon_button.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_selector_field.dart';
import '../../widgets/design/cash_section.dart';
import 'analytics_tab.dart';
import 'break_even_screen.dart';
import 'business_form_screen.dart';
import 'closings_tab.dart';
import 'expenses_tab.dart';
import 'pos_screen.dart';
import 'products_tab.dart';
import 'sales_tab.dart';
import 'sellers_tab.dart';

/// Dashboard del negocio: centro de control del propietario.
///
/// Cabecera con identidad del negocio (icono, color, tipo y estado activo),
/// fondo de renovación de inventario, acción principal (POS) y métricas clave.
/// Se ha reducido la información mostrada para evitar sobrecarga visual.
class BusinessDetailScreen extends StatefulWidget {
  final Business business;

  const BusinessDetailScreen({super.key, required this.business});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

/// Spec de pestaña interna del dashboard.
class _TabSpec {
  final String label;
  final IconData icon;

  const _TabSpec(this.label, this.icon);
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _sellerTypes = {'Retail', 'Restaurante', 'E-commerce'};

  bool get _hasSellers => _sellerTypes.contains(widget.business.type);

  @override
  void initState() {
    super.initState();
    final tabCount = _hasSellers ? 7 : 6;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // NAVEGACIÓN
  // ---------------------------------------------------------------------------

  void _openPos(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PosScreen()),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BusinessFormScreen(business: widget.business),
      ),
    );
  }

  void _jumpToTab(int index) {
    if (index < 0 || index >= _tabController.length) return;
    _tabController.animateTo(index);
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final Color color = Color(widget.business.colorValue);

    final List<_TabSpec> tabs = [
      _TabSpec(context.t('tab_products'), Icons.inventory_2_outlined),
      _TabSpec(context.t('tab_sales'), Icons.point_of_sale_outlined),
      _TabSpec(context.t('tab_expenses'), Icons.receipt_long_outlined),
      if (_hasSellers)
        _TabSpec(context.t('tab_sellers'), Icons.groups_outlined),
      _TabSpec(context.t('tab_closings'), Icons.lock_clock_outlined),
      _TabSpec(context.t('tab_analytics'), Icons.analytics_outlined),
      _TabSpec(context.t('break_even_title'), Icons.balance_rounded),
    ];

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              _buildSliverAppBar(context, color),
              SliverToBoxAdapter(
                child: Consumer<BusinessProvider>(
                  builder: (context, provider, _) {
                    return _buildDashboard(context, provider, color);
                  },
                ),
              ),
              _buildTabsHeader(context, color, tabs),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              const ProductsTab(),
              const SalesTab(),
              const ExpensesTab(),
              if (_hasSellers) const SellersTab(),
              const ClosingsTab(),
              const AnalyticsTab(),
              const BreakEvenScreen(),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CABECERA
  // ---------------------------------------------------------------------------

  Widget _buildSliverAppBar(BuildContext context, Color color) {
    final String name = widget.business.name;

    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: color,
      surfaceTintColor: AppColors.transparent,
      elevation: 0,
      foregroundColor: AppColors.white,
      iconTheme: const IconThemeData(color: AppColors.white),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: AppSpacing.sm),
          child: CashIconButton(
            icon: Icons.edit_outlined,
            size: 40,
            iconSize: 20,
            iconColor: AppColors.white,
            backgroundColor: AppColors.white.withValues(alpha: 0.18),
            tooltip: context.t('business_edit_btn'),
            onPressed: () => _openEdit(context),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        titlePadding: const EdgeInsetsDirectional.only(
          start: 60,
          bottom: 14,
          end: 56,
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_shade(color, 0.82), color],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            Positioned(
              right: -8,
              top: 6,
              child: Icon(
                BusinessIconHelper.getIcon(widget.business.iconCode),
                size: 100,
                color: AppColors.white.withValues(alpha: 0.14),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 76,
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.22),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      BusinessIconHelper.getIcon(widget.business.iconCode),
                      size: 26,
                      color: AppColors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.business.type,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.92),
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        const SizedBox(height: 6),
                        const _ActiveChip(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabsHeader(
    BuildContext context,
    Color color,
    List<_TabSpec> tabs,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: color,
          unselectedLabelColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondary,
          indicatorColor: color,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AppColors.transparent,
          labelStyle: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          unselectedLabelStyle: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          tabs: tabs
              .map((t) => Tab(icon: Icon(t.icon, size: 20), text: t.label))
              .toList(),
        ),
        isDark,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DASHBOARD SIMPLIFICADO
  // ---------------------------------------------------------------------------

  Widget _buildDashboard(
    BuildContext context,
    BusinessProvider provider,
    Color color,
  ) {
    final lowStock = provider.lowStockProducts;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInventoryFundCard(context, provider, color),
          const SizedBox(height: AppSpacing.xl),
          _buildQuickActions(context, color),
          if (lowStock.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildLowStock(context, provider, color),
          ],
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }

  String _currencySymbol(BuildContext context, String code) {
    final appProvider = context.read<AppProvider>();
    for (final currency in appProvider.availableCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  // ---------------------------------------------------------------------------
  // FONDO DE RENOVACIÓN DE INVENTARIO (simplificado)
  // ---------------------------------------------------------------------------

  Widget _buildInventoryFundCard(
    BuildContext context,
    BusinessProvider provider,
    Color color,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final appProvider = context.read<AppProvider>();
    final currency = provider.activeBusiness?.currency ?? 'CUP';
    final symbol = _currencySymbol(context, currency);

    final initialCapital = provider.initialCapital;
    final sales = provider.totalSalesRevenue;
    final available = provider.availableInventoryBalance;
    final isPositive = available >= 0;
    final statusColor = isPositive ? AppColors.income : AppColors.expense;

    AccountCard? linkedCard;
    if (provider.linkedCardId != null) {
      for (final c in appProvider.cards) {
        if (c.id == provider.linkedCardId) {
          linkedCard = c;
          break;
        }
      }
    }

    final String cardLabel = linkedCard != null
        ? '${linkedCard.isCash ? linkedCard.name : (linkedCard.bankName ?? context.t('card_default_name'))}'
              ' (${linkedCard.isCash ? 'CASH' : (linkedCard.cardNumber.length >= 4 ? linkedCard.cardNumber.substring(linkedCard.cardNumber.length - 4) : linkedCard.cardNumber)})'
        : context.t('no_linked_account');

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      boxShadow: AppShadows.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Icon(
                  Icons.all_inclusive_rounded,
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('inventory_fund_title'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(
                          linkedCard != null
                              ? Icons.credit_card
                              : Icons.link_off,
                          size: 13,
                          color: linkedCard != null
                              ? color
                              : isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cardLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: isDark
                                      ? AppColors.textSecondaryDark
                                      : AppColors.textSecondary,
                                  fontWeight: linkedCard != null
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _AdjustPill(
                label: context.t('business_adjust_short'),
                color: color,
                onTap: _showAdjustCapitalDialog,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // Balance disponible (prominente)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.08),
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        context.t('available_balance'),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${isPositive ? '' : '-'}$symbol'
                        '${available.abs().toFormattedString(2)} $currency',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  isPositive
                      ? Icons.check_circle_outline_rounded
                      : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 26,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Solo 2 métricas clave: Capital asignado y Ventas
          Row(
            children: [
              Expanded(
                child: _buildFundMetricTile(
                  context,
                  label: context.t('assigned_capital'),
                  value: '$symbol${initialCapital.toFormattedString(2)}',
                  color: AppColors.info,
                  icon: Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _buildFundMetricTile(
                  context,
                  label: context.t('sales_revenue'),
                  value: '+$symbol${sales.toFormattedString(2)}',
                  color: AppColors.income,
                  icon: Icons.point_of_sale_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFundMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACCIONES RÁPIDAS (solo POS principal + 2 accesos)
  // ---------------------------------------------------------------------------

  Widget _buildQuickActions(BuildContext context, Color color) {
    return CashSection(
      title: context.t('business_quick_actions'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CashButton(
            label: context.t('business_sell'),
            icon: const Icon(Icons.point_of_sale_rounded, size: 20),
            height: 54,
            onPressed: () => _openPos(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.inventory_2_outlined,
                  label: context.t('tab_products'),
                  color: Color(0xFF42A5F5),
                  onTap: () => _jumpToTab(0),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.receipt_long_outlined,
                  label: context.t('tab_expenses'),
                  color: AppColors.expense,
                  onTap: () => _jumpToTab(2),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _QuickActionButton(
                  icon: Icons.lock_clock_outlined,
                  label: context.t('tab_closings'),
                  color: color,
                  onTap: () => _jumpToTab(_hasSellers ? 4 : 3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // STOCK BAJO (máx 4 productos)
  // ---------------------------------------------------------------------------

  Widget _buildLowStock(
    BuildContext context,
    BusinessProvider provider,
    Color color,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final lowStock = provider.lowStockProducts.take(4).toList();
    final Color stockColor = AppColors.expense;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      border: Border.all(color: stockColor.withValues(alpha: 0.30), width: 1.2),
      boxShadow: AppShadows.soft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: stockColor.withValues(alpha: 0.10),
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: stockColor,
                  size: 21,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('business_low_stock'),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.t('business_low_stock_desc'),
                      maxLines: 1,
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
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          for (final product in lowStock) ...[
            InkWell(
              borderRadius: AppRadius.radiusMd,
              onTap: () => _jumpToTab(0),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.surfaceDark2
                      : AppColors.surfaceVariantLight,
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.inventory_2_outlined,
                      size: 15,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${product.currentStock.toFormattedString(0)} ${context.t('business_units')}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: stockColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (product != lowStock.last) const SizedBox(height: AppSpacing.xs),
          ],
          const SizedBox(height: AppSpacing.sm),
          InkWell(
            borderRadius: AppRadius.radiusSm,
            onTap: () => _jumpToTab(0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t('business_view_products'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right_rounded, size: 16, color: color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AJUSTAR CAPITAL DE INVENTARIO
  // ---------------------------------------------------------------------------

  Future<void> _showAdjustCapitalDialog() async {
    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final activeBiz = provider.activeBusiness;
    if (activeBiz == null) return;

    final capitalController = TextEditingController(
      text: activeBiz.initialCapital > 0
          ? activeBiz.initialCapital.toStringAsFixed(2)
          : '',
    );
    String? selectedCardId = activeBiz.linkedCardId;
    String? newCurrency;

    final saved = await CashBottomSheet.show<bool>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('edit_capital_title'),
        child: StatefulBuilder(
          builder: (modalContext, setModalState) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CashInput(
                  controller: capitalController,
                  label: context.t('initial_capital'),
                  hint: context.t('initial_capital_hint'),
                  prefix: const Icon(Icons.savings_outlined),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CashSelectorField(
                  label: context.t('linked_account'),
                  value: _adjustCapitalAccountLabel(
                    context,
                    appProvider,
                    selectedCardId,
                  ),
                  placeholder: context.t('select_linked_account'),
                  icon: Icons.account_balance_wallet_outlined,
                  onTap: () async {
                    final picked = await _pickAdjustCapitalAccount(
                      context,
                      appProvider,
                      selectedCardId,
                    );
                    if (picked == null || !modalContext.mounted) return;
                    setModalState(() {
                      selectedCardId = picked == _kNoAccount ? null : picked;
                      if (selectedCardId != null) {
                        final card = appProvider.cards.firstWhere(
                          (c) => c.id == selectedCardId,
                        );
                        capitalController.text = card.balance.toStringAsFixed(
                          2,
                        );
                        newCurrency = card.currency;
                      } else {
                        newCurrency = null;
                      }
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                CashButton(
                  label: context.t('btn_save'),
                  icon: const Icon(Icons.check_rounded, size: 20),
                  type: CashButtonType.primary,
                  onPressed: () async {
                    final cap =
                        double.tryParse(
                          capitalController.text.trim().replaceAll(',', '.'),
                        ) ??
                        0.0;
                    if (selectedCardId != null) {
                      final card = appProvider.cards.firstWhere(
                        (c) => c.id == selectedCardId,
                      );
                      newCurrency = card.currency;
                    }
                    await provider.updateBusinessCapital(
                      businessId: activeBiz.id,
                      initialCapital: cap,
                      linkedCardId: selectedCardId,
                      currency: newCurrency,
                      appProvider: appProvider,
                    );
                    if (sheetContext.mounted) {
                      Navigator.pop(sheetContext, true);
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('edit_capital_snackbar')),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  static const String _kNoAccount = '\u0000no_account';

  String _adjustCapitalAccountLabel(
    BuildContext context,
    AppProvider appProvider,
    String? selectedCardId,
  ) {
    if (selectedCardId == null) return '';
    for (final card in appProvider.cards) {
      if (card.id == selectedCardId) {
        final bank = card.isCash
            ? card.name
            : (card.bankName ?? context.t('card_default_name'));
        final last4 = card.isCash || card.cardNumber.length < 4
            ? ''
            : ' · •• ${card.cardNumber.substring(card.cardNumber.length - 4)}';
        return '$bank$last4 · ${card.currency}';
      }
    }
    return '';
  }

  Future<String?> _pickAdjustCapitalAccount(
    BuildContext context,
    AppProvider appProvider,
    String? currentId,
  ) {
    return CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('linked_account'),
        child: Column(
          children: [
            _SheetOptionRow(
              icon: Icons.link_off_rounded,
              iconColor: null,
              title: sheetContext.t('no_linked_account'),
              selected: currentId == null,
              onTap: () => Navigator.pop(sheetContext, _kNoAccount),
            ),
            for (final card in appProvider.cards)
              _SheetOptionRow(
                icon: card.isCash
                    ? Icons.account_balance_wallet_rounded
                    : Icons.credit_card_rounded,
                iconColor: Color(card.colorValue),
                title: card.isCash
                    ? card.name
                    : (card.bankName ?? sheetContext.t('card_default_name')),
                subtitle: card.isCash
                    ? '${card.name} · ${card.currency}'
                    : '•• ${card.cardNumber.length >= 4 ? card.cardNumber.substring(card.cardNumber.length - 4) : card.cardNumber} · ${card.currency}',
                selected: currentId == card.id,
                onTap: () => Navigator.pop(sheetContext, card.id),
              ),
          ],
        ),
      ),
    );
  }

  static Color _shade(Color color, double factor) {
    final HSLColor hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness * factor).clamp(0.0, 1.0))
        .toColor();
  }
}

// ---------------------------------------------------------------------------
// WIDGETS AUXILIARES
// ---------------------------------------------------------------------------

class _ActiveChip extends StatelessWidget {
  const _ActiveChip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.40)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle_rounded,
            size: 13,
            color: AppColors.white,
          ),
          const SizedBox(width: 4),
          Text(
            context.t('active'),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdjustPill extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdjustPill({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusSm,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm + 2,
          vertical: AppSpacing.xs + 2,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: AppRadius.radiusSm,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.tune_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              maxLines: 1,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: AppRadius.radiusLg,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(height: AppSpacing.xs + 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SheetOptionRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOptionRow({
    required this.icon,
    required this.title,
    required this.selected,
    required this.onTap,
    this.iconColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final Color accent = iconColor ?? secondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CashCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        border: selected
            ? Border.all(color: accent.withValues(alpha: 0.8), width: 1.4)
            : null,
        boxShadow: AppShadows.soft,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.13),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent, size: 20)
            else
              Icon(Icons.chevron_right, size: 20, color: secondary),
          ],
        ),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;
  final bool _isDark;

  _SliverAppBarDelegate(this._tabBar, this._isDark);

  @override
  double get minExtent => _tabBar.preferredSize.height + 1;

  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          bottom: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return oldDelegate._isDark != _isDark;
  }
}
