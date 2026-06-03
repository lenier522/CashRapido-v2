import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan.dart';
import '../../models/borrower.dart';
import '../../services/localization_service.dart';

class LoanFormScreen extends StatefulWidget {
  final Loan? loan; // Null if creating, non-null if editing
  const LoanFormScreen({super.key, this.loan});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _rateController;
  late TextEditingController _durationController;
  late TextEditingController _notesController;

  // Selected values
  String _interestType = 'simple';
  String _frequency = 'monthly';
  DateTime _startDate = DateTime.now();
  DateTime _dueDate = DateTime.now().add(const Duration(days: 30));
  bool _isNotificationsEnabled = true;
  String? _selectedBorrowerId;
  
  // Wallet integration
  bool _deductFromCard = false;
  String? _selectedCardId;
  String _selectedCurrency = 'CUP';

  bool get _isEditing => widget.loan != null;

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;

    _nameController = TextEditingController(text: loan?.borrowerName ?? '');
    _amountController = TextEditingController(text: loan?.amount != null ? loan!.amount.toString() : '');
    _rateController = TextEditingController(text: loan?.interestRate != null ? loan!.interestRate.toString() : '10.0');
    _durationController = TextEditingController(text: loan?.durationValue != null ? loan!.durationValue.toString() : '1');
    _notesController = TextEditingController(text: loan?.notes ?? '');

