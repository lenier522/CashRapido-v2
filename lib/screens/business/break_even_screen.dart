import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/business_expense.dart';
import '../../models/product.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_chart_card.dart';
import '../../widgets/design/cash_empty_state.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

/// Categorías de gasto que el simulador considera fijas por defecto.
const List<String> _fixedCategories = [
  'Alquiler',
  'Servicios',
  'Salarios',
  'Marketing',
];

/// Punto de equilibrio.
///
/// Toda la lógica financiera se conserva intacta: el cálculo de costos fijos,
/// el margen de contribución ponderado, las unidades y los ingresos de
/// equilibrio, así como el simulador de precios. El rediseño es únicamente de
/// presentación y jerarquía.
class BreakEvenScreen extends StatefulWidget {
  const BreakEvenScreen({super.key});

  @override
  State<BreakEvenScreen> createState() => _BreakEvenScreenState();
}

class _BreakEvenScreenState extends State<BreakEvenScreen> {
  String _selectedPeriod = 'monthly';
  final Set<String> _fixedCategorySet = {..._fixedCategories};

  // Simulator Overrides (Sandbox state)
  double _customFixedCosts = 0.0;
  final Map<String, double> _simulatedPrices = {};
  final Map<String, double> _simulatedCosts = {};
  final Map<String, double> _simulatedVolumes = {};

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final products = provider.products;
        final allExpenses = provider.expenses;

        // Initialize/sync simulated values if empty or when products count changes
        _syncSimulatedData(products);

        // 1. Calculate Fixed Costs based on expenses in last 30 days scaled to the period, plus custom overrides
        final double baseMonthlyFixedCosts = _calcBaseMonthlyFixedCosts(
          allExpenses,
          provider,
        );
        final double periodFixedCosts = _calcFixedCostsForPeriod(
          baseMonthlyFixedCosts,
        );
        final double totalFixedCosts = math.max(
          0.0,
          periodFixedCosts + _customFixedCosts,
        );

