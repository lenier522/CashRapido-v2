import 'package:material_ui/material_ui.dart';

import '../../models/models.dart';
import '../../services/stats_aggregator.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/icon_constants.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_icon_button.dart';
import '../../widgets/design/cash_section.dart';
import '../../widgets/design/cash_transaction_tile.dart';
import 'stats_shared.dart';

/// Vista de **Calendario financiero**.
///
/// Un mes natural por pantalla. Cada día se marca con la forma de su
/// actividad (ingresos, gastos, ambos o ninguno) y debajo se muestran el
/// resumen y el listado de la fecha seleccionada. La agregación por día la
/// hace [StatsAggregator]: aquí no se recalcula ninguna regla financiera.
///
/// Sólo se agrega el mes que se está viendo (≤31 días), no todo el historial,
/// y los movimientos de un día se filtran por su día natural, de modo que
/// nunca se mezclan fechas distintas.
class StatsCalendarView extends StatefulWidget {
  const StatsCalendarView({
    super.key,
    required this.transactions,
    required this.money,
    required this.categoryFor,
    required this.titleFor,
    required this.cardLabelFor,
    required this.selectedDayNotifier,
    this.now,
  });

  /// Movimientos ya filtrados por moneda y cuenta, de cualquier fecha.
  final List<InternalTransaction> transactions;

  /// Formateador monetario de la pantalla (símbolo + dos decimales).
  final String Function(double value, {bool signed}) money;

  /// Resuelve la categoría de un movimiento (nombre traducido, icono, color).
  final Category Function(String categoryId) categoryFor;

  /// Título legible de un movimiento.
  final String Function(InternalTransaction transaction) titleFor;

  /// Etiqueta de la cuenta asociada, o `null` si no procede.
  final String? Function(InternalTransaction transaction) cardLabelFor;

  /// Día seleccionado compartido con la pantalla (para poder compartirlo sin
  /// reconstruir todo el módulo en cada toque).
  final ValueNotifier<DateTime> selectedDayNotifier;

  /// Inyectable para pruebas; por defecto, el momento actual.
  final DateTime? now;

  @override
  State<StatsCalendarView> createState() => _StatsCalendarViewState();
}

class _StatsCalendarViewState extends State<StatsCalendarView> {
  late DateTime _today;
  late DateTime _month;
  late DateTime _selectedDay;

  @override
  void initState() {
    super.initState();
    _today = StatsAggregator.dayOf(widget.now ?? DateTime.now());
    _selectedDay = StatsAggregator.dayOf(widget.selectedDayNotifier.value);
    _month = StatsAggregator.firstDayOfMonth(_selectedDay);
  }

  void _goToMonth(int delta) {
    final DateTime target = DateTime(_month.year, _month.month + delta, 1);
    setState(() {
      _month = target;
      // La selección se conserva en la medida de lo posible: el mismo día del
      // mes, recortado al último día válido. Así nunca queda un día
      // seleccionado fuera del mes que se está viendo.
      final int lastDay = StatsAggregator.daysInMonth(target);
      final DateTime kept = DateTime(
        target.year,
        target.month,
        _selectedDay.day.clamp(1, lastDay),
      );
      if (kept != _selectedDay) {
        _selectedDay = kept;
        widget.selectedDayNotifier.value = kept;
      }
    });
  }

  void _selectDay(DateTime day) {
    final DateTime normalized = StatsAggregator.dayOf(day);
    if (normalized == _selectedDay) return;
    setState(() => _selectedDay = normalized);
    widget.selectedDayNotifier.value = normalized;
  }

