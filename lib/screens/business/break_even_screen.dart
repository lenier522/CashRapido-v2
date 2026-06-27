import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../providers/business_provider.dart';
import '../../models/product.dart';
import '../../models/business_expense.dart';
import '../../services/localization_service.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

const List<String> _fixedCategories = [
  'Alquiler',
  'Servicios',
  'Salarios',
  'Marketing',
];

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
        final double baseMonthlyFixedCosts = _calcBaseMonthlyFixedCosts(allExpenses, provider);
        final double periodFixedCosts = _calcFixedCostsForPeriod(baseMonthlyFixedCosts);
        final double totalFixedCosts = math.max(0.0, periodFixedCosts + _customFixedCosts);

        if (products.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _periodSelector(context),
              const SizedBox(height: 16),
              _fixedCostsSection(context, allExpenses, totalFixedCosts, periodFixedCosts, provider),
              const SizedBox(height: 16),
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
          final double mix = totalSimulatedVolume > 0 ? estVolume / totalSimulatedVolume : 1.0 / products.length;
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
        final double contributionMarginRatio = avgPrice > 0 ? avgContributionMargin / avgPrice : 0.0;
        final double bepUnits = avgContributionMargin > 0 ? totalFixedCosts / avgContributionMargin : 0.0;
        final double bepRevenue = bepUnits * avgPrice;
        final bool isNegativeMargin = avgContributionMargin <= 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period Selector & Simulator Header
            _periodSelector(context),
            const SizedBox(height: 16),

            // Fixed Costs Configurator
            _fixedCostsSection(context, allExpenses, totalFixedCosts, periodFixedCosts, provider),
            const SizedBox(height: 16),

            // Main Results Card
            _resultsSection(context, totalFixedCosts, avgPrice, avgVarCost, avgContributionMargin, contributionMarginRatio, bepUnits, bepRevenue, isNegativeMargin),
            const SizedBox(height: 16),

            // Interactive Graph (LineChart showing cost/rev lines)
            _buildInteractiveGraph(context, totalFixedCosts, avgPrice, avgVarCost, bepUnits, bepRevenue, isNegativeMargin),
            const SizedBox(height: 16),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        context.t('break_even_simulator'),
                        style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _resetSimulation(products),
                      icon: const Icon(Icons.refresh, size: 16),
                      label: Text(context.t('break_even_reset')),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => _applySimulatedPrices(context, provider),
                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                    label: Text(
                      context.t('break_even_apply_prices'),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Product Cards for sandbox tweaking
            ...productCalculations.map((calc) {
              final Product p = calc['product'];
              final double price = calc['price'];
              final double cost = calc['cost'];
              final double margin = calc['margin'];
              final double mix = calc['mix'];
              final double estVolume = calc['estVolume'];

              // Units this product needs to sell to satisfy its share of the BEP
              final double neededUnits = bepUnits * mix;
              final bool canAchieve = neededUnits <= p.initialQuantity;

              return _buildProductSimulatorCard(context, p, price, cost, margin, mix, estVolume, neededUnits, canAchieve);
            }),
            const SizedBox(height: 32),
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
        _simulatedVolumes[p.id] = p.initialQuantity > 0 ? p.initialQuantity.toDouble() : 10.0;
        updated = true;
      }
    }

    // Clean up deleted products
    final productIds = products.map((p) => p.id).toSet();
    final deletedPrices = _simulatedPrices.keys.where((id) => !productIds.contains(id)).toList();
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
        _simulatedVolumes[p.id] = p.initialQuantity > 0 ? p.initialQuantity.toDouble() : 10.0;
      }
    });
  }

  Future<void> _applySimulatedPrices(BuildContext context, BusinessProvider provider) async {
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
          content: Text(success
              ? context.t('break_even_prices_applied')
              : 'Error al aplicar cambios'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  double _calcBaseMonthlyFixedCosts(List<BusinessExpense> expenses, BusinessProvider provider) {
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
    final periods = [
      {'key': 'monthly', 'label': context.t('break_even_monthly')},
      {'key': 'weekly', 'label': context.t('break_even_weekly')},
      {'key': 'yearly', 'label': context.t('break_even_yearly')},
    ];
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: periods.map((p) {
          final selected = _selectedPeriod == p['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = p['key']!),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? Theme.of(context).colorScheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  p['label']!,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: selected ? Colors.white : Colors.grey,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.business_center_rounded, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('break_even_fixed_costs'),
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${context.t('break_even_period')}: ${context.t('break_even_$_selectedPeriod')}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
              Text(
                '\$ ${totalFixed.toFormattedString(2)}',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Categories list checklist
          if (periodGrouped.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.t('break_even_no_expenses'),
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            )
          else
            ...periodGrouped.entries.map((e) {
              final isFixed = _fixedCategorySet.contains(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isFixed) {
                            _fixedCategorySet.remove(e.key);
                          } else {
                            _fixedCategorySet.add(e.key);
                          }
                        });
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: isFixed ? Colors.orange : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isFixed ? Colors.orange : Colors.grey.withValues(alpha: 0.4),
                            width: 1.5,
                          ),
                        ),
                        child: isFixed
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        e.key,
                        style: TextStyle(
                          fontSize: 13,
                          color: isFixed ? null : Colors.grey,
                          fontWeight: isFixed ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                    Text(
                      '\$ ${e.value.toFormattedString(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: isFixed ? FontWeight.bold : FontWeight.normal,
                        color: isFixed ? null : Colors.grey,
                      ),
                    ),
                  ],
                ),
              );
            }),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(height: 1),
          ),

          // Custom Fixed Costs Override Slider
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.add_road_outlined, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text(
                    context.t('break_even_custom_fixed_costs'),
                    style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey[750]),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_customFixedCosts >= 0 ? "+" : ""}\$ ${_customFixedCosts.toFormattedString(0)}',
                  style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() => _customFixedCosts = math.max(-periodFixed, _customFixedCosts - 100)),
                icon: const Icon(Icons.remove_circle_outline, size: 18, color: Colors.orange),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: Colors.orange,
                    inactiveTrackColor: Colors.orange.withValues(alpha: 0.2),
                    thumbColor: Colors.orange,
                    overlayColor: Colors.orange.withValues(alpha: 0.1),
                    trackHeight: 3,
                  ),
                  child: Slider(
                    min: math.min(0.0, -periodFixed),
                    max: 50000.0,
                    value: _customFixedCosts.clamp(math.min(0.0, -periodFixed), 50000.0),
                    onChanged: (val) => setState(() => _customFixedCosts = val),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => _customFixedCosts += 100),
                icon: const Icon(Icons.add_circle_outline, size: 18, color: Colors.orange),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---- EMPTY PRODUCTS ----
  Widget _emptyProducts(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            context.t('break_even_no_products'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.w500),
          ),
        ],
      ),
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
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    context.t('break_even_negative_margin_alert'),
                    style: GoogleFonts.outfit(color: Colors.red[800], fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.deepPurple.shade700,
                Colors.deepPurple.shade900,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.deepPurple.withValues(alpha: 0.25),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              Text(
                context.t('break_even_title'),
                style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white70),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.shopping_cart_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isNegativeMargin ? '∞' : bepUnits.toFormattedString(1),
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.t('break_even_units'),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 50, width: 1, color: Colors.white24),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.attach_money_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isNegativeMargin ? '∞' : '\$ ${bepRevenue.toFormattedString(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          context.t('break_even_revenue'),
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    _metricRow('Costos Fijos Totales:', '\$${fixedCosts.toFormattedString(2)}', Colors.white),
                    const SizedBox(height: 6),
                    _metricRow('Precio Ponderado:', '\$${avgPrice.toFormattedString(2)}', Colors.white70),
                    const SizedBox(height: 6),
                    _metricRow('Costo Var. Ponderado:', '\$${avgVarCost.toFormattedString(2)}', Colors.white70),
                    const SizedBox(height: 6),
                    _metricRow('Margen de Contribución:', '\$${avgMargin.toFormattedString(2)} (${(marginRatio * 100).toFormattedString(1)}%)', Colors.white70),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _metricRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(color: color.withValues(alpha: 0.8), fontSize: 12),
        ),
        Text(
          value,
          style: GoogleFonts.outfit(color: color, fontWeight: FontWeight.bold, fontSize: 12),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.deepPurple.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.analytics_rounded, color: Colors.deepPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Gráfico de Equilibrio',
                      style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Cruces de Costos vs Ingresos por volumen de ventas',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => FlLine(
                    color: Colors.grey.withValues(alpha: 0.15),
                    strokeWidth: 1,
                    dashArray: [4, 4],
                  ),
                ),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 55,
                      getTitlesWidget: (value, meta) {
                        if (value == 0) return const SizedBox();
                        String formatted = '\$${value.toStringAsFixed(0)}';
                        if (value >= 1000000) {
                          formatted = '\$${(value / 1000000).toStringAsFixed(1)}M';
                        } else if (value >= 1000) {
                          formatted = '\$${(value / 1000).toStringAsFixed(1)}K';
                        }
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: Text(
                            formatted,
                            style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                            textAlign: TextAlign.right,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 22,
                      getTitlesWidget: (value, meta) {
                        if (value == 0 || value == meta.max) return const SizedBox();
                        return Text(
                          '${value.toStringAsFixed(0)} uds',
                          style: TextStyle(fontSize: 9, color: Colors.grey[500]),
                        );
                      },
                    ),
                  ),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: maxX,
                minY: 0,
                maxY: maxY,
                lineTouchData: LineTouchData(
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => Colors.deepPurple.shade900.withValues(alpha: 0.95),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((spot) {
                        String label = '';
                        if (spot.barIndex == 0) {
                          label = 'Costos Fijos';
                        } else if (spot.barIndex == 1) {
                          label = 'Costos Totales';
                        } else if (spot.barIndex == 2) {
                          label = 'Ingresos Totales';
                        } else {
                          return null;
                        }

                        return LineTooltipItem(
                          '$label\n${spot.x.toStringAsFixed(1)} uds: \$${spot.y.toFormattedString(2)}',
                          const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                        );
                      }).toList();
                    },
                  ),
                ),
                lineBarsData: [
                  // 1. Fixed Costs line (Horizontal, Orange)
                  LineChartBarData(
                    spots: [FlSpot(0, fixedCosts), FlSpot(maxX, fixedCosts)],
                    color: Colors.orange.withValues(alpha: 0.65),
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    dashArray: [6, 4],
                  ),
                  // 2. Total Costs line (Slope, Red)
                  LineChartBarData(
                    spots: [FlSpot(0, fixedCosts), FlSpot(maxX, fixedCosts + maxX * avgVarCost)],
                    color: Colors.red.shade400,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  // 3. Total Revenue line (Slope, Green)
                  LineChartBarData(
                    spots: [FlSpot(0, 0), FlSpot(maxX, maxX * avgPrice)],
                    color: Colors.green.shade500,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  // 4. BEP Dashed Indicators & Intersection dot
                  if (!isNegativeMargin && bepUnits > 0 && bepUnits.isFinite && bepUnits <= maxX) ...[
                    // Vertical Dashed
                    LineChartBarData(
                      spots: [FlSpot(bepUnits, 0), FlSpot(bepUnits, bepRevenue)],
                      color: Colors.deepPurple.withValues(alpha: 0.4),
                      barWidth: 1.5,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                    // Horizontal Dashed
                    LineChartBarData(
                      spots: [FlSpot(0, bepRevenue), FlSpot(bepUnits, bepRevenue)],
                      color: Colors.deepPurple.withValues(alpha: 0.4),
                      barWidth: 1.5,
                      dashArray: [4, 4],
                      dotData: const FlDotData(show: false),
                    ),
                    // Spot dot
                    LineChartBarData(
                      spots: [FlSpot(bepUnits, bepRevenue)],
                      color: Colors.deepPurple,
                      barWidth: 0,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                          radius: 5,
                          color: Colors.white,
                          strokeWidth: 3,
                          strokeColor: Colors.deepPurple,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _legendItem(Colors.orange, context.t('break_even_chart_fixed')),
              _legendItem(Colors.red.shade400, context.t('break_even_chart_costs')),
              _legendItem(Colors.green.shade500, context.t('break_even_chart_revenue')),
              if (!isNegativeMargin)
                _legendItem(Colors.deepPurple, 'Equilibrio (~${bepUnits.toStringAsFixed(0)} uds)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w500)),
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
    final double marginPercent = price > 0 ? (margin / price) * 100 : 0.0;

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: canAchieve ? Colors.green.withValues(alpha: 0.15) : Colors.red.withValues(alpha: 0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Name and SKU
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  p.name,
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: canAchieve ? Colors.green.withValues(alpha: 0.1) : Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  neededUnits.isInfinite || neededUnits.isNaN
                      ? 'No viable'
                      : '${neededUnits.ceil()} uds necesarias',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: canAchieve ? Colors.green : Colors.red,
                  ),
                ),
              ),
            ],
          ),
          if (p.sku.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              'SKU: ${p.sku}',
              style: TextStyle(fontSize: 10, color: Colors.grey[500]),
            ),
          ],
          const SizedBox(height: 12),

          // Margins Stats
          Row(
            children: [
              _infoTile('Inversión Real', '\$${p.realTotalInvestment.toFormattedString(0)}', Colors.grey[700]!),
              _infoTile('Stock Inicial / Disp', '${p.initialQuantity} / ${p.currentStock}', Colors.blue.shade700),
              _infoTile('Margen Unitario', '\$${margin.toFormattedString(1)} (${marginPercent.toFormattedString(0)}%)', margin > 0 ? Colors.green : Colors.red),
              _infoTile('Peso Mix', '${(mix * 100).toFormattedString(1)}%', Colors.purple),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(height: 1),
          ),

          // Sliders Tweakers
          // 1. Sale Price Sliders
          _sliderTweaker(
            label: 'Precio de Venta c/u:',
            value: price,
            min: 0.0,
            max: math.max(p.salePrice * 2.5, 5000.0),
            step: 10.0,
            color: Colors.green,
            onChanged: (val) => setState(() => _simulatedPrices[p.id] = val),
          ),
          const SizedBox(height: 4),
          // 2. Cost Unit Sliders
          _sliderTweaker(
            label: 'Costo Variable c/u:',
            value: cost,
            min: 0.0,
            max: math.max(p.realCostPerUnit * 2.5, 5000.0),
            step: 5.0,
            color: Colors.red,
            onChanged: (val) => setState(() => _simulatedCosts[p.id] = val),
          ),
          const SizedBox(height: 4),
          // 3. Sales Mix Volume Sliders
          _sliderTweaker(
            label: 'Volumen Estimado (Proporción):',
            value: estVolume,
            min: 0.0,
            max: math.max(p.initialQuantity.toDouble() * 2.0, 100.0),
            step: 1.0,
            color: Colors.purple,
            onChanged: (val) => setState(() => _simulatedVolumes[p.id] = val),
          ),

          // Achievements checklist status
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                canAchieve ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                size: 16,
                color: canAchieve ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  canAchieve
                      ? 'Viable: Puedes equilibrar vendiendo ${neededUnits.toStringAsFixed(1)} unidades. Te sobran ${(p.initialQuantity - neededUnits).toStringAsFixed(1)} unidades de tu stock para ganancia.'
                      : 'No viable con stock actual: Te faltan ${(neededUnits - p.initialQuantity).toStringAsFixed(1)} unidades adicionales en stock para amortizar tu inversión.',
                  style: TextStyle(fontSize: 11, color: canAchieve ? Colors.green[800] : Colors.red[850], height: 1.3),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoTile(String label, String value, Color valueColor) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 11, color: valueColor),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(fontSize: 8.5, color: Colors.grey[500]),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _sliderTweaker({
    required String label,
    required double value,
    required double min,
    required double max,
    required double step,
    required Color color,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[650])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                value.toFormattedString(1),
                style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: color),
              ),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              onPressed: () => onChanged(math.max(min, value - step)),
              icon: Icon(Icons.remove_circle_outline, size: 16, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
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
              icon: Icon(Icons.add_circle_outline, size: 16, color: color),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ],
    );
  }
}
