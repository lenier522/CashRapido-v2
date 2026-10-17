import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/icon_constants.dart';
import '../utils/number_format_utils.dart';
import '../widgets/add_transaction_modal.dart';
import '../widgets/design/cash_bottom_sheet.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_dialog.dart';
import '../widgets/design/cash_empty_state.dart';
import '../widgets/design/cash_input.dart';
import '../widgets/design/cash_snack.dart';
import '../widgets/design/cash_transaction_tile.dart';

/// Filtro por tipo de movimiento.
///
/// Se deriva exclusivamente del signo que ya usa la aplicación
/// (`amount < 0` gasto, `amount >= 0` ingreso). No interpreta, recalcula ni
/// transforma el importe almacenado.
enum _TxTypeFilter { all, income, expense }

/// Una fila del historial: una cabecera de día o un movimiento.
class _HistoryEntry {
  final DateTime? day;
  final InternalTransaction? tx;

  const _HistoryEntry.header(DateTime this.day) : tx = null;
  const _HistoryEntry.item(InternalTransaction this.tx) : day = null;

  bool get isHeader => tx == null;
}

/// Movimientos: centro de consulta financiera (y historial completo).
///
/// Esta pantalla es la pestaña **Movimientos** de la navegación inferior y,
/// a la vez, la vista de historial que Inicio abre desde su acción
/// "Historial". Es una pantalla de consulta: NO recalcula saldos ni importes.
/// Todo sale de `AppProvider` y las operaciones (editar, borrar, confirmación)
/// se conservan intactas.
///
/// Qué añade sobre el historial simple:
/// - Selector de período de hasta 30 días naturales (`_maxRangeDays`),
///   arrancando en los últimos 30 días incluida la fecha actual.
/// - Resumen del conjunto consultado: cantidad de movimientos, ingresos,
///   gastos y balance del período (`_summarize`).
/// - Buscador local sobre la lista ya cargada (descripción, categoría, cuenta
///   e importe), sin tocar el provider ni la persistencia.
/// - Filtro por tipo (ingresos/gastos) derivado del signo existente.
/// - Filtro por cuenta (ya existía) conservado.
/// - Agrupación por día para leer el historial con rapidez.
/// - Estados vacíos diferenciados (sin datos / período vacío / sin resultados).
/// - Modo claro/oscuro y listado perezoso (`SliverList.builder`).
///
/// El resumen, el listado y los estados vacíos comparten siempre el mismo
/// conjunto de consulta: período + filtros + búsqueda.
class AllTransactionsScreen extends StatefulWidget {
  final String? initialCardId;

  const AllTransactionsScreen({super.key, this.initialCardId});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

/// Resumen de los movimientos ya filtrados del período consultado.
///
/// Sólo agrega: no decide ni redondea nada. Los importes se suman tal cual
/// llegan del movimiento, de modo que la cifra que se muestra es exactamente
/// la misma que la que se guardó.
class _MovementsSummary {
  final int count;
  final double income;
  final double expense;

  const _MovementsSummary({
    required this.count,
    required this.income,
    required this.expense,
  });

  /// Ingresos menos gastos del período.
  ///
  /// NO es el saldo de una cuenta ni el saldo de la billetera: son conceptos
  /// distintos y aquí no se toca ningún saldo almacenado.
  double get balance => income - expense;
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  /// Días naturales máximos del período consultable, contando ambos extremos.
  static const int _maxRangeDays = 30;

  String? _selectedCardId;
  _TxTypeFilter _typeFilter = _TxTypeFilter.all;

  /// Período consultado. Siempre definido: arranca en los últimos 30 días
  /// naturales con la fecha actual incluida.
  late DateTimeRange _dateRange;

  String _query = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _selectedCardId = widget.initialCardId;
    _dateRange = _defaultRange();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getTransactionTitle(BuildContext context, InternalTransaction tx) {
    if (tx.categoryId == 'transfer_out') return context.t('transfer_sent');
    if (tx.categoryId == 'recharge') return context.t('recharge_success');
    if (tx.categoryId == 'income_request') return context.t('request_received');
    if (tx.categoryId == 'general') return context.t('cat_general');
    if (tx.categoryId.startsWith('cat_')) return context.t(tx.categoryId);
    return tx.title;
  }

