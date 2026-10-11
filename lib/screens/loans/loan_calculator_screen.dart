import 'dart:math';
import 'package:flutter/material.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_section.dart';

/// Simulador de préstamos.
///
/// Es una herramienta de simulación: no crea préstamos ni escribe nada. El
/// rediseño reorganiza la pantalla en resultados, parámetros y cronograma sin
/// tocar la fórmula original ([_calculateTotalRepayment]), los rangos de los
/// controles ni la lógica del desglose. Todos los importes usan el formateador
/// numérico de CashRapido.
class LoanCalculatorScreen extends StatefulWidget {
  const LoanCalculatorScreen({super.key});

  @override
  State<LoanCalculatorScreen> createState() => _LoanCalculatorScreenState();
}

class _LoanCalculatorScreenState extends State<LoanCalculatorScreen> {
  double _principal = 1000.0;
  double _interestRate = 10.0;
  int _duration = 10;

  String _interestType = 'simple'; // 'fixed', 'simple', 'compound'
  String _frequency = 'weekly'; // 'daily', 'weekly', 'biweekly', 'monthly'

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Cálculos existentes (sin modificar).
    final totalRepayment = _calculateTotalRepayment();
    final totalProfit = totalRepayment - _principal;
    final installmentAmount = totalRepayment / _duration;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('calc_title')),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.screenVertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSimulationResults(totalRepayment, totalProfit, installmentAmount),
            const SizedBox(height: AppSpacing.xxl),

            CashSection(
              title: context.t('calc_parameters'),
              child: Column(
                children: [
                  _buildSliderSection(
                    title: context.t('calc_principal'),
                    value: _principal,
                    min: 100,
                    max: 20000,
                    divisions: 199,
                    displayVal: '\$${_principal.toStringAsFixed(0)}',
                    onChanged: (val) => setState(() => _principal = val),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildSelectionBlock(
                    label: context.t('calc_interest_scheme'),
                    choices: _buildChoiceRow(
                      choices: [
                        _Choice('fixed', context.t('calc_type_fixed'), Icons.attach_money_rounded),
                        _Choice('simple', context.t('calc_type_percentage'), Icons.percent_rounded),
                        _Choice('compound', context.t('calc_type_compound'), Icons.trending_up_rounded),
                      ],
                      selected: _interestType,
                      onSelected: _selectInterestType,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildSliderSection(
                    title: _interestType == 'fixed'
                        ? context.t('calc_fixed_interest')
                        : context.t('calc_rate'),
                    value: _interestRate,
                    min: 1,
                    max: _interestType == 'fixed' ? 5000 : 100,
                    divisions: _interestType == 'fixed' ? 100 : 99,
                    displayVal: _interestType == 'fixed'
                        ? '\$${_interestRate.toStringAsFixed(0)}'
                        : '${_interestRate.toStringAsFixed(0)}%',
                    onChanged: (val) => setState(() => _interestRate = val),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildSelectionBlock(
                    label: context.t('calc_frequency_label'),
                    choices: _buildChoiceRow(
                      choices: [
                        _Choice('daily', context.t('freq_daily'), Icons.today_rounded),
                        _Choice('weekly', context.t('freq_weekly'), Icons.view_week_rounded),
                        _Choice('biweekly', context.t('freq_biweekly'), Icons.date_range_rounded),
                        _Choice('monthly', context.t('freq_monthly'), Icons.calendar_month_rounded),
                      ],
                      selected: _frequency,
                      onSelected: (val) => setState(() => _frequency = val),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _buildSliderSection(
                    title: context.t('calc_term'),
                    value: _duration.toDouble(),
                    min: 1,
                    max: 60,
                    divisions: 59,
                    displayVal: context.t('calc_installments_count').replaceAll(
                      '{count}',
                      _duration.toStringAsFixed(0),
                    ),
                    onChanged: (val) => setState(() => _duration = val.toInt()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),

            CashSection(
              title: context.t('calc_amort_table'),
              child: _buildAmortizationBreakdown(installmentAmount),
            ),
            const SizedBox(height: AppSpacing.xxxl),
          ],
        ),
      ),
    );
  }

  /// Fórmula original del simulador: idéntica a la anterior.
  double _calculateTotalRepayment() {
    if (_interestRate <= 0) return _principal;
    switch (_interestType) {
      case 'fixed':
        return _principal + _interestRate;
      case 'simple':
        return _principal + (_principal * (_interestRate / 100));
      case 'compound':
        return _principal * pow(1 + (_interestRate / 100), _duration);
      default:
        return _principal;
    }
  }

  void _selectInterestType(String value) {
    setState(() {
      _interestType = value;
      // Mismo ajuste de rango que la implementación anterior.
      if (_interestType == 'fixed' && _interestRate > 5000) {
        _interestRate = 500;
      } else if (_interestType != 'fixed' && _interestRate > 100) {
        _interestRate = 10;
      }
    });
  }

  // ──────────────────────────────────────────
  //   RESULTADOS
  // ──────────────────────────────────────────
  Widget _buildSimulationResults(
    double totalRepayment,
    double totalProfit,
    double installmentAmount,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      color: isDark ? AppColors.surfaceDark2 : AppColors.primarySurface,
      border: Border.all(
        color: AppColors.primary.withValues(alpha: isDark ? 0.35 : 0.25),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('calc_total_to_pay'),
            style: theme.textTheme.labelMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '\$${totalRepayment.toFormattedString(2)}',
              maxLines: 1,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              ),
            ),
          ),
          const Divider(height: AppSpacing.xxl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildResultMetric(
                  label: context.t('calc_interest_earned'),
                  value: '\$${totalProfit.toFormattedString(2)}',
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _buildResultMetric(
                  label: context.t('calc_estimated_quota'),
                  value: '\$${installmentAmount.toFormattedString(2)}',
                  color: AppColors.primary,
                  alignEnd: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultMetric({
    required String label,
    required String value,
    required Color color,
    bool alignEnd = false,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
          style: theme.textTheme.labelSmall?.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   PARÁMETROS
  // ──────────────────────────────────────────
  Widget _buildSliderSection({
    required String title,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayVal,
    required ValueChanged<double> onChanged,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(color: secondary),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                displayVal,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            activeColor: AppColors.primary,
            inactiveColor: AppColors.primary.withValues(alpha: 0.15),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionBlock({
    required String label,
    required Widget choices,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          choices,
        ],
      ),
    );
  }

  /// Fila de opciones desplazable horizontalmente: conserva las etiquetas
  /// completas incluso en pantallas estrechas.
  Widget _buildChoiceRow({
    required List<_Choice> choices,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final choice in choices) ...[
            CashChip(
              label: choice.label,
              icon: choice.icon,
              selected: selected == choice.value,
              onTap: () => onSelected(choice.value),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   CRONOGRAMA
  // ──────────────────────────────────────────
  Widget _buildAmortizationBreakdown(double quotaAmount) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final count = _duration > 15 ? 15 : _duration;

    return CashCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: count,
        separatorBuilder: (context, idx) => Divider(
          color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          height: 1,
        ),
        itemBuilder: (context, idx) {
          final quota = idx + 1;
          // Misma lógica de fechas que la versión anterior.
          DateTime simDate;
          switch (_frequency) {
            case 'daily':
              simDate = today.add(Duration(days: quota));
              break;
            case 'weekly':
              simDate = today.add(Duration(days: quota * 7));
              break;
            case 'biweekly':
              simDate = today.add(Duration(days: quota * 14));
              break;
            case 'monthly':
              int y = today.year;
              int m = today.month + quota;
              while (m > 12) {
                y++;
                m -= 12;
              }
              int d = today.day;
              final int maxDays = DateUtils.getDaysInMonth(y, m);
              if (d > maxDays) d = maxDays;
              simDate = DateTime(y, m, d);
              break;
            default:
              simDate = today.add(Duration(days: quota * 30));
              break;
          }

          return Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${context.t('calc_quota')} #$quota',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${simDate.day}/${simDate.month}/${simDate.year}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      '\$${quotaAmount.toFormattedString(2)}',
                      maxLines: 1,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark3
                        : AppColors.surfaceVariantLight,
                    borderRadius: AppRadius.radiusXs,
                  ),
                  child: Text(
                    context.t('calc_simulated'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: secondary,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _Choice {
  final String value;
  final String label;
  final IconData icon;

  const _Choice(this.value, this.label, this.icon);
}
