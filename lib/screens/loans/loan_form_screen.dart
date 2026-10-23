import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/borrower.dart';
import '../../models/loan.dart';
import '../../providers/app_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_selector_field.dart';

/// Alta y edición de un préstamo.
///
/// La pantalla agrupa los campos existentes en bloques funcionales
/// (prestatario, capital, condiciones, plan de pagos y opciones adicionales)
/// sin alterar ninguna regla de negocio. Todos los cálculos del resumen
/// provienen del [LoanProvider]; aquí no se recalcula ninguna fórmula.
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

  /// Evita que el préstamo se cree o actualice varias veces por pulsaciones
  /// repetidas del botón principal.
  bool _isSubmitting = false;

  bool get _isEditing => widget.loan != null;

  static const List<_FormOption> _interestTypes = [
    _FormOption('simple', 'interest_simple', Icons.percent_rounded),
    _FormOption('compound', 'interest_compound', Icons.trending_up_rounded),
    _FormOption('fixed', 'interest_fixed', Icons.attach_money_rounded),
  ];

  static const List<_FormOption> _frequencies = [
    _FormOption('daily', 'freq_daily', Icons.today_rounded),
    _FormOption('weekly', 'freq_weekly', Icons.view_week_rounded),
    _FormOption('biweekly', 'freq_biweekly', Icons.date_range_rounded),
    _FormOption('monthly', 'freq_monthly', Icons.calendar_month_rounded),
    _FormOption('single', 'freq_single', Icons.looks_one_rounded),
  ];

  @override
  void initState() {
    super.initState();
    final loan = widget.loan;

    _nameController = TextEditingController(text: loan?.borrowerName ?? '');
    _amountController = TextEditingController(
      text: loan?.amount != null ? loan!.amount.toString() : '',
    );
    _rateController = TextEditingController(
      text: loan?.interestRate != null ? loan!.interestRate.toString() : '10.0',
    );
    _durationController = TextEditingController(
      text: loan?.durationValue != null ? loan!.durationValue.toString() : '1',
    );
    _notesController = TextEditingController(text: loan?.notes ?? '');

    // Add listeners so the live calculation preview updates in real time
    _amountController.addListener(_onFieldChanged);
    _rateController.addListener(_onFieldChanged);
    _durationController.addListener(_onFieldChanged);

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
        final loanProvider = Provider.of<LoanProvider>(context, listen: false);
        setState(() {
          _selectedCurrency = appProvider.mainCurrency;
          if (appProvider.cards.isNotEmpty) {
            _selectedCardId = appProvider.cards.first.id;
          }
          final duration = int.tryParse(_durationController.text.trim()) ?? 1;
          _dueDate = loanProvider.calculateDueDateFromFrequency(
            startDate: _startDate,
            frequency: _frequency,
            durationValue: duration,
          );
        });
      });
    }
  }

  void _onFieldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _amountController.removeListener(_onFieldChanged);
    _rateController.removeListener(_onFieldChanged);
    _durationController.removeListener(_onFieldChanged);
    _nameController.dispose();
    _amountController.dispose();
    _rateController.dispose();
    _durationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────
  //   HELPERS
  // ──────────────────────────────────────────
  String _currencySymbol(AppProvider provider, String code) {
    for (final currency in provider.availableCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ──────────────────────────────────────────
  //   PICKERS
  // ──────────────────────────────────────────
  Future<void> _pickInterestType() async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('interest_type'),
        child: Column(
          children: [
            for (final option in _interestTypes)
              _SheetOption(
                leading: _SheetLeading(icon: option.icon),
                title: sheetContext.t(option.labelKey),
                selected: _interestType == option.value,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, option.value),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _interestType = selected);
  }

  Future<void> _pickFrequency(LoanProvider loanProvider) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('frequency'),
        child: Column(
          children: [
            for (final option in _frequencies)
              _SheetOption(
                leading: _SheetLeading(icon: option.icon),
                title: sheetContext.t(option.labelKey),
                selected: _frequency == option.value,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, option.value),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    setState(() {
      _frequency = selected;
      if (_frequency == 'single') {
        _durationController.text = '1';
      } else if (_dueDate.isAfter(_startDate)) {
        final newDuration = loanProvider.calculateDurationFromDates(
          startDate: _startDate,
          dueDate: _dueDate,
          frequency: _frequency,
        );
        _durationController.text = newDuration.toString();
      } else {
        final duration = int.tryParse(_durationController.text.trim()) ?? 1;
        _dueDate = loanProvider.calculateDueDateFromFrequency(
          startDate: _startDate,
          frequency: _frequency,
          durationValue: duration,
        );
      }
    });
  }

  Future<void> _pickCurrency(AppProvider appProvider) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('currency_label'),
        child: Column(
          children: [
            for (final currency in appProvider.availableCurrencies)
              _SheetOption(
                leading: _SheetLeading(
                  icon: Icons.attach_money,
                  label: currency.symbol,
                ),
                title: currency.code,
                subtitle: currency.name,
                selected: _selectedCurrency == currency.code,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, currency.code),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedCurrency = selected);
  }

  Future<void> _pickCard(AppProvider appProvider) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('select_card'),
        child: Column(
          children: [
            for (final card in appProvider.cards)
              _SheetOption(
                leading: _SheetLeading(
                  icon: card.isCash
                      ? Icons.account_balance_wallet_rounded
                      : Icons.credit_card_rounded,
                  color: Color(card.colorValue),
                ),
                title: card.isCash
                    ? card.name
                    : (card.bankName ?? sheetContext.t('card_default_name')),
                subtitle: card.currency,
                selected: _selectedCardId == card.id,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, card.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;

    final card = appProvider.cards.firstWhere(
      (c) => c.id == selected,
      orElse: () => appProvider.cards.first,
    );
    setState(() {
      _selectedCardId = card.id;
      // Conserva la moneda real de la cuenta seleccionada.
      _selectedCurrency = card.currency;
    });
  }

  String _cardLabel(AppProvider appProvider) {
    final id = _selectedCardId;
    if (id == null) return '';
    for (final card in appProvider.cards) {
      if (card.id == id) {
        final bank = card.isCash
            ? card.name
            : (card.bankName ?? context.t('card_default_name'));
        return '$bank · ${card.currency}';
      }
    }
    return '';
  }

  String _optionLabelFor(BuildContext context, String value, List<_FormOption> options) {
    for (final option in options) {
      if (option.value == value) return context.t(option.labelKey);
    }
    return value;
  }

  // ──────────────────────────────────────────
  //   DATES
  // ──────────────────────────────────────────
  Future<void> _selectStartDate() async {
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) => _buildDatePickerTheme(context, child!),
    );
    if (picked != null && mounted) {
      final duration = int.tryParse(_durationController.text.trim()) ?? 1;
      setState(() {
        _startDate = picked;
        _dueDate = loanProvider.calculateDueDateFromFrequency(
          startDate: _startDate,
          frequency: _frequency,
          durationValue: duration,
        );
      });
    }
  }

  Future<void> _selectDueDate() async {
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate.isBefore(_startDate) ? _startDate : _dueDate,
      firstDate: _startDate,
      lastDate: DateTime(2100),
      builder: (context, child) => _buildDatePickerTheme(context, child!),
    );
    if (picked != null && mounted) {
      setState(() {
        _dueDate = picked;
        final newDuration = loanProvider.calculateDurationFromDates(
          startDate: _startDate,
          dueDate: _dueDate,
          frequency: _frequency,
        );
        _durationController.text = newDuration.toString();
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
          surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          onSurface: isDark ? AppColors.textPrimaryDark : AppColors.textPrimary,
        ),
      ),
      child: child,
    );
  }

  // ──────────────────────────────────────────
  //   LIVE CALCULATION SUMMARY
  // ──────────────────────────────────────────
  Widget _buildSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final loanProvider = Provider.of<LoanProvider>(context);
    final appProvider = Provider.of<AppProvider>(context);

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    final rate = double.tryParse(_rateController.text.trim()) ?? 0.0;
    final duration = int.tryParse(_durationController.text.trim()) ?? 1;

    final totalRepayment = loanProvider.calculateTotalWithInterest(
      amount,
      rate,
      _interestType,
      duration,
    );
    final profit = (totalRepayment - amount).clamp(0.0, double.infinity);
    final quotaAmount = duration > 0 ? totalRepayment / duration : totalRepayment;
    final symbol = _currencySymbol(appProvider, _selectedCurrency);

    final freqLabel = _optionLabelFor(context, _frequency, _frequencies);

    final Color primaryText = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.28)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calculate_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.t('loan_summary_plan'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('loan_total_repayment'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: secondaryText,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$symbol ${totalRepayment.toFormattedString(2)} $_selectedCurrency',
                        maxLines: 1,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: primaryText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _frequency == 'single'
                          ? context.t('loan_single_payment')
                          : context.t('loan_estimated_installment'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: secondaryText,
                      ),
                      textAlign: TextAlign.end,
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '$symbol ${quotaAmount.toFormattedString(2)}',
                        maxLines: 1,
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.surfaceDark2
                  : AppColors.surfaceVariantLight,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _frequency == 'single'
                        ? context.t('loan_summary_single').replaceAll(
                            '{date}',
                            _formatDate(_dueDate),
                          )
                        : context.t('loan_summary_multi')
                            .replaceAll('{count}', '$duration')
                            .replaceAll('{freqLabel}', freqLabel)
                            .replaceAll('{date}', _formatDate(_dueDate)),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  context.t('loan_summary_interest').replaceAll(
                    '{profit}',
                    '$symbol${profit.toFormattedString(2)}',
                  ),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.income,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   SUBMIT
  // ──────────────────────────────────────────
  Future<void> _submitForm() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final savedMessage = context.t('loan_saved_msg');

    final name = _nameController.text.trim();
    final amount = double.parse(_amountController.text.trim());
    final interestRate = double.parse(_rateController.text.trim());
    final duration = int.parse(_durationController.text.trim());
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    if (_isEditing) {
      final oldLoan = widget.loan!;
      final oldTotalWithInterest = loanProvider.calculateTotalWithInterest(
        oldLoan.amount,
        oldLoan.interestRate,
        oldLoan.interestType,
        oldLoan.durationValue,
      );
      final paidAmount = (oldTotalWithInterest - oldLoan.remainingAmount).clamp(
        0.0,
        double.infinity,
      );

      final totalNewWithInterest = loanProvider.calculateTotalWithInterest(
        amount,
        interestRate,
        _interestType,
        duration,
      );
      double newRemaining = (totalNewWithInterest - paidAmount).clamp(
        0.0,
        double.infinity,
      );

      // Regenerate schedule with new parameters and allocate already paid amount
      final updatedInstallments = loanProvider.generateOrUpdateSchedule(
        principal: amount,
        rate: interestRate,
        interestType: _interestType,
        frequency: _frequency,
        durationValue: duration,
        startDate: _startDate,
        explicitDueDate: _dueDate,
        paidAmountTotal: paidAmount,
      );

      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
      final normalizedDue = DateTime(_dueDate.year, _dueDate.month, _dueDate.day);

      final updated = oldLoan.copyWith(
        borrowerName: name,
        // Conserva el prestatario recién seleccionado en el autocompletado.
        // Si no se seleccionó ninguno, copyWith mantiene el vínculo previo.
        borrowerId: _selectedBorrowerId,
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
            : (today.isAfter(normalizedDue) ? 'overdue' : 'active'),
        currency: _selectedCurrency,
        installments: updatedInstallments,
      );

      await loanProvider.editLoan(updated);
    } else {
      await loanProvider.createLoan(
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

    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(savedMessage)));
    navigator.pop();
  }

  // ──────────────────────────────────────────
  //   BUILD
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final appProvider = context.watch<AppProvider>();
    final loanProvider = context.watch<LoanProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? context.t('edit_loan') : context.t('new_loan')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              // ---- Prestatario ----
              _SectionHeader(
                icon: Icons.person_outline_rounded,
                title: context.t('borrower_basic_info'),
              ),
              const SizedBox(height: AppSpacing.md),
              _buildBorrowerField(context, loanProvider),
              const SizedBox(height: AppSpacing.xl),

              // ---- Capital: importe + moneda ----
              _SectionHeader(
                icon: Icons.savings_outlined,
                title: context.t('loan_principal_loaned'),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool wide = constraints.maxWidth >= 340;
                  final Widget amountField = CashInput(
                    controller: _amountController,
                    label: context.t('amount'),
                    hint: '0.00',
                    prefix: const Icon(Icons.attach_money_rounded),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return context.t('complete_data_error');
                      }
                      final parsed = double.tryParse(value);
                      if (parsed == null || parsed <= 0) {
                        return context.t('complete_data_error');
                      }
                      return null;
                    },
                  );

                  final Widget currencyField = CashSelectorField(
                    label: context.t('currency_label'),
                    value: _selectedCurrency,
                    icon: Icons.attach_money,
                    trailing: _currencySymbol(appProvider, _selectedCurrency),
                    onTap: _isEditing ? null : () => _pickCurrency(appProvider),
                    showChevron: !_isEditing,
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: amountField),
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(width: 138, child: currencyField),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      amountField,
                      const SizedBox(height: AppSpacing.md),
                      currencyField,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.xl),

              // ---- Condiciones ----
              _SectionHeader(
                icon: Icons.tune_rounded,
                title: context.t('loan_conditions'),
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool wide = constraints.maxWidth >= 340;
                  final Widget rateField = CashInput(
                    controller: _rateController,
                    label: context.t('interest_rate'),
                    prefix: const Icon(Icons.percent_rounded),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
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
                  );

                  final Widget typeField = CashSelectorField(
                    label: context.t('interest_type'),
                    value: _optionLabelFor(context, _interestType, _interestTypes),
                    icon: Icons.percent_rounded,
                    onTap: _pickInterestType,
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: rateField),
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(width: 150, child: typeField),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      rateField,
                      const SizedBox(height: AppSpacing.md),
                      typeField,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  final bool wide = constraints.maxWidth >= 340;
                  final Widget frequencyField = CashSelectorField(
                    label: context.t('frequency'),
                    value: _optionLabelFor(context, _frequency, _frequencies),
                    icon: Icons.repeat_rounded,
                    onTap: () => _pickFrequency(loanProvider),
                  );

                  final Widget durationField = CashInput(
                    controller: _durationController,
                    label: context.t('loan_terms'),
                    prefix: const Icon(Icons.onetwothree_rounded),
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    enabled: _frequency != 'single',
                    onChanged: (val) {
                      final parsed = int.tryParse(val.trim());
                      if (parsed != null && parsed > 0) {
                        setState(() {
                          _dueDate = loanProvider.calculateDueDateFromFrequency(
                            startDate: _startDate,
                            frequency: _frequency,
                            durationValue: parsed,
                          );
                        });
                      }
                    },
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
                  );

                  if (wide) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: frequencyField),
                        const SizedBox(width: AppSpacing.md),
                        SizedBox(width: 150, child: durationField),
                      ],
                    );
                  }
                  return Column(
                    children: [
                      frequencyField,
                      const SizedBox(height: AppSpacing.md),
                      durationField,
                    ],
                  );
                },
              ),
              const SizedBox(height: AppSpacing.md),

              // ---- Fechas ----
              CashCard(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Column(
                  children: [
                    CashSelectorField(
                      label: context.t('start_date'),
                      value: _formatDate(_startDate),
                      icon: Icons.calendar_today_rounded,
                      showChevron: false,
                      onTap: _selectStartDate,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    CashSelectorField(
                      label: context.t('due_date'),
                      value: _formatDate(_dueDate),
                      icon: Icons.event_available_rounded,
                      accent: AppColors.warning,
                      showChevron: false,
                      onTap: _selectDueDate,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ---- Plan de pagos ----
              _buildSummaryCard(context),
              const SizedBox(height: AppSpacing.xl),

              // ---- Financiamiento (sólo al crear) ----
              if (!_isEditing && appProvider.cards.isNotEmpty) ...[
                _SectionHeader(
                  icon: Icons.account_balance_wallet_outlined,
                  title: context.t('business_funding_section'),
                ),
                const SizedBox(height: AppSpacing.sm),
                CashCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.xs,
                  ),
                  child: Column(
                    children: [
                      Material(
                        type: MaterialType.transparency,
                        child: SwitchListTile(
                          value: _deductFromCard,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            context.t('disburse_check'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onChanged: (val) {
                            setState(() => _deductFromCard = val);
                          },
                        ),
                      ),
                      if (_deductFromCard) ...[
                        Padding(
                          padding: const EdgeInsets.only(
                            bottom: AppSpacing.md,
                            top: AppSpacing.xs,
                          ),
                          child: CashSelectorField(
                            label: context.t('select_card'),
                            value: _cardLabel(appProvider),
                            placeholder: context.t('form_select_account'),
                            icon: Icons.credit_card_rounded,
                            onTap: () => _pickCard(appProvider),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],

              // ---- Alertas ----
              _SectionHeader(
                icon: Icons.notifications_active_outlined,
                title: context.t('loan_due_alerts'),
              ),
              const SizedBox(height: AppSpacing.sm),
              CashCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                child: Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    value: _isNotificationsEnabled,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.t('reminders_enable'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: isDark
                            ? AppColors.textPrimaryDark
                            : AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: (val) {
                      setState(() => _isNotificationsEnabled = val);
                    },
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              // ---- Notas ----
              _SectionHeader(
                icon: Icons.edit_note_rounded,
                title: context.t('loan_notes'),
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _notesController,
                label: context.t('form_note_optional'),
                prefix: const Icon(Icons.edit_note_rounded),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: AppSpacing.xxl),

              // ---- Guardar ----
              CashButton(
                label: context.t(
                  _isEditing ? 'borrower_save_changes' : 'save',
                ),
                icon: const Icon(Icons.check_rounded, size: 20),
                loading: _isSubmitting,
                onPressed: _submitForm,
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBorrowerField(
    BuildContext context,
    LoanProvider loanProvider,
  ) {
    final borrowers = loanProvider.borrowers;
    return Autocomplete<Borrower>(
      initialValue: TextEditingValue(text: _nameController.text),
      optionsBuilder: (TextEditingValue textEditingValue) {
        final query = textEditingValue.text.toLowerCase().trim();
        if (query.isEmpty) return const Iterable<Borrower>.empty();
        return borrowers.where(
          (b) =>
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
      fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
        // Sync external controller with autocomplete internal controller
        if (controller.text != _nameController.text &&
            _nameController.text.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (controller.text != _nameController.text) {
              controller.text = _nameController.text;
            }
          });
        }
        return CashInput(
          controller: controller,
          focusNode: focusNode,
          label: context.t('borrower_name'),
          prefix: const Icon(Icons.person_outline_rounded),
          suffix: _selectedBorrowerId != null
              ? const Icon(Icons.link_rounded, color: AppColors.primary)
              : null,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          onSubmitted: (_) => onFieldSubmitted(),
          onChanged: (val) {
            _nameController.text = val;
            // Si el usuario escribe manualmente limpiamos el vínculo
            if (_selectedBorrowerId != null) {
              final matched = borrowers.any((b) => b.fullName == val);
              if (!matched) setState(() => _selectedBorrowerId = null);
            }
          },
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return context.t('enter_name_error');
            }
            return null;
          },
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: AppRadius.radiusLg,
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 240),
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final b = options.elementAt(index);
                  return InkWell(
                    borderRadius: AppRadius.radiusMd,
                    onTap: () => onSelected(b),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                        vertical: AppSpacing.md,
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primary.withValues(
                              alpha: isDark ? 0.24 : 0.12,
                            ),
                            child: Text(
                              b.name.isNotEmpty
                                  ? b.name[0].toUpperCase()
                                  : '?',
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  b.fullName,
                                  style: Theme.of(context).textTheme.titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                if (b.phone.isNotEmpty)
                                  Text(
                                    b.phone,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: isDark
                                              ? AppColors.textSecondaryDark
                                              : AppColors.textSecondary,
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
  }
}

// ---------------------------------------------------------------------------
// WIDGETS AUXILIARES
// ---------------------------------------------------------------------------

class _FormOption {
  final String value;
  final String labelKey;
  final IconData icon;

  const _FormOption(this.value, this.labelKey, this.icon);
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _SheetLeading extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final String? label;

  const _SheetLeading({required this.icon, this.color, this.label});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent =
        color ??
        (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: AppRadius.radiusMd,
      ),
      alignment: Alignment.center,
      child: label != null
          ? Text(
              label!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w700,
              ),
            )
          : Icon(icon, size: 20, color: accent),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SheetOption({
    required this.leading,
    required this.title,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CashCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        border: selected
            ? Border.all(color: accent.withValues(alpha: 0.8), width: 1.4)
            : null,
        child: Row(
          children: [
            leading,
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent, size: 20)
            else
              Icon(Icons.chevron_right, size: 20, color: secondary),
          ],
        ),
      ),
    );
  }
}
