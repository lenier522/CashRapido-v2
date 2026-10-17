import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../services/stats_aggregator.dart';
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
import '../widgets/design/cash_snack.dart';
import '../widgets/design/cash_stat_card.dart';
import 'licenses_screen.dart';
import 'stats/stats_calendar_view.dart';
import 'stats/stats_projection_view.dart';
import 'stats/stats_shared.dart';

/// Períodos disponibles en el análisis.
///
/// El conjunto no se reduce ni se amplía: `canViewDetailedStats` decide cuáles
/// están abiertos, igual que antes.
enum TimeRange { day, week, month, year, custom }

/// Apartados del centro de análisis de Estadísticas.
///
/// No son tres pantallas independientes: son tres vistas del mismo módulo,
/// que comparten estado (moneda, cuenta, movimientos) y navegación inferior.
enum StatsView { analytics, projection, calendar }

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

  /// Categorías con presupuesto que entran en la gráfica de presupuestos.
  static const int _maxBudgetBars = 6;

  /// Porciones o barras de la gráfica principal antes de agrupar el resto.
  static const int _maxChartSections = 6;

  /// Apartado activo. Analítica es el predeterminado.
  StatsView _view = StatsView.analytics;

  /// Día seleccionado del calendario.
  ///
  /// Vive aquí para poder compartirlo desde la cabecera sin reconstruir el
  /// módulo entero cada vez que el usuario toca un día: la vista del
  /// calendario escribe en este notificador y la pantalla lo lee al compartir.
  final ValueNotifier<DateTime> _calendarDay = ValueNotifier<DateTime>(
    DateTime.now(),
  );

  /// Fechas de la línea de tiempo.
  DateTime _selectedDate = DateTime.now();
  TimeRange _timeRange = TimeRange.month;
  DateTimeRange? _customDateRange;

  /// Lado que muestran la gráfica principal y el desglose: `false` gasto,
  /// `true` ingreso. El tipo de gráfica (circular, barras o línea) no se guarda
  /// aquí: es el ajuste `provider.chartType`, compartido con Ajustes.
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

  @override
  void dispose() {
    _calendarDay.dispose();
    super.dispose();
  }

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
                children: <Widget>[
                  _buildHeader(context, provider),
                  const SizedBox(height: AppSpacing.xxl),
                  _buildFilterBar(context, provider, currencies),
                  const SizedBox(height: AppSpacing.xxl),
                  ..._buildActiveView(context, provider, hiddenCurrencies),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  /// Cuerpo del apartado activo.
  ///
  /// Cada vista recibe exactamente lo que usa: Analítica trabaja sólo con el
  /// período elegido, Proyección con el mes en curso y Calendario con el
  /// historial completo del alcance (moneda y cuenta), porque necesita poder
  /// navegar por cualquier mes. Así el historial completo no se materializa
  /// mientras el usuario está en Analítica.
  List<Widget> _buildActiveView(
    BuildContext context,
    AppProvider provider,
    int hiddenCurrencies,
  ) {
    switch (_view) {
      case StatsView.analytics:
        return _buildAnalytics(context, provider, hiddenCurrencies);
      case StatsView.projection:
        final DateTime today = DateTime.now();
        return <Widget>[
          StatsProjectionView(
            transactions: _filter(
              provider,
              _Period(
                StatsAggregator.firstDayOfMonth(today),
                StatsAggregator.lastDayOfMonth(today),
              ),
            ),
            money: (double value, {bool signed = false}) =>
                _money(provider, value, signed: signed),
          ),
        ];
      case StatsView.calendar:
        return <Widget>[
          StatsCalendarView(
            transactions: _filterAll(provider),
            money: (double value, {bool signed = false}) =>
                _money(provider, value, signed: signed),
            categoryFor: _categoryFor,
            titleFor: (InternalTransaction tx) =>
                _transactionTitle(context, tx),
            cardLabelFor: (InternalTransaction tx) =>
                _cardLabelFor(context, provider, tx),
            selectedDayNotifier: _calendarDay,
          ),
        ];
    }
  }

  /// Contenido de Analítica: período, resumen mensual, una gráfica elegible,
  /// desglose por categorías e insights.
  List<Widget> _buildAnalytics(
    BuildContext context,
    AppProvider provider,
    int hiddenCurrencies,
  ) {
    final _Period period = _currentPeriod();
    final List<InternalTransaction> transactions = _filter(provider, period);

    // Resumen de ambas caras del período: lo necesitan el balance del mes y la
    // tasa de ahorro, que no dependen del lado que estén mirando las gráficas.
    final StatsTotals totals = StatsAggregator.totals(transactions);
    final StatsTotals previousTotals = StatsAggregator.totals(
      _filter(provider, _previousPeriod()),
    );

    // Resumen de una sola cara: alimenta las gráficas y el desglose.
    final _StatsSummary summary = _summarize(
      transactions,
      showIncome: _showIncome,
    );
    final _StatsSummary previous = _summarize(
      _filter(provider, _previousPeriod()),
      showIncome: _showIncome,
    );
    final _StatsSummary expenses = _summarize(
      transactions,
      showIncome: false,
    );

    return <Widget>[
      _buildPeriodSelector(context, provider),
      const SizedBox(height: AppSpacing.lg),
      _buildPeriodNavigator(context, provider),
      const SizedBox(height: AppSpacing.xxl),
      if (totals.isEmpty)
        _buildEmptyState(context, provider, hiddenCurrencies)
      else ...[
        _buildMonthlySummary(
          context,
          provider,
          totals,
          previousTotals,
          period,
        ),
        const SizedBox(height: AppSpacing.xxl),
        // Gráfica principal: una sola, con el tipo elegido en la propia
        // pantalla (circular, barras o línea) y los importes siempre a la vista.
        _buildChart(context, provider, summary, transactions, period),
        const SizedBox(height: AppSpacing.xxl),
        _buildBudgetChart(context, provider, expenses),
        const SizedBox(height: AppSpacing.xxl),
        _buildCategories(context, provider, summary),
        const SizedBox(height: AppSpacing.xxl),
        _buildInsights(context, provider, summary, previous),
      ],
    ];
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
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
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            CashIconButton(
              icon: Icons.ios_share_rounded,
              tooltip: context.t('stats_share'),
              onPressed: () => _shareStats(context, provider),
            ),
            const SizedBox(width: AppSpacing.xs),
            _buildViewMenu(context),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        // El apartado activo se indica de forma explícita, no sólo por el menú.
        _buildActiveViewBadge(context),
      ],
    );
  }

  /// Menú de tres puntos con los tres apartados del módulo.
  ///
  /// Presenta exactamente Analítica, Proyección financiera y Calendario
  /// financiero, cada uno con su icono y su etiqueta, y marca el activo con un
  /// check para que el estado no dependa del color.
  Widget _buildViewMenu(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return PopupMenuButton<StatsView>(
      tooltip: StatsShared.text(context, 'stats_view_analytics'),
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: _selectView,
      itemBuilder: (BuildContext context) => <PopupMenuEntry<StatsView>>[
        for (final StatsView view in StatsView.values)
          PopupMenuItem<StatsView>(
            value: view,
            child: Row(
              children: <Widget>[
                Icon(
                  _viewIcon(view),
                  size: 20,
                  color: view == _view
                      ? AppColors.primary
                      : StatsShared.secondaryText(context),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    _viewLabel(context, view),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: view == _view
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: view == _view ? AppColors.primary : null,
                    ),
                  ),
                ),
                if (view == _view)
                  const Icon(
                    Icons.check_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildActiveViewBadge(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(_viewIcon(_view), size: 16, color: AppColors.primary),
        const SizedBox(width: AppSpacing.xs),
        Flexible(
          child: Text(
            _viewLabel(context, _view),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  IconData _viewIcon(StatsView view) {
    switch (view) {
      case StatsView.analytics:
        return Icons.insights_rounded;
      case StatsView.projection:
        return Icons.trending_up_rounded;
      case StatsView.calendar:
        return Icons.calendar_month_rounded;
    }
  }

  String _viewLabel(BuildContext context, StatsView view) {
    switch (view) {
      case StatsView.analytics:
        return context.t('stats_view_analytics');
      case StatsView.projection:
        return context.t('stats_view_projection');
      case StatsView.calendar:
        return context.t('stats_view_calendar');
    }
  }

  void _selectView(StatsView view) {
    if (view == _view) return;
    setState(() => _view = view);
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
        const SizedBox(width: AppSpacing.xs),
        // El salto directo por fecha se movió aquí desde la cabecera para
        // dejar sitio al compartir y al menú de apartados sin recortar el
        // título en pantallas de 320 px.
        CashIconButton(
          icon: Icons.calendar_month_rounded,
          tooltip: context.t('stats_select_range'),
          size: 44,
          bordered: true,
          onPressed: () => _guard(
            context,
            provider.canViewDetailedStats,
            () => _showDatePickerForRange(context),
          ),
          badge: provider.canViewDetailedStats ? null : const _LockBadge(),
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

  // ---------------------------------------------------------------------------
  // RESUMEN FINANCIERO DEL MES
  // ---------------------------------------------------------------------------

  /// Resumen bilateral del período: balance, ingresos, gastos y tasa de ahorro.
  ///
  /// A diferencia del desglose por lados, este resumen muestra siempre las dos
  /// caras del período, porque el balance y la tasa de ahorro no tienen sentido
  /// con una sola: la tasa necesita los ingresos como base y el balance
  /// necesita ambos.
  Widget _buildMonthlySummary(
    BuildContext context,
    AppProvider provider,
    StatsTotals totals,
    StatsTotals previousTotals,
    _Period period,
  ) {
    final _Trend? incomeTrend = _trend(totals.income, previousTotals.income);
    final _Trend? expenseTrend = _trend(totals.expense, previousTotals.expense);
    // La comparación del balance sólo se hace con una base positiva, igual que
    // antes: un período anterior en negativo no da una variación interpretable.
    final _Trend? netTrend = previousTotals.net > 0
        ? _trend(totals.net, previousTotals.net)
        : null;

    final double? savingsRate = totals.savingsRate;

    // Las cuatro métricas del mes van en una sola rejilla 2×2: el balance (la
    // cifra que responde "¿cómo va el mes?") encabeza, y debajo se leen los dos
    // flujos y la tasa de ahorro. Así el resumen ocupa dos filas en vez de
    // dejar una tarjeta suelta en una tercera.
    final List<Widget> cards = <Widget>[
      CashStatCard(
        title: context.t('stats_balance_month'),
        value: _money(provider, totals.net, signed: true),
        icon: totals.net >= 0
            ? Icons.savings_rounded
            : Icons.trending_down_rounded,
        iconColor: totals.net >= 0 ? AppColors.income : AppColors.expense,
        trend: netTrend?.label,
        trendPositive: netTrend?.increased,
      ),
      CashStatCard(
        title: context.t('income'),
        value: _money(provider, totals.income),
        icon: Icons.south_west_rounded,
        iconColor: AppColors.income,
        trend: incomeTrend?.label,
        trendPositive: incomeTrend?.increased,
      ),
      CashStatCard(
        title: context.t('expense'),
        value: _money(provider, totals.expense),
        icon: Icons.north_east_rounded,
        iconColor: AppColors.expense,
        trend: expenseTrend?.label,
        trendPositive: expenseTrend?.increased,
        // Gastar menos es una buena noticia aunque la cifra baje.
        trendGoodWhenDown: true,
      ),
      CashStatCard(
        title: context.t('stats_savings_rate'),
        // Sin ingresos no se divide: se dice que no está disponible en lugar
        // de mostrar un porcentaje inventado.
        value: savingsRate == null
            ? context.t('stats_savings_rate_unavailable')
            : '${savingsRate.toFormattedString(1)}%',
        icon: Icons.percent_rounded,
        iconColor: savingsRate == null
            ? StatsShared.secondaryText(context)
            : savingsRate >= 0
            ? AppColors.income
            : AppColors.expense,
      ),
    ];

    return CashSection(
      title: context.t('stats_month_summary'),
      subtitle: _periodRangeLabel(context, period, totals.count),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StatsShared.statGrid(context, cards, maxColumns: 2),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.t('stats_savings_rate_hint'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: StatsShared.secondaryText(context),
            ),
          ),
        ],
      ),
    );
  }

  /// Rango real de fechas del período, explícito, más el número de movimientos.
  String _periodRangeLabel(BuildContext context, _Period period, int count) {
    final String locale = Localizations.localeOf(context).toString();
    final DateFormat format = DateFormat.MMMd(locale);
    final String start = format.format(period.start);
    final String end = format.format(period.end);
    final String range = start == end ? start : '$start – $end';
    return '$range · ${_tpl(context, 'stats_movements', <String, String>{
      '{n}': '$count',
    })}';
  }

  /// Variación entre dos importes. Sin base de comparación no se inventa nada.
  _Trend? _trend(double current, double previous) {
    if (previous <= 0) return null;
    final double difference = (current - previous) / previous * 100;
    return _Trend(difference.abs(), difference >= 0);
  }

  // ---------------------------------------------------------------------------
  // GRÁFICAS DE ANALÍTICA
  // ---------------------------------------------------------------------------

  /// Pregunta concreta que responde la gráfica seleccionada.
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

  /// Segunda línea de la tarjeta: el detalle que hace legible la gráfica.
  String _chartSubtitle(
    BuildContext context,
    _StatsSummary summary,
    String chartType,
  ) {
    switch (chartType) {
      case 'Line':
        return switch (_timeRange) {
          TimeRange.day => context.t('stats_by_hour'),
          TimeRange.year => context.t('stats_by_month'),
          _ => context.t('stats_by_day'),
        };
      default:
        return _tpl(context, 'stats_categories', <String, String>{
          '{n}': '${summary.byCategory.length}',
        });
    }
  }

  /// Selector del tipo de gráfica: circular, barras o línea.
  ///
  /// Vive en la propia pantalla y escribe el mismo ajuste que Ajustes
  /// (`provider.chartType`), de modo que ambos quedan sincronizados y el cambio
  /// se refleja aquí de inmediato.
  Widget _buildChartTypeSelector(BuildContext context, AppProvider provider) {
    // Circular está abierto para todos; barras y línea son de pago.
    const List<String> types = <String>['Pie', 'Bar', 'Line'];
    const Map<String, IconData> icons = <String, IconData>{
      'Pie': Icons.pie_chart_rounded,
      'Bar': Icons.bar_chart_rounded,
      'Line': Icons.show_chart_rounded,
    };

    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
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

  /// Gráfica principal de Analítica: una sola, del tipo elegido en la pantalla
  /// y del lado elegido con el selector gastos/ingresos.
  ///
  /// Los importes van siempre impresos sobre cada punto o barra, sin necesidad
  /// de tocar la gráfica.
  Widget _buildChart(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary,
    List<InternalTransaction> transactions,
    _Period period,
  ) {
    final String chartType = provider.chartType;

    // La evolución diaria sólo se calcula para la línea, que es la única que la
    // necesita; así el resto de tipos no paga ese coste.
    List<_Bucket> buckets = const <_Bucket>[];
    List<double> values = const <double>[];
    if (chartType == 'Line') {
      buckets = _buckets(context, period);
      values = _valuesPerBucket(
        transactions,
        buckets,
        period,
        showIncome: _showIncome,
      );
    }
    final bool lineHasData = values.any((double value) => value > 0);
    final bool empty = chartType == 'Line'
        ? !lineHasData
        : _sortedCategories(summary).isEmpty;

    return CashSection(
      title: _chartTitle(context, chartType),
      subtitle: empty
          ? context.t('no_data')
          : _chartSubtitle(context, summary, chartType),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // Lado de la gráfica. Comparte estado con el desglose de categorías.
          _buildScopeToggle(context),
          const SizedBox(height: AppSpacing.md),
          // Tipo de gráfica, en la propia pantalla.
          _buildChartTypeSelector(context, provider),
          const SizedBox(height: AppSpacing.md),
          LayoutBuilder(
            builder: (context, constraints) => CashChartCard(
              title: _chartTitle(context, chartType),
              subtitle: empty
                  ? context.t('stats_chart_empty_hint')
                  : _chartSubtitle(context, summary, chartType),
              height: CashChartCard.heightFor(constraints.maxWidth),
              chart: empty
                  ? _buildNoChartData(context)
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      // Sólo el tipo va en la clave: cambiar de período o de
                      // lado no recrea la gráfica, la transforma (fl_chart
                      // interpola entre los datos viejos y los nuevos).
                      transitionBuilder:
                          (Widget child, Animation<double> animation) =>
                              FadeTransition(
                                opacity: animation,
                                child: ScaleTransition(
                                  scale: Tween<double>(
                                    begin: 0.94,
                                    end: 1,
                                  ).animate(animation),
                                  child: child,
                                ),
                              ),
                      child: KeyedSubtree(
                        key: ValueKey<String>(chartType),
                        child: _buildChartBody(
                          context,
                          provider,
                          summary,
                          transactions,
                          period,
                          chartType,
                        ),
                      ),
                    ),
            ),
          ),
          if (chartType == 'Line' && lineHasData)
            ..._buildLineCaptions(context, provider, buckets, values),
        ],
      ),
    );
  }

  /// Promedio y día de mayor movimiento bajo la gráfica de evolución.
  List<Widget> _buildLineCaptions(
    BuildContext context,
    AppProvider provider,
    List<_Bucket> buckets,
    List<double> values,
  ) {
    final double total = values.fold<double>(
      0,
      (double sum, double value) => sum + value,
    );
    final double average = buckets.isEmpty ? 0 : total / buckets.length;

    int peakIndex = 0;
    for (int i = 1; i < values.length; i++) {
      if (values[i] > values[peakIndex]) peakIndex = i;
    }
    final double peak = values.isEmpty ? 0 : values[peakIndex];
    final String peakLabel = buckets.isEmpty ? '' : buckets[peakIndex].label;

    return <Widget>[
      const SizedBox(height: AppSpacing.sm),
      // En columna, a todo el ancho: cada métrica recorta su valor si no cabe,
      // en vez de desbordar la fila.
      _metricCaption(
        context,
        icon: Icons.functions_rounded,
        label: context.t('stats_daily_average'),
        value: _money(provider, average),
      ),
      const SizedBox(height: AppSpacing.xxs),
      _metricCaption(
        context,
        icon: Icons.vertical_align_top_rounded,
        label: context.t('stats_peak_day'),
        value: '$peakLabel · ${_money(provider, peak)}',
      ),
    ];
  }

  /// Cuerpo de la gráfica según el tipo elegido.
  ///
  /// Las tres entran animadas: las barras y la línea crecen desde el eje (sus
  /// importes van contando hasta el valor real) y el círculo se abre desde el
  /// centro. Si el sistema pide reducir movimiento, se dibujan ya terminadas.
  Widget _buildChartBody(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary,
    List<InternalTransaction> transactions,
    _Period period,
    String chartType,
  ) {
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: animate ? 0 : 1, end: 1),
      duration: animate
          ? const Duration(milliseconds: 850)
          : Duration.zero,
      curve: Curves.easeOutCubic,
      builder: (BuildContext context, double progress, Widget? child) {
        switch (chartType) {
          case 'Bar':
            return _buildBarChart(
              context,
              provider,
              summary,
              progress: progress,
            );
          case 'Line':
            return _buildLineChart(
              context,
              provider,
              transactions,
              period,
              showIncome: _showIncome,
              progress: progress,
            );
          default:
            return _buildPieChart(
              context,
              provider,
              summary,
              progress: progress,
            );
        }
      },
    );
  }

  /// Gráfica de presupuestos: lo previsto frente a lo gastado.
  ///
  /// Sólo tiene sentido con un período de un mes, porque los presupuestos son
  /// mensuales: comparar un presupuesto de mes con el gasto de un año mezclaría
  /// dos bases de tiempo distintas. Tampoco se inventa un límite para las
  /// categorías que no lo tienen.
  Widget _buildBudgetChart(
    BuildContext context,
    AppProvider provider,
    _StatsSummary expenseSummary,
  ) {
    if (_timeRange != TimeRange.month) {
      return CashSection(
        title: context.t('stats_budget_chart_title'),
        child: CashCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: CashEmptyState(
            icon: Icons.event_repeat_rounded,
            title: context.t('stats_budget_chart_title'),
            message: context.t('stats_budget_month_only'),
          ),
        ),
      );
    }

    final List<Category> budgeted = provider.categories
        .where((Category c) => (c.monthlyBudget ?? 0) > 0)
        .toList();

    if (budgeted.isEmpty) {
      return CashSection(
        title: context.t('stats_budget_chart_title'),
        child: CashCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          child: CashEmptyState(
            icon: Icons.savings_outlined,
            title: context.t('stats_budget_empty_title'),
            message: context.t('stats_budget_empty_hint'),
          ),
        ),
      );
    }

    // Primero las categorías con más gasto del período; el empate se resuelve
    // por nombre para que el orden no baile entre reconstrucciones.
    final List<Category> sorted = budgeted.toList()
      ..sort((Category a, Category b) {
        final double spentA = expenseSummary.byCategory[a.id] ?? 0;
        final double spentB = expenseSummary.byCategory[b.id] ?? 0;
        final int bySpent = spentB.compareTo(spentA);
        return bySpent != 0 ? bySpent : a.name.compareTo(b.name);
      });
    final List<Category> visible = sorted.take(_maxBudgetBars).toList();

    final double peak = visible.fold<double>(0, (double max, Category c) {
      final double spent = expenseSummary.byCategory[c.id] ?? 0;
      final double budget = c.monthlyBudget ?? 0;
      final double top = spent > budget ? spent : budget;
      return top > max ? top : max;
    });
    final double maxY = peak <= 0 ? 100 : peak * 1.2;

    return CashSection(
      title: context.t('stats_budget_chart_title'),
      subtitle: _tpl(context, 'stats_budget_count', <String, String>{
        '{n}': '${budgeted.length}',
      }),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          LayoutBuilder(
            builder: (context, constraints) => CashChartCard(
              title: context.t('stats_budget_chart_title'),
              subtitle: _tpl(
                context,
                'stats_budget_chart_subtitle',
                <String, String>{'{period}': _dateLabel(context)},
              ),
              height: CashChartCard.heightFor(constraints.maxWidth),
              chart: TweenAnimationBuilder<double>(
                // Las barras suben desde el eje al entrar; una vez
                // asentadas, fl_chart interpola los cambios de datos
                // (mes, moneda, presupuestos).
                tween: Tween<double>(
                  begin: MediaQuery.disableAnimationsOf(context) ? 1 : 0,
                  end: 1,
                ),
                duration: MediaQuery.disableAnimationsOf(context)
                    ? Duration.zero
                    : const Duration(milliseconds: 850),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double progress, Widget? child) {
                  return BarChart(
                    // Las barras crecen con nuestra animación; ya asentadas,
                    // fl_chart interpola los cambios de datos. Con movimiento
                    // reducido no se anima ninguno de los dos.
                    duration:
                        !MediaQuery.disableAnimationsOf(context) &&
                            progress >= 1
                        ? const Duration(milliseconds: 450)
                        : Duration.zero,
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
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 48,
                            interval: maxY / 3,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              if (value < 0 || value > maxY) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(
                                  right: AppSpacing.xs,
                                ),
                                child: Text(
                                  _axisMoney(provider, value),
                                  textAlign: TextAlign.right,
                                  maxLines: 1,
                                  style: Theme.of(context).textTheme.labelSmall
                                      ?.copyWith(
                                        color: CashChartCard.axisColor(context),
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              );
                            },
                          ),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final int index = value.round();
                              if (index < 0 || index >= visible.length) {
                                return const SizedBox.shrink();
                              }
                              // Icono en lugar de nombre: los nombres largos se
                              // solaparían en un eje de seis columnas.
                              final Category category = visible[index];
                              return Padding(
                                padding: const EdgeInsets.only(top: AppSpacing.xs),
                                child: Icon(
                                  IconConstants.getCategoryIcon(category.iconCode),
                                  size: 16,
                                  color: Color(category.colorValue),
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
                                final Category category = visible[group.x];
                                final double spent =
                                    expenseSummary.byCategory[category.id] ?? 0;
                                final double budget = category.monthlyBudget ?? 0;
                                final double difference = budget - spent;
                                return BarTooltipItem(
                                  category.name,
                                  TextStyle(
                                    color: CashChartCard.tooltipTextColor(context),
                                    fontWeight: FontWeight.w700,
                                  ),
                                  children: <TextSpan>[
                                    TextSpan(
                                      text:
                                          '\n${context.t('stats_budget_label')}: '
                                          '${_money(provider, budget)}',
                                    ),
                                    TextSpan(
                                      text:
                                          '\n${context.t('stats_budget_spent')}: '
                                          '${_money(provider, spent)}',
                                    ),
                                    TextSpan(
                                      text:
                                          '\n${difference >= 0 ? context.t('stats_budget_remaining') : context.t('stats_budget_exceeded')}: '
                                          '${_money(provider, difference.abs())}',
                                    ),
                                  ],
                                );
                              },
                        ),
                      ),
                      barGroups: <BarChartGroupData>[
                        for (int i = 0; i < visible.length; i++)
                          BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: <BarChartRodData>[
                              // Presupuesto: barra tenue, es la referencia.
                              BarChartRodData(
                                toY: (visible[i].monthlyBudget ?? 0) * progress,
                                width: 12,
                                color: AppColors.primary.withValues(alpha: 0.32),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.xs),
                                ),
                              ),
                              // Gasto real: barra sólida con el color de la
                              // categoría; si supera la tenue, se ve de inmediato.
                              BarChartRodData(
                                toY:
                                    (expenseSummary.byCategory[visible[i].id] ?? 0) *
                                    progress,
                                width: 12,
                                color: Color(visible[i].colorValue),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(AppRadius.xs),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          // Leyenda explícita: el orden y el color no bastan por sí solos.
          Wrap(
            spacing: AppSpacing.lg,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _chartLegend(
                context,
                color: AppColors.primary.withValues(alpha: 0.32),
                label: context.t('stats_budget_label'),
              ),
              _chartLegend(
                context,
                color: AppColors.expense,
                label: context.t('stats_budget_spent'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Gráfica circular: reparto del lado elegido por categorías.
  ///
  /// El porcentaje de cada porción va impreso sobre el propio sector, así que la
  /// gráfica se lee sin tocarla. Las categorías que no entran se agrupan y el
  /// desglose de abajo sigue enumerando cada una: no se pierde ningún dato.
  ///
  /// [progress] va de 0 a 1 y sólo se usa al entrar: el anillo se abre desde el
  /// centro y gira un poco, y los porcentajes aparecen al final del recorrido
  /// para que no se amontonen mientras el círculo aún es pequeño.
  Widget _buildPieChart(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary, {
    required double progress,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final List<MapEntry<String, double>> sorted = _sortedCategories(summary);
    final List<MapEntry<String, double>> visible = sorted
        .take(_maxChartSections)
        .toList();
    final double grouped = sorted.skip(_maxChartSections).fold<double>(
      0,
      (double sum, MapEntry<String, double> e) => sum + e.value,
    );
    final double total = _showIncome ? summary.income : summary.expense;

    // El radio del sector y el barrido inicial dependen del avance de entrada.
    final double radius = 52 * progress;
    final double startAngle = -90 - (1 - progress) * 60;
    // Los porcentajes se leen a partir de media entrada.
    final double labelAlpha = progress <= 0.5
        ? 0
        : ((progress - 0.5) / 0.5).clamp(0.0, 1.0);

    final List<PieChartSectionData> sections = <PieChartSectionData>[
      for (final MapEntry<String, double> entry in visible)
        _pieSection(
          context,
          color: Color(_categoryFor(entry.key).colorValue),
          share: summary.shareOf(entry.value, _showIncome),
          isDark: isDark,
          radius: radius,
          labelAlpha: labelAlpha,
        ),
    ];
    if (grouped > 0) {
      sections.add(
        _pieSection(
          context,
          color: isDark
              ? AppColors.surfaceDark3
              : AppColors.surfaceVariantLight,
          share: summary.shareOf(grouped, _showIncome),
          isDark: isDark,
          textColor: isDark
              ? AppColors.textSecondaryDark
              : AppColors.textSecondary,
          radius: radius,
          labelAlpha: labelAlpha,
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
            startDegreeOffset: startAngle,
            borderData: FlBorderData(show: false),
            sections: sections,
          ),
          // Durante la entrada manda nuestra animación; al terminar, fl_chart
          // interpola los cambios de datos (período, lado, moneda).
          duration: animate && progress >= 1
              ? const Duration(milliseconds: 450)
              : Duration.zero,
          curve: Curves.easeOutCubic,
        ),
        // El centro del gráfico no admite hijos: se superpone y no intercepta
        // el toque.
        IgnorePointer(
          child: Opacity(
            opacity: labelAlpha,
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
        ),
      ],
    );
  }

  PieChartSectionData _pieSection(
    BuildContext context, {
    required Color color,
    required double share,
    required bool isDark,
    required double radius,
    required double labelAlpha,
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
      radius: radius,
      // Sólo las porciones con peso propio llevan etiqueta: en las franjas
      // estrechas el texto se solaparía.
      title: share >= 5 ? '${share.toFormattedString(0)}%' : '',
      titleStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
        color: foreground.withValues(alpha: labelAlpha),
        fontWeight: FontWeight.w700,
      ),
      borderSide: BorderSide(
        color: (isDark ? AppColors.backgroundDark : AppColors.backgroundLight)
            .withValues(alpha: labelAlpha),
        width: 2,
      ),
    );
  }

  /// Gráfica de barras: las categorías con más peso del lado elegido.
  ///
  /// El importe de cada barra va impreso encima, siempre visible; por eso se
  /// desactiva el tooltip al tocar, que ya no aporta nada.
  ///
  /// [progress] va de 0 a 1 y hace que las barras suban desde el eje: como la
  /// etiqueta muestra el valor actual de la barra, los importes cuentan hacia
  /// arriba hasta su cifra real.
  Widget _buildBarChart(
    BuildContext context,
    AppProvider provider,
    _StatsSummary summary, {
    required double progress,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool animate = !MediaQuery.disableAnimationsOf(context);
    final List<MapEntry<String, double>> top = _sortedCategories(summary)
        .take(_maxChartSections)
        .toList();
    if (top.isEmpty) return _buildNoChartData(context);

    final double maxValue = top.first.value;
    final double maxY = maxValue <= 0 ? 100 : maxValue * 1.25;

    return BarChart(
      BarChartData(
        maxY: maxY,
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 3,
          getDrawingHorizontalLine: (double value) =>
              FlLine(color: CashChartCard.gridColor(context), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: maxY / 3,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value < 0 || value > maxY) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    _axisMoney(provider, value),
                    textAlign: TextAlign.right,
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.round();
                if (index < 0 || index >= top.length) {
                  return const SizedBox.shrink();
                }
                // Icono en lugar de nombre: los nombres largos se solaparían en
                // un eje de seis columnas.
                final Category category = _categoryFor(top[index].key);
                return Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Icon(
                    IconConstants.getCategoryIcon(category.iconCode),
                    size: 16,
                    color: Color(category.colorValue),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          // El importe va siempre encima: no hace falta tocarla.
          handleBuiltInTouches: false,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => CashChartCard.tooltipColor(context),
            tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
            getTooltipItem:
                (
                  BarChartGroupData group,
                  int groupIndex,
                  BarChartRodData rod,
                  int rodIndex,
                ) => BarTooltipItem(
                  _axisMoney(provider, rod.toY),
                  TextStyle(
                    color: CashChartCard.tooltipTextColor(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
          ),
        ),
        barGroups: <BarChartGroupData>[
          for (int i = 0; i < top.length; i++)
            BarChartGroupData(
              x: i,
              showingTooltipIndicators: const <int>[0],
              barRods: <BarChartRodData>[
                BarChartRodData(
                  toY: top[i].value * progress,
                  width: 16,
                  color: Color(_categoryFor(top[i].key).colorValue),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.xs),
                  ),
                ),
              ],
            ),
        ],
      ),
      // Durante la entrada manda nuestra animación; al terminar, fl_chart
      // interpola los cambios de datos (período, lado, moneda).
      duration: animate && progress >= 1
          ? const Duration(milliseconds: 450)
          : Duration.zero,
      curve: Curves.easeOutCubic,
    );
  }

  /// Cuadro de color + etiqueta para leer una gráfica con más de una serie.
  Widget _chartLegend(
    BuildContext context, {
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: StatsShared.secondaryText(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  /// Dato numérico de apoyo bajo una gráfica, con icono y etiqueta.
  ///
  /// Icono a la izquierda y, a su lado, las dos líneas del dato. Tanto la
  /// etiqueta como el valor recortan con elipsis: los rótulos son largos
  /// ("Día de mayor movimiento") y a 280 px de una pantalla de 320 no caben en
  /// una sola fila, así que la fila no puede medir por su contenido.
  Widget _metricCaption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Icon(icon, size: 14, color: StatsShared.secondaryText(context)),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: StatsShared.secondaryText(context),
                ),
              ),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Alterna el lado de la gráfica principal y del desglose de categorías.
  ///
  /// Un mismo estado para las dos secciones: la gráfica y la lista tienen que
  /// mirar el mismo lado, si no dirían cosas distintas a la vez.
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
      _showAllCategories = false;
    });
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
  // GRÁFICO DE EVOLUCIÓN
  // ---------------------------------------------------------------------------

  /// Una sola línea: la evolución de un lado a lo largo del período.
  ///
  /// No se apilan ingresos y gastos porque mezclarlos en un mismo eje obliga a
  /// elegir una escala y la comparación deja de ser honesta. Analítica dibuja
  /// una gráfica por lado, así que el lado llega por parámetro.
  ///
  /// El propio `fl_chart` interpola entre series al cambiar el período
  /// (`duration` + `curve`); respetando la preferencia de movimiento reducido
  /// del sistema la transición se desactiva.
  ///
  /// [progress] va de 0 a 1 y hace que la línea suba desde el eje al entrar; el
  /// importe impreso sobre cada punto es el valor actual, así que también cuenta
  /// hacia arriba hasta su cifra real.
  Widget _buildLineChart(
    BuildContext context,
    AppProvider provider,
    List<InternalTransaction> transactions,
    _Period period, {
    required bool showIncome,
    required double progress,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final List<_Bucket> buckets = _buckets(context, period);
    final Color lineColor = showIncome ? AppColors.income : AppColors.expense;
    final List<double> values = _valuesPerBucket(
      transactions,
      buckets,
      period,
      showIncome: showIncome,
    );
    final bool animate = !MediaQuery.disableAnimationsOf(context);

    final List<FlSpot> spots = <FlSpot>[
      for (int i = 0; i < buckets.length; i++)
        FlSpot(buckets[i].index.toDouble(), values[i] * progress),
    ];

    final double peak = values.fold<double>(
      0,
      (double max, double value) => value > max ? value : max,
    );
    final double maxY = peak <= 0 ? 100 : peak * 1.3;

    // Una marca por cada seis cubos como máximo: nunca se solapan.
    final int labelStep = (buckets.length / 6).ceil().clamp(1, 999);

    // Serie de la línea. Se guarda la referencia para poder pedir a fl_chart
    // que imprima la etiqueta de cada punto con datos sin tocar la gráfica.
    final LineChartBarData bar = LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.24,
      // La línea puede ser recta cuando solo hay un cubo con datos.
      preventCurveOverShooting: true,
      color: lineColor,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: true,
        // Punto visible sólo donde hay importe; en los cubos a cero, nada.
        getDotPainter:
            (FlSpot spot, double percent, LineChartBarData barData, int index) =>
                FlDotCirclePainter(
                  radius: values[index] > 0 ? 3 * progress : 0,
                  color: lineColor,
                  strokeWidth: 0,
                ),
      ),
      belowBarData: BarAreaData(
        show: true,
        color: lineColor.withValues(
          alpha: (isDark ? 0.22 : 0.12) * progress,
        ),
      ),
    );

    return LineChart(
      duration: !animate || progress < 1
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
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
        // Importe impreso sobre cada punto con datos: la gráfica se lee sin
        // tocarla. Se abrevia para que las etiquetas no se pisen entre sí.
        showingTooltipIndicators: <ShowingTooltipIndicators>[
          for (int i = 0; i < spots.length; i++)
            if (values[i] > 0)
              ShowingTooltipIndicators(<LineBarSpot>[
                LineBarSpot(bar, 0, spots[i]),
              ]),
        ],
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          // Números del eje vertical siempre visibles: la gráfica dice su
          // escala sin necesidad de tocar el gráfico.
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 48,
              interval: maxY / 3,
              getTitlesWidget: (double value, TitleMeta meta) {
                if (value < 0 || value > maxY) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.xs),
                  child: Text(
                    _axisMoney(provider, value),
                    textAlign: TextAlign.right,
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
                // Sin espacio para la etiqueta no se dibuja: la gráfica sigue
                // diciendo el importe de cada punto.
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
          // El importe ya va impreso sobre cada punto: no hace falta tocar.
          handleBuiltInTouches: false,
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => CashChartCard.tooltipColor(context),
            tooltipBorderRadius: BorderRadius.circular(AppRadius.sm),
            getTooltipItems: (List<LineBarSpot> touched) => touched
                .map(
                  (LineBarSpot spot) => LineTooltipItem(
                    _axisMoney(provider, spot.y),
                    TextStyle(
                      color: CashChartCard.tooltipTextColor(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        lineBarsData: <LineChartBarData>[bar],
      ),
    );
  }

  /// Reparte el total de un lado entre los cubos del eje.
  ///
  /// Los importes se suman tal cual llegan del movimiento, solo cambia el
  /// agrupamiento: antes el eje siempre era el día del mes, incluso al mirar un
  /// día, una semana o un año, donde esa lectura no significaba nada.
  List<double> _valuesPerBucket(
    List<InternalTransaction> transactions,
    List<_Bucket> buckets,
    _Period period, {
    required bool showIncome,
  }) {
    final List<double> values = List<double>.filled(buckets.length, 0);

    for (final InternalTransaction transaction in transactions) {
      if (showIncome ? transaction.amount <= 0 : transaction.amount >= 0) {
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          // El lado no se repite aquí: lo decide el selector gastos/ingresos de
          // la gráfica, de arriba; el título de la sección dice cuál es.
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
    // La base es el lado que se está mirando: si ese lado no tuvo nada el
    // período anterior no hay porcentaje que calcular, y dividir entre cero
    // mostraría un dato infinito.
    final double before = _showIncome ? previous.income : previous.expense;
    if (before > 0) {
      final double current = _showIncome ? summary.income : summary.expense;
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
    return provider.transactions
        .where(
          (InternalTransaction t) =>
              !_day(t.date).isBefore(period.start) &&
              !_day(t.date).isAfter(period.end) &&
              _matchesScope(provider, t),
        )
        .toList();
  }

  /// Movimientos dentro del alcance (moneda y cuenta) sin límite de fecha.
  ///
  /// Lo usa el calendario, que necesita poder navegar por cualquier mes del
  /// historial sin recalcular con un período fijo.
  List<InternalTransaction> _filterAll(AppProvider provider) {
    return provider.transactions
        .where((InternalTransaction t) => _matchesScope(provider, t))
        .toList();
  }

  /// Condiciones de moneda y cuenta, comunes a todos los filtros.
  bool _matchesScope(AppProvider provider, InternalTransaction t) {
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
  }

  /// Título legible de un movimiento.
  ///
  /// Reutiliza las mismas traducciones que la lista de Movimientos: los
  /// movimientos técnicos (transferencia, recarga, solicitud) y las categorías
  /// sembradas se muestran en la lengua activa, y el resto conserva el título
  /// real que se guardó.
  String _transactionTitle(BuildContext context, InternalTransaction tx) {
    if (tx.categoryId == 'transfer_out') return context.t('transfer_sent');
    if (tx.categoryId == 'recharge') return context.t('recharge_success');
    if (tx.categoryId == 'income_request') return context.t('request_received');
    if (tx.categoryId == 'general') return context.t('cat_general');
    if (tx.categoryId.startsWith('cat_')) return context.t(tx.categoryId);
    return tx.title;
  }

  /// Etiqueta de la cuenta de un movimiento, o `null` si no tiene.
  String? _cardLabelFor(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
  ) {
    final String? cardId = tx.cardId;
    if (cardId == null) return null;
    for (final AccountCard card in provider.cards) {
      if (card.id == cardId) return _cardFilterLabel(context, card);
    }
    return null;
  }

  /// Resumen de una sola cara del período.
  ///
  /// Delega en [StatsAggregator.totals] con el lado pedido, de modo que la
  /// regla de clasificación (signo del importe) vive en un único sitio y no se
  /// repite aquí. Conserva el contrato anterior: `count` es el total de
  /// registros recibidos, no los del lado seleccionado.
  _StatsSummary _summarize(
    List<InternalTransaction> transactions, {
    required bool showIncome,
  }) {
    final StatsTotals totals = StatsAggregator.totals(
      transactions,
      side: showIncome ? StatsSide.income : StatsSide.expense,
    );

    return _StatsSummary(
      income: totals.income,
      expense: totals.expense,
      byCategory: totals.byCategory,
      count: totals.count,
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

  /// Importe abreviado para las etiquetas del eje vertical.
  ///
  /// El eje no tiene ancho para dos decimales ni para cifras largas, así que se
  /// abrevia con `k`/`M` manteniendo el símbolo de la moneda. Es una etiqueta de
  /// escala: la cifra exacta se sigue viendo al tocar el punto.
  String _axisMoney(AppProvider provider, double value) {
    final Currency currency = _currency(provider);
    final double magnitude = value.abs();
    if (magnitude >= 1000000) {
      return '${currency.symbol}${(value / 1000000).toFormattedString(1)}M';
    }
    if (magnitude >= 1000) {
      final double thousands = value / 1000;
      final String text = thousands.abs() >= 10
          ? thousands.toFormattedString(0)
          : thousands.toFormattedString(1);
      return '${currency.symbol}${text}k';
    }
    return '${currency.symbol}${value.toFormattedString(0)}';
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

  /// Recorta un texto largo para que no se convierta en un chip infinito.
  static String _shorten(String value, int maxLength) {
    if (value.length <= maxLength) return value;
    return '${value.substring(0, maxLength - 1)}\u2026';
  }

  /// Plantilla localizada con sustituciones.
  ///
  /// Delega en [StatsShared.text] para que las tres vistas del módulo
  /// sustituyan igual; el servicio de traducción no admite parámetros, así que
  /// la sustitución vive en un único sitio.
  String _tpl(BuildContext context, String key, Map<String, String> values) =>
      StatsShared.text(context, key, values);

  // ---------------------------------------------------------------------------
  // COMPARTIR
  // ---------------------------------------------------------------------------

  /// Comparte un resumen de la vista activa con la hoja nativa del sistema.
  ///
  /// No envía nada por su cuenta: abre el selector del sistema y es el usuario
  /// quien decide si comparte y con qué aplicación. El texto sólo lleva cifras
  /// agregadas del período visible; no incluye identificadores, cuentas ni
  /// ningún otro dato sensible. El mensaje de confirmación aparece únicamente
  /// cuando la API indica que el contenido se compartió.
  Future<void> _shareStats(BuildContext context, AppProvider provider) async {
    final ShareParams params = ShareParams(
      text: _shareText(context, provider),
      subject: _tpl(context, 'stats_share_subject', <String, String>{
        '{title}': context.t('statistics'),
      }),
    );

    try {
      final ShareResult result = await SharePlus.instance.share(params);
      if (!context.mounted) return;
      if (result.status == ShareResultStatus.success) {
        CashSnack.success(context, context.t('stats_share_ok'));
      }
    } catch (_) {
      if (!context.mounted) return;
      CashSnack.error(context, context.t('stats_share_error'));
    }
  }

  /// Texto del resumen según el apartado activo.
  String _shareText(BuildContext context, AppProvider provider) {
    switch (_view) {
      case StatsView.analytics:
        return _shareAnalytics(context, provider);
      case StatsView.projection:
        return _shareProjection(context, provider);
      case StatsView.calendar:
        return _shareCalendar(context, provider);
    }
  }

  String _shareAnalytics(BuildContext context, AppProvider provider) {
    final _Period period = _currentPeriod();
    final StatsTotals totals = StatsAggregator.totals(
      _filter(provider, period),
    );
    final double? rate = totals.savingsRate;

    return <String>[
      '${context.t('statistics')} · ${context.t('stats_view_analytics')}',
      '${context.t('stats_share_period')}: '
          '${_periodRangeLabel(context, period, totals.count)}',
      '${context.t('stats_balance_month')}: '
          '${_money(provider, totals.net, signed: true)}',
      '${context.t('income')}: ${_money(provider, totals.income)}',
      '${context.t('expense')}: ${_money(provider, totals.expense)}',
      '${context.t('stats_savings_rate')}: '
          '${rate == null ? context.t('stats_savings_rate_unavailable') : '${rate.toFormattedString(1)}%'}',
    ].join('\n');
  }

  String _shareProjection(BuildContext context, AppProvider provider) {
    final DateTime today = DateTime.now();
    final DateTime month = StatsAggregator.firstDayOfMonth(today);
    final StatsTotals accumulated = StatsAggregator.totals(
      _filter(
        provider,
        _Period(month, StatsAggregator.lastDayOfMonth(today)),
      ),
    );
    final MonthlyProjection projection = StatsAggregator.projection(
      today: today,
      month: month,
      accumulated: accumulated,
    );

    final List<String> lines = <String>[
      '${context.t('statistics')} · ${context.t('stats_view_projection')}',
      StatsShared.monthLabel(context, month),
    ];

    if (projection.isEmpty) {
      lines.add(context.t('stats_projection_unavailable_title'));
      return lines.join('\n');
    }

    // Al compartir se aplican las mismas reglas que en pantalla: lo estimado se
    // etiqueta como estimado y lo que no se puede afirmar no se muestra.
    final bool monthComplete =
        projection.isMonthComplete && projection.isCurrentMonth;
    final bool incomeShown =
        projection.incomeProjectionReliable || monthComplete;
    final bool expenseShown =
        projection.expenseProjectionReliable || monthComplete;
    final double projectedIncome = monthComplete
        ? projection.accumulatedIncome
        : projection.projectedIncome;
    final double projectedExpense = monthComplete
        ? projection.accumulatedExpense
        : projection.projectedExpense;

    lines
      ..add(
        '${context.t('stats_accumulated')}: '
        '${_money(provider, projection.accumulatedNet, signed: true)}',
      )
      ..add(
        '${context.t('stats_projection_income')}: '
        '${incomeShown ? '≈ ${_money(provider, projectedIncome)}' : context.t('stats_projection_income_unavailable')}',
      )
      ..add(
        '${context.t('stats_projection_expense')}: '
        '${expenseShown ? '≈ ${_money(provider, projectedExpense)}' : context.t('stats_projection_unavailable_title')}',
      )
      ..add(
        '${context.t('stats_share_method')}: '
        '${_tpl(context, 'stats_projection_method', <String, String>{
          '{elapsed}': '${projection.elapsedDays}',
          '{total}': '${projection.totalDays}',
        })}',
      )
      ..add(context.t('stats_projection_disclaimer'));

    return lines.join('\n');
  }

  String _shareCalendar(BuildContext context, AppProvider provider) {
    final DateTime day = StatsAggregator.dayOf(_calendarDay.value);
    final List<DayTotals> days = StatsAggregator.dailyTotals(
      _filterAll(provider),
      start: day,
      end: day,
    );
    final DayTotals totals = days.isEmpty
        ? DayTotals(day: day, income: 0, expense: 0, count: 0)
        : days.first;

    return <String>[
      '${context.t('statistics')} · ${context.t('stats_view_calendar')}',
      StatsShared.fullDate(context, day),
      '${context.t('stats_calendar_day_income')}: '
          '${_money(provider, totals.income)}',
      '${context.t('stats_calendar_day_expense')}: '
          '${_money(provider, totals.expense)}',
      '${context.t('stats_calendar_day_balance')}: '
          '${_money(provider, totals.net, signed: true)}',
      _tpl(context, 'stats_movements', <String, String>{
        '{n}': '${totals.count}',
      }),
    ].join('\n');
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
