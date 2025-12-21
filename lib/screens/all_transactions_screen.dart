import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../services/localization_service.dart';

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
    if (tx.categoryId == 'transfer_out') {
      return context.t('transfer_sent');
    }
    if (tx.categoryId == 'recharge') {
      return context.t('recharge_success');
    }
    if (tx.categoryId == 'income_request') {
      return context.t('request_received');
    }
    if (tx.categoryId == 'general') {
      return context.t('cat_general');
    }
    // Default Categories
    if (tx.categoryId.startsWith('cat_')) {
      return context.t(tx.categoryId);
    }
    // Fallback to stored title if custom or unknown
    return tx.title;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final cards = provider.cards;

    // Filter logic
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
          // Filter Section
          if (cards.isNotEmpty)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // 'All Cards' Chip
                  _buildFilterChip(
                    label: context.t('all_cards'),
                    isSelected: _selectedCardId == null,
                    onTap: () => setState(() => _selectedCardId = null),
                  ),
                  // Individual Cards
                  ...cards.map((card) {
                    final bankName = card.bankName == 'Efectivo'
                        ? context.t('card_cash')
                        : (card.bankName ?? context.t('card_default_name'));
                    final last4 = card.cardNumber.length >= 4
                        ? card.cardNumber.substring(card.cardNumber.length - 4)
                        : '****';

                    return _buildFilterChip(
                      label: '$bankName $last4',
                      isSelected: _selectedCardId == card.id,
                      onTap: () => setState(() => _selectedCardId = card.id),
                    );
                  }),
                ],
              ),
            ),

          // Transactions List
          Expanded(
            child: transactions.isEmpty
                ? Center(
                    child: Text(
                      context.t('no_recent_transactions'),
                      style: GoogleFonts.outfit(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: transactions.length,
                    itemBuilder: (ctx, index) {
                      final tx = transactions[index];
                      final isExpense = tx.amount < 0;

                      Color iconColor = Colors.grey;
                      Color bgColor = Colors.grey.withAlpha(25);
                      IconData icon = Icons.help_outline;

                      // Resolve Icon/Color from Category
                      try {
                        final cat = provider.categories.firstWhere(
                          (c) => c.id == tx.categoryId,
                          orElse: () => Category(
                            id: 'unknown',
                            name: 'Unknown',
                            iconCode: 0xe8fd, // help_outline
                            colorValue: 0xFF9E9E9E, // Colors.grey
                          ),
                        );
                        iconColor = Color(cat.colorValue);
                        bgColor = iconColor.withAlpha(25); // ~0.1 opacity
                        icon = IconData(
                          cat.iconCode,
                          fontFamily: 'MaterialIcons',
                        );
                      } catch (e) {
                        // ignore
                      }

                      return _buildTransactionItem(
                        title: _getTransactionTitle(context, tx),
                        subtitle: tx.date.toString().substring(
                          0,
                          10,
                        ), // Simple date
                        amount:
                            '${isExpense ? '-' : '+'}\$${tx.amount.abs().toStringAsFixed(2)}',
                        bgColor: bgColor,
                        iconColor: iconColor,
                        icon: icon,
                        context: context, // Need context for theme
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

  Widget _buildTransactionItem({
    required String title,
    required String subtitle,
    required String amount,
    required Color bgColor,
    required Color iconColor,
    required IconData icon,
    required BuildContext context,
  }) {
    // Determine color based on '+' or '-' prefix in amount string
    final isPositive = amount.startsWith('+');
    final amountColor = isPositive ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(12), // approx 0.05
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
                  subtitle,
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).textTheme.bodySmall?.color,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: amountColor,
            ),
          ),
        ],
      ),
    );
  }
}