    if (loan != null) {
      _interestType = loan.interestType;
      _frequency = loan.frequency;
      _startDate = loan.startDate;
      _dueDate = loan.dueDate;
      _isNotificationsEnabled = loan.isNotificationsEnabled;
      _selectedCardId = loan.cardId;
      _selectedCurrency = loan.currency;
      _selectedBorrowerId = loan.borrowerId;
    } else {
      // Default currency from app main settings
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final appProvider = Provider.of<AppProvider>(context, listen: false);
        setState(() {
          _selectedCurrency = appProvider.mainCurrency;
          if (appProvider.cards.isNotEmpty) {
            _selectedCardId = appProvider.cards.first.id;
          }
        });
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => _buildDatePickerTheme(context, child!),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        // Adjust due date if simple default frequency
        if (_dueDate.isBefore(_startDate)) {
          _dueDate = _startDate.add(const Duration(days: 30));
        }
      });
    }
  }

  Future<void> _selectDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      builder: (context, child) => _buildDatePickerTheme(context, child!),
    );
    if (picked != null) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Widget _buildDatePickerTheme(BuildContext context, Widget child) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
          primary: Theme.of(context).colorScheme.primary,
          onPrimary: Colors.white,
          surface: isDark ? const Color(0xFF1E1E2C) : Colors.white,
          onSurface: isDark ? Colors.white : Colors.black87,
        ),
      ),
      child: child,
    );
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);

    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final interestRate = double.parse(_rateController.text.trim());
    final duration = int.parse(_durationController.text.trim());
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    if (_isEditing) {
      final oldLoan = widget.loan!;
      
      // Calculate new remaining based on total repaid and edits
      final totalNewWithInterest = loanProvider.calculateTotalWithInterest(amount, interestRate, _interestType, duration);
      final paidAmount = loanProvider.calculateTotalWithInterest(oldLoan.amount, oldLoan.interestRate, oldLoan.interestType, oldLoan.durationValue) - oldLoan.remainingAmount;
      double newRemaining = totalNewWithInterest - paidAmount;
      if (newRemaining < 0) newRemaining = 0;

      final updated = oldLoan.copyWith(
        borrowerName: name,
        amount: amount,
        interestRate: interestRate,
        interestType: _interestType,
        frequency: _frequency,
        durationValue: duration,
        startDate: _startDate,
        dueDate: _dueDate,
        isNotificationsEnabled: _isNotificationsEnabled,
        notes: notes,
        remainingAmount: newRemaining,
        status: newRemaining == 0 
            ? 'paid' 
            : (DateTime.now().isAfter(_dueDate) ? 'overdue' : 'active'),
        currency: _selectedCurrency,
      );

      loanProvider.editLoan(updated);
    } else {
      loanProvider.createLoan(
        borrowerName: name,
        amount: amount,
        interestRate: interestRate,
        interestType: _interestType,
        frequency: _frequency,
        durationValue: duration,
        startDate: _startDate,
        dueDate: _dueDate,
        isNotificationsEnabled: _isNotificationsEnabled,
        notes: notes,
        cardId: _selectedCardId,
        currency: _selectedCurrency,
        appProvider: appProvider,
        deductFromCard: _deductFromCard,
        borrowerId: _selectedBorrowerId,
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('loan_saved_msg'))),
    );

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isEditing ? context.t('edit_loan') : context.t('new_loan'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Borrower Name con autocompletado del directorio
                Consumer<LoanProvider>(
                  builder: (context, loanProvider, _) {
                    final borrowers = loanProvider.borrowers;
                    return Autocomplete<Borrower>(
                      initialValue: TextEditingValue(text: _nameController.text),
                      optionsBuilder: (TextEditingValue textEditingValue) {
                        final query = textEditingValue.text.toLowerCase().trim();
                        if (query.isEmpty) return const Iterable<Borrower>.empty();
                        return borrowers.where((b) =>
                          b.fullName.toLowerCase().contains(query) ||
                          b.phone.toLowerCase().contains(query),
                        );
                      },
                      displayStringForOption: (b) => b.fullName,
                      onSelected: (Borrower b) {
                        setState(() {
                          _nameController.text = b.fullName;
                          _selectedBorrowerId = b.id;
                        });
                      },
                      fieldViewBuilder: (context, controller, focusNode, onEditingComplete) {
                        // Sync external controller with autocomplete internal controller
                        if (controller.text != _nameController.text && _nameController.text.isNotEmpty) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (controller.text != _nameController.text) {
                              controller.text = _nameController.text;
                            }
                          });
                        }
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          onEditingComplete: onEditingComplete,
                          onChanged: (val) {
                            _nameController.text = val;
                            // Si el usuario escribe manualmente limpiamos el vínculo
                            if (_selectedBorrowerId != null) {
                              final matched = borrowers.any((b) => b.fullName == val);
                              if (!matched) setState(() => _selectedBorrowerId = null);
                            }
                          },
                          style: GoogleFonts.outfit(),
                          decoration: InputDecoration(
                            labelText: context.t('borrower_name'),
                            labelStyle: GoogleFonts.outfit(),
                            prefixIcon: const Icon(Icons.person_outline_rounded),
                            suffixIcon: _selectedBorrowerId != null
                                ? const Icon(Icons.link_rounded, color: Colors.green)
                                : null,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.t('enter_name_error');
                            }
                            return null;
                          },
                        );
                      },
                      optionsViewBuilder: (context, onSelected, options) {
                        return Align(
                          alignment: Alignment.topLeft,
                          child: Material(
                            elevation: 8,
                            borderRadius: BorderRadius.circular(16),
                            color: Theme.of(context).brightness == Brightness.dark
                                ? const Color(0xFF1E1E2C)
                                : Colors.white,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 220),
                              child: ListView.builder(
                                padding: EdgeInsets.zero,
                                shrinkWrap: true,
                                itemCount: options.length,
                                itemBuilder: (context, index) {
                                  final b = options.elementAt(index);
                                  return InkWell(
                                    borderRadius: BorderRadius.circular(16),
                                    onTap: () => onSelected(b),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                                            child: Text(
                                              b.name.isNotEmpty ? b.name[0].toUpperCase() : '?',
                                              style: GoogleFonts.outfit(
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context).colorScheme.primary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  b.fullName,
                                                  style: GoogleFonts.outfit(fontWeight: FontWeight.w600),
                                                ),
                                                if (b.phone.isNotEmpty)
                                                  Text(
                                                    b.phone,
                                                    style: GoogleFonts.outfit(
                                                      fontSize: 12,
                                                      color: Theme.of(context).hintColor,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Amount & Currency Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: TextFormField(
                        controller: _amountController,
                        style: GoogleFonts.outfit(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.t('amount'),
                          labelStyle: GoogleFonts.outfit(),
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.t('enter_name_error'); // generic error
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed <= 0) {
                            return context.t('complete_data_error');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String>(
                        initialValue: _selectedCurrency,
                        decoration: InputDecoration(
                          labelText: context.t('currency_label'),
                          labelStyle: GoogleFonts.outfit(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: appProvider.availableCurrencies.map((c) {
                          return DropdownMenuItem<String>(
                            value: c.code,
                            child: Text(c.code, style: GoogleFonts.outfit()),
                          );
                        }).toList(),
                        onChanged: _isEditing ? null : (val) {
                          if (val != null) {
                            setState(() {
                              _selectedCurrency = val;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Interest Rate & Interest Type Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _rateController,
                        style: GoogleFonts.outfit(),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: context.t('interest_rate'),
                          labelStyle: GoogleFonts.outfit(),
                          prefixIcon: const Icon(Icons.percent_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.t('complete_data_error');
                          }
                          final parsed = double.tryParse(value);
                          if (parsed == null || parsed < 0) {
                            return context.t('complete_data_error');
                          }
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _interestType,
                        decoration: InputDecoration(
                          labelText: context.t('interest_type'),
                          labelStyle: GoogleFonts.outfit(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: [
                          DropdownMenuItem(value: 'simple', child: Text(context.t('interest_simple'), style: GoogleFonts.outfit())),
                          DropdownMenuItem(value: 'compound', child: Text(context.t('interest_compound'), style: GoogleFonts.outfit())),
                          DropdownMenuItem(value: 'fixed', child: Text(context.t('interest_fixed'), style: GoogleFonts.outfit())),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _interestType = val;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Frequency & Duration Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _frequency,
                        decoration: InputDecoration(
                          labelText: context.t('frequency'),
                          labelStyle: GoogleFonts.outfit(),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        items: [
                          DropdownMenuItem(value: 'daily', child: Text(context.t('freq_daily'), style: GoogleFonts.outfit())),
                          DropdownMenuItem(value: 'weekly', child: Text(context.t('freq_weekly'), style: GoogleFonts.outfit())),
                          DropdownMenuItem(value: 'monthly', child: Text(context.t('freq_monthly'), style: GoogleFonts.outfit())),
                          DropdownMenuItem(value: 'single', child: Text(context.t('freq_single'), style: GoogleFonts.outfit())),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _frequency = val;
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _durationController,
                        style: GoogleFonts.outfit(),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: context.t('loan_terms'),
                          labelStyle: GoogleFonts.outfit(),
                          prefixIcon: const Icon(Icons.onetwothree_rounded),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return context.t('complete_data_error');
                          }
                          final parsed = int.tryParse(value);
                          if (parsed == null || parsed <= 0) {
                            return context.t('complete_data_error');
                          }
                          return null;
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Dates Selection Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.t('start_date'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: _selectStartDate,
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: Text(
                              '${_startDate.day}/${_startDate.month}/${_startDate.year}',
                              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(context.t('due_date'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                          TextButton.icon(
                            onPressed: _selectDueDate,
                            icon: const Icon(Icons.calendar_today_rounded, size: 16),
                            label: Text(
                              '${_dueDate.day}/${_dueDate.month}/${_dueDate.year}',
                              style: GoogleFonts.outfit(color: Colors.red, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Wallet Integration Options (Only during creation)
                if (!_isEditing && appProvider.cards.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[150],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.15)),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _deductFromCard,
                          title: Text(context.t('disburse_check'), style: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.w600)),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setState(() {
                              _deductFromCard = val == true;
                            });
                          },
                        ),
                        if (_deductFromCard) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCardId,
                            decoration: InputDecoration(
                              labelText: context.t('select_card'),
                              labelStyle: GoogleFonts.outfit(),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            items: appProvider.cards.map((c) {
                              return DropdownMenuItem<String>(
                                value: c.id,
                                child: Text('${c.isCash ? context.t('card_cash') : (c.bankName ?? 'Tarjeta')} - ${c.currency}', style: GoogleFonts.outfit(fontSize: 13)),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                final selected = appProvider.cards.firstWhere((c) => c.id == val);
                                setState(() {
                                  _selectedCardId = val;
                                  _selectedCurrency = selected.currency; // match card currency
                                });
                              }
                            },
                          ),
                        ]
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Reminders Toggle
                SwitchListTile(
                  title: Text(context.t('reminders_enable'), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 14)),
                  value: _isNotificationsEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) {
                    setState(() {
                      _isNotificationsEnabled = val;
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Notes Description
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: GoogleFonts.outfit(),
                  decoration: InputDecoration(
                    labelText: context.t('description_hint'),
                    labelStyle: GoogleFonts.outfit(),
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(height: 40),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      context.t('confirm').toUpperCase(),
                      style: GoogleFonts.outfit(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
