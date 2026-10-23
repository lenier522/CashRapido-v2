import 'package:fl_chart/fl_chart.dart';
import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../services/stats_aggregator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chart_card.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_progress_bar.dart';
import '../../widgets/design/cash_section.dart';
import '../../widgets/design/cash_stat_card.dart';
import 'stats_shared.dart';

/// Vista de **Proyección financiera**.
///
/// Estima cómo cerraría el mes natural en curso si se mantiene el ritmo
/// observado. No es una pantalla de resultados: separa en todo momento lo que
/// ya ha ocurrido (acumulado real) de lo que se estima (proyección), y cuando
/// no hay base para estimar lo dice en lugar de rellenar con ceros.
///
/// El método vive en [StatsAggregator.projection]; esta clase sólo lo presenta.
class StatsProjectionView extends StatelessWidget {
  const StatsProjectionView({
    super.key,
    required this.transactions,
    required this.money,
    this.now,
  });

  /// Movimientos ya filtrados por moneda y cuenta, de cualquier fecha.
  final List<InternalTransaction> transactions;

  /// Formateador monetario de la pantalla (símbolo + dos decimales).
  final String Function(double value, {bool signed}) money;

  /// Inyectable para pruebas; por defecto, el momento actual.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final DateTime today = now ?? DateTime.now();
    final DateTime month = StatsAggregator.firstDayOfMonth(today);

