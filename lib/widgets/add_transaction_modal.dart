import '../services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../screens/add_category_screen.dart';

class AddTransactionModal extends StatefulWidget {
  final InternalTransaction? transactionToEdit;

  const AddTransactionModal({super.key, this.transactionToEdit});

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  String _selectedCategoryId = '';
  String? _selectedCardId;
  AccountCard? _selectedCard; // Added state variable
  String _selectedCurrency = 'USD';
  bool _isExpense = true; // Default to Expense

  @override
  void initState() {
    super.initState();
    // If editing, populate fields
    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!;
      _amountController.text = tx.amount.abs().toStringAsFixed(2);
      _titleController.text = tx.title;
      _selectedCategoryId = tx.categoryId;
      _selectedCardId = tx.cardId;
      _selectedCurrency = tx.currency;
      _isExpense = tx.amount < 0;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _saveTransaction() {
    final amountText = _amountController.text.replaceAll(
      RegExp(r'[^0-9.]'),
      '',
    );
    final amount = double.tryParse(amountText) ?? 0.0;

    if (amount <= 0 || _selectedCategoryId.isEmpty) {
      // Show error snackbar or simple return
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('enter_amount_category_error'))),
      );
      return;
    }

    // Determine sign based on transaction type
    final finalAmount = _isExpense ? -amount : amount;

    // Use Category Name if title is empty
    String title = _titleController.text;
    if (title.isEmpty) {
      final category = Provider.of<AppProvider>(context, listen: false)
          .categories
          .firstWhere(
            (cat) => cat.id == _selectedCategoryId,
            orElse: () => Provider.of<AppProvider>(
              context,
              listen: false,
            ).categories.first,
          );
      title = category.name;
    }

    // Validate Card Security
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (_selectedCardId != null) {
      try {
        final card = provider.cards.firstWhere((c) => c.id == _selectedCardId);

        if (card.isLocked) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.t('card_locked'))));
          return;
        }

        // Check Insufficient Funds (Only for Expenses, and only when adding new transactions)
        if (_isExpense &&
            widget.transactionToEdit == null &&
            amount > card.balance) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${context.t('insufficient_funds')} (${context.t('balance')}: ${card.balance.toStringAsFixed(2)} ${card.currency})',
              ),
            ),
          );
          return;
        }

        if (card.pin != null && card.pin!.isNotEmpty) {
          _showPinDialog(context, (pin) {
            if (pin == card.pin) {
              _executeTransaction(provider, finalAmount, title);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t('incorrect_pin'))),
              );
            }
          });
          return;
        }
      } catch (e) {
        // Card might not exist or other error
      }
    }

    _executeTransaction(provider, finalAmount, title);
  }

  void _executeTransaction(
    AppProvider provider,
    double amount,
    String title,
  ) async {
    if (widget.transactionToEdit != null) {
      // Edit mode
      try {
        await provider.editTransaction(
          widget.transactionToEdit!.id,
          newAmount: amount,
          newTitle: title,
          newCategoryId: _selectedCategoryId,
          newCurrency: _selectedCurrency,
        );
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      // Add mode
      provider.addTransaction(
        amount: amount,
        title: title,
        categoryId: _selectedCategoryId,
        currency: _selectedCurrency,
        cardId: _selectedCardId,
      );
      Navigator.pop(context);
    }
  }

  void _showPinDialog(BuildContext context, Function(String) onConfirm) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          context.t('enter_pin'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: "****"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm(controller.text);
            },
            child: Text(context.t('confirm')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fetch categories from provider
    final provider = Provider.of<AppProvider>(context);
    final categories = provider.categories;
    // Set default category if none selected and categories exist
    if (_selectedCategoryId.isEmpty && categories.isNotEmpty) {
      _selectedCategoryId = categories.first.id;
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.90,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor, // Replaced Colors.white
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.transactionToEdit != null
                    ? context.t('edit_transaction')
                    : context.t('new_transaction'),
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Transaction Type Toggle
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExpense = true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _isExpense
                            ? Colors.red.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: _isExpense
                            ? Border.all(
                                color: Colors.red.withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          context.t('type_expense'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: _isExpense
                                ? Colors.red
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isExpense = false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_isExpense
                            ? Colors.green.withValues(alpha: 0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: !_isExpense
                            ? Border.all(
                                color: Colors.green.withValues(alpha: 0.5),
                              )
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          context.t('type_income'),
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: !_isExpense
                                ? Colors.green
                                : Theme.of(context).textTheme.bodyMedium?.color,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
          // Card Selector instead of just Currency
          // Filter cards by selected currency or auto-select logic
          Consumer<AppProvider>(
            builder: (ctx, provider, _) {
              if (provider.cards.isEmpty) return const SizedBox.shrink();

              // If no card selected yet, pick first
              if (_selectedCardId == null && provider.cards.isNotEmpty) {
                _selectedCardId = provider.cards.first.id;
                _selectedCurrency = provider.cards.first.currency;
                _selectedCard =
                    provider.cards.first; // Initialize _selectedCard
              } else if (_selectedCard != null) {
                _selectedCurrency = _selectedCard!.currency;
              }

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _selectedCardId,
                    hint: Text(
                      context.t('select_card'),
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                    dropdownColor: Theme.of(context).cardColor,
                    items: provider.cards.map((card) {
                      final last4 =
                          card.cardNumber.isEmpty || card.cardNumber == 'CASH'
                          ? ''
                          : (card.cardNumber.length >= 4
                                ? '(...${card.cardNumber.substring(card.cardNumber.length - 4)})'
                                : '');

                      String displayName;
                      if (card.isCash) {
                        // User requested format: "Cash(Name)-Currency"
                        displayName =
                            "${context.t('card_cash')}(${card.name})-${card.currency}";
                      } else {
                        // Format for Bank Cards: "BankName (...1234) - USD"
                        String bankName =
                            card.bankName ?? context.t('card_default_name');
                        displayName = "$bankName $last4 - ${card.currency}";
                      }

                      return DropdownMenuItem<String>(
                        value: card.id,
                        child: Text(
                          displayName,
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(
                              context,
                            ).textTheme.bodyMedium?.color,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      final card = provider.cards.firstWhere(
                        (c) => c.id == val,
                      );
                      setState(() {
                        _selectedCardId = val;
                        _selectedCard = card;
                        _selectedCurrency = card.currency;
                      });
                    },
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 20),
          // Amount Input
          Center(
            child: Column(
              children: [
                Text(
                  '${context.t('amount')} ($_selectedCurrency)',
                  style: GoogleFonts.outfit(
                    color: Theme.of(context).hintColor,
                  ), // Replaced Colors.grey
                ),
                Container(
                  // Added Container for amount input styling
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: TextField(
                    controller: _amountController,
                    textAlign: TextAlign.center,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: _amountController.text.isEmpty
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : (_isExpense ? Colors.red : Colors.green),
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0.00',
                      hintStyle: GoogleFonts.outfit(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                TextField(
                  controller: _titleController,
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: context.t('description_hint'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          // Category Selection
          Text(
            context.t('category_label'),
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                ...categories.map((cat) {
                  String displayName = cat.name;
                  if (cat.id.startsWith('cat_')) {
                    displayName = context.t(cat.id);
                  }
                  return _buildCategorySelector(
                    displayName,
                    IconData(cat.iconCode, fontFamily: 'MaterialIcons'),
                    Color(cat.colorValue),
                    _selectedCategoryId == cat.id,
                    () => setState(() => _selectedCategoryId = cat.id),
                  );
                }),
                // Add Custom Category Button
                _buildCategorySelector(
                  context.t('create'),
                  Icons.add, // Always show Add icon
                  Colors.grey,
                  false,
                  () {
                    if (provider.canCreateCategory) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AddCategoryScreen(),
                        ),
                      );
                    } else {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Text(context.t('feature_locked_title')),
                          content: Text(context.t('feature_locked_desc')),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(context.t('close')),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  isLocked: !provider.canCreateCategory, // Pass locked state
                ),
              ],
            ),
          ),
          const Spacer(),
          // Save Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _saveTransaction,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                context.t('save_transaction'),
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).viewInsets.bottom,
          ), // Keyboard spacer
        ],
      ),
    );
  }

  Widget _buildCategorySelector(
    String label,
    IconData icon,
    Color color,
    bool isSelected,
    VoidCallback onTap, {
    bool isLocked = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        child: SizedBox(
          width: 72, // Fixed width for consistent spacing
          child: Column(
            children: [
              Stack(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isSelected ? color : Colors.grey[100],
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: color, width: 2)
                          : null,
                    ),
                    child: Icon(
                      icon,
                      color: isSelected ? Colors.white : Colors.grey,
                    ),
                  ),
                  if (isLocked)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.amber, // Warning/Lock color
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock,
                          size: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center, // Center text
                maxLines: 2, // Allow 2 lines for longer names
                overflow: TextOverflow.ellipsis, // Truncate if too long
                style: GoogleFonts.outfit(
                  fontSize: 12, // Slightly smaller font
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).disabledColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
