import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/icon_constants.dart';
import '../utils/number_format_utils.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chart_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_empty_state.dart';
import '../widgets/design/cash_icon_button.dart';
import '../widgets/design/cash_input.dart';
import '../widgets/design/cash_progress_bar.dart';
import '../widgets/design/cash_section.dart';
import '../widgets/design/cash_stat_card.dart';
import 'licenses_screen.dart';

/// Períodos disponibles en el análisis.
///
/// El conjunto no se reduce ni se amplía: `canViewDetailedStats` decide cuáles
/// están abiertos, igual que antes.
enum TimeRange { day, week, month, year, custom }

/// Ventana de fechas analizada. Ambas extremos son inclusivos por día.
class _Period {
  final DateTime start;
  final DateTime end;

  const _Period(this.start, this.end);

  int get days =>
      end.difference(DateTime(start.year, start.month, start.day)).inDays + 1;
}

/// Resultado de agregar los movimientos ya filtrados.
///
/// Solo agrupa: no decide ni redondea nada. Los importes se suman tal cual
/// llegan del movimiento, de modo que la cifra que se muestra es exactamente
/// la misma que la que se guardó.
class _StatsSummary {
  final double income;
  final double expense;
  final Map<String, double> byCategory;
  final int count;

  const _StatsSummary({
    required this.income,
    required this.expense,
    required this.byCategory,
    required this.count,
  });

  double get net => income - expense;

  /// Periodo sin ningún movimiento, ni de ingreso ni de gasto.
  bool get hasNoMovements => count == 0;

  /// El lado seleccionado (gasto o ingreso) no tiene nada que repartir.
  bool isScopeEmpty(bool showIncome) => showIncome ? income == 0 : expense == 0;

  /// Porcentaje que representa [value] sobre el total del lado seleccionado.
  double shareOf(double value, bool showIncome) {
    final double total = showIncome ? income : expense;
    if (total <= 0) return 0;
    return value / total * 100;
  }
}

/// Un punto del eje horizontal del gráfico de evolución.
class _Bucket {
  final int index;
  final String label;

  const _Bucket(this.index, this.label);
}

/// Cambio de una métrica entre el período actual y el anterior.
class _Trend {
  final double percent;
  final bool increased;

  const _Trend(this.percent, this.increased);