  void _goToToday() {
    final DateTime today = StatsAggregator.dayOf(widget.now ?? DateTime.now());
    setState(() {
      _today = today;
      _selectedDay = today;
      _month = StatsAggregator.firstDayOfMonth(today);
    });
    widget.selectedDayNotifier.value = today;
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedDay = StatsAggregator.dayOf(picked);
      _month = StatsAggregator.firstDayOfMonth(picked);
    });
    widget.selectedDayNotifier.value = StatsAggregator.dayOf(picked);
  }

  // ---------------------------------------------------------------------------
  // DATOS DEL MES VISIBLE
  // ---------------------------------------------------------------------------

  /// Totales del mes que se está viendo (días naturales completos).
  ///
  /// Sólo se agrega el mes visible, nunca el historial completo.
  List<DayTotals> _monthDays() => StatsAggregator.dailyTotals(
    widget.transactions,
    start: StatsAggregator.firstDayOfMonth(_month),
    end: StatsAggregator.lastDayOfMonth(_month),
  );

  /// Totales del día seleccionado dentro de [days].
  DayTotals _totalsFor(List<DayTotals> days, DateTime day) {
    for (final DayTotals entry in days) {
      if (entry.day == day) return entry;
    }
    return DayTotals(day: day, income: 0, expense: 0, count: 0);
  }

  /// Movimientos del día seleccionado, conservando el orden del proveedor
  /// (más reciente primero) en lugar de reordenarlos.
  List<InternalTransaction> _transactionsFor(DateTime day) =>
      widget.transactions
          .where(
            (InternalTransaction t) => StatsAggregator.dayOf(t.date) == day,
          )
          .toList();

  // ---------------------------------------------------------------------------
  // CONSTRUCCIÓN
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final List<DayTotals> days = _monthDays();
    final DayTotals selected = _totalsFor(days, _selectedDay);
    final List<InternalTransaction> movements = _transactionsFor(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CashSection(
          title: StatsShared.text(context, 'stats_calendar_title'),
          subtitle: StatsShared.text(
            context,
            'stats_calendar_subtitle',
            <String, String>{
              '{month}': StatsShared.monthLabel(context, _month),
            },
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _buildMonthSelector(context),
              const SizedBox(height: AppSpacing.md),
              _buildCalendar(context, days),
              const SizedBox(height: AppSpacing.md),
              _buildLegend(context),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        _buildDaySummary(context, selected),
        const SizedBox(height: AppSpacing.xxl),
        _buildDayMovements(context, selected, movements),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CABECERA DEL CALENDARIO
  // ---------------------------------------------------------------------------

  Widget _buildMonthSelector(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // Dos filas en vez de una: la navegación del mes es intocable en la primera
    // y las acciones ("Hoy", elegir fecha) caben siempre en la segunda, incluso
    // a 320 px, sin recortar el nombre del mes.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            CashIconButton(
              icon: Icons.chevron_left_rounded,
              tooltip: StatsShared.monthLabel(
                context,
                DateTime(_month.year, _month.month - 1, 1),
              ),
              onPressed: () => _goToMonth(-1),
            ),
            Expanded(
              child: Text(
                _capitalize(StatsShared.monthLabel(context, _month)),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            CashIconButton(
              icon: Icons.chevron_right_rounded,
              tooltip: StatsShared.monthLabel(
                context,
                DateTime(_month.year, _month.month + 1, 1),
              ),
              onPressed: () => _goToMonth(1),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: Alignment.centerRight,
          child: Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              CashButton(
                label: StatsShared.text(context, 'today'),
                type: CashButtonType.outlined,
                fullWidth: false,
                height: 40,
                onPressed: _goToToday,
              ),
              CashIconButton(
                icon: Icons.event_rounded,
                tooltip: StatsShared.text(context, 'stats_calendar_pick_date'),
                onPressed: _pickDate,
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _capitalize(String value) {
    if (value.isEmpty) return value;
    return value[0].toUpperCase() + value.substring(1);
  }

  // ---------------------------------------------------------------------------
  // REJILLA DEL CALENDARIO
  // ---------------------------------------------------------------------------

  Widget _buildCalendar(BuildContext context, List<DayTotals> days) {
    final ThemeData theme = Theme.of(context);
    final MaterialLocalizations localizations = MaterialLocalizations.of(
      context,
    );
    final int firstWeekday = localizations.firstDayOfWeekIndex;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color border = isDark ? AppColors.borderDark : AppColors.borderLight;

    // Día de la semana (0=domingo) del primer día del mes, reindexado al orden
    // que usa la lengua activa.
    final DateTime first = StatsAggregator.firstDayOfMonth(_month);
    final int leading = (first.weekday % 7 - firstWeekday + 7) % 7;
    final int rows = ((leading + days.length) / 7).ceil();

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double cellWidth = constraints.maxWidth / 7;
        // Techo alto para que el número y las marcas quepan siempre: el
        // contenido mide ~27 px, así que 38 px de mínimo no desborda nunca.
        final double cellHeight = cellWidth.clamp(38.0, 60.0).toDouble();

        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Column(
            children: <Widget>[
              // Cabecera con los días de la semana en el orden de la lengua.
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    for (int i = 0; i < 7; i++)
                      Expanded(
                        child: Text(
                          localizations
                              .narrowWeekdays[(firstWeekday + i) % 7],
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: StatsShared.secondaryText(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              for (int row = 0; row < rows; row++)
                Row(
                  children: <Widget>[
                    for (int column = 0; column < 7; column++)
                      Builder(
                        builder: (BuildContext context) {
                          final int index = row * 7 + column - leading;
                          if (index < 0 || index >= days.length) {
                            return SizedBox(
                              width: cellWidth,
                              height: cellHeight,
                            );
                          }
                          return SizedBox(
                            width: cellWidth,
                            height: cellHeight,
                            child: _buildDayCell(
                              context,
                              days[index],
                              cellHeight,
                            ),
                          );
                        },
                      ),
                  ],
                ),
              const SizedBox(height: AppSpacing.xs),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDayCell(
    BuildContext context,
    DayTotals day,
    double cellHeight,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isSelected = day.day == _selectedDay;
    final bool isToday = day.day == _today;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.xxs),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadius.radiusMd,
          onTap: () => _selectDay(day.day),
          // Área táctil: toda la celda, con al menos 38 px de alto.
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.16)
                  : null,
              borderRadius: AppRadius.radiusMd,
              border: isSelected
                  ? Border.all(color: AppColors.primary, width: 1.5)
                  : isToday
                  ? Border.all(
                      color: AppColors.primary.withValues(alpha: 0.55),
                    )
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  '${day.day.day}',
                  maxLines: 1,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.1,
                    fontWeight: isSelected || isToday
                        ? FontWeight.w800
                        : FontWeight.w500,
                    color: isSelected
                        ? AppColors.primary
                        : isToday
                        ? AppColors.primary
                        : theme.textTheme.bodySmall?.color,
                  ),
                ),
                const SizedBox(height: 3),
                SizedBox(height: 8, child: _buildDayMarks(context, day)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Marcas del día. La forma distingue el tipo de actividad además del color:
  /// círculo = ingresos, cuadrado = gastos. Así la lectura no depende sólo del
  /// color, y un día sin movimientos no dibuja ninguna marca (no es un error
  /// de lectura: es que no hubo actividad).
  Widget _buildDayMarks(BuildContext context, DayTotals day) {
    if (day.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (day.hasIncome) const _DayMark(shape: _DayMarkShape.circle),
        if (day.hasIncome && day.hasExpense) const SizedBox(width: 3),
        if (day.hasExpense) const _DayMark(shape: _DayMarkShape.square),
      ],
    );
  }

  Widget _buildLegend(BuildContext context) {
    return CashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            StatsShared.text(context, 'stats_calendar_legend'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: StatsShared.secondaryText(context),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.md,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              _legendItem(
                context,
                child: const _DayMark(shape: _DayMarkShape.circle),
                label: StatsShared.text(
                  context,
                  'stats_calendar_legend_income',
                ),
              ),
              _legendItem(
                context,
                child: const _DayMark(shape: _DayMarkShape.square),
                label: StatsShared.text(
                  context,
                  'stats_calendar_legend_expense',
                ),
              ),
              _legendItem(
                context,
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _DayMark(shape: _DayMarkShape.circle),
                    SizedBox(width: 3),
                    _DayMark(shape: _DayMarkShape.square),
                  ],
                ),
                label: StatsShared.text(context, 'stats_calendar_legend_both'),
              ),
              _legendItem(
                context,
                child: Icon(
                  Icons.remove_rounded,
                  size: 14,
                  color: StatsShared.secondaryText(context),
                ),
                label: StatsShared.text(context, 'stats_calendar_legend_none'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(
    BuildContext context, {
    required Widget child,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        child,
        const SizedBox(width: AppSpacing.xs),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: StatsShared.secondaryText(context),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // RESUMEN DEL DÍA
  // ---------------------------------------------------------------------------

  Widget _buildDaySummary(BuildContext context, DayTotals day) {
    return CashSection(
      title: StatsShared.text(context, 'stats_calendar_selected_day'),
      subtitle: StatsShared.fullDate(context, day.day),
      child: CashCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: AppSpacing.md,
              runSpacing: AppSpacing.md,
              children: <Widget>[
                _summaryItem(
                  context,
                  label: StatsShared.text(
                    context,
                    'stats_calendar_day_income',
                  ),
                  value: widget.money(day.income),
                  color: AppColors.income,
                ),
                _summaryItem(
                  context,
                  label: StatsShared.text(
                    context,
                    'stats_calendar_day_expense',
                  ),
                  value: widget.money(day.expense),
                  color: AppColors.expense,
                ),
                _summaryItem(
                  context,
                  label: StatsShared.text(
                    context,
                    'stats_calendar_day_balance',
                  ),
                  value: widget.money(day.net, signed: true),
                  color: day.net >= 0 ? AppColors.income : AppColors.expense,
                ),
                _summaryItem(
                  context,
                  label: StatsShared.text(
                    context,
                    'stats_calendar_day_count',
                  ),
                  value: '${day.count}',
                  color: StatsShared.secondaryText(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      width: 130,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: StatsShared.secondaryText(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LISTADO DEL DÍA
  // ---------------------------------------------------------------------------

  Widget _buildDayMovements(
    BuildContext context,
    DayTotals day,
    List<InternalTransaction> movements,
  ) {
    return CashSection(
      title: StatsShared.text(context, 'stats_calendar_movements'),
      subtitle: StatsShared.text(context, 'stats_movements', <String, String>{
        '{n}': '${movements.length}',
      }),
      child: movements.isEmpty
          ? CashCard(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: CashEmptyState(
                icon: Icons.event_busy_rounded,
                title: StatsShared.text(
                  context,
                  'stats_calendar_empty_day_title',
                ),
                message: StatsShared.text(
                  context,
                  'stats_calendar_empty_day_hint',
                ),
              ),
            )
          : Column(
              children: <Widget>[
                for (final InternalTransaction tx in movements)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _buildTransactionTile(context, tx),
                  ),
              ],
            ),
    );
  }

  Widget _buildTransactionTile(BuildContext context, InternalTransaction tx) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Category category = widget.categoryFor(tx.categoryId);
    final bool isExpense = tx.amount < 0;
    final String? cardLabel = widget.cardLabelFor(tx);
    final String time = StatsShared.timeOf(context, tx.date);
    final String subtitle = cardLabel == null
        ? time
        : '$time · $cardLabel';

    return Material(
      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
      borderRadius: AppRadius.radiusLg,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: CashTransactionTile(
          icon: IconConstants.getCategoryIcon(category.iconCode),
          iconColor: Color(category.colorValue),
          title: widget.titleFor(tx),
          subtitle: subtitle,
          // La fila antepone el signo según el signo del movimiento; el
          // formateador de la pantalla ya añade el símbolo de la moneda.
          amount: widget.money(tx.amount),
          isIncome: !isExpense,
        ),
      ),
    );
  }
}

/// Forma de la marca de un día.
enum _DayMarkShape { circle, square }

/// Marca discreta de actividad diaria.
class _DayMark extends StatelessWidget {
  const _DayMark({required this.shape});

  final _DayMarkShape shape;

  @override
  Widget build(BuildContext context) {
    final Color color = shape == _DayMarkShape.circle
        ? AppColors.income
        : AppColors.expense;
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: color,
        shape: shape == _DayMarkShape.circle
            ? BoxShape.circle
            : BoxShape.rectangle,
        borderRadius: shape == _DayMarkShape.square
            ? BorderRadius.circular(1.5)
            : null,
      ),
    );
  }
}