        if (products.isEmpty) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.screenVertical,
              AppSpacing.screenHorizontal,
              AppSpacing.huge,
            ),
            children: [
              _periodSelector(context),
              const SizedBox(height: AppSpacing.lg),
              _fixedCostsSection(
                context,
                allExpenses,
                totalFixedCosts,
                periodFixedCosts,
                provider,
              ),
              const SizedBox(height: AppSpacing.lg),
              _emptyProducts(context),
            ],
          );
        }

        // 2. Compute Sales Mix and Weighted Contribution Margin
        double totalSimulatedVolume = 0;
        for (final p in products) {
          totalSimulatedVolume += _simulatedVolumes[p.id] ?? 0.0;
        }

        // Weighted Metrics
        double avgPrice = 0.0;
        double avgVarCost = 0.0;
        double avgContributionMargin = 0.0;

        final List<Map<String, dynamic>> productCalculations = [];

        for (final p in products) {
          final double price = _simulatedPrices[p.id] ?? p.salePrice;
          final double cost = _simulatedCosts[p.id] ?? p.realCostPerUnit;
          final double estVolume = _simulatedVolumes[p.id] ?? 0.0;
          final double mix = totalSimulatedVolume > 0
              ? estVolume / totalSimulatedVolume
              : 1.0 / products.length;
          final double margin = price - cost;

          avgPrice += mix * price;
          avgVarCost += mix * cost;
          avgContributionMargin += mix * margin;

          productCalculations.add({
            'product': p,
            'price': price,
            'cost': cost,
            'margin': margin,
            'mix': mix,
            'estVolume': estVolume,
          });
        }

        // Global Break-Even Point Calculations
        final double contributionMarginRatio = avgPrice > 0
            ? avgContributionMargin / avgPrice
            : 0.0;
        final double bepUnits = avgContributionMargin > 0
            ? totalFixedCosts / avgContributionMargin
            : 0.0;
        final double bepRevenue = bepUnits * avgPrice;
        final bool isNegativeMargin = avgContributionMargin <= 0;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.screenVertical,
            AppSpacing.screenHorizontal,
            AppSpacing.huge,
          ),
          children: [
            // Period Selector
            _periodSelector(context),
            const SizedBox(height: AppSpacing.lg),

            // Main Results Card
            _resultsSection(
              context,
              totalFixedCosts,
              avgPrice,
              avgVarCost,
              avgContributionMargin,
              contributionMarginRatio,
              bepUnits,
              bepRevenue,
              isNegativeMargin,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Fixed Costs Configurator
            _fixedCostsSection(
              context,
              allExpenses,
              totalFixedCosts,
              periodFixedCosts,
              provider,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Interactive Graph (LineChart showing cost/rev lines)
            _buildInteractiveGraph(
              context,
              totalFixedCosts,
              avgPrice,
              avgVarCost,
              bepUnits,
              bepRevenue,
              isNegativeMargin,
            ),
            const SizedBox(height: AppSpacing.lg),

            // Simulator header + apply action
            _simulatorHeader(context, provider),
            const SizedBox(height: AppSpacing.md),

            // Product Cards for sandbox tweaking
            ...productCalculations.map((calc) {
              final Product p = calc['product'] as Product;
              final double price = calc['price'] as double;
              final double cost = calc['cost'] as double;
              final double margin = calc['margin'] as double;
              final double mix = calc['mix'] as double;
              final double estVolume = calc['estVolume'] as double;

              // Units this product needs to sell to satisfy its share of the BEP
              final double neededUnits = bepUnits * mix;
              final bool canAchieve = neededUnits <= p.initialQuantity;

              return _buildProductSimulatorCard(
                context,
                p,
                price,
                cost,
                margin,
                mix,
                estVolume,
                neededUnits,
                canAchieve,
              );
            }),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        );
      },
    );
  }

  void _syncSimulatedData(List<Product> products) {
    bool updated = false;
    for (final p in products) {
      if (!_simulatedPrices.containsKey(p.id)) {
        _simulatedPrices[p.id] = p.salePrice;
        updated = true;
      }
      if (!_simulatedCosts.containsKey(p.id)) {
        _simulatedCosts[p.id] = p.realCostPerUnit;
        updated = true;
      }
      if (!_simulatedVolumes.containsKey(p.id)) {
        _simulatedVolumes[p.id] = p.initialQuantity > 0
            ? p.initialQuantity.toDouble()
            : 10.0;
        updated = true;
      }
    }

    // Clean up deleted products
    final productIds = products.map((p) => p.id).toSet();
    final deletedPrices = _simulatedPrices.keys
        .where((id) => !productIds.contains(id))
        .toList();
    if (deletedPrices.isNotEmpty) {
      for (final id in deletedPrices) {
        _simulatedPrices.remove(id);
        _simulatedCosts.remove(id);
        _simulatedVolumes.remove(id);
      }
      updated = true;
    }

    if (updated && mounted) {
      // Re-trigger layout without recursive loop
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }
  }

  void _resetSimulation(List<Product> products) {
    setState(() {
      _customFixedCosts = 0.0;
      _simulatedPrices.clear();
      _simulatedCosts.clear();
      _simulatedVolumes.clear();
      for (final p in products) {
        _simulatedPrices[p.id] = p.salePrice;
        _simulatedCosts[p.id] = p.realCostPerUnit;
        _simulatedVolumes[p.id] = p.initialQuantity > 0
            ? p.initialQuantity.toDouble()
            : 10.0;
      }
    });
  }

  Future<void> _applySimulatedPrices(
    BuildContext context,
    BusinessProvider provider,
  ) async {
    final products = provider.products;
    bool success = true;
    try {
      for (final p in products) {
        final simPrice = _simulatedPrices[p.id];
        if (simPrice != null && simPrice != p.salePrice) {
          final updated = p.copyWith(salePrice: simPrice);
          await provider.editProduct(updated);
        }
      }
    } catch (e) {
      success = false;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? context.t('break_even_prices_applied')
                : 'Error al aplicar cambios',
          ),
          backgroundColor: success ? AppColors.income : AppColors.expense,
        ),
      );
    }
  }

  double _calcBaseMonthlyFixedCosts(
    List<BusinessExpense> expenses,
    BusinessProvider provider,
  ) {
    final now = DateTime.now();
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    double last30DaysSum = 0;
    double allTimeSum = 0;

    for (final e in expenses) {
      if (_fixedCategorySet.contains(e.category)) {
        final convertedAmount = provider.convertAmount(e.amount, e.currency);
        allTimeSum += convertedAmount;
        if (e.date.isAfter(thirtyDaysAgo)) {
          last30DaysSum += convertedAmount;
        }
      }
    }

    // Fallback to all time sum if there are no expenses in the last 30 days
    return last30DaysSum > 0 ? last30DaysSum : allTimeSum;
  }

  double _calcFixedCostsForPeriod(double baseMonthly) {
    switch (_selectedPeriod) {
      case 'weekly':
        return baseMonthly / 4.0;
      case 'yearly':
        return baseMonthly * 12.0;
      default:
        return baseMonthly;
    }
  }

  // ---- PERIOD SELECTOR ----
  Widget _periodSelector(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final periods = [
      {'key': 'monthly', 'label': context.t('break_even_monthly')},
      {'key': 'weekly', 'label': context.t('break_even_weekly')},
      {'key': 'yearly', 'label': context.t('break_even_yearly')},
    ];

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceVariantLight,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        children: periods.map((p) {
          final selected = _selectedPeriod == p['key'];
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedPeriod = p['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.transparent,
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Text(
                  p['label']!,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: selected
                        ? AppColors.white
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---- FIXED COSTS MANAGER ----
  Widget _fixedCostsSection(
    BuildContext context,
    List<BusinessExpense> expenses,
    double totalFixed,
    double periodFixed,
    BusinessProvider provider,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Group all expenses by category (converted to base currency)
    final grouped = <String, double>{};
    for (final e in expenses) {
      final converted = provider.convertAmount(e.amount, e.currency);
      grouped[e.category] = (grouped[e.category] ?? 0) + converted;
    }

    // Convert grouped costs to selected period
    final periodGrouped = <String, double>{};
    grouped.forEach((category, amount) {
      double periodAmount = amount;
      if (_selectedPeriod == 'weekly') periodAmount /= 4.0;
      if (_selectedPeriod == 'yearly') periodAmount *= 12.0;
      periodGrouped[category] = periodAmount;
    });

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusMd,
                ),
                child: const Icon(
                  Icons.business_center_rounded,
                  color: AppColors.warning,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('break_even_fixed_costs'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      '${context.t('break_even_period')}: ${context.t('break_even_$_selectedPeriod')}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '\$${totalFixed.toFormattedString(2)}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Categories list checklist
          if (periodGrouped.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text(
                context.t('break_even_no_expenses'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: secondary),
              ),
            )
          else
            ...periodGrouped.entries.map((e) {
              final isFixed = _fixedCategorySet.contains(e.key);
              return InkWell(
                borderRadius: AppRadius.radiusSm,
                onTap: () {
                  setState(() {
                    if (isFixed) {
                      _fixedCategorySet.remove(e.key);
                    } else {
                      _fixedCategorySet.add(e.key);
                    }
                  });
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isFixed
                              ? AppColors.warning
                              : AppColors.transparent,
                          borderRadius: AppRadius.radiusXs,
                          border: Border.all(
                            color: isFixed
                                ? AppColors.warning
                                : (isDark
                                      ? AppColors.borderDark
                                      : AppColors.textDisabled),
                            width: 1.5,
                          ),
                        ),
                        child: isFixed
                            ? const Icon(
                                Icons.check,
                                size: 15,
                                color: AppColors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          e.key,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: isFixed ? null : secondary,
                                fontWeight: isFixed
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '\$${e.value.toFormattedString(2)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isFixed
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: isFixed ? null : secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1, thickness: 1),
          ),

          // Custom Fixed Costs Override
          Row(
            children: [
              const Icon(
                Icons.add_road_outlined,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.t('break_even_custom_fixed_costs'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusXs,
                ),
                child: Text(
                  '${_customFixedCosts >= 0 ? '+' : ''}\$${_customFixedCosts.toFormattedString(0)}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(
                  () => _customFixedCosts = math.max(
                    -periodFixed,
                    _customFixedCosts - 100,
                  ),
                ),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  size: 20,
                  color: AppColors.warning,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '-100',
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: AppColors.warning,
                    inactiveTrackColor: AppColors.warning.withValues(
                      alpha: 0.2,
                    ),
                    thumbColor: AppColors.warning,
                    overlayColor: AppColors.warning.withValues(alpha: 0.1),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: math.min(0.0, -periodFixed),
                    max: 50000.0,
                    value: _customFixedCosts.clamp(
                      math.min(0.0, -periodFixed),
                      50000.0,
                    ),
                    onChanged: (val) => setState(() => _customFixedCosts = val),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _customFixedCosts += 100),
                icon: const Icon(
                  Icons.add_circle_outline,
                  size: 20,
                  color: AppColors.warning,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: '+100',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- EMPTY PRODUCTS ----
  Widget _emptyProducts(BuildContext context) {
    return CashEmptyState(
      icon: Icons.inventory_2_outlined,
      title: context.t('break_even_no_products'),
    );
  }

  // ---- KEY FINANCIAL METRICS ----
  Widget _resultsSection(
    BuildContext context,
    double fixedCosts,
    double avgPrice,
    double avgVarCost,
    double avgMargin,
    double marginRatio,
    double bepUnits,
    double bepRevenue,
    bool isNegativeMargin,
  ) {
    return Column(
      children: [
        if (isNegativeMargin)
          Container(
            margin: const EdgeInsets.only(bottom: AppSpacing.md),
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.expense.withValues(alpha: 0.1),
              borderRadius: AppRadius.radiusMd,
              border: Border.all(
                color: AppColors.expense.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.expense,
                  size: 22,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    context.t('break_even_negative_margin_alert'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            gradient: isNegativeMargin
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFFE45757), Color(0xFF9E2B28)],
                  )
                : AppColors.heroGradient,
            borderRadius: AppRadius.radiusXxl,
          ),
          child: Column(
            children: [
              Text(
                context.t('break_even_title'),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  context.t('break_even_explanation'),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _heroResult(
                      context,
                      icon: Icons.shopping_cart_rounded,
                      value: isNegativeMargin
                          ? '∞'
                          : bepUnits.toFormattedString(1),
                      label: context.t('break_even_units'),
                    ),
                  ),
                  Container(
                    height: 56,
                    width: 1,
                    color: AppColors.white.withValues(alpha: 0.25),
                  ),
                  Expanded(
                    child: _heroResult(
                      context,
                      icon: Icons.attach_money_rounded,
                      value: isNegativeMargin
                          ? '∞'
                          : '\$${bepRevenue.toFormattedString(2)}',
                      label: context.t('break_even_revenue'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.white.withValues(alpha: 0.10),
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.10),
                  ),
                ),
                child: Column(
                  children: [
                    _metricRow(
                      context,
                      context.t('break_even_fixed_costs'),
                      '\$${fixedCosts.toFormattedString(2)}',
                      emphasized: true,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _metricRow(
                      context,
                      context.t('break_even_unit_price'),
                      '\$${avgPrice.toFormattedString(2)}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _metricRow(
                      context,
                      context.t('break_even_unit_cost'),
                      '\$${avgVarCost.toFormattedString(2)}',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _metricRow(
                      context,
                      context.t('break_even_contribution_margin'),
                      '\$${avgMargin.toFormattedString(2)} (${(marginRatio * 100).toFormattedString(1)}%)',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _heroResult(
    BuildContext context, {
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: AppColors.white.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.white, size: 20),
        ),
        const SizedBox(height: AppSpacing.sm),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.white,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: AppColors.white.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _metricRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasized = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.white.withValues(alpha: emphasized ? 0.95 : 0.8),
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 2,
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ---- DYNAMIC LINE CHART ----
  Widget _buildInteractiveGraph(
    BuildContext context,
    double fixedCosts,
    double avgPrice,
    double avgVarCost,
    double bepUnits,
    double bepRevenue,
    bool isNegativeMargin,
  ) {
    double maxX = (bepUnits > 0 && bepUnits.isFinite) ? bepUnits * 1.5 : 50.0;
    if (maxX < 15) maxX = 15;
    if (maxX.isNaN || maxX.isInfinite) maxX = 50.0;

    final double costAtMaxX = fixedCosts + maxX * avgVarCost;
    final double revAtMaxX = maxX * avgPrice;
    double maxY = costAtMaxX > revAtMaxX ? costAtMaxX : revAtMaxX;
    maxY = maxY > 0 ? maxY * 1.15 : 100.0;
    if (maxY.isNaN || maxY.isInfinite) maxY = 100.0;

    final Color axisColor = CashChartCard.axisColor(context);

    return CashChartCard(
      title: context.t('break_even_chart_title'),
      subtitle: context.t('break_even_explanation'),
      height:
          CashChartCard.heightFor(MediaQuery.sizeOf(context).width) +
          AppSpacing.giant,
      chart: Column(
        children: [
          Expanded(
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: CashChartCard.gridColor(context),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 52,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        String formatted = '\$${value.toStringAsFixed(0)}';
                        if (value >= 1000000) {
                          formatted =
                              '\$${(value / 1000000).toStringAsFixed(1)}M';
                        } else if (value >= 1000) {
                          formatted = '\$${(value / 1000).toStringAsFixed(1)}K';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: AppSpacing.xs),
                          child: Text(
                            formatted,
                            textAlign: TextAlign.right,
                            style: TextStyle(fontSize: 10, color: axisColor),
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) {
                          return const SizedBox();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Text(
                            value.toStringAsFixed(0),
                            style: TextStyle(fontSize: 10, color: axisColor),
                          ),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => CashChartCard.tooltipColor(context),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        String label;
                        if (spot.barIndex == 0) {
                          label = context.t('break_even_chart_fixed');
                        } else if (spot.barIndex == 1) {
                          label = context.t('break_even_chart_costs');
                        } else if (spot.barIndex == 2) {
                          label = context.t('break_even_chart_revenue');
                        } else {
                          return null;
                        }

                        return LineTooltipItem(
                          '$label\n${spot.x.toStringAsFixed(1)} ${context.t('stock_units')}: \$${spot.y.toFormattedString(2)}',
                          TextStyle(
                            color: CashChartCard.tooltipTextColor(context),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // 1. Fixed Costs line (Horizontal, Orange)
                  LineChartBarData(
                    spots: [FlSpot(0, fixedCosts), FlSpot(maxX, fixedCosts)],
                    color: AppColors.warning.withValues(alpha: 0.7),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    dashArray: [6, 4],
                  ),
                  // 2. Total Costs line (Slope, Red)
                  LineChartBarData(
                    spots: [
                      FlSpot(0, fixedCosts),
                      FlSpot(maxX, fixedCosts + maxX * avgVarCost),
                    ],
                    color: AppColors.expense,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  // 3. Total Revenue line (Slope, Green)
                  LineChartBarData(
                    spots: [FlSpot(0, 0), FlSpot(maxX, maxX * avgPrice)],
                    color: AppColors.income,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  // 4. BEP Dashed Indicators & Intersection dot
                  if (!isNegativeMargin &&
                      bepUnits > 0 &&
                      bepUnits.isFinite &&
                      bepUnits <= maxX) ...[
                    // Vertical Dashed
                    LineChartBarData(
                      spots: [
                        FlSpot(bepUnits, 0),
                        FlSpot(bepUnits, bepRevenue),
                      ],
                      color: AppColors.purple.withValues(alpha: 0.5),
                      barWidth: 1.5,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                    // Horizontal Dashed
                    LineChartBarData(
                      spots: [
                        FlSpot(0, bepRevenue),
                        FlSpot(bepUnits, bepRevenue),
                      ],
                      color: AppColors.purple.withValues(alpha: 0.5),
                      barWidth: 1.5,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                    // Spot dot
                    LineChartBarData(
                      spots: [FlSpot(bepUnits, bepRevenue)],
                      color: AppColors.purple,
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) =>
                            FlDotCirclePainter(
                              radius: 5,
                              color: AppColors.white,
                              strokeWidth: 3,
                              strokeColor: AppColors.purple,
                            ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _chartLegend(context, isNegativeMargin, bepUnits),
        ],
      ),
    );
  }

  Widget _chartLegend(
    BuildContext context,
    bool isNegativeMargin,
    double bepUnits,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color textColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    Widget item(Color color, String label) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 3,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: textColor),
          ),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.lg,
      runSpacing: AppSpacing.xs,
      children: [
        item(AppColors.warning, context.t('break_even_chart_fixed')),
        item(AppColors.expense, context.t('break_even_chart_costs')),
        item(AppColors.income, context.t('break_even_chart_revenue')),
        if (!isNegativeMargin)
          item(
            AppColors.purple,
            '${context.t('break_even_title')} (~${bepUnits.toStringAsFixed(0)} ${context.t('stock_units')})',
          ),
      ],
    );
  }

  // ---- SIMULATOR HEADER ----
  Widget _simulatorHeader(BuildContext context, BusinessProvider provider) {
    final products = provider.products;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                context.t('break_even_simulator'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            TextButton.icon(
              onPressed: () => _resetSimulation(products),
              icon: const Icon(Icons.refresh, size: 18),
              label: Text(context.t('break_even_reset')),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        CashButton(
          label: context.t('break_even_apply_prices'),
          onPressed: () => _applySimulatedPrices(context, provider),
          icon: const Icon(Icons.check, size: 18),
          height: 48,
        ),
      ],
    );
  }

  // ---- DYNAMIC PRODUCT SIMULATOR CARD ----
  Widget _buildProductSimulatorCard(
    BuildContext context,
    Product p,
    double price,
    double cost,
    double margin,
    double mix,
    double estVolume,
    double neededUnits,
    bool canAchieve,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final double marginPercent = price > 0 ? (margin / price) * 100 : 0.0;
    final bool viable = !(neededUnits.isInfinite || neededUnits.isNaN);

    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppRadius.radiusXl,
        border: Border.all(
          color: (canAchieve ? AppColors.income : AppColors.expense).withValues(
            alpha: 0.25,
          ),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name and viability badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (p.sku.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'SKU: ${p.sku}',
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
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: (canAchieve ? AppColors.income : AppColors.expense)
                      .withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: Text(
                  viable
                      ? '${neededUnits.ceil()} ${context.t('break_even_needed')}'
                      : 'No viable',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: canAchieve ? AppColors.income : AppColors.expense,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Margins Stats
          LayoutBuilder(
            builder: (context, constraints) {
              final double itemWidth =
                  (constraints.maxWidth - AppSpacing.md) / 2;
              return Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _infoTile(
                    context,
                    'Inversión Real',
                    '\$${p.realTotalInvestment.toFormattedString(0)}',
                    secondary,
                    width: itemWidth,
                  ),
                  _infoTile(
                    context,
                    'Stock Inicial / Disp',
                    '${p.initialQuantity} / ${p.currentStock}',
                    secondary,
                    width: itemWidth,
                  ),
                  _infoTile(
                    context,
                    'Margen Unitario',
                    '\$${margin.toFormattedString(1)} (${marginPercent.toFormattedString(0)}%)',
                    margin > 0 ? AppColors.income : AppColors.expense,
                    width: itemWidth,
                  ),
                  _infoTile(
                    context,
                    'Peso Mix',
                    '${(mix * 100).toFormattedString(1)}%',
                    AppColors.purple,
                    width: itemWidth,
                  ),
                ],
              );
            },
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
            child: Divider(height: 1),
          ),

          // Sliders Tweakers
          _sliderTweaker(
            context,
            label: 'Precio de Venta c/u:',
            value: price,
            min: 0.0,
            max: math.max(p.salePrice * 2.5, 5000.0),
            step: 10.0,
            color: AppColors.income,
            onChanged: (val) => setState(() => _simulatedPrices[p.id] = val),
          ),
          const SizedBox(height: AppSpacing.xs),
          _sliderTweaker(
            context,
            label: 'Costo Variable c/u:',
            value: cost,
            min: 0.0,
            max: math.max(p.realCostPerUnit * 2.5, 5000.0),
            step: 5.0,
            color: AppColors.expense,
            onChanged: (val) => setState(() => _simulatedCosts[p.id] = val),
          ),
          const SizedBox(height: AppSpacing.xs),
          _sliderTweaker(
            context,
            label: context.t('break_even_est_volume'),
            value: estVolume,
            min: 0.0,
            max: math.max(p.initialQuantity.toDouble() * 2.0, 100.0),
            step: 1.0,
            color: AppColors.purple,
            onChanged: (val) => setState(() => _simulatedVolumes[p.id] = val),
          ),

          // Achievements checklist status
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                canAchieve
                    ? Icons.check_circle_outline_rounded
                    : Icons.warning_amber_rounded,
                size: 16,
                color: canAchieve ? AppColors.income : AppColors.expense,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  canAchieve
                      ? 'Viable: Puedes equilibrar vendiendo ${neededUnits.toStringAsFixed(1)} unidades. Te sobran ${(p.initialQuantity - neededUnits).toStringAsFixed(1)} unidades de tu stock para ganancia.'
                      : 'No viable con stock actual: Te faltan ${(neededUnits - p.initialQuantity).toStringAsFixed(1)} unidades adicionales en stock para amortizar tu inversión.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: canAchieve ? AppColors.income : AppColors.expense,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(
    BuildContext context,
    String label,
    String value,
    Color valueColor, {
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: valueColor.withValues(alpha: 0.08),
          borderRadius: AppRadius.radiusMd,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: valueColor,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sliderTweaker(
    BuildContext context, {
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xxs,
              ),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: AppRadius.radiusXs,
              ),
              child: Text(
                value.toFormattedString(1),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => onChanged(math.max(min, value - step)),
              icon: Icon(Icons.remove_circle_outline, size: 18, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '-',
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: color,
                  inactiveTrackColor: color.withValues(alpha: 0.2),
                  thumbColor: color,
                  overlayColor: color.withValues(alpha: 0.1),
                  trackHeight: 2,
                ),
                child: Slider(
                  min: min,
                  max: max,
                  value: value.clamp(min, max),
                  onChanged: onChanged,
                ),
              ),
            ),
            IconButton(
              onPressed: () => onChanged(math.min(max, value + step)),
              icon: Icon(Icons.add_circle_outline, size: 18, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              tooltip: '+',
            ),
          ],
        ),
      ],
    );
  }
}
