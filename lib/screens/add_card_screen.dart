import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/card_scanner_screen.dart';
import '../screens/licenses_screen.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';

import '../widgets/design/cash_bottom_sheet.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_currency_field.dart';
import '../widgets/design/cash_icon_button.dart';
import '../widgets/design/cash_input.dart';
import '../widgets/design/cash_selector_field.dart';

/// Alta / edición de cuentas y tarjetas.
///
/// Tipos soportados: Cuenta Corriente, Ahorros, Tarjeta de Crédito, Efectivo, Otros.
/// - Ahorros: permite activar rendimiento con Tasa EA (%), frecuencia (diario/mensual/anual)
///   y próximo rendimiento (fecha y hora).
/// - Tarjeta de Crédito: límite de crédito, día de corte, día de pago, tasa de interés anual,
///   cuota de manejo mensual.
class AddCardScreen extends StatefulWidget {
  final AccountCard? cardToEdit;
  final String? initialHolder;
  final String? initialNumber;
  final String? initialExpiry;

  const AddCardScreen({
    super.key,
    this.cardToEdit,
    this.initialHolder,
    this.initialNumber,
    this.initialExpiry,
  });

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  late TextEditingController _holderController;
  late TextEditingController _numberController;
  late TextEditingController _expiryController;
  late TextEditingController _balanceController;

  // Nuevos campos
  late TextEditingController _interestRateController;
  late TextEditingController _creditLimitController;
  late TextEditingController _cutoffDayController;
  late TextEditingController _paymentDueDayController;
  late TextEditingController _annualInterestRateController;
  late TextEditingController _monthlyFeeController;

  String _selectedCurrency = 'USD';
  String _selectedBank = 'VISA';
  int _selectedColorValue = 0xFF42A5F5;
  String _accountType = AccountTypes.current;

  bool _interestEnabled = false;
  String _interestFrequency = 'monthly';
  DateTime? _nextInterestAt;

  String? _holderError;
  String? _numberError;
  String? _expiryError;
  bool _isSaving = false;

  bool get _isEditing => widget.cardToEdit != null;
  bool get _isCash => _accountType == AccountTypes.cash;
  bool get _isSavings => _accountType == AccountTypes.savings;
  bool get _isCreditCard => _accountType == AccountTypes.creditCard;
  bool get _isCurrent => _accountType == AccountTypes.current;
  bool get _isOther => _accountType == AccountTypes.other;

