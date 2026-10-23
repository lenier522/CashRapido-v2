import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/business_expense.dart';
import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_dialog.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import 'expense_form_screen.dart';

/// Centro de control de gastos del negocio.
///
/// Conserva intactas la lógica de filtrado, el cálculo del total, el
/// ordenamiento y las acciones de crear/editar/eliminar. Sólo cambia la
/// presentación para que el listado sea compacto y navegable desde el móvil.
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

  /// Misma lógica de filtrado que la versión anterior (sin cambios).
  List<BusinessExpense> _filterExpenses(List<BusinessExpense> expenses) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    List<BusinessExpense> filtered = List.from(expenses);

    // Date filter
    switch (_dateFilter) {
      case 'today':
        filtered = filtered
            .where(
              (e) => e.date.isAfter(
                todayStart.subtract(const Duration(seconds: 1)),
              ),
            )
            .toList();
        break;
      case 'week':
        final weekStart = todayStart.subtract(
          Duration(days: todayStart.weekday - 1),
        );
        filtered = filtered
            .where(
              (e) => e.date.isAfter(
                weekStart.subtract(const Duration(seconds: 1)),
              ),
            )
            .toList();
        break;
      case 'month':
        final monthStart = DateTime(now.year, now.month, 1);
        filtered = filtered
            .where(
              (e) => e.date.isAfter(
                monthStart.subtract(const Duration(seconds: 1)),
              ),
            )
            .toList();
        break;
      case 'custom':
        if (_customStart != null && _customEnd != null) {
          filtered = filtered
              .where(
                (e) =>
                    e.date.isAfter(
                      _customStart!.subtract(const Duration(seconds: 1)),
                    ) &&
                    e.date.isBefore(_customEnd!.add(const Duration(days: 1))),
              )
              .toList();
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

        return Stack(
          children: [
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, provider.expenses.length),
                ),
                SliverToBoxAdapter(
                  child: _buildSummary(context, total, filteredExpenses.length),
                ),
                SliverToBoxAdapter(child: _buildDateChips(context)),
                SliverToBoxAdapter(child: _buildCategoryChips(context)),
                if (sortedExpenses.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoResults(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      144,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _ExpenseTile(
                          expense: sortedExpenses[index],
                          provider: provider,
                        ),
                        childCount: sortedExpenses.length,
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: CashFloatingButton(
                heroTag: 'add_expense',
                icon: Icons.add_rounded,
                label: context.t('rec_new_expense'),
                backgroundColor: AppColors.expense,
                onPressed: () => _openCreate(context),
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CABECERA Y RESUMEN
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t('business_expense'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark2
                  : AppColors.expenseLight,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              total == 1 ? '1 gasto' : '$total gastos',
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.expense,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(BuildContext context, double total, int count) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: CashCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        boxShadow: AppShadows.soft,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.expense.withValues(alpha: 0.12),
                borderRadius: AppRadius.radiusMd,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: AppColors.expense,
                size: 22,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Total de gastos',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _periodLabel(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiary,
                    ),
                  ),
                  Text(
                    '$count ${count == 1 ? 'registro' : 'registros'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                '\$${total.toFormattedString(2)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.expense,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel() {
    switch (_dateFilter) {
      case 'today':
        return 'Hoy';
      case 'week':
        return 'Esta semana';
      case 'month':
        return 'Este mes';
      case 'custom':
        if (_customStart != null && _customEnd != null) {
          final fmt = DateFormat('dd/MM/yyyy');
          return '${fmt.format(_customStart!)} – ${fmt.format(_customEnd!)}';
        }
        return 'Todas las fechas';
      default:
        return 'Todas las fechas';
    }
  }

  // ---------------------------------------------------------------------------
  // FILTROS
  // ---------------------------------------------------------------------------

  Widget _buildDateChips(BuildContext context) {
    final filters = <(String, String, IconData)>[
      ('all', 'Todas', Icons.apps_rounded),
      ('today', 'Hoy', Icons.today_outlined),
      ('week', 'Esta semana', Icons.date_range_outlined),
      ('month', 'Este mes', Icons.calendar_month_outlined),
      ('custom', 'Personalizado', Icons.tune_rounded),
    ];

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          for (final (key, label, icon) in filters)
            Padding(
              padding: EdgeInsets.only(left: key == 'all' ? 0 : AppSpacing.sm),
              child: CashChip(
                label: label,
                icon: icon,
                selected: _dateFilter == key,
                onTap: () {
                  if (key == 'custom') {
                    _showDateRangePicker(context);
                  } else {
                    _setDateFilter(key);
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryChips(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: SizedBox(
        height: 38,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            CashChip(
              label: 'Todas las categorías',
              icon: Icons.category_outlined,
              selected: _categoryFilter == null,
              onTap: () => setState(() => _categoryFilter = null),
            ),
            for (final category in BusinessProvider.expenseCategories)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.sm),
                child: CashChip(
                  label: category,
                  icon: _categoryIcon(category),
                  selected: _categoryFilter == category,
                  onTap: () => setState(
                    () => _categoryFilter = _categoryFilter == category
                        ? null
                        : category,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ESTADOS VACÍOS
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
    return CashEmptyState(
      icon: Icons.receipt_long_outlined,
      title: 'No hay gastos registrados',
      message:
          'Registra los gastos del negocio para controlar su rentabilidad.',
      buttonLabel: 'Registrar gasto',
      onButtonPressed: () => _openCreate(context),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return CashEmptyState(
      icon: Icons.search_off_rounded,
      title: 'No hay gastos en este filtro',
      message: 'Prueba con otro período o cambia la categoría seleccionada.',
      action: TextButton.icon(
        onPressed: () => setState(() {
          _dateFilter = 'all';
          _customStart = null;
          _customEnd = null;
          _categoryFilter = null;
        }),
        icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
        label: const Text('Limpiar filtros'),
      ),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ExpenseFormScreen()),
    );
  }
}

// ---------------------------------------------------------------------------
// MAPEO DE CATEGORÍAS
// ---------------------------------------------------------------------------

Color _categoryColor(String category) {
  switch (category) {
    case 'Alquiler':
      return AppColors.purple;
    case 'Servicios':
      return AppColors.info;
    case 'Salarios':
      return AppColors.secondary;
    case 'Insumos':
      return AppColors.orange;
    case 'Marketing':
      return const Color(0xFFEC4899);
    case 'Transporte':
      return const Color(0xFF6366F1);
    default:
      return AppColors.textSecondary;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Alquiler':
      return Icons.home_work_outlined;
    case 'Servicios':
      return Icons.build_outlined;
    case 'Salarios':
      return Icons.people_outline;
    case 'Insumos':
      return Icons.inventory_2_outlined;
    case 'Marketing':
      return Icons.campaign_outlined;
    case 'Transporte':
      return Icons.local_shipping_outlined;
    default:
      return Icons.receipt_outlined;
  }
}

// ---------------------------------------------------------------------------
// FILA DE GASTO
// ---------------------------------------------------------------------------

class _ExpenseTile extends StatelessWidget {
  final BusinessExpense expense;
  final BusinessProvider provider;

  const _ExpenseTile({required this.expense, required this.provider});

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showCashConfirmDialog(
      context,
      title: 'Eliminar gasto',
      message: '¿Eliminar "${expense.description}"?\n'
          'Esta acción no se puede deshacer.',
      confirmLabel: 'Eliminar',
      cancelLabel: 'Cancelar',
      icon: Icons.delete_outline_rounded,
    );
    return confirmed ?? false;
  }

  Future<void> _delete(BuildContext context) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    await provider.deleteExpense(expense.id, appProvider: appProvider);
  }

  void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ExpenseFormScreen(expense: expense)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = _categoryColor(expense.category);
    final IconData icon = _categoryIcon(expense.category);
    final String subtitle =
        '${expense.category} · ${DateFormat('dd/MM/yyyy – HH:mm').format(expense.date)}';

    return Dismissible(
      key: Key(expense.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _delete(context),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.error,
          borderRadius: AppRadius.radiusXl,
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.delete_outline, color: AppColors.white, size: 22),
            SizedBox(height: AppSpacing.xxs),
            Text(
              'Eliminar',
              style: TextStyle(color: AppColors.white, fontSize: 11),
            ),
          ],
        ),
      ),
      child: CashCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.md),
        padding: const EdgeInsets.all(AppSpacing.compactPadding),
        onTap: () => _openEdit(context),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: isDark ? 0.22 : 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 21),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '\$${expense.amount.toFormattedString(2)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.expense,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    expense.currency,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textTertiaryDark
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            _buildMenu(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return PopupMenuButton<String>(
      tooltip: 'Acciones',
      icon: Icon(Icons.more_vert_rounded, size: 20, color: secondary),
      constraints: const BoxConstraints(minWidth: 168),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
      onSelected: (value) async {
        if (value == 'edit') {
          _openEdit(context);
        } else if (value == 'delete') {
          final bool confirmed = await _confirmDelete(context);
          if (confirmed && context.mounted) _delete(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: secondary),
              const SizedBox(width: AppSpacing.md),
              const Text('Editar'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: AppColors.error),
              SizedBox(width: AppSpacing.md),
              Text('Eliminar', style: TextStyle(color: AppColors.error)),
            ],
          ),
        ),
      ],
    );
  }
}
