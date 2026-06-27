import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/business_provider.dart';
import '../../models/business_expense.dart';
import 'expense_form_screen.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class ExpensesTab extends StatefulWidget {
  const ExpensesTab({super.key});

  @override
  State<ExpensesTab> createState() => _ExpensesTabState();
}

class _ExpensesTabState extends State<ExpensesTab> {
  String _dateFilter = 'all'; // 'all', 'today', 'week', 'month', 'custom'
  DateTime? _customStart;
  DateTime? _customEnd;
  String? _categoryFilter;

  void _setDateFilter(String filter) {
    setState(() => _dateFilter = filter);
  }

  void _showDateRangePicker(BuildContext context) {
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
    ).then((range) {
      if (range != null) {
        setState(() {
          _dateFilter = 'custom';
          _customStart = range.start;
          _customEnd = range.end;
        });
      }
    });
  }

  List<BusinessExpense> _filterExpenses(List<BusinessExpense> expenses) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    List<BusinessExpense> filtered = List.from(expenses);

    // Date filter
    switch (_dateFilter) {
      case 'today':
        filtered = filtered.where(
          (e) => e.date.isAfter(todayStart.subtract(const Duration(seconds: 1))),
        ).toList();
        break;
      case 'week':
        final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
        filtered = filtered.where(
          (e) => e.date.isAfter(weekStart.subtract(const Duration(seconds: 1))),
        ).toList();
        break;
      case 'month':
        final monthStart = DateTime(now.year, now.month, 1);
        filtered = filtered.where(
          (e) => e.date.isAfter(monthStart.subtract(const Duration(seconds: 1))),
        ).toList();
        break;
      case 'custom':
        if (_customStart != null && _customEnd != null) {
          filtered = filtered.where(
            (e) =>
                e.date.isAfter(_customStart!.subtract(const Duration(seconds: 1))) &&
                e.date.isBefore(_customEnd!.add(const Duration(days: 1))),
          ).toList();
        }
        break;
    }

    // Category filter
    if (_categoryFilter != null) {
      filtered = filtered.where((e) => e.category == _categoryFilter).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final filteredExpenses = _filterExpenses(provider.expenses);
        final sortedExpenses = List<BusinessExpense>.from(filteredExpenses)
          ..sort((a, b) => b.date.compareTo(a.date));

        final total = filteredExpenses.fold<double>(
          0.0,
          (sum, e) => sum + provider.convertAmount(e.amount, e.currency),
        );

        if (provider.expenses.isEmpty) {
          return _buildEmptyState(context);
        }

        return Column(
          children: [
            _buildFilterBar(context, provider, total),
            Expanded(
              child: sortedExpenses.isEmpty
                  ? Center(
                      child: Text(
                        'No hay gastos en este período',
                        style: TextStyle(color: Colors.grey[500]),
                      ),
                    )
                  : Stack(
                      children: [
                        ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: sortedExpenses.length,
                          itemBuilder: (context, index) {
                            final expense = sortedExpenses[index];
                            return _ExpenseCard(expense: expense, provider: provider);
                          },
                        ),
                        Positioned(
                          bottom: 16,
                          right: 16,
                          child: FloatingActionButton(
                            heroTag: 'add_expense',
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ExpenseFormScreen(),
                                ),
                              );
                            },
                            backgroundColor: Colors.red,
                            child: const Icon(Icons.add),
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context, BusinessProvider provider, double total) {
    final dateFilters = [
      {'key': 'all', 'label': 'Todas'},
      {'key': 'today', 'label': 'Hoy'},
      {'key': 'week', 'label': 'Esta Semana'},
      {'key': 'month', 'label': 'Este Mes'},
      {'key': 'custom', 'label': 'Personalizado'},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: dateFilters.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final f = dateFilters[index];
                final selected = _dateFilter == f['key'];
                return GestureDetector(
                  onTap: () {
                    if (f['key'] == 'custom') {
                      _showDateRangePicker(context);
                    } else {
                      _setDateFilter(f['key'] as String);
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? Theme.of(context).primaryColor
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: selected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.withOpacity(0.2),
                      ),
                    ),
                    child: Text(
                      f['label'] as String,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? Colors.white : Colors.grey[700],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              // Category filter dropdown
              Expanded(
                child: Row(
                  children: [
                    Text('Categoría: ', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            builder: (ctx) => Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  title: const Text('Todas'),
                                  selected: _categoryFilter == null,
                                  onTap: () {
                                    setState(() => _categoryFilter = null);
                                    Navigator.pop(ctx);
                                  },
                                ),
                                ...BusinessProvider.expenseCategories.map(
                                  (cat) => ListTile(
                                    title: Text(cat),
                                    selected: _categoryFilter == cat,
                                    onTap: () {
                                      setState(() => _categoryFilter = cat);
                                      Navigator.pop(ctx);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.withOpacity(0.2)),
                          ),
                          child: Text(
                            _categoryFilter ?? 'Todas',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Total: ',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              Text(
                '\$${total.toFormattedString(2)}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Colors.red,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay gastos registrados',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar Gasto'),
          ),
        ],
      ),
    );
  }
}

class _ExpenseCard extends StatelessWidget {
  final BusinessExpense expense;
  final BusinessProvider provider;

  const _ExpenseCard({required this.expense, required this.provider});

  Color _categoryColor(String category) {
    switch (category) {
      case 'Alquiler':
        return Colors.purple;
      case 'Servicios':
        return Colors.blue;
      case 'Salarios':
        return Colors.teal;
      case 'Insumos':
        return Colors.orange;
      case 'Marketing':
        return Colors.pink;
      case 'Transporte':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  IconData _categoryIcon(String category) {
    switch (category) {
      case 'Alquiler':
        return Icons.home_work;
      case 'Servicios':
        return Icons.build;
      case 'Salarios':
        return Icons.people;
      case 'Insumos':
        return Icons.inventory_2;
      case 'Marketing':
        return Icons.campaign;
      case 'Transporte':
        return Icons.local_shipping;
      default:
        return Icons.receipt;
    }
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Gasto'),
        content: Text(
          '¿Eliminar el gasto "${expense.description}"?\nEsta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              provider.deleteExpense(expense.id);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(expense: expense),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _categoryColor(expense.category);
    final icon = _categoryIcon(expense.category);

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        bool confirmed = false;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Eliminar Gasto'),
            content: Text('¿Eliminar "${expense.description}"?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  confirmed = true;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return confirmed;
      },
      onDismissed: (_) => provider.deleteExpense(expense.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete, color: Colors.white),
            SizedBox(height: 4),
            Text('Eliminar', style: TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            expense.category,
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 2),
              Text(
                expense.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('dd/MM/yyyy – HH:mm').format(expense.date),
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '\$${expense.amount.toFormattedString(2)}',
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                  fontSize: 16,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  expense.currency,
                  style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          isThreeLine: true,
          onTap: () => _openEdit(context),
          onLongPress: () => _confirmDelete(context),
        ),
      ),
    );
  }
}
