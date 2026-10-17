import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
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
/// No se añade ningún campo ni se cambia ninguna regla: siguen presentes los mismos
/// datos del modelo `AccountCard` (nombre, tipo, banco, número, vencimiento,
/// saldo, moneda, color), las mismas validaciones y las mismas llamadas
/// `addCard` / `editCard`.
///
/// [initialHolder], [initialNumber] y [initialExpiry] sólo sirven para
/// precargar el formulario (por ejemplo con lo leído por el escáner desde
/// Inicio); no crean ni modifican ningún dato por sí mismos.
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

  String _selectedCurrency = 'USD';
  String _selectedBank = 'VISA';
  int _selectedColorValue = 0xFF42A5F5;
  bool _isCash = false;

  /// Errores contextuales por campo.
  String? _holderError;
  String? _numberError;
  String? _expiryError;
  bool _isSaving = false;

  bool get _isEditing => widget.cardToEdit != null;

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

    if (card != null) {
      _selectedCurrency = card.currency;
      _selectedBank = card.bankName ?? 'VISA';
      _isCash = card.isCash;
      _selectedColorValue = card.colorValue;
    }

    // Defer the safety check to next frame or use didChangeDependencies
    // However, we can access Provider with listen: false here safely for initial values.
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
    super.dispose();
  }

  void _validateState() {
    final provider = Provider.of<AppProvider>(context, listen: false);

    // CRASH FIX: Recover lost "Cash" status
    if (!_isCash &&
        (_selectedBank == 'Efectivo' ||
            _selectedBank == 'Cash' ||
            _selectedBank == 'Espèces')) {
      setState(() {
        _isCash = true;
      });
    }

    // CRASH FIX: Ensure selected bank exists in dropdown if not cash
    if (!_isCash) {
      if (!provider.availableBanks.contains(_selectedBank)) {
        setState(() {
          _selectedBank = provider.availableBanks.isNotEmpty
              ? provider.availableBanks.first
              : 'VISA';
        });
      }
    }
  }

  final List<Color> _cardColors = [
    const Color(0xFF1A1A1A), // Black
    const Color(0xFF42A5F5), // Blue
    const Color(0xFF7E57C2), // Deep Purple
    const Color(0xFF66BB6A), // Green
    const Color(0xFFFF7043), // Orange
    const Color(0xFFEC407A), // Pink
  ];

  // ---------------------------------------------------------------------------
  // LÓGICA DE NEGOCIO (sin cambios)
  // ---------------------------------------------------------------------------

  Future<void> _saveCard() async {
    if (_isSaving) return;

    // Validaciones idénticas; el mensaje pasa a vivir bajo el campo en vez de
    // aparecer en un Snackbar que deja la pantalla quieta.
    if (!_isCash) {
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

    final balance =
        double.tryParse(
          _balanceController.text
              .replaceAll(RegExp(r'[^0-9.,]'), '')
              .replaceAll(',', '.'),
        ) ??
        0.0;

    final provider = Provider.of<AppProvider>(context, listen: false);

    if (_isEditing) {
      // Edit Mode
      final updatedCard = AccountCard(
        id: widget.cardToEdit!.id, // Keep ID
        name: _holderController.text.toUpperCase(),
        balance: balance,
        currency: _selectedCurrency,
        cardNumber: _isCash ? 'CASH' : _numberController.text,
        expiryDate: _isCash ? 'N/A' : _expiryController.text,
        colorValue: _selectedColorValue,
        bankName: _isCash ? context.t('card_cash') : _selectedBank,
        isLocked: widget.cardToEdit!.isLocked,
        pin: widget.cardToEdit!.pin,
        spendingLimit: widget.cardToEdit!.spendingLimit,
        isCash: _isCash,
      );
      await provider.editCard(updatedCard);
    } else {
      // New Mode
      final newCard = AccountCard(
        id: const Uuid().v4(),
        name: _holderController.text.toUpperCase(),
        balance: balance,
        currency: _selectedCurrency,
        cardNumber: _isCash ? 'CASH' : _numberController.text,
        expiryDate: _isCash
            ? 'N/A'
            : (_expiryController.text.isEmpty
                  ? '12/28'
                  : _expiryController.text),
        colorValue: _selectedColorValue,
        bankName: _isCash ? context.t('card_cash') : _selectedBank,
        isCash: _isCash,
      );
      await provider.addCard(newCard);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('card_scanned'))));
    }
  }

  bool get _canScan {
    if (_isEditing || _isCash) return false;
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // ---------------------------------------------------------------------------
  // SELECTORES
  // ---------------------------------------------------------------------------

  Future<void> _pickBank(AppProvider provider) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('bank_label'),
        child: Column(
          children: [
            Wrap(
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
        child: Column(
          children: [
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final currency in provider.availableCurrencies)
                  CashChip(
                    label: currency.code,
                    selected: currency.code == _selectedCurrency,
                    icon: currency.code == _selectedCurrency
                        ? Icons.check
                        : null,
                    onTap: () => Navigator.pop(sheetContext, currency.code),
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedCurrency = selected);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

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
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
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
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Expanded(
                      child: _buildTypeOption(
                        title: context.t('bank_card'),
                        icon: Icons.credit_card_rounded,
                        isSelected: !_isCash,
                        onTap: () => setState(() => _isCash = false),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: _buildTypeOption(
                        title: context.t('card_cash'),
                        icon: Icons.payments_outlined,
                        isSelected: _isCash,
                        onTap: () => setState(() => _isCash = true),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              _buildPreview(currencyObj),
              const SizedBox(height: AppSpacing.xl),
              if (!_isCash) ...[
                Text(
                  context.t('form_identity_section'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CashSelectorField(
                  label: context.t('bank_label'),
                  value: _selectedBank,
                  placeholder: context.t('select_bank'),
                  icon: Icons.account_balance_outlined,
                  onTap: () => _pickBank(provider),
                ),
                const SizedBox(height: AppSpacing.md),
                CashInput(
                  controller: _holderController,
                  label: context.t('card_holder'),
                  hint: context.t('full_name'),
                  prefix: const Icon(Icons.person_outline),
                  textCapitalization: TextCapitalization.words,
                  errorText: _holderError,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) {
                    if (_holderError != null) {
                      setState(() => _holderError = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                CashInput(
                  controller: _numberController,
                  label: context.t('card_number'),
                  hint: 'XXXX-XXXX-XXXX-XXXX',
                  prefix: const Icon(Icons.numbers),
                  keyboardType: TextInputType.number,
                  maxLength: 19,
                  errorText: _numberError,
                  textInputAction: TextInputAction.next,
                  onChanged: _onCardNumberChanged,
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: CashInput(
                        controller: _expiryController,
                        label: context.t('expiration'),
                        hint: 'MM/YY',
                        keyboardType: TextInputType.number,
                        maxLength: 5,
                        errorText: _expiryError,
                        textInputAction: TextInputAction.next,
                        onChanged: _onExpiryChanged,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(child: _buildBalanceInput()),
                  ],
                ),
              ] else ...[
                Text(
                  context.t('wallet_name'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                CashInput(
                  controller: _holderController,
                  label: context.t('wallet_name'),
                  hint: context.t('cat_name_hint'),
                  prefix: const Icon(Icons.account_balance_wallet_outlined),
                  textCapitalization: TextCapitalization.words,
                  errorText: _holderError,
                  onChanged: (_) {
                    if (_holderError != null) {
                      setState(() => _holderError = null);
                    }
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                _buildBalanceInput(),
              ],
              const SizedBox(height: AppSpacing.xl),
              Text(
                context.t('form_currency_section'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              CashCurrencyField(
                code: _selectedCurrency,
                symbol: currencyObj.symbol,
                name: currencyObj.name,
                onTap: () => _pickCurrency(provider),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.t('form_color_section'),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  for (final color in _cardColors)
                    _ColorSwatch(
                      color: color,
                      isSelected: _selectedColorValue == color.toARGB32(),
                      onTap: () => setState(
                        () => _selectedColorValue = color.toARGB32(),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxxl),
              CashButton(
                label: context.t('save_card'),
                icon: const Icon(Icons.check, size: 20),
                loading: _isSaving,
                onPressed: _isSaving ? null : _saveCard,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScanAction(AppProvider provider) {
    final bool locked = !provider.canUseScanner;

    return CashIconButton(
      icon: Icons.document_scanner_outlined,
      size: 42,
      bordered: true,
      tooltip: context.t('scan_card'),
      badge: locked
          ? Container(
              padding: const EdgeInsets.all(AppSpacing.xxs),
              decoration: BoxDecoration(
                color: AppColors.warning,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  width: 1.5,
                ),
              ),
              child: const Icon(Icons.lock, size: 8, color: AppColors.white),
            )
          : null,
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
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('close')),
          ),
          CashButton(
            label: context.t('upgrade_btn'),
            fullWidth: false,
            height: 44,
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicensesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceInput() {
    final Currency currencyObj =
        Provider.of<AppProvider>(
          context,
          listen: false,
        ).availableCurrencies.firstWhere(
          (c) => c.code == _selectedCurrency,
          orElse: () =>
              Currency(code: _selectedCurrency, symbol: '\$', name: ''),
        );

    return CashInput(
      controller: _balanceController,
      label: context.t('initial_balance'),
      hint: '0.00',
      prefix: Text(
        currencyObj.symbol,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.done,
    );
  }

  Widget _buildPreview(Currency currencyObj) {
    final String balanceText = _balanceController.text.isEmpty
        ? '0.00'
        : _balanceController.text;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(_selectedColorValue).withValues(alpha: 0.92),
          Color(_selectedColorValue),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: Color(_selectedColorValue).withValues(alpha: 0.35),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _isCash ? context.t('card_cash') : _selectedBank,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                _selectedCurrency,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                _isCash
                    ? Icons.account_balance_wallet_rounded
                    : Icons.contactless,
                color: AppColors.white.withValues(alpha: 0.85),
                size: 20,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${currencyObj.symbol} $balanceText',
              maxLines: 1,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!_isCash) ...[
            Text(
              _numberController.text.isEmpty
                  ? '****-****-****-****'
                  : _numberController.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.white,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: Text(
                  _holderController.text.isEmpty
                      ? (_isCash
                            ? context.t('wallet_name')
                            : context.t('card_holder_placeholder'))
                      : _holderController.text.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (!_isCash) ...[
                const SizedBox(width: AppSpacing.sm),
                Text(
                  _expiryController.text.isEmpty
                      ? 'MM/YY'
                      : _expiryController.text,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10)
                : isDark
                ? AppColors.surfaceDark2
                : AppColors.surfaceVariantLight,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected ? AppColors.primary : secondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected ? AppColors.primary : null,
                  ),
                ),
              ),
              if (isSelected) ...[
                const SizedBox(width: AppSpacing.xs),
                const Icon(
                  Icons.check_circle,
                  size: 16,
                  color: AppColors.primary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FORMATO (sin cambios)
  // ---------------------------------------------------------------------------

  void _onCardNumberChanged(String val) {
    if (_numberError != null) setState(() => _numberError = null);
    _formatCardNumber(val);
  }

  void _onExpiryChanged(String val) {
    if (_expiryError != null) setState(() => _expiryError = null);
    _formatExpiryDate(val);
  }

  /// Agrupa el número en bloques de cuatro dígitos, sin tocar el estado.
  ///
  /// Función pura para poder reutilizarse en `initState` (precarga del escáner),
  /// donde `setState` no es válido.
  static String _groupCardNumber(String? value) {
    final String digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    final StringBuffer formatted = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted.write('-');
      }
      formatted.write(digits[i]);
    }
    return formatted.toString();
  }

  void _formatCardNumber(String val) {
    final String formatted = _groupCardNumber(val);

    // Update controller if changed to avoid infinite loop
    if (_numberController.text != formatted) {
      _numberController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {});
  }

  void _formatExpiryDate(String val) {
    String text = val.replaceAll(RegExp(r'\D'), '');
    String formatted = '';

    if (text.length >= 2) {
      formatted = '${text.substring(0, 2)}/${text.substring(2)}';
    } else {
      formatted = text;
    }

    if (_expiryController.text != formatted) {
      _expiryController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
    setState(() {});
  }
}

class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

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
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary
                  : Colors.transparent,
              width: 2.5,
            ),
          ),
          // La selección no depende sólo del color: hay un check visible.
          child: isSelected
              ? const Icon(Icons.check, color: AppColors.white, size: 20)
              : null,
        ),
      ),
    );
  }
}
