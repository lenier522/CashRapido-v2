import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/localization_service.dart';
import '../utils/icon_constants.dart';
import '../widgets/add_transaction_modal.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

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

  void _showOptionsMenu(BuildContext context, AppProvider provider, InternalTransaction tx) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: Colors.blue),
              title: Text(context.t('edit')),
              onTap: () {
                Navigator.pop(ctx);
                _showEditTransactionDialog(context, tx);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: Text(
                context.t('delete'),
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _showDeleteConfirmation(context, provider, tx);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditTransactionDialog(BuildContext context, InternalTransaction tx) {
    showModalBottomSheet(
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
            const SizedBox(width: 8),
            Text(context.t('delete_transaction')),
          ],
        ),
        content: Text(context.t('delete_transaction_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              await provider.deleteTransaction(tx.id);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('transaction_deleted'))),
                );
              }
            },
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final cards = provider.cards;

    List<InternalTransaction> transactions = provider.transactions;
    if (_selectedCardId != null) {
      transactions = transactions.where((t) => t.cardId == _selectedCardId).toList();
    }

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          context.t('history_title'),
          style: GoogleFonts.outfit(
            color: Theme.of(context).textTheme.bodyLarge?.color,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: IconThemeData(
          color: Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      body: Column(
        children: [
          // Filter chips
          if (cards.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildFilterChip(
                    label: context.t('all_cards'),
                    isSelected: _selectedCardId == null,
                    onTap: () => setState(() => _selectedCardId = null),
                  ),
                  ...cards.map((card) {
                    String label;
                    if (card.isCash) {
                      label = card.name.isNotEmpty
                          ? "${context.t('card_cash')} - ${card.name}"
                          : context.t('card_cash');
                    } else {
                      final bankName = card.bankName == 'Efectivo'
                          ? context.t('card_cash')
                          : (card.bankName ?? context.t('card_default_name'));
                      final last4 = card.cardNumber.length >= 4
                          ? card.cardNumber.substring(card.cardNumber.length - 4)
                          : '****';
                      label = '$bankName $last4';
                    }
                    return _buildFilterChip(
                      label: label,
                      isSelected: _selectedCardId == card.id,
                      onTap: () => setState(() => _selectedCardId = card.id),
                    );
                  }),
                ],
              ),
            ),

          // Hint label
          if (transactions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Icon(Icons.touch_app_outlined, size: 13, color: Colors.grey.shade500),
                  const SizedBox(width: 4),
                  Text(
                    'Mantén pulsado para editar o eliminar',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

          // Transactions List
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Text(
                      context.t('no_recent_transactions'),
                      style: GoogleFonts.outfit(color: Colors.grey, fontSize: 16),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: transactions.length,
                    itemBuilder: (ctx, index) {
                      final tx = transactions[index];
                      final isExpense = tx.amount < 0;
                      final title = _getTransactionTitle(context, tx);

                      String cardNameStr = '';
                      try {
                        final card = provider.cards.firstWhere((c) => c.id == tx.cardId);
                        if (card.isCash) {
                          cardNameStr = " • ${context.t('card_cash')} - ${card.name}";
                        } else {
                          final bName = card.bankName == 'Efectivo'
                              ? context.t('card_cash')
                              : (card.bankName ?? context.t('card_default_name'));
                          final l4 = card.cardNumber.length >= 4
                              ? card.cardNumber.substring(card.cardNumber.length - 4)
                              : '****';
                          cardNameStr = " • $bName $l4";
                        }
                      } catch (_) {}

                      Color iconColor = Colors.grey;
                      Color bgColor = Colors.grey.withAlpha(25);
                      IconData icon = Icons.help_outline;

                      try {
                        final cat = provider.categories.firstWhere(
                          (c) => c.id == tx.categoryId,
                          orElse: () => Category(
                            id: 'unknown',
                            name: 'Unknown',
                            iconCode: 0xe8fd,
                            colorValue: 0xFF9E9E9E,
                          ),
                        );
                        iconColor = Color(cat.colorValue);
                        bgColor = iconColor.withAlpha(25);
                        icon = IconConstants.getCategoryIcon(cat.iconCode);
                      } catch (_) {}

                      final amount =
                          '${isExpense ? '-' : '+'}${tx.amount.abs().toFormattedString(2)}';

                      return GestureDetector(
                        onLongPress: () => _showOptionsMenu(context, provider, tx),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withAlpha(12),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                height: 48,
                                width: 48,
                                decoration: BoxDecoration(
                                  color: bgColor,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(icon, color: iconColor),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: GoogleFonts.outfit(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      "${tx.date.toString().substring(0, 10)}$cardNameStr",
                                      style: GoogleFonts.outfit(
                                        color: Theme.of(context).textTheme.bodySmall?.color,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '\$$amount',
                                    style: GoogleFonts.outfit(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: isExpense ? Colors.red : Colors.green,
                                    ),
                                  ),
                                  Icon(
                                    Icons.more_horiz,
                                    size: 14,
                                    color: Colors.grey.shade400,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? null
              : Border.all(color: Colors.grey.withAlpha(50)),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).textTheme.bodyMedium?.color,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }
}
