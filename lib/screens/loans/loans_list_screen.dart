import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan.dart';
import 'package:cashrapido/utils/number_format_utils.dart';
import 'loan_form_screen.dart';
import 'loan_detail_screen.dart';
import 'borrowers_list_screen.dart';
import 'loan_calculator_screen.dart';
import 'loan_reports_screen.dart';

class LoansListScreen extends StatefulWidget {
  const LoansListScreen({super.key});

  @override
  State<LoansListScreen> createState() => _LoansListScreenState();
}

class _LoansListScreenState extends State<LoansListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _searchQuery = '';
  String _filterTag = 'all'; // 'all', 'active', 'overdue', 'paid', 'today', 'week'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<Loan> _applyFilters(List<Loan> loans) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfWeek = startOfToday.add(const Duration(days: 7));

    List<Loan> result = loans;

    // Text search
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result.where((l) =>
          l.borrowerName.toLowerCase().contains(q) ||
          l.id.toLowerCase().contains(q) ||
          (l.borrowerId?.toLowerCase().contains(q) ?? false)).toList();
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
        result = result.where((l) =>
            l.dueDate.year == now.year &&
            l.dueDate.month == now.month &&
            l.dueDate.day == now.day).toList();
        break;
      case 'week':
        result = result.where((l) =>
            l.dueDate.isAfter(startOfToday) && l.dueDate.isBefore(endOfWeek)).toList();
        break;
      default:
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          Localizations.localeOf(context).languageCode == 'es' ? 'Módulo de Préstamos' : 'Loans Module',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Reports button
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Reportes' : 'Reports',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LoanReportsScreen()),
            ),
          ),
          // Calculator
          IconButton(
            icon: const Icon(Icons.calculate_outlined),
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Simulador' : 'Calculator',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const LoanCalculatorScreen()),
            ),
          ),
          // Clients
          IconButton(
            icon: const Icon(Icons.people_outline_rounded),
            tooltip: Localizations.localeOf(context).languageCode == 'es' ? 'Clientes' : 'Clients',
            onPressed: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const BorrowersListScreen()),
            ),
          ),
        ],
      ),
      body: Consumer<LoanProvider>(
        builder: (context, loanProvider, _) {
          if (loanProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final currency = appProvider.mainCurrency;
          final allLoans = loanProvider.loans;
          final filtered = _applyFilters(allLoans);

          return Column(
            children: [
              // ── DASHBOARD METRICS ──
              _buildDashboard(context, loanProvider, currency, isDark),

              // ── SEARCH BAR ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141428) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.outfit(color: isDark ? Colors.white : Colors.black87, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: Localizations.localeOf(context).languageCode == 'es'
                          ? 'Buscar por nombre, teléfono o ID...'
                          : 'Search by name, phone or ID...',
                      hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey, size: 20),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),

              // ── FILTER TAGS ──
              _buildFilterTags(context, isDark),

              // ── UPCOMING MATURITIES ──
              if (_searchQuery.isEmpty && _filterTag == 'all')
                _buildUpcomingMaturities(context, loanProvider, isDark),

              // ── LOAN LIST ──
              Expanded(
                child: allLoans.isEmpty
                    ? _buildEmptyState(context)
                    : filtered.isEmpty
                        ? Center(
                            child: Text(
                              Localizations.localeOf(context).languageCode == 'es'
                                  ? 'Sin resultados para la búsqueda'
                                  : 'No results found',
                              style: GoogleFonts.outfit(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                            itemCount: filtered.length,
                            itemBuilder: (context, i) => _buildLoanCard(context, filtered[i], loanProvider),
                          ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => const LoanFormScreen()),
        ),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: Text(
          Localizations.localeOf(context).languageCode == 'es' ? 'Nuevo Préstamo' : 'New Loan',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
        ),
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  // ──────────────────────────────────────────
  //   DASHBOARD METRICS
  // ──────────────────────────────────────────
  Widget _buildDashboard(BuildContext context, LoanProvider lp, String currency, bool isDark) {
    final today = lp.getMetricTotalDisbursedToday(currency);
    final todayCollected = lp.getMetricTotalCollectedToday(currency);
    final outstanding = lp.getMetricOutstandingBalance(currency);
    final morosos = lp.getMorososCount();
    final profit = lp.getMetricGainGenerated(currency);
    final activeCount = lp.activeLoans.length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _metricCard(context, Localizations.localeOf(context).languageCode == 'es' ? 'Prestado hoy' : 'Lent today', today, currency, Colors.blueAccent, Icons.arrow_upward_rounded, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _metricCard(context, Localizations.localeOf(context).languageCode == 'es' ? 'Cobrado hoy' : 'Collected today', todayCollected, currency, Colors.greenAccent, Icons.arrow_downward_rounded, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _metricCard(context, Localizations.localeOf(context).languageCode == 'es' ? 'Pendiente' : 'Outstanding', outstanding, currency, Colors.orangeAccent, Icons.pending_actions, isDark)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _metricCard(context, Localizations.localeOf(context).languageCode == 'es' ? 'Morosos' : 'Delinquent', morosos.toDouble(), '', Colors.redAccent, Icons.warning_amber_rounded, isDark, isCount: true)),
              const SizedBox(width: 8),
              Expanded(child: _metricCard(context, Localizations.localeOf(context).languageCode == 'es' ? 'Ganancia' : 'Profit', profit, currency, Colors.purpleAccent, Icons.trending_up_rounded, isDark)),
              const SizedBox(width: 8),
              Expanded(child: _metricCard(context, Localizations.localeOf(context).languageCode == 'es' ? 'Activos' : 'Active', activeCount.toDouble(), '', Colors.cyanAccent, Icons.real_estate_agent_outlined, isDark, isCount: true)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metricCard(BuildContext context, String label, double value, String currency, Color color, IconData icon, bool isDark, {bool isCount = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 6, offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(label, style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            isCount ? value.toInt().toString() : '\$${value.toStringAsFixed(0)}',
            style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: color),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (!isCount && currency.isNotEmpty)
            Text(currency, style: GoogleFonts.outfit(fontSize: 9, color: Colors.grey)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   FILTER TAGS
  // ──────────────────────────────────────────
  Widget _buildFilterTags(BuildContext context, bool isDark) {
    final theme = Theme.of(context);
    final filters = [
      {'val': 'all', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Todos' : 'All'},
      {'val': 'active', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Activos' : 'Active'},
      {'val': 'overdue', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Morosos' : 'Overdue'},
      {'val': 'paid', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Pagados' : 'Paid'},
      {'val': 'today', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Hoy' : 'Today'},
      {'val': 'week', 'lbl': Localizations.localeOf(context).languageCode == 'es' ? 'Esta Semana' : 'This Week'},
    ];

    return SizedBox(
      height: 38,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, i) {
          final f = filters[i];
          final active = _filterTag == f['val'];
          return GestureDetector(
            onTap: () => setState(() => _filterTag = f['val']!),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: active ? theme.colorScheme.primary : (isDark ? const Color(0xFF141428) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? theme.colorScheme.primary : (isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.2)),
                ),
              ),
              child: Text(
                f['lbl']!,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal,
                  color: active ? Colors.white : Colors.grey,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────
  //   UPCOMING MATURITIES
  // ──────────────────────────────────────────
  Widget _buildUpcomingMaturities(BuildContext context, LoanProvider lp, bool isDark) {
    final now = DateTime.now();
    final next7Days = now.add(const Duration(days: 7));

    // Flatten all upcoming installments from active loans
    final upcoming = <Map<String, dynamic>>[];
    for (var loan in lp.activeLoans) {
      for (var inst in loan.installments) {
        if (inst.status != 'paid' && inst.dueDate.isAfter(now) && inst.dueDate.isBefore(next7Days)) {
          upcoming.add({'loan': loan, 'inst': inst});
        }
      }
    }

    if (upcoming.isEmpty) return const SizedBox.shrink();

    upcoming.sort((a, b) => (a['inst'] as Installment).dueDate.compareTo((b['inst'] as Installment).dueDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            Localizations.localeOf(context).languageCode == 'es' ? '⏰ Próximos Vencimientos (7 días)' : '⏰ Upcoming Maturities (7 days)',
            style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orangeAccent),
          ),
        ),
        SizedBox(
          height: 80,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: upcoming.length > 10 ? 10 : upcoming.length,
            itemBuilder: (ctx, i) {
              final loan = upcoming[i]['loan'] as Loan;
              final inst = upcoming[i]['inst'] as Installment;
              final daysLeft = inst.dueDate.difference(now).inDays;

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loan: loan))),
                child: Container(
                  width: 130,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF141428) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: daysLeft <= 1 ? Colors.red.withValues(alpha: 0.4) : Colors.orange.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loan.borrowerName,
                        style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$${inst.remainingAmount.toStringAsFixed(2)} ${loan.currency}',
                        style: GoogleFonts.outfit(fontSize: 11, color: Colors.orangeAccent, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        daysLeft == 0
                            ? (Localizations.localeOf(context).languageCode == 'es' ? '🔴 Vence HOY' : '🔴 Due TODAY')
                            : (Localizations.localeOf(context).languageCode == 'es' ? 'En $daysLeft día(s)' : 'In $daysLeft day(s)'),
                        style: GoogleFonts.outfit(fontSize: 10, color: daysLeft <= 1 ? Colors.redAccent : Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   LOAN CARD
  // ──────────────────────────────────────────
  Widget _buildLoanCard(BuildContext context, Loan loan, LoanProvider loanProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalWithInterest = loanProvider.calculateTotalWithInterest(
      loan.amount, loan.interestRate, loan.interestType, loan.durationValue);
    final paidAmount = totalWithInterest - loan.remainingAmount;
    final progress = totalWithInterest > 0 ? (paidAmount / totalWithInterest).clamp(0.0, 1.0) : 0.0;
    final progressPct = (progress * 100).toStringAsFixed(0);

    Color statusColor;
    IconData statusIcon;
    String displayStatus;

    switch (loan.status) {
      case 'paid':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle_outline_rounded;
        displayStatus = Localizations.localeOf(context).languageCode == 'es' ? 'Pagado' : 'Paid';
        break;
      case 'overdue':
        statusColor = Colors.red;
        statusIcon = Icons.error_outline_rounded;
        displayStatus = Localizations.localeOf(context).languageCode == 'es' ? 'Vencido' : 'Overdue';
        break;
      case 'written_off':
        statusColor = Colors.grey;
        statusIcon = Icons.cancel_outlined;
        displayStatus = Localizations.localeOf(context).languageCode == 'es' ? 'Incobrable' : 'Written Off';
        break;
      case 'refinanced':
        statusColor = Colors.blueGrey;
        statusIcon = Icons.swap_horiz_rounded;
        displayStatus = Localizations.localeOf(context).languageCode == 'es' ? 'Refinanciado' : 'Refinanced';
        break;
      case 'active':
      default:
        statusColor = theme.colorScheme.primary;
        statusIcon = Icons.trending_up_rounded;
        displayStatus = Localizations.localeOf(context).languageCode == 'es' ? 'Activo' : 'Active';
    }

    // Installment summary
    final pendingInstallments = loan.installments.where((i) => i.status != 'paid').length;
    final overdueInstallments = loan.installments.where((i) => i.status == 'overdue').length;

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => LoanDetailScreen(loan: loan))),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141428) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: loan.status == 'overdue' ? Colors.red.withValues(alpha: 0.3) : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      loan.borrowerName,
                      style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 13),
                        const SizedBox(width: 4),
                        Text(displayStatus, style: GoogleFonts.outfit(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Localizations.localeOf(context).languageCode == 'es' ? 'Pendiente' : 'Remaining', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                      Text(
                        '\$${loan.remainingAmount.toFormattedString(2)} ${loan.currency}',
                        style: GoogleFonts.outfit(fontSize: 15, fontWeight: FontWeight.bold,
                            color: loan.status == 'overdue' ? Colors.red : (isDark ? Colors.white : Colors.black87)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(Localizations.localeOf(context).languageCode == 'es' ? 'Capital' : 'Principal', style: GoogleFonts.outfit(fontSize: 11, color: Colors.grey)),
                      Text('\$${loan.amount.toFormattedString(2)} ${loan.currency}',
                          style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w500)),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: progress,
                        backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                        color: statusColor,
                        minHeight: 6,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text('$progressPct%', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor)),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${Localizations.localeOf(context).languageCode == 'es' ? 'Vence' : 'Due'}: ${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}',
                    style: GoogleFonts.outfit(fontSize: 11, color: loan.status == 'overdue' ? Colors.red : Colors.grey,
                        fontWeight: loan.status == 'overdue' ? FontWeight.bold : FontWeight.normal),
                  ),
                  if (loan.installments.isNotEmpty)
                    Row(
                      children: [
                        if (overdueInstallments > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('$overdueInstallments ${Localizations.localeOf(context).languageCode == 'es' ? 'vencidas' : 'overdue'}',
                                style: GoogleFonts.outfit(fontSize: 10, color: Colors.redAccent)),
                          )
                        else
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                            child: Text('$pendingInstallments ${Localizations.localeOf(context).languageCode == 'es' ? 'cuotas pend.' : 'pending inst.'}',
                                style: GoogleFonts.outfit(fontSize: 10, color: Colors.grey)),
                          ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.real_estate_agent_outlined, size: 64, color: theme.colorScheme.primary),
            ),
            const SizedBox(height: 24),
            Text(
              Localizations.localeOf(context).languageCode == 'es' ? 'Sin Préstamos' : 'No Loans',
              style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              Localizations.localeOf(context).languageCode == 'es'
                  ? 'Aún no has registrado ningún préstamo. Toca el botón \'+\' para comenzar a gestionar tu cartera.'
                  : 'No loans registered yet. Tap \'+\' to start managing your portfolio.',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoanFormScreen())),
              icon: const Icon(Icons.add, color: Colors.white),
              label: Text(Localizations.localeOf(context).languageCode == 'es' ? 'Nuevo Préstamo' : 'New Loan', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
