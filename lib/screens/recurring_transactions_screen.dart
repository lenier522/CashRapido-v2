import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/recurring_transaction.dart';
import 'recurring_transaction_form_screen.dart';
import 'package:intl/intl.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class RecurringTransactionsScreen extends StatelessWidget {
  const RecurringTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text('Transacciones Recurrentes', style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 22)),
          centerTitle: true,
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 16),
            unselectedLabelStyle: GoogleFonts.outfit(fontWeight: FontWeight.normal, fontSize: 16),
            tabs: const [
              Tab(text: 'Ingresos'),
              Tab(text: 'Gastos'),
            ],
          ),
        ),
        body: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final incomes = provider.recurringTransactions.where((r) => r.isIncome).toList().reversed.toList();
            final expenses = provider.recurringTransactions.where((r) => !r.isIncome).toList().reversed.toList();

            return TabBarView(
              children: [
                _buildList(context, incomes, provider, true),
                _buildList(context, expenses, provider, false),
              ],
            );
          },
        ),
        floatingActionButton: Consumer<AppProvider>(
          builder: (context, provider, _) {
            return FloatingActionButton.extended(
              onPressed: () {
                final tabIndex = DefaultTabController.of(context).index;
                final isIncome = tabIndex == 0;
                Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringTransactionFormScreen(isIncome: isIncome)));
              },
              icon: const Icon(Icons.add),
              label: Text('Añadir', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            );
          },
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, List<RecurringTransaction> items, AppProvider provider, bool isIncome) {
    final themeColor = isIncome ? Colors.green : Colors.redAccent;

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: themeColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.autorenew_rounded, size: 80, color: themeColor.withValues(alpha: 0.5)),
            ),
            const SizedBox(height: 24),
            Text(
              isIncome ? 'No hay ingresos recurrentes' : 'No hay gastos recurrentes',
              style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Text(
              'Automatiza tus finanzas añadiendo uno nuevo.',
              style: GoogleFonts.outfit(fontSize: 14, color: Colors.grey[400]),
            ),
            const SizedBox(height: 32),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16).copyWith(bottom: 100),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final rt = items[index];
        final account = provider.cards.firstWhere((c) => c.id == rt.accountId, orElse: () => provider.cards.first);
        final isAuto = rt.autoRegister;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => RecurringTransactionFormScreen(transaction: rt, isIncome: rt.isIncome)));
              },
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(rt.title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.account_balance_wallet_outlined, size: 14, color: Colors.grey[500]),
                                  const SizedBox(width: 4),
                                  Text(account.name, style: GoogleFonts.outfit(color: Colors.grey[600], fontSize: 13)),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '\$${rt.amount.toFormattedString(2)}',
                            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: themeColor, fontSize: 16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.event_repeat, size: 16, color: Colors.blueGrey[400]),
                            const SizedBox(width: 6),
                            Text(
                              rt.recurrence.toUpperCase(),
                              style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey[600]),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
                            const SizedBox(width: 4),
                            Text(
                              DateFormat('dd/MM/yy').format(rt.nextExecutionDate),
                              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isAuto ? Icons.auto_awesome : Icons.pan_tool_outlined,
                              size: 16,
                              color: isAuto ? Colors.amber[600] : Colors.grey[400],
                            ),
                            const SizedBox(width: 6),
                            Text(
                              isAuto ? 'Automático' : 'Manual',
                              style: GoogleFonts.outfit(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isAuto ? Colors.amber[700] : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                          onPressed: () => _confirmDelete(context, rt.id, provider, rt.isIncome),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmDelete(BuildContext context, String id, AppProvider provider, bool isIncome) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Eliminar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
        content: Text(
          isIncome ? '¿Estás seguro de eliminar este ingreso recurrente?' : '¿Estás seguro de eliminar este gasto recurrente?',
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false), 
            child: Text('Cancelar', style: GoogleFonts.outfit(color: Colors.grey[600]))
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Eliminar', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result == true) {
      provider.deleteRecurringTransaction(id);
    }
  }
}
