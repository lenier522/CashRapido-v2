import '../services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../screens/add_category_screen.dart';
import '../utils/icon_constants.dart';

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
      // Close modal first, then show error
      Navigator.pop(context);
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
          // Close modal first, then show error
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(context.t('card_locked'))));
          return;
        }

        // Check Insufficient Funds (Only for Expenses, and only when adding new transactions)
        if (_isExpense &&
            widget.transactionToEdit == null &&
            amount > card.balance) {
          // Close modal first, then show error
          Navigator.pop(context);
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
              // Close modal first, then show error
              Navigator.pop(context);
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

      // Check Budget Alerts
      if (amount < 0) {
        final category = provider.categories.firstWhere(
          (c) => c.id == _selectedCategoryId,
          orElse: () => provider.categories.first,
        );
        if (category.monthlyBudget != null && category.monthlyBudget! > 0) {
          final spentNow = provider.getSpentForCategoryThisMonth(category.id);
          final ratio = spentNow / category.monthlyBudget!;
          
          if (ratio >= 1.0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.t('budget_alert_100')} ${category.name}'),
                backgroundColor: Colors.red,
              ),
            );
          } else if (ratio >= 0.8) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${context.t('budget_alert_80')} ${category.name}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

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
          // Category Selection (Modern Grid)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('category_label'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_selectedCategoryId.isNotEmpty && categories.isNotEmpty)
                Builder(
                  builder: (_) {
                    final selected = categories.firstWhere(
                      (cat) => cat.id == _selectedCategoryId,
                      orElse: () => categories.first,
                    );
                    String selectedName = selected.name;
                    if (selected.id.startsWith('cat_')) {
                      selectedName = context.t(selected.id);
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Color(selected.colorValue).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        selectedName,
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Theme.of(context).scaffoldBackgroundColor.withValues(
                  alpha: 0.5,
                ),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
              ),
              child: GridView.builder(
              itemCount: categories.length + 1,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.65,
              ),
              itemBuilder: (context, index) {
                if (index == categories.length) {
                  return _buildCategorySelector(
                    label: context.t('create'),
                    icon: Icons.add,
                    color: Colors.grey,
                    isSelected: false,
                    onTap: () {
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
                    isLocked: !provider.canCreateCategory,
                    isAddButton: true,
                  );
                }

                final cat = categories[index];
                String displayName = cat.name;
                if (cat.id.startsWith('cat_')) {
                  displayName = context.t(cat.id);
                }
                return _buildCategorySelector(
                  label: displayName,
                  icon: IconConstants.getCategoryIcon(cat.iconCode),
                  color: Color(cat.colorValue),
                  isSelected: _selectedCategoryId == cat.id,
                  onTap: () => setState(() => _selectedCategoryId = cat.id),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 20),
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
            height: MediaQuery.of(context).viewInsets.bottom > 0
                ? MediaQuery.of(context).viewInsets.bottom
                : MediaQuery.of(context).padding.bottom,
          ), // Keyboard spacer & Safe Area
        ],
      ),
    );
  }

  Widget _buildCategorySelector({
    required String label,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
    bool isLocked = false,
    bool isAddButton = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: isSelected
              ? color.withValues(alpha: 0.18)
              : Theme.of(context).cardColor,
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.8)
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 1.4 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.22),
                blurRadius: 12,
                offset: const Offset(0, 5),
              ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: isAddButton
                        ? Colors.grey.withValues(alpha: 0.15)
                        : color.withValues(alpha: isSelected ? 0.95 : 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 20,
                    color: isAddButton
                        ? Theme.of(context).hintColor
                        : (isSelected ? Colors.white : color),
                  ),
                ),
                if (isSelected)
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: Icon(
                      Icons.check_circle,
                      size: 14,
                      color: Colors.green,
                    ),
                  ),
                if (isLocked)
                  const Positioned(
                    right: -2,
                    bottom: -2,
                    child: Icon(Icons.lock, size: 12, color: Colors.amber),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.outfit(
                fontSize: 11.5,
                height: 1.15,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).textTheme.bodySmall?.color,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