  @override
  void initState() {
    super.initState();
    final card = widget.cardToEdit;

    _holderController = TextEditingController(
      text: card?.name ?? widget.initialHolder ?? '',
    );
    _numberController = TextEditingController(
      text: card?.cardNumber ?? _groupCardNumber(widget.initialNumber),
    );
    _expiryController = TextEditingController(
      text: card?.expiryDate ?? widget.initialExpiry ?? '',
    );
    _balanceController = TextEditingController(
      text: card?.balance.toString() ?? '',
    );
    _interestRateController = TextEditingController(
      text: card?.interestRateEA?.toString() ?? '',
    );
    _creditLimitController = TextEditingController(
      text: card?.creditLimit?.toString() ?? '',
    );
    _cutoffDayController = TextEditingController(
      text: card?.cutoffDay?.toString() ?? '',
    );
    _paymentDueDayController = TextEditingController(
      text: card?.paymentDueDay?.toString() ?? '',
    );
    _annualInterestRateController = TextEditingController(
      text: card?.annualInterestRate?.toString() ?? '',
    );
    _monthlyFeeController = TextEditingController(
      text: card?.monthlyManagementFee?.toString() ?? '',
    );

    if (card != null) {
      _selectedCurrency = card.currency;
      _selectedBank = card.bankName ?? 'VISA';
      _accountType = AccountTypes.normalize(card.accountType);
      _selectedColorValue = card.colorValue;
      _interestEnabled = card.interestEnabled;
      _interestFrequency = card.interestFrequency ?? 'monthly';
      _nextInterestAt = card.nextInterestAt;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _validateState();
    });
  }

  @override
  void dispose() {
    _holderController.dispose();
    _numberController.dispose();
    _expiryController.dispose();
    _balanceController.dispose();
    _interestRateController.dispose();
    _creditLimitController.dispose();
    _cutoffDayController.dispose();
    _paymentDueDayController.dispose();
    _annualInterestRateController.dispose();
    _monthlyFeeController.dispose();
    super.dispose();
  }

  void _validateState() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!_isCash && !provider.availableBanks.contains(_selectedBank)) {
      setState(() {
        _selectedBank = provider.availableBanks.isNotEmpty
            ? provider.availableBanks.first
            : 'VISA';
      });
    }
  }

  final List<Color> _cardColors = [
    const Color(0xFF1A1A1A),
    const Color(0xFF42A5F5),
    const Color(0xFF7E57C2),
    const Color(0xFF66BB6A),
    const Color(0xFFFF7043),
    const Color(0xFFEC407A),
  ];

  Future<void> _saveCard() async {
    if (_isSaving) return;

    if (!_isCash && !_isCreditCard && !_isSavings) {
      final holderEmpty = _holderController.text.isEmpty;
      final numberShort = _numberController.text.length < 19;
      final expiryBad =
          _expiryController.text.length != 5 ||
          !_expiryController.text.contains('/');
      if (holderEmpty || numberShort || expiryBad) {
        setState(() {
          _holderError = holderEmpty ? context.t('enter_name_error') : null;
          _numberError = numberShort ? context.t('complete_data_error') : null;
          _expiryError = expiryBad ? context.t('invalid_date_format') : null;
        });
        return;
      }
    } else if (_isCreditCard || _isSavings) {
      final holderEmpty = _holderController.text.isEmpty;
      if (holderEmpty) {
        setState(() => _holderError = context.t('enter_name_error'));
        return;
      }
    } else if (_holderController.text.isEmpty) {
      setState(() => _holderError = context.t('enter_name_error'));
      return;
    }

    setState(() {
      _holderError = null;
      _numberError = null;
      _expiryError = null;
      _isSaving = true;
    });

    double _parse(String text) {
      final cleaned = text.replaceAll(RegExp(r'[^0-9.,]'), '').replaceAll(',', '.');
      return double.tryParse(cleaned) ?? 0.0;
    }

    int? _parseInt(String text) {
      if (text.trim().isEmpty) return null;
      final cleaned = text.trim().replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(cleaned);
    }

    final balance = _parse(_balanceController.text);
    final provider = Provider.of<AppProvider>(context, listen: false);

    final String cardNumberVal = _isCash
        ? 'CASH'
        : _isCreditCard
            ? (_numberController.text.isEmpty ? '****' : _numberController.text)
            : _isSavings
                ? 'SAVINGS'
                : _numberController.text;
    final String expiryVal = (_isCash || _isCreditCard || _isSavings) ? 'N/A' : (_expiryController.text.isEmpty ? '12/28' : _expiryController.text);
    final String bankVal = _isCash
        ? context.t('card_cash')
        : _isCreditCard
            ? (_selectedBank.isEmpty ? 'VISA' : _selectedBank)
            : _isSavings
                ? 'AHORRO'
                : _selectedBank;

    if (_isEditing) {
      final updatedCard = AccountCard(
        id: widget.cardToEdit!.id,
        name: _holderController.text.toUpperCase(),
        balance: balance,
        currency: _selectedCurrency,
        cardNumber: cardNumberVal,
        expiryDate: expiryVal,
        colorValue: _selectedColorValue,
        bankName: bankVal,
        isLocked: widget.cardToEdit!.isLocked,
        pin: widget.cardToEdit!.pin,
        spendingLimit: widget.cardToEdit!.spendingLimit,
        isCash: _isCash,
        accountType: _accountType,
        interestEnabled: _isSavings ? _interestEnabled : false,
        interestRateEA: _isSavings && _interestEnabled ? _parse(_interestRateController.text) : null,
        interestFrequency: _isSavings && _interestEnabled ? _interestFrequency : null,
        nextInterestAt: _isSavings && _interestEnabled ? _nextInterestAt : null,
        creditLimit: _isCreditCard ? _parse(_creditLimitController.text) : null,
        cutoffDay: _isCreditCard ? _parseInt(_cutoffDayController.text) : null,
        paymentDueDay: _isCreditCard ? _parseInt(_paymentDueDayController.text) : null,
        annualInterestRate: _isCreditCard ? _parse(_annualInterestRateController.text) : null,
        monthlyManagementFee: _isCreditCard ? _parse(_monthlyFeeController.text) : null,
      );
      await provider.editCard(updatedCard);
    } else {
      final newCard = AccountCard(
        id: const Uuid().v4(),
        name: _holderController.text.toUpperCase(),
        balance: balance,
        currency: _selectedCurrency,
        cardNumber: cardNumberVal,
        expiryDate: expiryVal,
        colorValue: _selectedColorValue,
        bankName: bankVal,
        isCash: _isCash,
        accountType: _accountType,
        interestEnabled: _isSavings ? _interestEnabled : false,
        interestRateEA: _isSavings && _interestEnabled ? _parse(_interestRateController.text) : null,
        interestFrequency: _isSavings && _interestEnabled ? _interestFrequency : null,
        nextInterestAt: _isSavings && _interestEnabled ? _nextInterestAt : null,
        creditLimit: _isCreditCard ? _parse(_creditLimitController.text) : null,
        cutoffDay: _isCreditCard ? _parseInt(_cutoffDayController.text) : null,
        paymentDueDay: _isCreditCard ? _parseInt(_paymentDueDayController.text) : null,
        annualInterestRate: _isCreditCard ? _parse(_annualInterestRateController.text) : null,
        monthlyManagementFee: _isCreditCard ? _parse(_monthlyFeeController.text) : null,
      );
      await provider.addCard(newCard);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: _nextInterestAt ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextInterestAt ?? now),
    );
    if (time == null || !mounted) return;
    setState(() {
      _nextInterestAt = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    final d = dt;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  // ... rest of UI methods follow same pattern as before
  Future<void> _scanCard() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CardScannerScreen()),
    );
    if (!mounted) return;
    if (result != null && result is Map) {
      setState(() {
        if (result['holder'] != null) {
          _holderController.text = result['holder'];
        }
        if (result['number'] != null) {
          _numberController.text = result['number'];
          _formatCardNumber(_numberController.text);
        }
        if (result['expiry'] != null) {
          _expiryController.text = result['expiry'];
        }
        _holderError = null;
        _numberError = null;
        _expiryError = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.t('card_scanned'))));
    }
  }

  bool get _canScan {
    if (_isEditing || _isCash || _isCreditCard) return false;
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final Currency currencyObj = provider.availableCurrencies.firstWhere(
      (c) => c.code == _selectedCurrency,
      orElse: () => Currency(code: _selectedCurrency, symbol: '\$', name: ''),
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          _isEditing ? context.t('edit_card_title') : context.t('new_card'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurface),
        actions: [
          if (_canScan) _buildScanAction(provider),
          const SizedBox(width: AppSpacing.sm),
        ],
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!_isEditing) ...[
                Text(
                  context.t('account_type'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.md),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: [
                    _buildTypeChip('Cuenta Corriente', AccountTypes.current, Icons.account_balance_outlined),
                    _buildTypeChip('Ahorros', AccountTypes.savings, Icons.savings_outlined),
                    _buildTypeChip('Tarjeta de Crédito', AccountTypes.creditCard, Icons.credit_card_rounded),
                    _buildTypeChip('Efectivo', AccountTypes.cash, Icons.payments_outlined),
                    _buildTypeChip('Otros', AccountTypes.other, Icons.category_outlined),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              _buildPreview(currencyObj),
              const SizedBox(height: AppSpacing.xl),
              if (_isCreditCard) ...[
                Text('Datos de la tarjeta de crédito', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                CashInput(controller: _holderController, label: 'Nombre de la tarjeta / Titular', hint: context.t('full_name'), prefix: const Icon(Icons.person_outline), textCapitalization: TextCapitalization.words, errorText: _holderError, onChanged: (_) { if (_holderError != null) setState(() => _holderError = null); }),
                const SizedBox(height: AppSpacing.md),
                CashInput(controller: _creditLimitController, label: 'Límite de crédito', hint: '0.00', prefix: const Icon(Icons.credit_score_outlined), keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: AppSpacing.md),
                Row(children: [
                  Expanded(child: CashInput(controller: _cutoffDayController, label: 'Día de corte', hint: 'DD', keyboardType: TextInputType.number, maxLength: 2)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: CashInput(controller: _paymentDueDayController, label: 'Día de pago', hint: 'DD', keyboardType: TextInputType.number, maxLength: 2)),
                ]),
                const SizedBox(height: AppSpacing.md),
                CashInput(controller: _annualInterestRateController, label: 'Tasa de interés anual (%)', hint: '0.00', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: AppSpacing.md),
                CashInput(controller: _monthlyFeeController, label: 'Cuota de manejo mensual', hint: '0.00', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                const SizedBox(height: AppSpacing.md),
                _buildBalanceInput(),
              ] else if (_isSavings) ...[
                Text('Cuenta de ahorro', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                CashInput(controller: _holderController, label: 'Nombre de la cuenta de ahorro', hint: 'Ej. Fondo de emergencia', prefix: const Icon(Icons.savings_outlined), textCapitalization: TextCapitalization.words, errorText: _holderError, onChanged: (_) { if (_holderError != null) setState(() => _holderError = null); }),
                const SizedBox(height: AppSpacing.lg),
                Text('Rendimiento', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.sm),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activar rendimiento'),
                  subtitle: const Text('Activar para generar rendimiento sobre esta cuenta de ahorro'),
                  value: _interestEnabled,
                  onChanged: (v) => setState(() => _interestEnabled = v),
                ),
                if (_interestEnabled) ...[
                  const SizedBox(height: AppSpacing.sm),
                  CashInput(controller: _interestRateController, label: 'Tasa EA (%)', hint: 'Ej. 12.5', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                  const SizedBox(height: AppSpacing.md),
                  CashSelectorField(label: 'Frecuencia de rendimiento', value: _freqLabel(_interestFrequency), placeholder: 'Seleccionar (diario, mensual o anual)', icon: Icons.schedule, onTap: _pickFrequency),
                  const SizedBox(height: AppSpacing.md),
                  CashSelectorField(label: 'Próximo rendimiento (fecha y hora)', value: _formatDateTime(_nextInterestAt), placeholder: 'Seleccionar fecha y hora', icon: Icons.event, onTap: _pickDateTime),
                  const SizedBox(height: AppSpacing.md),
                ],
                const SizedBox(height: AppSpacing.md),
                _buildBalanceInput(),
              ] else if (!_isCash) ...[
                Text(context.t('form_identity_section'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                CashSelectorField(label: context.t('bank_label'), value: _selectedBank, placeholder: context.t('select_bank'), icon: Icons.account_balance_outlined, onTap: () => _pickBank(provider)),
                const SizedBox(height: AppSpacing.md),
                CashInput(controller: _holderController, label: context.t('card_holder'), hint: context.t('full_name'), prefix: const Icon(Icons.person_outline), textCapitalization: TextCapitalization.words, errorText: _holderError, textInputAction: TextInputAction.next, onChanged: (_) { if (_holderError != null) setState(() => _holderError = null); }),
                const SizedBox(height: AppSpacing.md),
                CashInput(controller: _numberController, label: context.t('card_number'), hint: 'XXXX-XXXX-XXXX-XXXX', prefix: const Icon(Icons.numbers), keyboardType: TextInputType.number, maxLength: 19, errorText: _numberError, textInputAction: TextInputAction.next, onChanged: _onCardNumberChanged),
                const SizedBox(height: AppSpacing.md),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: CashInput(controller: _expiryController, label: context.t('expiration'), hint: 'MM/YY', keyboardType: TextInputType.number, maxLength: 5, errorText: _expiryError, textInputAction: TextInputAction.next, onChanged: _onExpiryChanged)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _buildBalanceInput()),
                ]),
              ] else ...[
                Text(_isOther ? 'Nombre de la cuenta' : context.t('wallet_name'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: AppSpacing.md),
                CashInput(controller: _holderController, label: _isOther ? 'Nombre de la cuenta' : context.t('wallet_name'), hint: _isOther ? 'Ej. Caja chica' : context.t('cat_name_hint'), prefix: const Icon(Icons.account_balance_wallet_outlined), textCapitalization: TextCapitalization.words, errorText: _holderError, onChanged: (_) { if (_holderError != null) setState(() => _holderError = null); }),
                const SizedBox(height: AppSpacing.md),
                _buildBalanceInput(),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(context.t('form_currency_section'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.sm),
              CashCurrencyField(code: _selectedCurrency, symbol: currencyObj.symbol, name: currencyObj.name, onTap: () => _pickCurrency(provider)),
              const SizedBox(height: AppSpacing.md),
              Text(context.t('form_color_section'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: AppSpacing.md),
              Wrap(spacing: AppSpacing.md, runSpacing: AppSpacing.md, children: [for (final color in _cardColors) _ColorSwatch(color: color, isSelected: _selectedColorValue == color.toARGB32(), onTap: () => setState(() => _selectedColorValue = color.toARGB32()))]),
              const SizedBox(height: AppSpacing.xxxl),
              CashButton(label: context.t('save_card'), icon: const Icon(Icons.check, size: 20), loading: _isSaving, onPressed: _isSaving ? null : _saveCard),
            ],
          ),
        ),
      ),
    );
  }

  String _freqLabel(String f) {
    switch (f) {
      case 'daily': return 'Diario';
      case 'monthly': return 'Mensual';
      case 'yearly': return 'Anual';
      default: return 'Mensual';
    }
  }

  Future<void> _pickFrequency() async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: 'Frecuencia de rendimiento',
        child: Column(children: [
          ListTile(title: const Text('Diario'), onTap: () => Navigator.pop(sheetContext, 'daily')),
          ListTile(title: const Text('Mensual'), onTap: () => Navigator.pop(sheetContext, 'monthly')),
          ListTile(title: const Text('Anual'), onTap: () => Navigator.pop(sheetContext, 'yearly')),
        ]),
      ),
    );
    if (selected != null) setState(() => _interestFrequency = selected);
  }

  Widget _buildTypeChip(String title, String type, IconData icon) {
    final selected = _accountType == type;
    return ChoiceChip(
      label: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(title)]),
      selected: selected,
      onSelected: (_) => setState(() => _accountType = type),
    );
  }

  Widget _buildScanAction(AppProvider provider) {
    final bool locked = !provider.canUseScanner;
    return CashIconButton(
      icon: Icons.document_scanner_outlined,
      size: 42,
      bordered: true,
      tooltip: context.t('scan_card'),
      badge: locked ? Container(padding: const EdgeInsets.all(AppSpacing.xxs), decoration: BoxDecoration(color: AppColors.warning, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5)), child: const Icon(Icons.lock, size: 8, color: AppColors.white)) : null,
      onPressed: () {
        if (provider.canUseScanner) {
          _scanCard();
        } else {
          _showScannerLocked();
        }
      },
    );
  }

  void _showScannerLocked() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(Icons.lock_outline, color: AppColors.warning),
        title: Text(context.t('feature_locked_title')),
        content: Text(context.t('feature_locked_desc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('close'))),
          CashButton(label: context.t('upgrade_btn'), fullWidth: false, height: 44, onPressed: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const LicensesScreen())); }),
        ],
      ),
    );
  }

  Widget _buildBalanceInput() {
    final Currency currencyObj = Provider.of<AppProvider>(context, listen: false).availableCurrencies.firstWhere((c) => c.code == _selectedCurrency, orElse: () => Currency(code: _selectedCurrency, symbol: '\$', name: ''));
    return CashInput(controller: _balanceController, label: _isCreditCard ? 'Saldo actual / Deuda' : context.t('initial_balance'), hint: '0.00', prefix: Text(currencyObj.symbol, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)), keyboardType: const TextInputType.numberWithOptions(decimal: true), textInputAction: TextInputAction.done);
  }

  Widget _buildPreview(Currency currencyObj) {
    final String balanceText = _balanceController.text.isEmpty ? '0.00' : _balanceController.text;
    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(_selectedColorValue).withValues(alpha: 0.92), Color(_selectedColorValue)]),
      boxShadow: [BoxShadow(color: Color(_selectedColorValue).withValues(alpha: 0.35), blurRadius: 16, offset: const Offset(0, 8))],
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Expanded(child: Text(_isCash ? context.t('card_cash') : (_isSavings ? 'Cuenta de Ahorros' : _isCreditCard ? 'Tarjeta de Crédito' : (_isCurrent ? 'Cuenta Corriente' : (_isOther ? 'Otros' : _selectedBank))), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: AppColors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700))),
          const SizedBox(width: AppSpacing.sm),
          Text(_selectedCurrency, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: AppSpacing.lg),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text('${currencyObj.symbol} $balanceText', maxLines: 1, style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppColors.white, fontWeight: FontWeight.w700))),
        const SizedBox(height: AppSpacing.md),
        Row(children: [
          Expanded(child: Text(_holderController.text.isEmpty ? (_isCash ? context.t('wallet_name') : context.t('card_holder_placeholder')) : _holderController.text.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w700))),
        ]),
      ]),
    );
  }

  Future<void> _pickBank(AppProvider provider) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('bank_label'),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final bank in provider.availableBanks)
              CashChip(
                label: bank,
                selected: bank == _selectedBank,
                icon: bank == _selectedBank ? Icons.check : null,
                onTap: () => Navigator.pop(sheetContext, bank),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedBank = selected);
  }

  Future<void> _pickCurrency(AppProvider provider) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('form_currency_section'),
        child: Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final currency in provider.availableCurrencies)
              CashChip(
                label: currency.code,
                selected: currency.code == _selectedCurrency,
                icon: currency.code == _selectedCurrency ? Icons.check : null,
                onTap: () => Navigator.pop(sheetContext, currency.code),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedCurrency = selected);
  }

  void _onCardNumberChanged(String val) {
    if (_numberError != null) setState(() => _numberError = null);
    _formatCardNumber(val);
  }

  void _onExpiryChanged(String val) {
    if (_expiryError != null) setState(() => _expiryError = null);
    _formatExpiryDate(val);
  }

  static String _groupCardNumber(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    final StringBuffer formatted = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) formatted.write('-');
      formatted.write(digits[i]);
    }
    return formatted.toString();
  }

  void _formatCardNumber(String val) {
    final String formatted = _groupCardNumber(val);
    if (_numberController.text != formatted) {
      _numberController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
    }
    setState(() {});
  }

  void _formatExpiryDate(String val) {
    String text = val.replaceAll(RegExp(r'\D'), '');
    String formatted = text.length >= 2 ? '${text.substring(0, 2)}/${text.substring(2)}' : text;
    if (_expiryController.text != formatted) {
      _expiryController.value = TextEditingValue(text: formatted, selection: TextSelection.collapsed(offset: formatted.length));
    }
    setState(() {});
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;
  const _ColorSwatch({required this.color, required this.isSelected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: Border.all(color: isSelected ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary) : Colors.transparent, width: 2.5)),
          child: isSelected ? const Icon(Icons.check, color: AppColors.white, size: 20) : null,
        ),
      ),
    );
  }
}
