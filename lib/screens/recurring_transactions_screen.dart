import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../models/recurring_transaction.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../utils/icon_constants.dart';
import '../utils/number_format_utils.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_dialog.dart';
import '../widgets/design/cash_empty_state.dart';
import '../widgets/design/cash_floating_button.dart';
import '../widgets/design/cash_icon_button.dart';
import 'recurring_transaction_form_screen.dart';

/// Lista de transacciones recurrentes, diferenciadas en Ingresos y Gastos.
///
/// Cada tarjeta muestra de un vistazo: operación, monto, categoría, cuenta,
/// frecuencia, próxima ejecución y si el registro es automático o manual.
/// Conserva el modelo (`RecurringTransaction`), el borrado con confirmación y
/// la navegación al formulario: sólo cambia la presentación.
class RecurringTransactionsScreen extends StatelessWidget {
  const RecurringTransactionsScreen({super.key});

  static const List<String> _tabs = <String>[
    'rec_tab_incomes',
    'rec_tab_expenses',
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: Colors.transparent,
          title: Text(
            context.t('rec_screen_title'),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          centerTitle: true,
          bottom: TabBar(
            indicatorSize: TabBarIndicatorSize.label,
            labelStyle: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            unselectedLabelStyle: Theme.of(context).textTheme.titleSmall,
            tabs: <Widget>[
              for (final String key in _tabs) Tab(text: context.t(key)),
            ],
          ),
        ),
        body: Consumer<AppProvider>(
          builder: (context, provider, _) {
            final List<RecurringTransaction> incomes = provider
                .recurringTransactions
                .where((r) => r.isIncome)
                .toList()
                .reversed
                .toList();
            final List<RecurringTransaction> expenses = provider
                .recurringTransactions
                .where((r) => !r.isIncome)
                .toList()
                .reversed
                .toList();

            return TabBarView(
              children: <Widget>[
                _buildList(context, incomes, provider, true),
                _buildList(context, expenses, provider, false),
              ],
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (fabContext) => CashFloatingButton(
            heroTag: 'recurring_add',
            icon: Icons.add_rounded,
            label: context.t('create'),
            onPressed: () {
              // `fabContext` está por debajo del DefaultTabController, así que
              // puede leer el índice de la pestaña activa.
              final int tabIndex = DefaultTabController.of(fabContext).index;
              final bool isIncome = tabIndex == 0;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      RecurringTransactionFormScreen(isIncome: isIncome),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildList(
    BuildContext context,
    List<RecurringTransaction> items,
    AppProvider provider,
    bool isIncome,
  ) {
    if (items.isEmpty) {
      return CashEmptyState(
        icon: Icons.autorenew_rounded,
        title: context.t(isIncome ? 'rec_empty_incomes' : 'rec_empty_expenses'),
        message: context.t('rec_empty_hint'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.screenHorizontal,
        AppSpacing.md,
        AppSpacing.screenHorizontal,
        AppSpacing.giant,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final RecurringTransaction rt = items[index];
        return _RecurringCard(
          transaction: rt,
          account: _accountFor(provider, rt.accountId),
          isIncome: isIncome,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => RecurringTransactionFormScreen(
                  transaction: rt,
                  isIncome: rt.isIncome,
                ),
              ),
            );
          },
          onDelete: () => _confirmDelete(context, rt.id, provider, rt.isIncome),
        );
      },
    );
  }

  AccountCard? _accountFor(AppProvider provider, String accountId) {
    for (final AccountCard card in provider.cards) {
      if (card.id == accountId) return card;
    }
    return provider.cards.isEmpty ? null : provider.cards.first;
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String id,
    AppProvider provider,
    bool isIncome,
  ) async {
    final bool? result = await showCashConfirmDialog(
      context,
      title: context.t('delete'),
      message: context.t(
        isIncome
            ? 'rec_delete_question_income'
            : 'rec_delete_question_expense',
      ),
      confirmLabel: context.t('delete'),
      cancelLabel: context.t('cancel'),
      icon: Icons.delete_outline_rounded,
    );

    if (result == true) {
      provider.deleteRecurringTransaction(id);
    }
  }
}

class _RecurringCard extends StatelessWidget {
  final RecurringTransaction transaction;
  final AccountCard? account;
  final bool isIncome;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _RecurringCard({
    required this.transaction,
    required this.account,
    required this.isIncome,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color semantic = isIncome ? AppColors.income : AppColors.expense;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final Category? category = _findCategory(context);
    final Color categoryColor = Color(category?.colorValue ?? 0xFF18C96E);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: CashCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: categoryColor.withValues(alpha: 0.16),
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Icon(
                    IconConstants.getCategoryIcon(category?.iconCode ?? 0xe8fd),
                    size: 22,
                    color: categoryColor,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        _subtitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  '\$${transaction.amount.toFormattedString(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: semantic,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.event_repeat_rounded, size: 16, color: secondary),
                const SizedBox(width: AppSpacing.xs),
                Flexible(
                  child: Text(
                    context.t('rec_next_run'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: secondary),
                  ),
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  DateFormat('dd/MM/yy').format(transaction.nextExecutionDate),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                CashChip(
                  label: context.t(
                    transaction.autoRegister
                        ? 'rec_label_auto'
                        : 'rec_label_manual',
                  ),
                  icon: transaction.autoRegister
                      ? Icons.auto_awesome_rounded
                      : Icons.touch_app_outlined,
                  color: transaction.autoRegister
                      ? AppColors.warning
                      : secondary,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Align(
              alignment: Alignment.topRight,
              child: CashIconButton(
                icon: Icons.delete_outline_rounded,
                iconColor: AppColors.error,
                size: 40,
                iconSize: 18,
                tooltip: context.t('delete'),
                onPressed: onDelete,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(BuildContext context) {
    final String frequency = _frequencyLabel(context, transaction.recurrence);
    final String accountName = account?.name ?? '—';
    return '$frequency · $accountName';
  }

  String _frequencyLabel(BuildContext context, String recurrence) {
    switch (recurrence) {
      case 'diario':
        return context.t('rec_daily');
      case 'semanal':
        return context.t('rec_weekly');
      case 'quincenal':
        return context.t('rec_biweekly');
      case 'mensual':
        return context.t('rec_monthly');
      case 'trimestral':
        return context.t('rec_quarterly');
      case 'anual':
        return context.t('rec_yearly');
      default:
        return recurrence;
    }
  }

  Category? _findCategory(BuildContext context) {
    final AppProvider provider = context.read<AppProvider>();
    for (final Category category in provider.categories) {
      if (category.id == transaction.categoryId) return category;
    }
    return null;
  }
}