    final StatsTotals accumulated = StatsAggregator.totals(
      transactions.where(
        (InternalTransaction t) =>
            t.date.year == month.year && t.date.month == month.month,
      ),
    );
    final MonthlyProjection projection = StatsAggregator.projection(
      today: today,
      month: month,
      accumulated: accumulated,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CashSection(
          title: StatsShared.text(context, 'stats_view_projection'),
          subtitle:
              '${StatsShared.text(context, 'stats_projection_current_month')}'
              ' · ${StatsShared.monthLabel(context, month)}',
          child: projection.isEmpty
              ? _buildUnavailable(context)
              : _buildContent(context, projection),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ESTADO SIN DATOS
  // ---------------------------------------------------------------------------

  Widget _buildUnavailable(BuildContext context) {
    return CashCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.lg,
      ),
      child: CashEmptyState(
        icon: Icons.query_stats_rounded,
        title: StatsShared.text(
          context,
          'stats_projection_unavailable_title',
        ),
        message: StatsShared.text(context, 'stats_projection_unavailable_hint'),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CONTENIDO
  // ---------------------------------------------------------------------------

  Widget _buildContent(BuildContext context, MonthlyProjection projection) {
    final bool monthComplete =
        projection.isMonthComplete && projection.isCurrentMonth;

    // Cuando el mes ya terminó, la estimación coincide con lo real: el factor
    // del método es 1 y no tiene sentido marcar los valores como no
    // disponibles.
    final bool incomeShown = projection.incomeProjectionReliable || monthComplete;
    final bool expenseShown =
        projection.expenseProjectionReliable || monthComplete;
    final double projectedIncome = monthComplete
        ? projection.accumulatedIncome
        : projection.projectedIncome;
    final double projectedExpense = monthComplete
        ? projection.accumulatedExpense
        : projection.projectedExpense;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildProgress(context, projection, monthComplete),
        const SizedBox(height: AppSpacing.lg),

        // --- Resultado real acumulado -------------------------------------
        CashSection(
          title: StatsShared.text(context, 'stats_accumulated'),
          subtitle: StatsShared.text(
            context,
            'stats_projection_progress',
            <String, String>{
              '{day}': '${projection.elapsedDays}',
              '{total}': '${projection.totalDays}',
            },
          ),
          child: StatsShared.statGrid(context, <Widget>[
            CashStatCard(
              title: StatsShared.text(context, 'income'),
              value: money(projection.accumulatedIncome),
              icon: Icons.south_west_rounded,
              iconColor: AppColors.income,
            ),
            CashStatCard(
              title: StatsShared.text(context, 'expense'),
              value: money(projection.accumulatedExpense),
              icon: Icons.north_east_rounded,
              iconColor: AppColors.expense,
            ),
            CashStatCard(
              title: StatsShared.text(context, 'stats_balance_month'),
              value: money(projection.accumulatedNet, signed: true),
              icon: projection.accumulatedNet >= 0
                  ? Icons.savings_rounded
                  : Icons.trending_down_rounded,
              iconColor: projection.accumulatedNet >= 0
                  ? AppColors.income
                  : AppColors.expense,
            ),
          ]),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // --- Estimación al cierre -----------------------------------------
        CashSection(
          title: StatsShared.text(context, 'stats_projected_close'),
          subtitle: monthComplete
              ? StatsShared.text(context, 'stats_projection_month_complete')
              : null,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildEstimateBlock(
                context,
                incomeShown: incomeShown,
                expenseShown: expenseShown,
                projectedIncome: projectedIncome,
                projectedExpense: projectedExpense,
                projection: projection,
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildComparisonChart(
                context,
                projection: projection,
                incomeShown: incomeShown,
                expenseShown: expenseShown,
                projectedIncome: projectedIncome,
                projectedExpense: projectedExpense,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),

        // --- Método y advertencia -----------------------------------------
        _buildMethod(context, projection),
      ],
    );
  }

  Widget _buildProgress(
    BuildContext context,
    MonthlyProjection projection,
    bool monthComplete,
  ) {
    final double value =
        (projection.progress ?? 0).clamp(0.0, 1.0).toDouble();
    return CashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.timelapse_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  monthComplete
                      ? StatsShared.text(
                          context,
                          'stats_projection_month_complete',
                        )
                      : StatsShared.text(
                          context,
                          'stats_projection_progress',
                          <String, String>{
                            '{day}': '${projection.elapsedDays}',
                            '{total}': '${projection.totalDays}',
                          },
                        ),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          CashProgressBar(
            value: value,
            color: AppColors.primary,
            label: StatsShared.monthLabel(context, projection.start),
            valueLabel: '${(value * 100).round()}%',
          ),
        ],
      ),
    );
  }

  /// Bloque de estimaciones: dos columnas comparables (ingresos y gastos) y el
  /// balance estimado. Cada valor que no se puede afirmar se marca como no
  /// disponible en lugar de mostrar un cero engañoso.
  Widget _buildEstimateBlock(
    BuildContext context, {
    required bool incomeShown,
    required bool expenseShown,
    required double projectedIncome,
    required double projectedExpense,
    required MonthlyProjection projection,
  }) {
    final ThemeData theme = Theme.of(context);
    final double? projectedNet = incomeShown && expenseShown
        ? projectedIncome - projectedExpense
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: _estimateItem(
                context,
                icon: Icons.south_west_rounded,
                color: AppColors.income,
                label: StatsShared.text(context, 'stats_projection_income'),
                value: incomeShown
                    ? _approx(projectedIncome)
                    : null,
                unavailableLabel: StatsShared.text(
                  context,
                  'stats_projection_income_unavailable',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: _estimateItem(
                context,
                icon: Icons.north_east_rounded,
                color: AppColors.expense,
                label: StatsShared.text(context, 'stats_projection_expense'),
                value: expenseShown
                    ? _approx(projectedExpense)
                    : null,
                unavailableLabel: StatsShared.text(
                  context,
                  'stats_projection_unavailable_title',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: (projectedNet != null && projectedNet < 0
                    ? AppColors.expense
                    : AppColors.income)
                .withValues(alpha: 0.10),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                projectedNet == null
                    ? Icons.help_outline_rounded
                    : projectedNet >= 0
                    ? Icons.savings_rounded
                    : Icons.trending_down_rounded,
                size: 22,
                color: projectedNet == null
                    ? StatsShared.secondaryText(context)
                    : projectedNet >= 0
                    ? AppColors.income
                    : AppColors.expense,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  StatsShared.text(context, 'stats_projection_balance'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                projectedNet == null
                    ? StatsShared.text(
                        context,
                        'stats_savings_rate_unavailable',
                      )
                    : _approx(projectedNet, signed: true),
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
        if (!incomeShown && !projection.isMonthComplete) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                size: 16,
                color: StatsShared.secondaryText(context),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  StatsShared.text(context, 'stats_projection_no_income_hint'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: StatsShared.secondaryText(context),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _estimateItem(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String? value,
    required String unavailableLabel,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool available = value != null;
    final String display = value ?? unavailableLabel;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: AppRadius.radiusLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: StatsShared.secondaryText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            display,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: available
                ? theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  )
                : theme.textTheme.bodySmall?.copyWith(
                    color: StatsShared.secondaryText(context),
                  ),
          ),
        ],
      ),
    );
  }

  /// Distingue visualmente una estimación de un dato real: el prefijo `≈` y el
  /// texto se acompañan del bloque "Estimado al cierre".
  String _approx(double value, {bool signed = false}) {
    return '≈ ${money(value, signed: signed)}';
  }

  // ---------------------------------------------------------------------------
  // GRÁFICA DE COMPARACIÓN
  // ---------------------------------------------------------------------------

  Widget _buildComparisonChart(
    BuildContext context, {
    required MonthlyProjection projection,
    required bool incomeShown,
    required bool expenseShown,
    required double projectedIncome,
    required double projectedExpense,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final double realIncome = projection.accumulatedIncome;
    final double realExpense = projection.accumulatedExpense;
    final double maxValue = <double>[
      realIncome,
      realExpense,
      if (incomeShown) projectedIncome,
      if (expenseShown) projectedExpense,
    ].fold<double>(0, (double max, double v) => v > max ? v : max);
    final double maxY = maxValue <= 0 ? 100 : maxValue * 1.2;

    final Color projectedColor = isDark
        ? AppColors.surfaceDark2
        : AppColors.surfaceVariantLight;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return CashChartCard(
              title: StatsShared.text(context, 'stats_projected_close'),
              subtitle: StatsShared.monthLabel(context, projection.start),
              height: CashChartCard.heightFor(constraints.maxWidth),
              chart: BarChart(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeOutCubic,
                BarChartData(
                  maxY: maxY,
                  alignment: BarChartAlignment.spaceAround,
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: maxY / 3,
                    getDrawingHorizontalLine: (double value) => FlLine(
                      color: CashChartCard.gridColor(context),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (double value, TitleMeta meta) {
                          if (value != value.roundToDouble()) {
                            return const SizedBox.shrink();
                          }
                          final String label = value.toInt() == 0
                              ? StatsShared.text(context, 'income')
                              : StatsShared.text(context, 'expense');
                          return Padding(
                            padding: const EdgeInsets.only(top: AppSpacing.xs),
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: CashChartCard.axisColor(context),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) =>
                          CashChartCard.tooltipColor(context),
                      tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
                      getTooltipItem:
                          (
                            BarChartGroupData group,
                            int groupIndex,
                            BarChartRodData rod,
                            int rodIndex,
                          ) {
                            final String side = group.x == 0
                                ? StatsShared.text(context, 'income')
                                : StatsShared.text(context, 'expense');
                            final String kind = group.barRods.length > 1 &&
                                    rodIndex == 1
                                ? StatsShared.text(
                                    context,
                                    'stats_projected_close',
                                  )
                                : StatsShared.text(context, 'stats_accumulated');
                            return BarTooltipItem(
                              '$side · $kind',
                              TextStyle(
                                color: CashChartCard.tooltipTextColor(context),
                                fontWeight: FontWeight.w700,
                              ),
                              children: <TextSpan>[
                                TextSpan(
                                  text: '\n${money(rod.toY)}',
                                  style: TextStyle(
                                    color: CashChartCard.tooltipTextColor(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            );
                          },
                    ),
                  ),
                  barGroups: <BarChartGroupData>[
                    // Ingresos: real y, si procede, estimado.
                    BarChartGroupData(
                      x: 0,
                      barsSpace: 6,
                      barRods: <BarChartRodData>[
                        _rod(realIncome, AppColors.income),
                        if (incomeShown)
                          _rod(projectedIncome, AppColors.income, faded: true),
                      ],
                    ),
                    // Gastos: real y, si procede, estimado.
                    BarChartGroupData(
                      x: 1,
                      barsSpace: 6,
                      barRods: <BarChartRodData>[
                        _rod(realExpense, AppColors.expense),
                        if (expenseShown)
                          _rod(projectedExpense, AppColors.expense, faded: true),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        // Leyenda explícita: el color solo no distingue real de estimado.
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            _legend(
              context,
              color: AppColors.primary,
              label: StatsShared.text(context, 'stats_accumulated'),
              solid: true,
            ),
            _legend(
              context,
              color: projectedColor,
              label: StatsShared.text(context, 'stats_projected_close'),
              solid: false,
              outline: isDark ? AppColors.borderDark : AppColors.borderLight,
            ),
          ],
        ),
      ],
    );
  }

  BarChartRodData _rod(double value, Color color, {bool faded = false}) {
    return BarChartRodData(
      toY: value.isFinite ? value : 0,
      width: 22,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xs),
      ),
      color: faded ? color.withValues(alpha: 0.38) : color,
    );
  }

  Widget _legend(
    BuildContext context, {
    required Color color,
    required String label,
    required bool solid,
    Color? outline,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: solid ? null : Border.all(color: outline ?? color),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: StatsShared.secondaryText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // MÉTODO
  // ---------------------------------------------------------------------------

  Widget _buildMethod(BuildContext context, MonthlyProjection projection) {
    final ThemeData theme = Theme.of(context);
    return CashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.functions_rounded,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                StatsShared.text(context, 'stats_projection_method_title'),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            StatsShared.text(
              context,
              'stats_projection_method',
              <String, String>{
                '{elapsed}': '${projection.elapsedDays}',
                '{total}': '${projection.totalDays}',
              },
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: StatsShared.secondaryText(context),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                Icons.warning_amber_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  StatsShared.text(context, 'stats_projection_disclaimer'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: StatsShared.secondaryText(context),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