  String get label {
    final String value = '${percent.toFormattedString(1)}%';
    return increased ? '+$value' : '-$value';
  }
}

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  /// Categorías mostradas antes de desplegar la lista completa.
  static const int _collapsedCategories = 5;

  /// Secciones que se muestran en el gráfico circular antes de agrupar el
  /// resto en "Otros". La lista de texto siempre las enumera todas.
  static const int _maxPieSections = 5;

  /// Fechas de la línea de tiempo.
  DateTime _selectedDate = DateTime.now();
  TimeRange _timeRange = TimeRange.month;
  DateTimeRange? _customDateRange;

  /// Lado que muestran el gráfico y el desglose: `false` gasto, `true` ingreso.
  bool _showIncome = false;

  /// 'all' | 'card' | 'cash' | id de cuenta.
  String _accountTypeFilter = 'all';

  /// Moneda de las estadísticas.
  ///
  /// Las estadísticas nunca mezclan monedas: se calcula una sola y se dice cuál
  /// es. `null` se resuelve a la principal del ajuste.
  String? _currencyCode;

  /// Despliega la lista completa de categorías.
  bool _showAllCategories = false;

  /// Índice de la porción del gráfico circular que el dedo está tocando.
  int _touchedIndex = -1;

  // ---------------------------------------------------------------------------
  // ESTRUCTURA
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        // La barra de navegación principal ya reserva el espacio inferior.
        bottom: false,
        child: Consumer<AppProvider>(
          builder: (context, provider, child) {
            final List<Currency> currencies = _availableCurrencies(provider);

            if (_currencyCode == null ||
                !currencies.any((Currency c) => c.code == _currencyCode)) {
              _currencyCode = _defaultCurrencyCode(currencies);
            }

            final _Period period = _currentPeriod();
            final List<InternalTransaction> transactions = _filter(
              provider,
              period,
            );
            final _StatsSummary summary = _summarize(
              transactions,
              showIncome: _showIncome,
            );
            final _StatsSummary previous = _summarize(
              _filter(provider, _previousPeriod()),
              showIncome: _showIncome,
            );
            final int hiddenCurrencies = currencies
                .where((Currency c) => c.code != _currencyCode)
                .where(
                  (Currency c) => provider.transactions.any(
                    (InternalTransaction t) => t.currency == c.code,
                  ),
                )
                .length;

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.screenVertical,
                AppSpacing.screenHorizontal,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, provider),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildPeriodSelector(context, provider),
                  const SizedBox(height: AppSpacing.lg),
                  _buildPeriodNavigator(context, provider),
                  const SizedBox(height: AppSpacing.lg),
                  _buildFilterBar(context, provider, currencies),
                  const SizedBox(height: AppSpacing.xxl),
                  if (summary.hasNoMovements)
                    _buildEmptyState(context, provider, hiddenCurrencies)
                  else ...[
                    _buildSummary(context, provider, summary, previous),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildChart(
                      context,
                      provider,
                      transactions,
                      summary,
                      period,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildCategories(context, provider, summary),
                    const SizedBox(height: AppSpacing.xxl),
                    _buildInsights(context, provider, summary, previous),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, AppProvider provider) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.t('statistics'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineMedium,
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                context.t('stats_subtitle'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        CashIconButton(
          icon: Icons.calendar_month_rounded,
          tooltip: context.t('stats_select_range'),
          onPressed: () => _guard(
            context,
            provider.canViewDetailedStats,
            () => _showDatePickerForRange(context),
          ),
          // El candado avisa de que el salto por fechas es una función de pago
          // antes de que el usuario lo descubra al tocar.
          badge: provider.canViewDetailedStats ? null : const _LockBadge(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SELECTOR DE PERÍODO
  // ---------------------------------------------------------------------------

  Widget _buildPeriodSelector(BuildContext context, AppProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('stats_period'),
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: <Widget>[
            for (final TimeRange range in TimeRange.values)
              _buildPeriodChip(context, provider, range),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodChip(
    BuildContext context,
    AppProvider provider,
    TimeRange range,
  ) {
    final bool selected = _timeRange == range;

    // El mes siempre está abierto; el resto es una función de pago.
    final bool locked =
        !provider.canViewDetailedStats && range != TimeRange.month;

    return CashChip(
      label: _periodLabel(context, range),
      selected: selected,
      color: AppColors.primary,
      // El estado no se apoya solo en el color: la selección suma un check y
      // el bloqueo un candado.
      icon: locked
          ? Icons.lock_rounded
          : selected
          ? Icons.check_rounded
          : null,
      onTap: locked
          ? () => _showLicenseDialog(context)
          : () => _selectPeriod(context, range),
    );
  }

  void _selectPeriod(BuildContext context, TimeRange range) {
    if (range == TimeRange.custom) {
      _pickCustomRange(context);
      return;
    }
    setState(() {
      _timeRange = range;
      _touchedIndex = -1;
    });
  }

  Future<void> _pickCustomRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange:
          _customDateRange ??
          DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 7)),
            end: DateTime.now(),
          ),
    );

    if (picked == null || !mounted) return;

    setState(() {
      _timeRange = TimeRange.custom;
      _customDateRange = picked;
      _touchedIndex = -1;
    });
  }

  String _periodLabel(BuildContext context, TimeRange range) {
    switch (range) {
      case TimeRange.day:
        return context.t('day');
      case TimeRange.week:
        return context.t('week');
      case TimeRange.month:
        return context.t('month');
      case TimeRange.year:
        return context.t('year');
      case TimeRange.custom:
        return context.t('range');
    }
  }

  // ---------------------------------------------------------------------------
  // NAVEGACIÓN ENTRE PERÍODOS
  // ---------------------------------------------------------------------------

  Widget _buildPeriodNavigator(BuildContext context, AppProvider provider) {
    if (_timeRange == TimeRange.custom) {
      return CashCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 20,
              color: AppColors.primary,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                _dateLabel(context),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            CashButton(
              label: context.t('edit'),
              type: CashButtonType.outlined,
              fullWidth: false,
              height: 40,
              onPressed: () => _pickCustomRange(context),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        _buildNavButton(
          context,
          provider,
          icon: Icons.chevron_left_rounded,
          onPressed: () => setState(() => _updateDate(-1)),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            _dateLabel(context),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        _buildNavButton(
          context,
          provider,
          icon: Icons.chevron_right_rounded,
          onPressed: () => setState(() => _updateDate(1)),
        ),
      ],
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    AppProvider provider, {
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return CashIconButton(
      icon: icon,
      size: 44,
      bordered: true,
      onPressed: () =>
          _guard(context, provider.canViewDetailedStats, onPressed),
      badge: provider.canViewDetailedStats ? null : const _LockBadge(),
    );
  }

  void _updateDate(int direction) {
    setState(() {
      switch (_timeRange) {
        case TimeRange.day:
          _selectedDate = _selectedDate.add(Duration(days: direction));
          break;
        case TimeRange.week:
          _selectedDate = _selectedDate.add(Duration(days: direction * 7));
          break;
        case TimeRange.month:
          _selectedDate = DateTime(
            _selectedDate.year,
            _selectedDate.month + direction,
            _selectedDate.day,
          );
          break;
        case TimeRange.year:
          _selectedDate = DateTime(
            _selectedDate.year + direction,
            _selectedDate.month,
            _selectedDate.day,
          );
          break;
        case TimeRange.custom:
          // El rango personalizado se cambia con el selector, no con las flechas.
          break;
      }
      _touchedIndex = -1;
    });
  }

  String _dateLabel(BuildContext context) {
    final String locale = Localizations.localeOf(context).toString();
    final DateFormat dateFormat = DateFormat.yMMMMd(locale);
    final DateFormat monthFormat = DateFormat.yMMMM(locale);
    final DateFormat yearFormat = DateFormat.y(locale);
    final DateFormat shortDate = DateFormat.MMMd(locale);

    switch (_timeRange) {
      case TimeRange.day:
        return dateFormat.format(_selectedDate);
      case TimeRange.week:
        final DateTime startOfWeek = _startOfWeek(_selectedDate);
        final DateTime endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${shortDate.format(startOfWeek)} - ${shortDate.format(endOfWeek)}';
      case TimeRange.month:
        return monthFormat.format(_selectedDate);
      case TimeRange.year:
        return yearFormat.format(_selectedDate);
      case TimeRange.custom:
        if (_customDateRange == null) return context.t('stats_select_range');
        return '${shortDate.format(_customDateRange!.start)} - '
            '${shortDate.format(_customDateRange!.end)}';
    }
  }

  // ---------------------------------------------------------------------------
  // FILTROS
  // ---------------------------------------------------------------------------

  Widget _buildFilterBar(
    BuildContext context,
    AppProvider provider,
    List<Currency> currencies,
  ) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        CashChip(
          label:
              '${context.t('stats_account_filter')}: '
              '${_shorten(_accountFilterLabel(context, provider), 22)}',
          selected: _accountTypeFilter != 'all',
          icon: _accountTypeFilter == 'all'
              ? Icons.account_balance_wallet_rounded
              : Icons.check_rounded,
          onTap: () => _showAccountFilterSheet(context, provider),
        ),
        for (final Currency currency in currencies)
          CashChip(
            label: currency.code,
            selected: currency.code == _currencyCode,
            icon: currency.code == _currencyCode ? Icons.check_rounded : null,
            onTap: () => setState(() => _currencyCode = currency.code),
          ),
      ],
    );
  }

  String _accountFilterLabel(BuildContext context, AppProvider provider) {
    switch (_accountTypeFilter) {
      case 'all':
        return context.t('all_accounts');
      case 'card':
        return context.t('bank_cards_only');
      case 'cash':
        return context.t('cash_only');
      default:
        final Iterable<AccountCard> match = provider.cards.where(
          (AccountCard c) => c.id == _accountTypeFilter,
        );
        if (match.isEmpty) return context.t('all_accounts');
        final AccountCard card = match.first;
        return card.isCash ? card.name : (card.bankName ?? card.name);
    }
  }

  Future<void> _showAccountFilterSheet(
    BuildContext context,
    AppProvider provider,
  ) async {
    final String? selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.surfaceDark
          : AppColors.surfaceLight,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.72,
          ),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: <Widget>[
              Text(
                context.t('stats_account_filter'),
                style: Theme.of(
                  ctx,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildFilterOption(
                ctx,
                'all',
                context.t('all_accounts'),
                icon: Icons.account_balance_wallet_rounded,
              ),
              _buildFilterOption(
                ctx,
                'card',
                context.t('bank_cards_only'),
                icon: Icons.credit_card_rounded,
              ),
              _buildFilterOption(
                ctx,
                'cash',
                context.t('cash_only'),
                icon: Icons.payments_rounded,
              ),
              for (final AccountCard card in provider.cards)
                _buildFilterOption(
                  ctx,
                  card.id,
                  _cardFilterLabel(context, card),
                  icon: card.isCash
                      ? Icons.account_balance_wallet_rounded
                      : Icons.credit_card_rounded,
                  dotColor: Color(card.colorValue),
                  locked: !provider.canFilterStatsByIndividualAccount,
                ),
            ],
          ),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _accountTypeFilter = selected);
  }

  String _cardFilterLabel(BuildContext context, AccountCard card) {
    if (card.isCash) {
      return '${context.t('card_cash')} - ${card.name}';
    }
    final String bank = card.bankName == 'Efectivo'
        ? context.t('card_cash')
        : (card.bankName ?? context.t('card_default_name'));
    final String digits = card.cardNumber.length >= 4
        ? card.cardNumber.substring(card.cardNumber.length - 4)
        : '****';
    return '$bank $digits';
  }

  Widget _buildFilterOption(
    BuildContext context,
    String value,
    String label, {
    IconData? icon,
    Color? dotColor,
    bool locked = false,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool selected = _accountTypeFilter == value;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: selected
            ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
            : Colors.transparent,
        borderRadius: AppRadius.radiusMd,
        child: InkWell(
          borderRadius: AppRadius.radiusMd,
          onTap: locked
              ? () => _showLicenseDialog(context)
              : () => Navigator.pop(context, value),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                if (dotColor != null)
                  Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                      ),
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 20, color: AppColors.primary),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (locked)
                  const Padding(
                    padding: EdgeInsets.only(left: AppSpacing.sm),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                  )
                else if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RESUMEN FINANCIERO
  // ---------------------------------------------------------------------------

  Widget _buildSummary(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary,
    _StatsSummary previous,
  ) {
    final _Trend? incomeTrend = _trend(summary.income, previous.income);
    final _Trend? expenseTrend = _trend(summary.expense, previous.expense);
    final _Trend? netTrend = previous.net > 0
        ? _trend(summary.net, previous.net)
        : null;

    final List<Widget> cards = <Widget>[
      CashStatCard(
        title: context.t('income'),
        value: _money(provider, summary.income),
        icon: Icons.south_west_rounded,
        iconColor: AppColors.income,
        trend: incomeTrend?.label,
        trendPositive: incomeTrend?.increased,
      ),
      CashStatCard(
        title: context.t('expense'),
        value: _money(provider, summary.expense),
        icon: Icons.north_east_rounded,
        iconColor: AppColors.expense,
        trend: expenseTrend?.label,
        trendPositive: expenseTrend?.increased,
        // Gastar menos es una buena noticia aunque la cifra baje.
        trendGoodWhenDown: true,
      ),
      CashStatCard(
        title: context.t('stats_net'),
        value: _money(provider, summary.net, signed: true),
        icon: summary.net >= 0
            ? Icons.savings_rounded
            : Icons.trending_down_rounded,
        iconColor: summary.net >= 0 ? AppColors.income : AppColors.expense,
        trend: netTrend?.label,
        trendPositive: netTrend?.increased,
      ),
    ];

    return CashSection(
      title: _scopeTitle(context, provider),
      subtitle: _tpl(context, 'stats_movements', <String, String>{
        '{n}': '${summary.count}',
      }),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double spacing = AppSpacing.md;
          // En pantallas muy estrechas una sola columna: dos tarjetas de 134 px
          // obligan a recortar el importe, y el importe es el dato principal.
          final int columns = constraints.maxWidth >= 420
              ? 3
              : constraints.maxWidth >= 300
              ? 2
              : 1;
          final double itemWidth =
              (constraints.maxWidth - spacing * (columns - 1)) / columns;
          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: <Widget>[
              for (final Widget card in cards)
                SizedBox(width: itemWidth, child: card),
            ],
          );
        },
      ),
    );
  }

  /// Variación entre dos importes. Sin base de comparación no se inventa nada.
  _Trend? _trend(double current, double previous) {
    if (previous <= 0) return null;
    final double difference = (current - previous) / previous * 100;
    return _Trend(difference.abs(), difference >= 0);
  }

  // ---------------------------------------------------------------------------
  // GRÁFICO
  // ---------------------------------------------------------------------------

  Widget _buildChart(
    BuildContext context,
    AppProvider provider,
    List<InternalTransaction> transactions,
    _StatsSummary summary,
    _Period period,
  ) {
    final bool scopeEmpty = summary.isScopeEmpty(_showIncome);
    final String chartType = provider.chartType;

    return CashSection(
      title: _scopeTitle(context, provider),
      subtitle: scopeEmpty
          ? context.t('no_data')
          : _tpl(context, 'stats_movements', <String, String>{
              '{n}': '${summary.count}',
            }),
      // Los dos selectores viven en filas propias con envoltura: juntos no caben
      // en una sola línea a 320 px y una fila fija los dejaría fuera de pantalla.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildScopeToggle(context),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) => CashChartCard(
              // El título de la tarjeta es la pregunta que responde el gráfico;
              // el lado y la moneda ya están en el título de la sección.
              title: _chartTitle(context, chartType),
              subtitle: scopeEmpty
                  ? context.t('no_data')
                  : _chartSubtitle(context, summary, chartType),
              height: CashChartCard.heightFor(constraints.maxWidth),
              chart: scopeEmpty
                  ? _buildNoChartData(context)
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 220),
                      child: KeyedSubtree(
                        key: ValueKey<String>(
                          '$chartType|${_timeRange.name}|$_showIncome'
                          '|$_currencyCode',
                        ),
                        child: _buildChartBody(
                          context,
                          provider,
                          transactions,
                          summary,
                          period,
                          chartType,
                        ),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _buildChartTypeSelector(context, provider),
        ],
      ),
    );
  }

  /// Pregunta concreta que responde el gráfico seleccionado.
  String _chartTitle(BuildContext context, String chartType) {
    switch (chartType) {
      case 'Bar':
        return context.t('stats_top_expenses');
      case 'Line':
        return context.t('stats_evolution');
      default:
        return context.t('stats_distribution');
    }
  }

  /// Segunda línea de la tarjeta: el detalle que hace legible el gráfico.
  String _chartSubtitle(
    BuildContext context,
    _StatsSummary summary,
    String chartType,
  ) {
    switch (chartType) {
      case 'Bar':
      case 'Pie':
        return _tpl(context, 'stats_categories', <String, String>{
          '{n}': '${summary.byCategory.length}',
        });
      case 'Line':
        return switch (_timeRange) {
          TimeRange.day => context.t('stats_by_hour'),
          TimeRange.year => context.t('stats_by_month'),
          _ => context.t('stats_by_day'),
        };
      default:
        return context.t('no_data');
    }
  }

  Widget _buildScopeToggle(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.xs,
      children: <Widget>[
        CashChip(
          label: context.t('expense'),
          selected: !_showIncome,
          color: AppColors.expense,
          onTap: () => _setScope(context, false),
        ),
        CashChip(
          label: context.t('income'),
          selected: _showIncome,
          color: AppColors.income,
          onTap: () => _setScope(context, true),
        ),
      ],
    );
  }

  void _setScope(BuildContext context, bool showIncome) {
    if (_showIncome == showIncome) return;
    setState(() {
      _showIncome = showIncome;
      _touchedIndex = -1;
      _showAllCategories = false;
    });
  }

  Widget _buildChartTypeSelector(BuildContext context, AppProvider provider) {
    // Solo el sector está abierto para los niveles basic; el resto es de pago.
    const List<String> types = <String>['Pie', 'Bar', 'Line'];
    const Map<String, IconData> icons = <String, IconData>{
      'Pie': Icons.pie_chart_rounded,
      'Bar': Icons.bar_chart_rounded,
      'Line': Icons.show_chart_rounded,
    };

    return Wrap(
      spacing: AppSpacing.xs,
      children: <Widget>[
        for (final String type in types)
          CashChip(
            label: switch (type) {
              'Bar' => context.t('stats_chart_bar'),
              'Line' => context.t('stats_chart_line'),
              _ => context.t('stats_chart_pie'),
            },
            icon: icons[type],
            selected: provider.chartType == type,
            color: AppColors.primary,
            onTap: () => _guard(
              context,
              provider.canCustomizeCharts || type == 'Pie',
              () => provider.setChartType(type),
            ),
          ),
      ],
    );
  }

  Widget _buildChartBody(
    BuildContext context,
    AppProvider provider,
    List<InternalTransaction> transactions,
    _StatsSummary summary,
    _Period period,
    String chartType,
  ) {
    switch (chartType) {
      case 'Bar':
        return _buildBarChart(context, provider, summary);
      case 'Line':
        return _buildLineChart(context, provider, transactions, period);
      default:
        return _buildPieChart(context, provider, summary);
    }
  }

  Widget _buildNoChartData(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.query_stats_rounded,
            size: 36,
            color: isDark ? AppColors.textDisabledDark : AppColors.textDisabled,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.t('no_data'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GRÁFICO CIRCULAR
  // ---------------------------------------------------------------------------

  Widget _buildPieChart(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<MapEntry<String, double>> sorted = _sortedCategories(summary);

    // Pasado cierto número de porciones el círculo deja de leerse: el resto se
    // agrupa y la lista de texto sigue enumerando cada categoría, así que no
    // se pierde ningún dato.
    final List<MapEntry<String, double>> visible = sorted
        .take(_maxPieSections)
        .toList();
    final double grouped = sorted
        .skip(_maxPieSections)
        .fold<double>(
          0,
          (double sum, MapEntry<String, double> e) => sum + e.value,
        );
    final double total = _scopeTotal(summary);

    final List<PieChartSectionData> sections = <PieChartSectionData>[];
    for (int i = 0; i < visible.length; i++) {
      final Category category = _categoryFor(visible[i].key);
      sections.add(
        _pieSection(
          context,
          color: Color(category.colorValue),
          share: summary.shareOf(visible[i].value, _showIncome),
          touched: _touchedIndex == i,
          isDark: isDark,
        ),
      );
    }

    if (grouped > 0) {
      sections.add(
        _pieSection(
          context,
          color: isDark
              ? AppColors.surfaceDark3
              : AppColors.surfaceVariantLight,
          share: summary.shareOf(grouped, _showIncome),
          touched: _touchedIndex == visible.length,
          isDark: isDark,
          textColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondary,
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 52,
            startDegreeOffset: -90,
            pieTouchData: PieTouchData(
              touchCallback: (FlTouchEvent event, PieTouchResponse? response) {
                if (!event.isInterestedForInteractions ||
                    response?.touchedSection == null) {
                  if (_touchedIndex == -1) return;
                  setState(() => _touchedIndex = -1);
                  return;
                }
                final int index = response!.touchedSection!.touchedSectionIndex;
                if (index == _touchedIndex) return;
                setState(() => _touchedIndex = index);
              },
            ),
            borderData: FlBorderData(show: false),
            sections: sections,
          ),
        ),
        // El centro del gráfico no admite hijos: se superpone y no intercepta
        // el toque, para que el círculo siga siendo interactivo.
        IgnorePointer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                _showIncome ? context.t('income') : context.t('expense'),
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                _money(provider, total),
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  PieChartSectionData _pieSection(
    BuildContext context, {
    required Color color,
    required double share,
    required bool touched,
    required bool isDark,
    Color? textColor,
  }) {
    // El porcentaje se pinta sobre el color de la categoría, así que el texto
    // necesita su propio contraste en lugar de asumir uno.
    final Color foreground =
        textColor ??
        (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
            ? AppColors.backgroundLight
            : AppColors.textPrimary);

    return PieChartSectionData(
      color: color,
      value: share <= 0 ? 1 : share,
      radius: touched ? 62 : 52,
      // Solo las porciones con peso propio llevan etiqueta: en las slivers
      // estrechas el texto se solaparía.
      title: share >= 5 ? '${share.toFormattedString(0)}%' : '',
      titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foreground,
        fontWeight: FontWeight.w700,
      ),
      borderSide: BorderSide(
        color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
        width: 2,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GRÁFICO DE BARRAS
  // ---------------------------------------------------------------------------

  Widget _buildBarChart(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<MapEntry<String, double>> top = _sortedCategories(
      summary,
    ).take(_maxPieSections).toList();

    if (top.isEmpty) return _buildNoChartData(context);

    final double maxValue = top.first.value;
    final double maxY = maxValue <= 0 ? 100 : maxValue * 1.2;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => CashChartCard.tooltipColor(context),
            tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
            getTooltipItem:
                (
                  BarChartGroupData group,
                  int groupIndex,
                  BarChartRodData rod,
                  int rodIndex,
                ) {
                  final Category category = _categoryFor(top[group.x].key);
                  final Color foreground = CashChartCard.tooltipTextColor(
                    context,
                  );
                  return BarTooltipItem(
                    category.name,
                    TextStyle(color: foreground, fontWeight: FontWeight.w700),
                    children: <TextSpan>[
                      TextSpan(
                        text:
                            '\n${_money(provider, rod.toY)}'
                            ' · ${summary.shareOf(top[group.x].value, _showIncome).toFormattedString(0)}%',
                        style: TextStyle(
                          color: foreground,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (double value) =>
              FlLine(color: CashChartCard.gridColor(context), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
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
              reservedSize: 28,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value != value.roundToDouble()) {
                  return const SizedBox.shrink();
                }
                final int index = value.toInt();
                if (index < 0 || index >= top.length) {
                  return const SizedBox.shrink();
                }
                final Category category = _categoryFor(top[index].key);
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Icon(
                    IconConstants.getCategoryIcon(category.iconCode),
                    size: 18,
                    color: Color(category.colorValue),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < top.length; i++)
            BarChartGroupData(
              x: i,
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: top[i].value,
                  width: 18,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xs),
                  ),
                  color: Color(_categoryFor(top[i].key).colorValue),
                  // La pista de fondo da contexto de cuánto queda por llegar
                  // al valor mayor sin añadir otra rejilla.
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxY,
                    color: isDark
                        ? AppColors.surfaceDark2
                        : AppColors.surfaceVariantLight,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GRÁFICO DE EVOLUCIÓN
  // ---------------------------------------------------------------------------

  /// Una sola línea: la evolución del lado seleccionado a lo largo del período.
  ///
  /// No se apilan ingresos y gastos porque mezclarlos en un mismo eje obliga a
  /// elegir una escala y la comparación deja de ser honesta. El resumen de
  /// arriba ya muestra las tres cifras a la vez.
  Widget _buildLineChart(
    BuildContext context,
    AppProvider provider,
    List<InternalTransaction> transactions,
    _Period period,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<_Bucket> buckets = _buckets(context, period);
    final Color lineColor = _showIncome ? AppColors.income : AppColors.expense;
    final List<double> values = _valuesPerBucket(transactions, buckets, period);

    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < buckets.length; i++)
        FlSpot(buckets[i].index.toDouble(), values[i]),
    ];

    final double peak = values.fold<double>(
      0,
      (double max, double value) => value > max ? value : max,
    );
    final double maxY = peak <= 0 ? 100 : peak * 1.2;

    // Una marca por cada seis cubos como máximo: nunca se solapan.
    final int labelStep = (buckets.length / 6).ceil().clamp(1, 999);

    return LineChart(
      LineChartData(
        minX: buckets.first.index.toDouble(),
        maxX: buckets.last.index.toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (double value) =>
              FlLine(color: CashChartCard.gridColor(context), strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
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
              reservedSize: 26,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.round();
                if (index % labelStep != 0 ||
                    index < 0 ||
                    index >= buckets.length) {
                  return const SizedBox.shrink();
                }
                // Sin espacio para la etiqueta no se dibuja: el tooltip sigue
                // dando el dato exacto.
                if (meta.parentAxisSize / buckets.length < 30) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    buckets[index].label,
                    maxLines: 1,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: CashChartCard.axisColor(context),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => CashChartCard.tooltipColor(context),
            tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
            getTooltipItems: (List<LineBarSpot> touched) =>
                touched.map((LineBarSpot spot) {
                  final int index = spot.x.round().clamp(0, buckets.length - 1);
                  return LineTooltipItem(
                    '${buckets[index].label}\n${_money(provider, spot.y)}',
                    TextStyle(
                      color: CashChartCard.tooltipTextColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  );
                }).toList(),
          ),
        ),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.24,
            // La línea puede ser recta cuando solo hay un cubo con datos.
            preventCurveOverShooting: true,
            color: lineColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: isDark ? 0.22 : 0.12),
            ),
          ),
        ],
      ),
    );
  }

  /// Reparte el total del lado seleccionado entre los cubos del eje.
  ///
  /// Los importes se suman tal cual llegan del movimiento, solo cambia el
  /// agrupamiento: antes el eje siempre era el día del mes, incluso al mirar un
  /// día, una semana o un año, donde esa lectura no significaba nada.
  List<double> _valuesPerBucket(
    List<InternalTransaction> transactions,
    List<_Bucket> buckets,
    _Period period,
  ) {
    final List<double> values = List<double>.filled(buckets.length, 0);

    for (final InternalTransaction transaction in transactions) {
      if (_showIncome ? transaction.amount <= 0 : transaction.amount >= 0) {
        continue;
      }
      final int index = _bucketIndexOf(
        transaction.date,
        period,
        buckets.length,
      );
      if (index < 0 || index >= values.length) continue;
      values[index] += transaction.amount.abs();
    }

    return values;
  }

  /// Posición de una fecha dentro de los cubos, o -1 si no corresponde.
  int _bucketIndexOf(DateTime date, _Period period, int bucketCount) {
    switch (_timeRange) {
      case TimeRange.day:
        return date.hour.clamp(0, bucketCount - 1);
      case TimeRange.week:
        return _day(date)
            .difference(_startOfWeek(_selectedDate))
            .inDays
            .clamp(0, bucketCount - 1);
      case TimeRange.month:
        return (date.day - 1).clamp(0, bucketCount - 1);
      case TimeRange.year:
        return (date.month - 1).clamp(0, bucketCount - 1);
      case TimeRange.custom:
        if (period.days <= 31) {
          return _day(
            date,
          ).difference(period.start).inDays.clamp(0, bucketCount - 1);
        }
        return ((date.year - period.start.year) * 12 +
                date.month -
                period.start.month)
            .clamp(0, bucketCount - 1);
    }
  }

  /// Cubos del eje horizontal según el período: horas en un día, días en una
  /// semana o un mes, meses en un año.
  List<_Bucket> _buckets(BuildContext context, _Period period) {
    final String locale = Localizations.localeOf(context).toString();
    final DateFormat weekday = DateFormat.E(locale);
    final DateFormat monthShort = DateFormat.MMM(locale);

    switch (_timeRange) {
      case TimeRange.day:
        return <_Bucket>[
          for (int hour = 0; hour < 24; hour += 1)
            _Bucket(hour, hour % 6 == 0 ? '$hour' : ''),
        ];
      case TimeRange.week:
        final DateTime start = _startOfWeek(_selectedDate);
        return <_Bucket>[
          for (int i = 0; i < 7; i += 1)
            _Bucket(i, weekday.format(start.add(Duration(days: i)))),
        ];
      case TimeRange.month:
        final int days = DateUtils.getDaysInMonth(
          _selectedDate.year,
          _selectedDate.month,
        );
        return <_Bucket>[
          for (int day = 1; day <= days; day += 1) _Bucket(day - 1, '$day'),
        ];
      case TimeRange.year:
        return <_Bucket>[
          for (int i = 0; i < 12; i += 1)
            _Bucket(i, monthShort.format(DateTime(_selectedDate.year, i + 1))),
        ];
      case TimeRange.custom:
        if (period.days <= 31) {
          return <_Bucket>[
            for (int day = 0; day < period.days; day += 1)
              _Bucket(day, '${period.start.add(Duration(days: day)).day}'),
          ];
        }
        final int months =
            (period.end.year - period.start.year) * 12 +
            period.end.month -
            period.start.month +
            1;
        return <_Bucket>[
          for (int i = 0; i < months; i += 1)
            _Bucket(
              i,
              monthShort.format(
                DateTime(period.start.year, period.start.month + i),
              ),
            ),
        ];
    }
  }
  // ---------------------------------------------------------------------------
  // CATEGORÍAS
  // ---------------------------------------------------------------------------

  Widget _buildCategories(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary,
  ) {
    final ThemeData theme = Theme.of(context);
    final List<MapEntry<String, double>> sorted = _sortedCategories(summary);
    final bool collapsed =
        !_showAllCategories && sorted.length > _collapsedCategories;
    final List<MapEntry<String, double>> shown = collapsed
        ? sorted.take(_collapsedCategories).toList()
        : sorted;

    return CashSection(
      title: _showIncome
          ? context.t('income')
          : context.t('stats_top_expenses'),
      subtitle: context.t('stats_category_share'),
      action: sorted.length > _collapsedCategories
          ? TextButton(
              onPressed: () =>
                  setState(() => _showAllCategories = !_showAllCategories),
              child: Text(
                _showAllCategories
                    ? context.t('stats_show_less')
                    : context.t('view_all'),
              ),
            )
          : null,
      child: Column(
        children: <Widget>[
          for (final MapEntry<String, double> entry in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildCategoryRow(context, provider, summary, entry),
            ),
          if (sorted.isEmpty)
            CashCard(
              child: Text(
                context.t('no_data'),
                style: theme.textTheme.bodyMedium,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryRow(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary,
    MapEntry<String, double> entry,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final Category category = _categoryFor(entry.key);
    final Color categoryColor = Color(category.colorValue);
    final double share = summary.shareOf(entry.value, _showIncome);
    final String amount = _money(provider, entry.value, signed: _showIncome);

    // El presupuesto mensual solo tiene sentido sobre el mes y sobre el gasto,
    // igual que antes.
    final bool showBudget =
        _timeRange == TimeRange.month &&
        !_showIncome &&
        category.monthlyBudget != null &&
        category.monthlyBudget! > 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.radiusMd,
        onTap: () => _guard(
          context,
          provider.canCreateCategory,
          () => _showEditBudgetDialog(context, category, provider),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: categoryColor.withValues(alpha: 0.14),
                      borderRadius: AppRadius.radiusMd,
                    ),
                    child: Icon(
                      IconConstants.getCategoryIcon(category.iconCode),
                      size: 20,
                      color: categoryColor,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    amount,
                    maxLines: 1,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: _showIncome ? AppColors.income : AppColors.expense,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  // El porcentaje va escrito junto a la barra: la barra sola no
                  // le dice nada a quien no ve el color.
                  Text(
                    '${share.toFormattedString(0)}%',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: secondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: CashProgressBar(
                      value: share / 100,
                      color: categoryColor,
                      height: 6,
                    ),
                  ),
                ],
              ),
              if (showBudget) ...[
                const SizedBox(height: AppSpacing.sm),
                _buildBudgetProgress(context, provider, category, entry.value),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Consumo del presupuesto mensual de la categoría.
  ///
  /// El color acompaña al porcentaje, nunca lo sustituye: el número siempre
  /// está visible para saber si lo que se agotó es el límite o solo una
  /// advertencia.
  Widget _buildBudgetProgress(
    BuildContext context,
    AppProvider provider,
    Category category,
    double spent,
  ) {
    final double budget = category.monthlyBudget!;
    final double progress = spent / budget;

    final Color color = progress >= 1
        ? AppColors.expense
        : progress >= 0.8
        ? AppColors.warning
        : AppColors.income;

    return CashProgressBar(
      value: progress,
      color: color,
      label: '${context.t('stats_budget_label')}: ${_money(provider, budget)}',
      valueLabel: '${(progress * 100).toFormattedString(0)}%',
    );
  }

  // ---------------------------------------------------------------------------
  // INSIGHTS
  // ---------------------------------------------------------------------------

  Widget _buildInsights(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary,
    _StatsSummary previous,
  ) {
    final List<Widget> insights = <Widget>[];

    // 1) Principal categoría de gasto.
    if (!_showIncome && summary.expense > 0) {
      final List<MapEntry<String, double>> sorted = _sortedCategories(summary);
      if (sorted.isNotEmpty) {
        final Category top = _categoryFor(sorted.first.key);
        insights.add(
          _buildInsight(
            context,
            icon: IconConstants.getCategoryIcon(top.iconCode),
            color: Color(top.colorValue),
            text: _tpl(context, 'stats_insight_top_category', <String, String>{
              '{category}': top.name,
              '{percent}':
                  '${summary.shareOf(sorted.first.value, false).toFormattedString(0)}%',
            }),
          ),
        );
      }
    }

    // 2) Ingresos frente a gastos.
    if (summary.income > 0 || summary.expense > 0) {
      final bool surplus = summary.net >= 0;
      insights.add(
        _buildInsight(
          context,
          icon: surplus ? Icons.savings_rounded : Icons.trending_down_rounded,
          color: surplus ? AppColors.income : AppColors.expense,
          text: _tpl(
            context,
            surplus ? 'stats_insight_surplus' : 'stats_insight_deficit',
            <String, String>{'{value}': _money(provider, summary.net.abs())},
          ),
        ),
      );
    }

    // 3) Comparación con el período anterior, solo si hay base de comparación.
    if (previous.expense > 0 || previous.income > 0) {
      final double current = _showIncome ? summary.income : summary.expense;
      final double before = _showIncome ? previous.income : previous.expense;
      final double difference = (current - before) / before * 100;
      final bool equal = difference.abs() < 0.05;

      insights.add(
        _buildInsight(
          context,
          icon: equal
              ? Icons.trending_flat_rounded
              : difference > 0
              ? Icons.trending_up_rounded
              : Icons.trending_down_rounded,
          color: equal
              ? AppColors.primary
              : difference > 0
              ? AppColors.expense
              : AppColors.income,
          text: _tpl(
            context,
            equal
                ? 'stats_insight_equal'
                : difference > 0
                ? 'stats_insight_more'
                : 'stats_insight_less',
            <String, String>{
              '{percent}': '${difference.abs().toFormattedString(1)}%',
              '{period}': _dateLabel(context),
            },
          ),
        ),
      );
    }

    if (insights.isEmpty) return const SizedBox.shrink();

    return CashSection(
      title: context.t('stats_insights'),
      // Punto de extensión para que Rapi ilustre estas conclusiones (FASE 10).
      subtitle: _dateLabel(context),
      child: CashCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < insights.length; i += 1) ...[
              if (i > 0) const SizedBox(height: AppSpacing.md),
              insights[i],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInsight(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.14),
            borderRadius: AppRadius.radiusSm,
          ),
          child: Icon(icon, size: 17, color: color),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ESTADO VACÍO
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(
    BuildContext context,
    AppProvider provider,
    int hiddenCurrencies,
  ) {
    return CashCard(
      child: Column(
        children: <Widget>[
          // Punto de extensión para la ilustración de Rapi (FASE 10).
          CashEmptyState(
            icon: Icons.insights_rounded,
            title: context.t('stats_empty_title'),
            message: context.t('stats_empty_hint'),
          ),
          if (hiddenCurrencies > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                const Icon(
                  Icons.currency_exchange_rounded,
                  size: 18,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _tpl(context, 'stats_other_currencies', <String, String>{
                      '{n}': '$hiddenCurrencies',
                    }),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CÁLCULO
  // ---------------------------------------------------------------------------

  /// Ventana del período seleccionado.
  _Period _currentPeriod() {
    switch (_timeRange) {
      case TimeRange.day:
        final DateTime day = _day(_selectedDate);
        return _Period(day, day);
      case TimeRange.week:
        final DateTime start = _startOfWeek(_selectedDate);
        return _Period(start, start.add(const Duration(days: 6)));
      case TimeRange.month:
        final DateTime start = DateTime(
          _selectedDate.year,
          _selectedDate.month,
        );
        final DateTime end = DateTime(
          _selectedDate.year,
          _selectedDate.month + 1,
          0,
        );
        return _Period(start, end);
      case TimeRange.year:
        return _Period(
          DateTime(_selectedDate.year),
          DateTime(_selectedDate.year, 12, 31),
        );
      case TimeRange.custom:
        if (_customDateRange == null) {
          final DateTime today = _day(DateTime.now());
          return _Period(today, today);
        }
        return _Period(
          _day(_customDateRange!.start),
          _day(_customDateRange!.end),
        );
    }
  }

  /// Ventana inmediatamente anterior y de la misma longitud.
  ///
  /// El desplazamiento de meses y años recorta el día al último del mes destino
  /// para que comparar marzo con febrero mida meses completos y no días
  /// sueltos. Es la única diferencia respecto al salto manual del navegador de
  /// períodos, que se conserva tal cual.
  _Period _previousPeriod() {
    switch (_timeRange) {
      case TimeRange.day:
        final DateTime day = _day(
          _selectedDate,
        ).subtract(const Duration(days: 1));
        return _Period(day, day);
      case TimeRange.week:
        final DateTime start = _startOfWeek(
          _selectedDate,
        ).subtract(const Duration(days: 7));
        return _Period(start, start.add(const Duration(days: 6)));
      case TimeRange.month:
        final DateTime start = DateTime(
          _selectedDate.year,
          _selectedDate.month - 1,
          1,
        );
        final DateTime end = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          0,
        );
        return _Period(start, end);
      case TimeRange.year:
        return _Period(
          DateTime(_selectedDate.year - 1),
          DateTime(_selectedDate.year - 1, 12, 31),
        );
      case TimeRange.custom:
        final _Period current = _currentPeriod();
        final int days = current.days;
        final DateTime end = current.start.subtract(const Duration(days: 1));
        return _Period(end.subtract(Duration(days: days - 1)), end);
    }
  }

  static DateTime _day(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  static DateTime _startOfWeek(DateTime date) =>
      date.subtract(Duration(days: date.weekday - 1));

  /// Aplica período, cuenta y moneda sobre los movimientos.
  ///
  /// Es el mismo filtro que usaba la pantalla, con una condición nueva: la
  /// moneda. Mezclar importes de monedas distintas en una sola suma no significa
  /// nada, así que cada estadística se calcula para una sola y el selector de
  /// arriba dice cuál es.
  List<InternalTransaction> _filter(AppProvider provider, _Period period) {
    return provider.transactions.where((InternalTransaction t) {
      final DateTime date = _day(t.date);
      if (date.isBefore(period.start) || date.isAfter(period.end)) {
        return false;
      }
      if (t.currency != _currencyCode) return false;
      if (_accountTypeFilter == 'all') return true;

      final String? cardId = t.cardId;
      if (cardId == null) return false;

      for (final AccountCard card in provider.cards) {
        if (card.id != cardId) continue;
        if (_accountTypeFilter == 'cash') return card.isCash;
        if (_accountTypeFilter == 'card') return !card.isCash;
        return _accountTypeFilter == card.id;
      }
      // Cuenta borrada o desconocida: no se inventa a qué grupo pertenecía.
      return false;
    }).toList();
  }

  _StatsSummary _summarize(
    List<InternalTransaction> transactions, {
    required bool showIncome,
  }) {
    double income = 0;
    double expense = 0;
    final Map<String, double> byCategory = <String, double>{};

    for (final InternalTransaction transaction in transactions) {
      final double amount = transaction.amount;
      final bool isExpense = amount < 0;
      if (showIncome ? amount <= 0 : amount >= 0) continue;

      final double value = amount.abs();
      byCategory[transaction.categoryId] =
          (byCategory[transaction.categoryId] ?? 0) + value;
      if (isExpense) {
        expense += value;
      } else {
        income += value;
      }
    }

    return _StatsSummary(
      income: income,
      expense: expense,
      byCategory: byCategory,
      count: transactions.length,
    );
  }

  List<MapEntry<String, double>> _sortedCategories(_StatsSummary summary) {
    final List<MapEntry<String, double>> entries =
        summary.byCategory.entries.toList()
          ..sort((MapEntry<String, double> a, MapEntry<String, double> b) {
            final int byValue = b.value.compareTo(a.value);
            // Empate resuelto por nombre para que el orden no baile entre
            // reconstrucciones.
            return byValue != 0
                ? byValue
                : _categoryFor(a.key).name.compareTo(_categoryFor(b.key).name);
          });
    return entries;
  }

  double _scopeTotal(_StatsSummary summary) =>
      _showIncome ? summary.income : summary.expense;

  // ---------------------------------------------------------------------------
  // MONEDAS Y FORMATO
  // ---------------------------------------------------------------------------

  /// Monedas que el usuario puede analizar.
  ///
  /// Se reúnen las que tienen cuenta y las que tienen movimientos para que
  /// ningún importe quede fuera de la pantalla. La principal del ajuste va
  /// primero.
  List<Currency> _availableCurrencies(AppProvider provider) {
    final Map<String, Currency> byCode = <String, Currency>{
      for (final Currency currency in provider.availableCurrencies)
        currency.code: currency,
    };

    for (final AccountCard card in provider.cards) {
      byCode.putIfAbsent(
        card.currency,
        () => Currency(
          code: card.currency,
          symbol: card.currency,
          name: card.currency,
        ),
      );
    }
    for (final InternalTransaction transaction in provider.transactions) {
      byCode.putIfAbsent(
        transaction.currency,
        () => Currency(
          code: transaction.currency,
          symbol: transaction.currency,
          name: transaction.currency,
        ),
      );
    }

    final List<Currency> currencies = byCode.values.toList();
    currencies.sort((Currency a, Currency b) {
      if (a.code == provider.mainCurrency) return -1;
      if (b.code == provider.mainCurrency) return 1;
      return a.code.compareTo(b.code);
    });
    return currencies;
  }

  String _defaultCurrencyCode(List<Currency> currencies) =>
      currencies.isEmpty ? 'CUP' : currencies.first.code;

  Currency _currency(AppProvider provider) {
    final String code = _currencyCode ?? provider.mainCurrency;
    for (final Currency currency in provider.availableCurrencies) {
      if (currency.code == code) return currency;
    }
    return Currency(code: code, symbol: code, name: code);
  }

  /// Importe con el símbolo de la moneda analizada.
  String _money(AppProvider provider, double value, {bool signed = false}) {
    final Currency currency = _currency(provider);
    final String amount = value.abs().toFormattedString(2);
    if (signed) {
      return '${value < 0 ? '-' : '+'}${currency.symbol}$amount';
    }
    return '${currency.symbol}$amount';
  }

  // ---------------------------------------------------------------------------
  // CATEGORÍAS
  // ---------------------------------------------------------------------------

  /// Categoría de un movimiento, con su nombre traducido cuando es del catálogo
  /// y con un sustituto cuando la categoría ya no existe.
  Category _categoryFor(String categoryId) {
    final List<Category> categories = context.read<AppProvider>().categories;

    for (final Category category in categories) {
      if (category.id != categoryId) continue;
      if (category.id.startsWith('cat_')) {
        return Category(
          id: category.id,
          name: context.t(category.id),
          iconCode: category.iconCode,
          colorValue: category.colorValue,
          isCustom: category.isCustom,
          monthlyBudget: category.monthlyBudget,
        );
      }
      return category;
    }

    switch (categoryId) {
      case 'transfer_out':
      case 'transfer_in':
        return Category(
          id: 'transfers',
          name: context.t('cat_transfer'),
          iconCode: 0xe044,
          colorValue: 0xFF9E9E9E,
          isCustom: false,
        );
      case 'recharge':
        return Category(
          id: 'recharge',
          name: context.t('cat_recharge'),
          iconCode: 0xe636,
          colorValue: 0xFF2196F3,
          isCustom: false,
        );
      case 'income_request':
        return Category(
          id: 'income_request',
          name: context.t('cat_request'),
          iconCode: 0xf1c6,
          colorValue: 0xFF4CAF50,
          isCustom: false,
        );
      case 'general':
        return Category(
          id: 'general',
          name: context.t('cat_general'),
          iconCode: 0xe88e,
          colorValue: 0xFF607D8B,
          isCustom: false,
        );
      default:
        return Category(
          id: 'unknown',
          name: context.t('cat_unknown'),
          iconCode: 0xe8fd,
          colorValue: 0xFF9E9E9E,
          isCustom: false,
        );
    }
  }

  // ---------------------------------------------------------------------------
  // TEXTOS AUXILIARES
  // ---------------------------------------------------------------------------

  /// Nombre del lado seleccionado, con la moneda para que la cifra nunca sea
  /// ambigua.
  String _scopeTitle(BuildContext context, AppProvider provider) {
    final String side = _showIncome
        ? context.t('income')
        : context.t('expense');
    return '$side · ${_currency(provider).code}';
  }

  /// Recorta un texto largo para que no se convierta en un chip infinito.
  static String _shorten(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1)}\u2026';
  }

  /// Plantilla localizada con sustituciones.
  ///
  /// El servicio de traducción no admite parámetros, así que la sustitución se
  /// hace aquí en lugar de tocar el servicio para una sola pantalla.
  String _tpl(BuildContext context, String key, Map<String, String> values) {
    String result = context.t(key);
    for (final MapEntry<String, String> entry in values.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // DIÁLOGOS
  // ---------------------------------------------------------------------------

  void _guard(BuildContext context, bool allowed, VoidCallback action) {
    if (allowed) {
      action();
    } else {
      _showLicenseDialog(context);
    }
  }

  void _showLicenseDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        icon: const Icon(
          Icons.lock_rounded,
          size: 40,
          color: AppColors.warning,
        ),
        title: Text(
          context.t('feature_locked_title'),
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: Text(
          context.t('feature_locked_desc'),
          textAlign: TextAlign.center,
          style: Theme.of(ctx).textTheme.bodyMedium,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('close')),
          ),
          CashButton(
            label: context.t('upgrade_btn'),
            fullWidth: false,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicensesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _showDatePickerForRange(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked == null || !mounted) return;
    setState(() {
      _selectedDate = picked;
      _touchedIndex = -1;
    });
  }

  void _showEditBudgetDialog(
    BuildContext context,
    Category category,
    AppProvider provider,
  ) {
    final TextEditingController controller = TextEditingController(
      text: category.monthlyBudget != null && category.monthlyBudget! > 0
          ? category.monthlyBudget!.toFormattedString(2)
          : '',
    );

    showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          '${context.t('monthly_budget')} - ${category.name}',
          style: Theme.of(ctx).textTheme.titleLarge,
        ),
        content: CashInput(
          controller: controller,
          label: context.t('monthly_budget'),
          hint: context.t('monthly_budget_hint'),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          autofocus: true,
          prefix: const Icon(Icons.attach_money_rounded),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: context.t('save'),
            fullWidth: false,
            onPressed: () {
              final double? value = double.tryParse(
                controller.text
                    .replaceAll(RegExp(r'[^0-9.,]'), '')
                    .replaceAll(',', '.'),
              );
              provider.editCategoryBudget(category.id, value ?? 0.0);
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }
}

/// Candado de tamaño reducido para marcar funciones de pago.
///
/// No se apoya en el color: el icono es la señal.
class _LockBadge extends StatelessWidget {
  const _LockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: const BoxDecoration(
        color: AppColors.warning,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.lock_rounded, size: 9, color: AppColors.white),
    );
  }
}