  // ---------------------------------------------------------------------------
  // CONSULTA (búsqueda, filtros y agrupación)
  // ---------------------------------------------------------------------------

  /// Filtros de refinamiento: cuenta, tipo y búsqueda.
  ///
  /// El período NO se considera un filtro: es el alcance principal de la
  /// pantalla y siempre está definido. Por eso "Limpiar filtros" devuelve la
  /// vista al conjunto completo del período, sin tocar el rango seleccionado.
  bool get _hasActiveFilters =>
      _selectedCardId != null ||
      _typeFilter != _TxTypeFilter.all ||
      _query.trim().isNotEmpty;

  void _clearFilters() {
    setState(() {
      _selectedCardId = null;
      _typeFilter = _TxTypeFilter.all;
      _query = '';
      _searchController.clear();
    });
  }

  void _clearSearch() {
    setState(() {
      _query = '';
      _searchController.clear();
    });
  }

  void _onQueryChanged(String value) {
    if (value == _query) return;
    setState(() => _query = value);
  }

  /// Movimientos de `provider.transactions` dentro del período seleccionado,
  /// todavía sin filtros ni búsqueda.
  ///
  /// El extremo inicial se toma a medianoche y el final al último instante
  /// del día para no perder movimientos registrados en las horas finales de
  /// la fecha límite.
  List<InternalTransaction> _periodTransactions(AppProvider provider) {
    final DateTime start = DateTime(
      _dateRange.start.year,
      _dateRange.start.month,
      _dateRange.start.day,
    );
    final DateTime end = DateTime(
      _dateRange.end.year,
      _dateRange.end.month,
      _dateRange.end.day,
      23,
      59,
      59,
      999,
    );
    return provider.transactions
        .where((t) => !t.date.isBefore(start) && !t.date.isAfter(end))
        .toList();
  }

  /// Aplica sobre [period] los filtros disponibles (cuenta, tipo y búsqueda).
  ///
  /// El orden de las transacciones (más reciente primero) lo decide el
  /// provider; aquí nunca se reordena ni se recalcula nada financiero.
  List<InternalTransaction> _applyFilters(
    BuildContext context,
    List<InternalTransaction> period,
    Map<String, AccountCard> cardById,
    Map<String, Category> categoryById,
  ) {
    Iterable<InternalTransaction> result = period;

    if (_selectedCardId != null) {
      result = result.where((t) => t.cardId == _selectedCardId);
    }

    switch (_typeFilter) {
      case _TxTypeFilter.income:
        result = result.where((t) => t.amount >= 0);
      case _TxTypeFilter.expense:
        result = result.where((t) => t.amount < 0);
      case _TxTypeFilter.all:
        break;
    }

    final String query = _query.trim().toLowerCase();
    if (query.isNotEmpty) {
      result = result.where(
        (t) => _matchesQuery(context, t, query, cardById, categoryById),
      );
    }

    return result.toList();
  }

  /// Búsqueda local: descripción (resuelta y almacenada), categoría, cuenta,
  /// moneda e importe. No consulta ni modifica el provider.
  bool _matchesQuery(
    BuildContext context,
    InternalTransaction tx,
    String query,
    Map<String, AccountCard> cardById,
    Map<String, Category> categoryById,
  ) {
    final StringBuffer haystack = StringBuffer()
      ..write(_getTransactionTitle(context, tx).toLowerCase())
      ..write(' ')
      ..write(tx.title.toLowerCase())
      ..write(' ')
      ..write(tx.currency.toLowerCase())
      ..write(' ')
      ..write(tx.amount.abs().toFormattedString(2));

    final Category? category = categoryById[tx.categoryId];
    if (category != null) {
      haystack
        ..write(' ')
        ..write(category.name.toLowerCase());
    }

    final AccountCard? card = cardById[tx.cardId];
    if (card != null) {
      haystack
        ..write(' ')
        ..write(_filterLabel(context, card).toLowerCase());
    }

    return haystack.toString().contains(query);
  }

