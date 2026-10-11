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
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_empty_state.dart';
import '../widgets/design/cash_transaction_tile.dart';

/// Historial completo de movimientos.
///
/// Se conservan el filtro por cuenta, la pulsación larga para editar o borrar,
/// la confirmación de borrado y las llamadas al provider. El dinero se
/// muestra con el símbolo de la moneda de la cuenta cuando se conoce, en lugar
/// de un `$` fijo, y cada movimiento usa `CashTransactionTile`.
class AllTransactionsScreen extends StatefulWidget {
  final String? initialCardId;

  const AllTransactionsScreen({super.key, this.initialCardId});

  @override
  State<AllTransactionsScreen> createState() => _AllTransactionsScreenState();
}

class _AllTransactionsScreenState extends State<AllTransactionsScreen> {
  String? _selectedCardId;

  @override
  void initState() {
    super.initState();
    _selectedCardId = widget.initialCardId;
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
  // ACCIONES (sin cambios)
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(Icons.warning_amber_rounded, color: AppColors.error),
        title: Text(context.t('delete_transaction')),
        content: Text(context.t('delete_transaction_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: context.t('delete'),
            type: CashButtonType.danger,
            fullWidth: false,
            height: 44,
            onPressed: () async {
              await provider.deleteTransaction(tx.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('transaction_deleted'))),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final cards = provider.cards;

    List<InternalTransaction> transactions = provider.transactions;
    if (_selectedCardId != null) {
      transactions = transactions
          .where((t) => t.cardId == _selectedCardId)
          .toList();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          context.t('history_title'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: Column(
        children: [
          if (cards.isNotEmpty)
            // `Wrap` en lugar de un carrusel horizontal: a 320 px las etiquetas
            // largas se recortaban y quedaban fuera de la vista.
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.screenHorizontal,
                AppSpacing.xs,
                AppSpacing.screenHorizontal,
                AppSpacing.xs,
              ),
              child: Align(
                alignment: Alignment.centerLeft,
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
                    for (final card in cards)
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

          if (transactions.isNotEmpty)
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
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      'Mantén pulsado para editar o eliminar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          Expanded(
            child: transactions.isEmpty
                ? CashEmptyState(
                    icon: Icons.receipt_long_rounded,
                    title: context.t('no_recent_transactions'),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.screenHorizontal,
                      AppSpacing.md,
                      AppSpacing.screenHorizontal,
                      AppSpacing.xxxl,
                    ),
                    itemCount: transactions.length,
                    itemBuilder: (ctx, index) {
                      final tx = transactions[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                        child: _buildTransactionTile(context, provider, tx),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
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

  Widget _buildTransactionTile(
    BuildContext context,
    AppProvider provider,
    InternalTransaction tx,
  ) {
    final bool isExpense = tx.amount < 0;
    final String title = _getTransactionTitle(context, tx);

    // Símbolo de la moneda: se usa el de la cuenta cuando está disponible y,
    // si no, el código de la moneda del propio movimiento.
    String symbol = tx.currency;
    AccountCard? card;
    for (final candidate in provider.cards) {
      if (candidate.id == tx.cardId) {
        card = candidate;
        break;
      }
    }
    if (card != null) {
      for (final currency in provider.availableCurrencies) {
        if (currency.code == card.currency) {
          symbol = currency.symbol;
          break;
        }
      }
    }

    Color iconColor = AppColors.textTertiary;
    IconData icon = Icons.help_outline;
    for (final cat in provider.categories) {
      if (cat.id == tx.categoryId) {
        iconColor = Color(cat.colorValue);
        icon = IconConstants.getCategoryIcon(cat.iconCode);
        break;
      }
    }

    final String cardSubtitle = card == null
        ? ''
        : ' • ${_filterLabel(context, card)}';
    final String dateLabel =
        '${tx.date.year}-${_two(tx.date.month)}-${_two(tx.date.day)}';

    return GestureDetector(
      onLongPress: () => _showOptionsMenu(context, provider, tx),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.surfaceDark
              : AppColors.surfaceLight,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.borderDark
                : AppColors.borderLight,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: CashTransactionTile(
          icon: icon,
          iconColor: iconColor,
          title: title,
          subtitle: '$dateLabel$cardSubtitle',
          // `CashTransactionTile` antepone el signo `+` / `-` según el signo
          // del movimiento, así que aquí va sólo el importe con su símbolo.
          amount: '$symbol${tx.amount.abs().toFormattedString(2)}',
          isIncome: !isExpense,
        ),
      ),
    );
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}
