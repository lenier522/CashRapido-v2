import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/app_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan.dart';
import '../../services/localization_service.dart';

class LoanPaymentFormScreen extends StatefulWidget {
  final Loan loan;
  const LoanPaymentFormScreen({super.key, required this.loan});

  @override
  State<LoanPaymentFormScreen> createState() => _LoanPaymentFormScreenState();
}

class _LoanPaymentFormScreenState extends State<LoanPaymentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _amountController;
  late TextEditingController _notesController;

  DateTime _paymentDate = DateTime.now();

  // Wallet integration
  bool _depositToCard = false;
  String? _selectedCardId;

  @override
  void initState() {
    super.initState();
    // Prefill with remaining balance or typical installment if possible
    _amountController = TextEditingController(
      text: widget.loan.remainingAmount.toString(),
    );
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      if (appProvider.cards.isNotEmpty) {
        setState(() {
          _selectedCardId = appProvider.cards.first.id;
        });
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
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
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _paymentDate = picked;
      });
    }
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);

    final amount = double.parse(_amountController.text.trim());
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    loanProvider.addPayment(
      loanId: widget.loan.id,
      amount: amount,
      cardId: _selectedCardId,
      notes: notes,
      date: _paymentDate,
      appProvider: appProvider,
      depositToCard: _depositToCard,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.t('payment_registered_msg'))),
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
          context.t('register_payment'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
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
                // Info block
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t('borrower_name'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        widget.loan.borrowerName,
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        context.t('remaining_balance'),
                        style: GoogleFonts.outfit(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '\$ ${widget.loan.remainingAmount.toStringAsFixed(2)} ${widget.loan.currency}',
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Amount paid input
                TextFormField(
                  controller: _amountController,
                  style: GoogleFonts.outfit(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: context.t('payment_amount'),
                    labelStyle: GoogleFonts.outfit(),
                    prefixIcon: const Icon(Icons.price_check_rounded),
                    suffixIcon: TextButton(
                      child: Text(
                        Localizations.localeOf(context).languageCode == 'es' ? 'TODO' : 'ALL',
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      onPressed: () {
                        setState(() {
                          _amountController.text = widget.loan.remainingAmount
                              .toString();
                        });
                      },
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return context.t('complete_data_error');
                    }
                    final parsed = double.tryParse(value);
                    if (parsed == null || parsed <= 0) {
                      return context.t('complete_data_error');
                    }
                    if (parsed > widget.loan.remainingAmount) {
                      return Localizations.localeOf(context).languageCode == 'es'
                          ? 'El monto excede el saldo restante'
                          : 'Amount exceeds outstanding balance';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Date Picker Button
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[50],
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.t('payment_date'),
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _selectDate,
                        icon: const Icon(
                          Icons.calendar_today_rounded,
                          size: 16,
                        ),
                        label: Text(
                          '${_paymentDate.day}/${_paymentDate.month}/${_paymentDate.year}',
                          style: GoogleFonts.outfit(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Wallet/Account balance Integration (Deposit)
                if (appProvider.cards.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E2C) : Colors.grey[50],
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(
                          alpha: 0.15,
                        ),
                      ),
                    ),
                    child: Column(
                      children: [
                        CheckboxListTile(
                          value: _depositToCard,
                          title: Text(
                            context.t('deposit_check'),
                            style: GoogleFonts.outfit(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          controlAffinity: ListTileControlAffinity.leading,
                          contentPadding: EdgeInsets.zero,
                          onChanged: (val) {
                            setState(() {
                              _depositToCard = val == true;
                            });
                          },
                        ),
                        if (_depositToCard) ...[
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedCardId,
                            decoration: InputDecoration(
                              labelText: context.t('select_card'),
                              labelStyle: GoogleFonts.outfit(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            items: appProvider.cards
                                .where(
                                  (c) => c.currency == widget.loan.currency,
                                ) // Filter to match currency
                                .map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Text(
                                      '${c.isCash ? context.t('card_cash') : (c.bankName ?? 'Tarjeta')} (...${c.isCash ? 'CASH' : (c.cardNumber.length >= 4 ? c.cardNumber.substring(c.cardNumber.length - 4) : c.cardNumber)})',
                                      style: GoogleFonts.outfit(fontSize: 13),
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedCardId = val;
                                });
                              }
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Notes Description
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  style: GoogleFonts.outfit(),
                  decoration: InputDecoration(
                    labelText: context.t('description_hint'),
                    labelStyle: GoogleFonts.outfit(),
                    prefixIcon: const Icon(Icons.edit_note_rounded),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