  /// Convierte la lista (ya ordenada) en filas con cabeceras de día.
  List<_HistoryEntry> _buildEntries(List<InternalTransaction> transactions) {
    final List<_HistoryEntry> entries = <_HistoryEntry>[];
    DateTime? lastDay;
    for (final InternalTransaction tx in transactions) {
      final DateTime day = DateTime(tx.date.year, tx.date.month, tx.date.day);
      if (lastDay == null || !_isSameDay(day, lastDay)) {
        entries.add(_HistoryEntry.header(day));
        lastDay = day;
      }
      entries.add(_HistoryEntry.item(tx));
    }
    return entries;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // ---------------------------------------------------------------------------
  // ACCIONES (sin cambios de comportamiento)
  // ---------------------------------------------------------------------------

  void _showOptionsMenu(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
  ) {
    CashBottomSheet.show<void>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: _getTransactionTitle(sheetContext, tx),
        subtitle: '${tx.amount.abs().toFormattedString(2)} ${tx.currency}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CashButton(
              label: context.t('edit'),
              icon: const Icon(Icons.edit_outlined, size: 20),
              type: CashButtonType.outlined,
              onPressed: () {
                Navigator.pop(sheetContext);
                _showEditTransactionDialog(context, tx);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            CashButton(
              label: context.t('delete'),
              icon: const Icon(Icons.delete_outline, size: 20),
              type: CashButtonType.danger,
              onPressed: () {
                Navigator.pop(sheetContext);
                _showDeleteConfirmation(context, provider, tx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionDialog(
    BuildContext context,
    InternalTransaction tx,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTransactionModal(transactionToEdit: tx),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
  ) {
    showCashConfirmDialog(
      context,
      title: context.t('delete_transaction'),
      message: context.t('delete_transaction_confirm'),
      confirmLabel: context.t('delete'),
      cancelLabel: context.t('cancel'),
      icon: Icons.delete_outline_rounded,
    ).then((confirmed) async {
      if (confirmed == true && context.mounted) {
        await provider.deleteTransaction(tx.id);
        if (context.mounted) {
          CashSnack.success(context, context.t('transaction_deleted'));
        }
      }
    });
  }

  // ---------------------------------------------------------------------------
  // PERÍODO (máximo 30 días naturales) Y RESUMEN
  // ---------------------------------------------------------------------------

  /// Últimos `_maxRangeDays` días naturales incluyendo la fecha actual.
  ///
  /// Se calcula siempre a partir de la fecha local del dispositivo: no hay
  /// ninguna fecha fija escrita en el código.
  DateTimeRange _defaultRange() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return DateTimeRange(
      start: today.subtract(const Duration(days: _maxRangeDays - 1)),
      end: today,
    );
  }

  /// Días naturales del rango contando ambos extremos (1..n).
  int _inclusiveDays(DateTimeRange range) {
    final DateTime start = DateTime(
      range.start.year,
      range.start.month,
      range.start.day,
    );
    final DateTime end = DateTime(
      range.end.year,
      range.end.month,
      range.end.day,
    );
    return end.difference(start).inDays + 1;
  }

  bool get _isDefaultRange {
    final DateTimeRange fallback = _defaultRange();
    return _isSameDay(_dateRange.start, fallback.start) &&
        _isSameDay(_dateRange.end, fallback.end);
  }

  void _resetRange() => setState(() => _dateRange = _defaultRange());

  /// Motivo por el que [range] no puede consultarse, o `null` si es válido.
  ///
  /// Nunca ajusta las fechas en silencio: el usuario siempre ve rechazado el
  /// rango que eligió y decide cuál poner.
  String? _rangeError(BuildContext context, DateTimeRange range) {
    if (range.end.isBefore(range.start)) {
      return context.t('movements_range_order');
    }
    if (_inclusiveDays(range) > _maxRangeDays) {
      return context.t('movements_range_limit');
    }
    return null;
  }

  /// Selector del período.
  ///
  /// Un rango inválido (invertido o mayor de 30 días naturales) NO se aplica:
  /// se muestra el motivo y se vuelve a abrir el selector para que el usuario
  /// pueda corregir la selección.
  Future<void> _pickDateRange(BuildContext context) async {
    while (mounted) {
      final DateTimeRange? picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime(2030),
        initialDateRange: _dateRange,
        helpText: context.t('filter_date_range'),
      );

      if (!context.mounted) return;
      if (picked == null) return; // Cancelado: el período no cambia.

      final String? error = _rangeError(context, picked);
      if (error != null) {
        CashSnack.warning(context, error);
        continue; // El usuario puede corregir la selección.
      }

      setState(() => _dateRange = picked);
      return;
    }
  }

  /// Agrega exactamente el conjunto que se está consultando (período +
  /// filtros + búsqueda), de modo que el resumen y el listado nunca se
  /// desincronican.
  ///
  /// Reglas financieras existentes, sin inventar ninguna fórmula nueva:
  /// ingreso = importe positivo y gasto = importe negativo, tal como hace
  /// `_summarize` de `stats_screen`. Las transferencias entre cuentas propias
  /// quedan fuera de ingresos y gastos —no son dinero nuevo ganado ni
  /// gastado, sino la misma bolsa desplazada de una cuenta a otra—, pero sí
  /// cuentan como movimientos en [count], porque cada una es un registro
  /// real con su propio identificador.
  _MovementsSummary _summarize(List<InternalTransaction> transactions) {
    double income = 0;
    double expense = 0;

    for (final InternalTransaction tx in transactions) {
      if (tx.categoryId == 'transfer_out' || tx.categoryId == 'transfer_in') {
        continue;
      }
      if (tx.amount < 0) {
        expense += tx.amount.abs();
      } else {
        income += tx.amount;
      }
    }

    return _MovementsSummary(
      count: transactions.length,
      income: income,
      expense: expense,
    );
  }

  /// Símbolo de la moneda principal, con el mismo mecanismo que usa la
  /// pantalla de Movimientos para cada fila (nunca se inventa un símbolo).
  String _mainCurrencySymbol(AppProvider provider) {
    for (final Currency currency in provider.availableCurrencies) {
      if (currency.code == provider.mainCurrency) return currency.symbol;
    }
    return provider.mainCurrency;
  }

  /// Formatea un importe del resumen igual que el resto de la app:
  /// separador decimal configurable y dos decimales, sin cambiar precisión.
  String _summaryAmount(double value, String symbol) =>
      '$symbol${value.abs().toFormattedString(2)}';

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final AppProvider provider = Provider.of<AppProvider>(context);
    final List<AccountCard> cards = provider.cards;

    // Índices O(1) para resolver icono, moneda, categoría y cuenta de cada
    // movimiento sin recorrer las listas dentro de cada fila.
    final Map<String, AccountCard> cardById = <String, AccountCard>{
      for (final AccountCard c in cards) c.id: c,
    };
    final Map<String, Category> categoryById = <String, Category>{
      for (final Category c in provider.categories) c.id: c,
    };

    // Un único conjunto de consulta para el listado, el resumen y los
    // estados vacíos: así nunca pueden desincronizarse entre sí.
    final List<InternalTransaction> period = _periodTransactions(provider);
    final List<InternalTransaction> filtered = _applyFilters(
      context,
      period,
      cardById,
      categoryById,
    );
    final List<_HistoryEntry> entries = _buildEntries(filtered);
    final _MovementsSummary summary = _summarize(filtered);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.t('nav_movements'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      // El cabecero comparte scroll con el listado: en pantallas de 320 px un
      // cabecero fijo se comía casi todo el listado visible.
      body: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: _buildHeader(context, provider, cards, filtered, summary),
          ),
          ..._buildSlivers(
            context,
            provider,
            period,
            filtered,
            entries,
            cardById,
            categoryById,
          ),
        ],
      ),
    );
  }

