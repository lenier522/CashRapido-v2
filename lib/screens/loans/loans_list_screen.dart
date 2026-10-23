import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/loan.dart';
import '../../providers/app_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import '../../widgets/design/cash_input.dart';
import 'borrowers_list_screen.dart';
import 'loan_calculator_screen.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';
import 'loan_reports_screen.dart';

/// Listado de préstamos: centro de control financiero.
///
/// Muestra un resumen compacto con los indicadores existentes del provider,
/// permite buscar y filtrar por los criterios ya soportados y abre el detalle
/// de cada préstamo. Toda la lógica financiera (saldos, estados, métricas)
/// proviene del [LoanProvider]; aquí no se recalcula ni reinterpreta.
class LoansListScreen extends StatefulWidget {
  const LoansListScreen({super.key});

  @override
  State<LoansListScreen> createState() => _LoansListScreenState();
}

class _LoansListScreenState extends State<LoansListScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  /// `'all'`, `'active'`, `'overdue'`, `'paid'`, `'today'`, `'week'`.
  String _filterTag = 'all';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  //   FILTRADO (misma lógica existente)
  // ──────────────────────────────────────────
  List<Loan> _applyFilters(List<Loan> loans) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfWeek = startOfToday.add(const Duration(days: 7));

    List<Loan> result = loans;

    // Text search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (l) =>
                l.borrowerName.toLowerCase().contains(q) ||
                l.id.toLowerCase().contains(q) ||
                (l.borrowerId?.toLowerCase().contains(q) ?? false),
          )
          .toList();
    }

    // Tag filter
    switch (_filterTag) {
      case 'active':
        result = result.where((l) => l.status == 'active').toList();
        break;
      case 'overdue':
        result = result.where((l) => l.status == 'overdue').toList();
        break;
      case 'paid':
        result = result.where((l) => l.status == 'paid').toList();
        break;
      case 'today':
        result = result
            .where(
              (l) =>
                  l.dueDate.year == now.year &&
                  l.dueDate.month == now.month &&
                  l.dueDate.day == now.day,
            )
            .toList();
        break;
      case 'week':
        result = result
            .where(
              (l) =>
                  l.dueDate.isAfter(startOfToday) &&
                  l.dueDate.isBefore(endOfWeek),
            )
            .toList();
        break;
      default:
        break;
    }

    return result;
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _searchQuery = '');
  }

  void _clearAll() {
    _searchController.clear();
    setState(() {
      _searchQuery = '';
      _filterTag = 'all';
    });
  }

  void _openLoanForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoanFormScreen()),
    );
  }

  void _openLoanDetail(BuildContext context, Loan loan) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => LoanDetailScreen(loan: loan)),
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  String _currencySymbol(AppProvider provider, String code) {
    for (final currency in provider.availableCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = Provider.of<AppProvider>(context);
    final loanProvider = context.watch<LoanProvider>();

    final allLoans = loanProvider.loans;
    final filtered = _applyFilters(allLoans);
    final bool hasNoLoans = allLoans.isEmpty;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('loans_module_title')),
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: context.t('loan_reports_title'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoanReportsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: context.t('calc_title'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LoanCalculatorScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.people_outline_rounded),
            tooltip: context.t('borrowers_title'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const BorrowersListScreen()),
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: loanProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (!hasNoLoans) ...[
                  _buildSummary(context, loanProvider, appProvider),
                  _buildSearchField(context),
                  _buildFilterChips(context),
                  if (_searchQuery.isEmpty && _filterTag == 'all')
                    _buildUpcomingMaturities(context, loanProvider, appProvider),
                ],
                Expanded(
                  child: hasNoLoans
                      ? _buildEmptyPortfolio(context)
                      : filtered.isEmpty
                      ? _buildEmptyResults(context)
                      : _buildLoanList(
                          context,
                          filtered,
                          loanProvider,
                          appProvider,
                        ),
                ),
              ],
            ),
      // El botón de creación se oculta cuando la cartera está vacía porque el
      // estado vacío ya ofrece la misma acción (evita duplicarla).
      floatingActionButton: hasNoLoans || loanProvider.isLoading
          ? null
          : CashFloatingButton(
              heroTag: 'loans_create_fab',
              icon: Icons.add_rounded,
              label: context.t('new_loan'),
              onPressed: () => _openLoanForm(context),
            ),
    );
  }

  // ──────────────────────────────────────────
  //   RESUMEN FINANCIERO
  // ──────────────────────────────────────────
  Widget _buildSummary(
    BuildContext context,
    LoanProvider lp,
    AppProvider appProvider,
  ) {
    final theme = Theme.of(context);
    final currency = appProvider.mainCurrency;
    final symbol = _currencySymbol(appProvider, currency);

    // Sólo indicadores que ya expone el provider. No se crean métricas nuevas.
    final metrics = <_Metric>[
      _Metric(
        context.t('metric_lent_today'),
        lp.getMetricTotalDisbursedToday(currency),
        Icons.arrow_upward_rounded,
        AppColors.info,
      ),
      _Metric(
        context.t('metric_collected_today'),
        lp.getMetricTotalCollectedToday(currency),
        Icons.arrow_downward_rounded,
        AppColors.income,
      ),
      _Metric(
        context.t('metric_outstanding'),
        lp.getMetricOutstandingBalance(currency),
        Icons.pending_actions_rounded,
        AppColors.warning,
      ),
      _Metric(
        context.t('metric_delinquent'),
        lp.getMorososCount().toDouble(),
        Icons.warning_amber_rounded,
        AppColors.error,
        isCount: true,
      ),
      _Metric(
        context.t('metric_profit'),
        lp.getMetricGainGenerated(currency),
        Icons.trending_up_rounded,
        AppColors.purple,
      ),
      _Metric(
        context.t('metric_active'),
        lp.activeLoans.length.toDouble(),
        Icons.real_estate_agent_outlined,
        AppColors.secondary,
        isCount: true,
      ),
    ];

    final rows = <List<_Metric>>[metrics.sublist(0, 3), metrics.sublist(3, 6)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.md,
      ),
      child: CashCard(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.sm,
          horizontal: AppSpacing.xs,
        ),
        child: Column(
          children: [
            for (int r = 0; r < rows.length; r++) ...[
              if (r > 0)
                Divider(height: 1, thickness: 1, color: theme.dividerColor),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  for (final metric in rows[r])
                    Expanded(child: _buildMetricCell(context, metric, symbol)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetricCell(BuildContext context, _Metric metric, String symbol) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final valueText = metric.isCount
        ? metric.value.toInt().toString()
        : '$symbol${metric.value.toFormattedString(0)}';

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(metric.icon, size: 14, color: metric.color),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: secondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // `FittedBox` reduce la escala antes de recortar el importe, así
          // nunca se pierde una cifra por falta de ancho.
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                valueText,
                maxLines: 1,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: metric.color,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   BÚSQUEDA Y FILTROS
  // ──────────────────────────────────────────
  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.sm,
      ),
      child: CashInput(
        controller: _searchController,
        hint: context.t('loans_search_hint'),
        prefix: const Icon(Icons.search_rounded),
        suffix: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                tooltip: context.t('close'),
                onPressed: _clearSearch,
              ),
        textInputAction: TextInputAction.search,
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context) {
    final filters = <_FilterOption>[
      _FilterOption('all', context.t('filter_all'), Icons.apps_rounded),
      _FilterOption(
        'active',
        context.t('filter_active'),
        Icons.trending_up_rounded,
      ),
      _FilterOption(
        'overdue',
        context.t('filter_overdue'),
        Icons.warning_amber_rounded,
      ),
      _FilterOption(
        'paid',
        context.t('filter_paid'),
        Icons.check_circle_outline_rounded,
      ),
      _FilterOption('today', context.t('filter_today'), Icons.today_rounded),
      _FilterOption(
        'week',
        context.t('filter_this_week'),
        Icons.date_range_rounded,
      ),
    ];

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        itemCount: filters.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
        itemBuilder: (context, i) {
          final filter = filters[i];
          return CashChip(
            label: filter.label,
            icon: filter.icon,
            selected: _filterTag == filter.value,
            onTap: () => setState(() => _filterTag = filter.value),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────
  //   PRÓXIMOS VENCIMIENTOS
  // ──────────────────────────────────────────
  Widget _buildUpcomingMaturities(
    BuildContext context,
    LoanProvider lp,
    AppProvider appProvider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next7Days = today.add(const Duration(days: 8));

    // Se aplanan las cuotas próximas de los préstamos activos (misma lógica).
    final upcoming = <Map<String, dynamic>>[];
    for (final loan in lp.activeLoans) {
      for (final inst in loan.installments) {
        final instDate = DateTime(
          inst.dueDate.year,
          inst.dueDate.month,
          inst.dueDate.day,
        );
        if (inst.status != 'paid' &&
            !instDate.isBefore(today) &&
            instDate.isBefore(next7Days)) {
          upcoming.add({'loan': loan, 'inst': inst});
        }
      }
    }

    if (upcoming.isEmpty) return const SizedBox.shrink();

    upcoming.sort(
      (a, b) => (a['inst'] as Installment).dueDate.compareTo(
        (b['inst'] as Installment).dueDate,
      ),
    );

    final int count = upcoming.length > 10 ? 10 : upcoming.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.xl,
            AppSpacing.sm,
            AppSpacing.xl,
            AppSpacing.sm,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                size: 16,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  context.t('upcoming_maturities'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            itemCount: count,
            separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
            itemBuilder: (ctx, i) {
              final loan = upcoming[i]['loan'] as Loan;
              final inst = upcoming[i]['inst'] as Installment;
              final instDate = DateTime(
                inst.dueDate.year,
                inst.dueDate.month,
                inst.dueDate.day,
              );
              final daysLeft = instDate.difference(today).inDays;
              final dueSoon = daysLeft <= 1;
              final accent = dueSoon ? AppColors.error : AppColors.warning;
              final symbol = _currencySymbol(appProvider, loan.currency);

              return SizedBox(
                width: 156,
                child: CashCard(
                  onTap: () => _openLoanDetail(context, loan),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.35),
                  ),
                  boxShadow: isDark ? AppShadows.darkSoft : AppShadows.soft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loan.borrowerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      SizedBox(
                        width: double.infinity,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '$symbol${inst.remainingAmount.toFormattedString(2)} ${loan.currency}',
                            maxLines: 1,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        daysLeft == 0
                            ? '🔴 ${context.t('due_today')}'
                            : context.t(
                                'in_days',
                              ).replaceAll('{days}', '$daysLeft'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: dueSoon ? AppColors.error : secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   LISTADO
  // ──────────────────────────────────────────
  Widget _buildLoanList(
    BuildContext context,
    List<Loan> loans,
    LoanProvider lp,
    AppProvider appProvider,
  ) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.xl,
        96,
      ),
      itemCount: loans.length,
      itemBuilder: (context, i) =>
          _buildLoanCard(context, loans[i], lp, appProvider),
    );
  }

  Widget _buildLoanCard(
    BuildContext context,
    Loan loan,
    LoanProvider lp,
    AppProvider appProvider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Cálculos existentes, sin alterarlos.
    final totalWithInterest = lp.calculateTotalWithInterest(
      loan.amount,
      loan.interestRate,
      loan.interestType,
      loan.durationValue,
    );
    final paidAmount = totalWithInterest - loan.remainingAmount;
    final progress = totalWithInterest > 0
        ? (paidAmount / totalWithInterest).clamp(0.0, 1.0)
        : 0.0;
    final progressPct = (progress * 100).toStringAsFixed(0);

    final pendingInstallments = loan.installments
        .where((i) => i.status != 'paid')
        .length;
    final overdueInstallments = loan.installments
        .where((i) => i.status == 'overdue')
        .length;

    final status = _statusStyle(context, loan.status, isDark);
    final bool isOverdue = loan.status == 'overdue';
    final symbol = _currencySymbol(appProvider, loan.currency);

    final primaryText = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      onTap: () => _openLoanDetail(context, loan),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      border: Border.all(
        color: isOverdue
            ? AppColors.error.withValues(alpha: 0.35)
            : (isDark ? AppColors.borderDark : AppColors.borderLight),
        width: isOverdue ? 1.5 : 1,
      ),
      boxShadow: isOverdue
          ? [
              BoxShadow(
                color: AppColors.error.withValues(alpha: isDark ? 0.22 : 0.12),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ]
          : (isDark ? AppShadows.darkSoft : AppShadows.soft),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Identificación + estado
          Row(
            children: [
              Expanded(
                child: Text(
                  loan.borrowerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusBadge(
                color: status.color,
                icon: status.icon,
                label: status.label,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Información secundaria: vencimiento + cuotas
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 14,
                color: isOverdue ? AppColors.error : secondaryText,
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '${context.t('loan_due_label')}: ${_formatDate(loan.dueDate)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isOverdue ? AppColors.error : secondaryText,
                    fontWeight: isOverdue ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (loan.installments.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.sm),
                _InstallmentBadge(
                  overdue: overdueInstallments,
                  pending: pendingInstallments,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 2. Información monetaria principal
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('loan_card_remaining'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '$symbol${loan.remainingAmount.toFormattedString(2)} ${loan.currency}',
                          maxLines: 1,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: isOverdue ? AppColors.error : primaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      context.t('loan_card_principal'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '$symbol${loan.amount.toFormattedString(2)} ${loan.currency}',
                          maxLines: 1,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: secondaryText,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          // 3. Progreso de cobro
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: AppRadius.radiusXs,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark
                        ? AppColors.surfaceDark3
                        : AppColors.surfaceVariantLight,
                    color: status.color,
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '$progressPct%',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: status.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  _StatusStyle _statusStyle(BuildContext context, String status, bool isDark) {
    switch (status) {
      case 'paid':
        return _StatusStyle(
          AppColors.income,
          Icons.check_circle_outline_rounded,
          context.t('loan_status_paid'),
        );
      case 'overdue':
        return _StatusStyle(
          AppColors.error,
          Icons.error_outline_rounded,
          context.t('loan_status_overdue'),
        );
      case 'written_off':
        return _StatusStyle(
          isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
          Icons.cancel_outlined,
          context.t('loan_status_written_off'),
        );
      case 'refinanced':
        return _StatusStyle(
          AppColors.info,
          Icons.swap_horiz_rounded,
          context.t('loan_status_refinanced'),
        );
      case 'active':
      default:
        return _StatusStyle(
          AppColors.primary,
          Icons.trending_up_rounded,
          context.t('loan_status_active'),
        );
    }
  }

  // ──────────────────────────────────────────
  //   ESTADOS VACÍOS
  // ──────────────────────────────────────────
  Widget _buildEmptyPortfolio(BuildContext context) {
    return CashEmptyState(
      icon: Icons.real_estate_agent_outlined,
      title: context.t('no_loans_title'),
      message: context.t('no_loans_desc_portfolio'),
      buttonLabel: context.t('new_loan'),
      onButtonPressed: () => _openLoanForm(context),
    );
  }

  Widget _buildEmptyResults(BuildContext context) {
    final bool searching = _searchQuery.trim().isNotEmpty;
    return CashEmptyState(
      icon: searching
          ? Icons.search_off_rounded
          : Icons.filter_alt_off_rounded,
      title: searching
          ? context.t('no_search_results')
          : context.t('no_data'),
      // Una sola acción devuelve al listado completo.
      action: _EmptyResetButton(onPressed: _clearAll),
    );
  }
}

// ─────────────────────────────────────────────
//   COMPONENTES AUXILIARES
// ─────────────────────────────────────────────

/// Insignia de estado: combina color e icono (no depende sólo del color).
class _StatusBadge extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;

  const _StatusBadge({
    required this.color,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen compacto de cuotas vencidas o pendientes de un préstamo.
class _InstallmentBadge extends StatelessWidget {
  final int overdue;
  final int pending;

  const _InstallmentBadge({required this.overdue, required this.pending});

  @override
  Widget build(BuildContext context) {
    final bool hasOverdue = overdue > 0;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = hasOverdue
        ? AppColors.error
        : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);
    final String text = hasOverdue
        ? context.t('installments_overdue_count').replaceAll('{count}', '$overdue')
        : context.t('installments_pending_count').replaceAll('{count}', '$pending');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusXs,
      ),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

/// Botón secundario para restablecer búsqueda y filtros desde el estado vacío.
class _EmptyResetButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _EmptyResetButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
      label: Text(context.t('filter_all')),
    );
  }
}

// ─────────────────────────────────────────────
//   MODELOS PRIVADOS
// ─────────────────────────────────────────────

class _Metric {
  final String label;
  final double value;
  final IconData icon;
  final Color color;
  final bool isCount;

  const _Metric(
    this.label,
    this.value,
    this.icon,
    this.color, {
    this.isCount = false,
  });
}

class _StatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const _StatusStyle(this.color, this.icon, this.label);
}

class _FilterOption {
  final String value;
  final String label;
  final IconData icon;

  const _FilterOption(this.value, this.label, this.icon);
}
