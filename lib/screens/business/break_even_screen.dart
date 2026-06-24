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

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final products = provider.products;
        final allExpenses = provider.expenses;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final periodMultiplier = _getPeriodMultiplier();
        final fixedCosts = _calculateFixedCosts(allExpenses, periodMultiplier);

        final avgPrice = _average(products.map((p) => p.salePrice).toList());
        final avgVariableCost = _average(products.map((p) => p.costPerUnit).toList());
        final contributionMargin = avgPrice - avgVariableCost;

        final bepUnits = contributionMargin > 0
            ? (fixedCosts / contributionMargin).ceilToDouble()
            : 0.0;
        final bepRevenue = bepUnits * avgPrice;

        final totalUnitsSold = provider.sales.fold<int>(
          0,
          (sum, s) => sum + s.items.fold(0, (a, b) => a + b.quantity),
        );

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildPeriodSelector(context),
            const SizedBox(height: 16),

            if (products.isEmpty)
              _buildEmptyState(context)
            else ...[
              _buildFixedCostsCard(context, allExpenses, isDark, periodMultiplier),
              const SizedBox(height: 16),

              _buildProductsSummaryCard(context, products, avgPrice, avgVariableCost, contributionMargin, isDark),
              const SizedBox(height: 16),

              _buildResultsCard(context, bepUnits, bepRevenue, fixedCosts, avgPrice, isDark),
              const SizedBox(height: 16),

              if (totalUnitsSold > 0 || bepUnits > 0)
                _buildChart(context, totalUnitsSold.toDouble(), bepUnits, isDark),
            ],
          ],
        );
      },
    );
  }

  int _getPeriodMultiplier() {
    switch (_selectedPeriod) {
      case 'weekly':
        return 4;
      case 'yearly':
        return 12;
      default:
        return 1;
    }
  }

  double _calculateFixedCosts(List<BusinessExpense> expenses, int multiplier) {
    double total = 0;
    for (final e in expenses) {
      if (_fixedCategorySet.contains(e.category)) {
        total += e.amount;
      }
    }
    return total * multiplier;
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  Widget _buildPeriodSelector(BuildContext context) {
    final periods = [
      {'key': 'monthly', 'label': context.t('break_even_monthly')},
      {'key': 'weekly', 'label': context.t('break_even_weekly')},
      {'key': 'yearly', 'label': context.t('break_even_yearly')},
    ];

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: periods.map((p) {
          final selected = _selectedPeriod == p['key'];
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedPeriod = p['key']!),
              child: Container(
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

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            context.t('break_even_no_products'),
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFixedCostsCard(
    BuildContext context,
    List<BusinessExpense> expenses,
    bool isDark,
    int multiplier,
  ) {
    final grouped = <String, double>{};
    for (final e in expenses) {
      grouped[e.category] = (grouped[e.category] ?? 0) + e.amount;
    }

    final totalFixed = _calculateFixedCosts(expenses, multiplier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.factory, color: Colors.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                context.t('break_even_fixed_costs'),
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
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
          const SizedBox(height: 4),
          Text(
            '${context.t('break_even_period')}: ${context.t('break_even_$_selectedPeriod')}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
          const SizedBox(height: 12),
          if (grouped.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                context.t('break_even_no_expenses'),
                style: TextStyle(color: Colors.grey[400], fontSize: 13),
              ),
            )
          else
            ...grouped.entries.map((e) {
              final isFixed = _fixedCategorySet.contains(e.key);
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
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
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isFixed ? Colors.orange : Colors.grey.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: isFixed
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
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
                      '\$ ${(e.value * multiplier).toFormattedString(2)}',
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildProductsSummaryCard(
    BuildContext context,
    List<Product> products,
    double avgPrice,
    double avgVariableCost,
    double contributionMargin,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.inventory_2, color: Colors.blue, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                '${context.t('tab_products')} (${products.length})',
                style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(context, context.t('break_even_unit_price'), '\$ ${avgPrice.toFormattedString(2)}', Colors.green),
          const SizedBox(height: 8),
          _buildInfoRow(context, context.t('break_even_unit_cost'), '\$ ${avgVariableCost.toFormattedString(2)}', Colors.red),
          const SizedBox(height: 8),
          Divider(color: Colors.grey.withOpacity(0.2)),
          const SizedBox(height: 8),
          _buildInfoRow(
            context,
            context.t('break_even_contribution_margin'),
            '\$ ${contributionMargin.toFormattedString(2)}',
            Colors.deepPurple,
            bold: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, Color color, {bool bold = false}) {
    return Row(
      children: [
        Container(height: 8, width: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
        const Spacer(),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: bold ? FontWeight.bold : FontWeight.w600,
            color: bold ? color : null,
          ),
        ),
      ],
    );
  }

  Widget _buildResultsCard(
    BuildContext context,
    double bepUnits,
    double bepRevenue,
    double fixedCosts,
    double avgPrice,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.deepPurple.withOpacity(0.85),
            Colors.deepPurple,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.deepPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            context.t('break_even_title'),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildResultItem(
                  '${bepUnits.toFormattedString(0)}',
                  context.t('break_even_units'),
                  Icons.shopping_cart,
                ),
              ),
              Container(height: 40, width: 1, color: Colors.white24),
              Expanded(
                child: _buildResultItem(
                  '\$ ${bepRevenue.toFormattedString(2)}',
                  context.t('break_even_revenue'),
                  Icons.attach_money,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline, size: 16, color: Colors.white70),
                const SizedBox(width: 8),
                Text(
                  '${context.t('break_even_explanation')}: \$ ${fixedCosts.toFormattedString(2)} / \$ ${avgPrice > 0 ? (avgPrice - fixedCosts / (bepUnits > 0 ? bepUnits : 1)).toFormattedString(2) : '0.00'}',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String value, String label, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white70, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.outfit(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildChart(BuildContext context, double current, double target, bool isDark) {
    final maxVal = (current > target ? current : target) * 1.3;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('break_even_chart_title'),
            style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 200,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxVal,
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${rod.toY.toFormattedString(0)}',
                        const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final labels = [
                          context.t('break_even_sold'),
                          context.t('break_even_needed'),
                        ];
                        final idx = value.toInt();
                        if (idx < 0 || idx >= labels.length) return const SizedBox();
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            labels[idx],
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 50,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toFormattedString(0),
                          style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxVal / 4,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                      color: Colors.grey.withOpacity(0.1),
                      strokeWidth: 1,
                    );
                  },
                ),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, current, Colors.blue),
                  _makeBarGroup(1, target, Colors.deepPurple),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(Colors.blue, context.t('break_even_sold')),
              const SizedBox(width: 24),
              _buildLegend(Colors.deepPurple, context.t('break_even_needed')),
            ],
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y > 0 ? y : 0.1,
          color: color,
          width: 32,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(8),
            topRight: Radius.circular(8),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4))),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }
}