  /// Cabecero de la pantalla, en el orden de consulta: período, resumen
  /// financiero, búsqueda y filtros.
  Widget _buildHeader(
    BuildContext context,
    AppProvider provider,
    List<AccountCard> cards,
    List<InternalTransaction> filtered,
    _MovementsSummary summary,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Selector de período (máximo 30 días naturales)
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            0,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _dateChip(context),
              if (!_isDefaultRange)
                CashChip(
                  label: context.t('movements_last_30_days'),
                  icon: Icons.restart_alt_rounded,
                  onTap: _resetRange,
                ),
            ],
          ),
        ),

        // 2. Resumen financiero del período consultado
        _buildSummary(context, provider, summary),

        // 3. Búsqueda
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
          ),
          child: CashInput(
            controller: _searchController,
            hint: context.t('search_transactions_hint'),
            textInputAction: TextInputAction.search,
            onChanged: _onQueryChanged,
            prefix: const Icon(Icons.search_rounded),
            suffix: _query.trim().isEmpty
                ? null
                : Tooltip(
                    message: context.t('clear_search'),
                    child: InkWell(
                      onTap: _clearSearch,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: const Padding(
                        padding: EdgeInsets.all(AppSpacing.sm),
                        child: Icon(Icons.close_rounded),
                      ),
                    ),
                  ),
          ),
        ),

        // 4. Filtros (tipo + limpiar)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenHorizontal,
          ),
          child: Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              _typeChip(context, _TxTypeFilter.all, context.t('all'), null),
              _typeChip(
                context,
                _TxTypeFilter.income,
                context.t('income'),
                AppColors.income,
              ),
              _typeChip(
                context,
                _TxTypeFilter.expense,
                context.t('expense'),
                AppColors.expense,
              ),
              if (_hasActiveFilters)
                CashChip(
                  label: context.t('clear_filters'),
                  icon: Icons.filter_alt_off_outlined,
                  onTap: _clearFilters,
                ),
            ],
          ),
        ),

        // 5. Filtro por cuenta (se conserva el existente)
        if (cards.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xs,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              // `Wrap` en lugar de un carrusel: a 320 px las etiquetas
              // largas se recortaban y quedaban fuera de la vista.
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  CashChip(
                    label: context.t('all_cards'),
                    selected: _selectedCardId == null,
                    icon: _selectedCardId == null ? Icons.check : null,
                    onTap: () => setState(() => _selectedCardId = null),
                  ),
                  for (final AccountCard card in cards)
                    CashChip(
                      label: _filterLabel(context, card),
                      selected: _selectedCardId == card.id,
                      icon: _selectedCardId == card.id ? Icons.check : null,
                      onTap: () => setState(() => _selectedCardId = card.id),
                    ),
                ],
              ),
            ),
          ),

        // 6. Ayuda contextual
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              0,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.touch_app_outlined,
                  size: 14,
                  color: _secondaryText(context),
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    context.t('history_hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: _secondaryText(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Resumen compacto del conjunto que se está consultando.
  ///
  /// Primero el balance del período (concepto distinto del saldo de la
  /// billetera), luego ingresos y gastos, y por último la cantidad de
  /// movimientos. Los importes se formatean con el mismo mecanismo que el
  /// resto de la app.
  Widget _buildSummary(
    BuildContext context,
    AppProvider provider,
    _MovementsSummary summary,
  ) {
    final ThemeData theme = Theme.of(context);
    final String symbol = _mainCurrencySymbol(provider);
    final double balance = summary.balance;
    final bool isNegative = balance < 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.sm,
        AppSpacing.screenHorizontal,
        AppSpacing.xs,
      ),
      child: CashCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    context.t('movements_balance_period'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _secondaryText(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '${summary.count} ${context.t('movements_count')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _secondaryText(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            // `scaleDown` encoge el importe largo en vez de desbordar o
            // recortarlo con puntos suspensivos.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${isNegative ? '-' : ''}${_summaryAmount(balance, symbol)}',
                maxLines: 1,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isNegative ? AppColors.expense : AppColors.income,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _summaryStat(
                    context,
                    icon: Icons.south_west_rounded,
                    color: AppColors.income,
                    label: context.t('income'),
                    value: _summaryAmount(summary.income, symbol),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: _summaryStat(
                    context,
                    icon: Icons.north_east_rounded,
                    color: AppColors.expense,
                    label: context.t('expense'),
                    value: _summaryAmount(summary.expense, symbol),
                  ),
                ),
              ],
            ),
            if (_hasActiveFilters) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                context.t('movements_summary_filtered'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _secondaryText(context),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Celda compacta de ingresos o gastos: icono, etiqueta e importe.
  Widget _summaryStat(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String label,
    required String value,
  }) {
    final ThemeData theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: _secondaryText(context),
                ),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Listado y estados vacíos como slivers del mismo scroll del cabecero.
  ///
  /// Los estados vacíos van en `SliverToBoxAdapter` con una altura mínima en
  /// lugar de `SliverFillRemaining`: así siguen visibles aunque el cabecero
  /// ocupe casi toda la pantalla.
  List<Widget> _buildSlivers(
    BuildContext context,
    AppProvider provider,
    List<InternalTransaction> period,
    List<InternalTransaction> filtered,
    List<_HistoryEntry> entries,
    Map<String, AccountCard> cardById,
    Map<String, Category> categoryById,
  ) {
    // Datos aún cargando: no confundir con "sin movimientos".
    if (provider.isLoading && provider.transactions.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(child: _emptyBox(const CircularProgressIndicator())),
      ];
    }

    // No hay ningún movimiento registrado en toda la app.
    if (provider.transactions.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _emptyBox(
            CashEmptyState(
              icon: Icons.receipt_long_rounded,
              title: context.t('no_recent_transactions'),
              message: context.t('home_empty_hint'),
            ),
          ),
        ),
      ];
    }

    // El período seleccionado no contiene movimientos.
    if (period.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _emptyBox(
            CashEmptyState(
              icon: Icons.event_busy_rounded,
              title: context.t('movements_empty_period'),
              message: context.t('movements_empty_period_hint'),
              buttonLabel: context.t('movements_change_range'),
              onButtonPressed: () => _pickDateRange(context),
            ),
          ),
        ),
      ];
    }

    // El período sí tiene movimientos, pero la búsqueda o los filtros no
    // devuelven ninguno.
    if (filtered.isEmpty) {
      return <Widget>[
        SliverToBoxAdapter(
          child: _emptyBox(
            CashEmptyState(
              icon: Icons.search_off_rounded,
              title: context.t('no_results_title'),
              message: context.t('no_results_message'),
              buttonLabel: context.t('clear_filters'),
              onButtonPressed: _clearFilters,
            ),
          ),
        ),
      ];
    }

    return <Widget>[
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.screenHorizontal,
          AppSpacing.sm,
          AppSpacing.screenHorizontal,
          AppSpacing.xxxl,
        ),
        sliver: SliverList.builder(
          itemCount: entries.length,
          itemBuilder: (ctx, index) {
            final _HistoryEntry entry = entries[index];
            if (entry.isHeader) {
              return _buildDateHeader(ctx, entry.day!);
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: _buildTransactionTile(
                ctx,
                provider,
                entry.tx!,
                cardById,
                categoryById,
              ),
            );
          },
        ),
      ),
    ];
  }

  /// Altura mínima compartida por los estados vacíos y la carga.
  Widget _emptyBox(Widget child) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 260),
    child: child,
  );

  Widget _typeChip(
    BuildContext context,
    _TxTypeFilter value,
    String label,
    Color? color,
  ) {
    final bool selected = _typeFilter == value;
    return CashChip(
      label: label,
      selected: selected,
      color: color,
      icon: selected ? Icons.check_rounded : null,
      onTap: () => setState(() => _typeFilter = value),
    );
  }

  /// Etiqueta del período seleccionado: el rango a la vista y su duración en
  /// días naturales, para que el alcance de la consulta siempre sea claro.
  Widget _dateChip(BuildContext context) {
    return CashChip(
      label: _rangeLabel(context, _dateRange),
      selected: true,
      icon: Icons.calendar_month_outlined,
      onTap: () => _pickDateRange(context),
    );
  }

  String _rangeLabel(BuildContext context, DateTimeRange range) {
    final MaterialLocalizations loc = MaterialLocalizations.of(context);
    return '${loc.formatShortDate(range.start)} – '
        '${loc.formatShortDate(range.end)}'
        ' · ${_inclusiveDays(range)} ${context.t('days')}';
  }

  String _filterLabel(BuildContext context, AccountCard card) {
    if (card.isCash) {
      return card.name.isNotEmpty
          ? '${context.t('card_cash')} - ${card.name}'
          : context.t('card_cash');
    }
    final String bankName = card.bankName == 'Efectivo'
        ? context.t('card_cash')
        : (card.bankName ?? context.t('card_default_name'));
    final String last4 = card.cardNumber.length >= 4
        ? card.cardNumber.substring(card.cardNumber.length - 4)
        : '****';
    return '$bankName $last4';
  }

  Widget _buildDateHeader(BuildContext context, DateTime day) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(
        MaterialLocalizations.of(context).formatFullDate(day),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          color: _secondaryText(context),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
    Map<String, AccountCard> cardById,
    Map<String, Category> categoryById,
  ) {
    final bool isExpense = tx.amount < 0;
    final String title = _getTransactionTitle(context, tx);
    final AccountCard? card = cardById[tx.cardId];
    final Category? category = categoryById[tx.categoryId];

    // Icono y color: el de su categoría cuando existe; para los movimientos
    // especiales (transferencias, recargas, solicitudes) se mantiene una señal
    // visual coherente con el resto de la app.
    final ({IconData icon, Color color}) visual = _categoryVisual(
      context,
      category,
      tx,
    );

    // Símbolo de la moneda: se usa el de la cuenta cuando está disponible y,
    // si no, el código de la moneda del propio movimiento.
    String symbol = tx.currency;
    if (card != null) {
      for (final Currency currency in provider.availableCurrencies) {
        if (currency.code == card.currency) {
          symbol = currency.symbol;
          break;
        }
      }
    }

    final String? cardSubtitle = card == null
        ? null
        : _filterLabel(context, card);

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final Color border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Material(
      color: surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => _showOptionsMenu(context, provider, tx),
        onLongPress: () => _showOptionsMenu(context, provider, tx),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: CashTransactionTile(
            icon: visual.icon,
            iconColor: visual.color,
            title: title,
            subtitle: cardSubtitle,
            // `CashTransactionTile` antepone el signo `+` / `-` según el signo
            // del movimiento, así que aquí va sólo el importe con su símbolo.
            amount: '$symbol${tx.amount.abs().toFormattedString(2)}',
            isIncome: !isExpense,
          ),
        ),
      ),
    );
  }

  /// Resuelve el icono y el color de un movimiento sin alterar su significado
  /// financiero: sólo presentación.
  ({IconData icon, Color color}) _categoryVisual(
    BuildContext context,
    Category? category,
    InternalTransaction tx,
  ) {
    if (category != null) {
      return (
        icon: IconConstants.getCategoryIcon(category.iconCode),
        color: Color(category.colorValue),
      );
    }

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color neutral = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiary;

    switch (tx.categoryId) {
      case 'transfer_out':
      case 'transfer_in':
        return (icon: Icons.swap_horiz_rounded, color: AppColors.info);
      case 'recharge':
        return (icon: Icons.add_card_rounded, color: AppColors.info);
      case 'income_request':
        return (icon: Icons.request_quote_rounded, color: AppColors.income);
      case 'general':
        return (icon: Icons.receipt_long_rounded, color: neutral);
      default:
        return (icon: Icons.help_outline, color: neutral);
    }
  }

  Color _secondaryText(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? AppColors.textSecondaryDark
      : AppColors.textSecondary;
}
