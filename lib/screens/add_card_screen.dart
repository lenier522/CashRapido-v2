import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../screens/card_scanner_screen.dart';
import '../screens/licenses_screen.dart';
import '../services/localization_service.dart';

class AddCardScreen extends StatefulWidget {
  final AccountCard? cardToEdit;
  const AddCardScreen({super.key, this.cardToEdit});

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

  @override
  void initState() {
    super.initState();
    final card = widget.cardToEdit;

    _holderController = TextEditingController(text: card?.name ?? '');
    _numberController = TextEditingController(text: card?.cardNumber ?? '');
    _expiryController = TextEditingController(text: card?.expiryDate ?? '');
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

  void _saveCard() {
    if (!_isCash) {
      if (_holderController.text.isEmpty ||
          _numberController.text.length < 19) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('complete_data_error'))),
        );
        return;
      }

      if (_expiryController.text.length != 5 ||
          !_expiryController.text.contains('/')) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.t('invalid_date_format'))),
        );
        return;
      }
    } else {
      // Cash validation: Name required
      if (_holderController.text.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.t('enter_name_error'))));
        return;
      }
    }

    final balance =
        double.tryParse(
          _balanceController.text.replaceAll(RegExp(r'[^0-9.]'), ''),
        ) ??
        0.0;

    final provider = Provider.of<AppProvider>(context, listen: false);

    if (widget.cardToEdit != null) {
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
      provider.editCard(updatedCard);
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
      provider.addCard(newCard);
    }

    Navigator.pop(context);
  }

  Future<void> _scanCard() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CardScannerScreen()),
    );

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
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('card_scanned'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Currency Symbol Lookup
    final currencyObj = Provider.of<AppProvider>(context).availableCurrencies
        .firstWhere(
          (c) => c.code == _selectedCurrency,
          orElse: () =>
              Currency(code: _selectedCurrency, symbol: '\$', name: ''),
        );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.cardToEdit != null
              ? context.t('edit_card_title')
              : context.t('new_card'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Theme.of(context).iconTheme.color,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (widget.cardToEdit == null && !_isCash) // Only for new cards
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  onPressed: () {
                    final provider = Provider.of<AppProvider>(
                      context,
                      listen: false,
                    );
                    if (provider.canUseScanner) {
                      _scanCard();
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
                            ElevatedButton(
                              onPressed: () {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const LicensesScreen(),
                                  ),
                                );
                              },
                              child: Text(context.t('upgrade_btn')),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  icon: const Icon(
                    Icons.document_scanner_outlined,
                    color: Colors.deepPurple,
                  ),
                  tooltip: context.t('scan_card'),
                ),
                Consumer<AppProvider>(
                  builder: (context, provider, _) {
                    if (!provider.canUseScanner) {
                      return Positioned(
                        right: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: Colors.amber,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                          child: const Icon(
                            Icons.lock,
                            size: 8,
                            color: Colors.white,
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ],
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Account Type Toggle
            if (widget.cardToEdit == null) ...[
              Text(
                context.t('account_type'),
                style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildTypeOption(
                      title: context.t('bank_card'),
                      icon: Icons.credit_card,
                      isSelected: !_isCash,
                      onTap: () => setState(() => _isCash = false),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTypeOption(
                      title: context.t('card_cash'),
                      icon: Icons.attach_money,
                      isSelected: _isCash,
                      onTap: () => setState(() => _isCash = true),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],

            // Preview Card
            Container(
              height: 200,
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Color(_selectedColorValue),
                borderRadius: BorderRadius.circular(24),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(_selectedColorValue).withValues(alpha: 0.9),
                    Color(_selectedColorValue),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(_selectedColorValue).withValues(alpha: 0.4),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _isCash ? context.t('card_cash') : _selectedBank,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            _selectedCurrency,
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            _isCash
                                ? Icons.account_balance_wallet
                                : Icons.contactless,
                            color: Colors.white70,
                          ),
                        ],
                      ),
                    ],
                  ),
                  Text(
                    '${currencyObj.symbol} ${_balanceController.text.isEmpty ? '0.00' : _balanceController.text}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isCash)
                        Text(
                          _numberController.text.isEmpty
                              ? '****-****-****-****'
                              : _numberController.text,
                          style: GoogleFonts.sourceCodePro(
                            color: Colors.white,
                            fontSize: 18,
                            letterSpacing: 2,
                          ),
                        ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _holderController.text.isEmpty
                                ? (_isCash
                                      ? context.t('wallet_name')
                                      : context.t('card_holder_placeholder'))
                                : _holderController.text.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (!_isCash)
                            Text(
                              _expiryController.text.isEmpty
                                  ? 'MM/YY'
                                  : _expiryController.text,
                              style: GoogleFonts.outfit(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // Inputs
            if (!_isCash) ...[
              _buildTextField(
                context.t('bank_label'),
                context.t('select_bank'),
                TextEditingController(text: _selectedBank),
                isDropdown: true,
              ),
              const SizedBox(height: 16),
            ],

            _buildTextField(
              _isCash ? context.t('wallet_name') : context.t('card_holder'),
              _isCash ? context.t('cat_name_hint') : context.t('full_name'),
              _holderController,
            ),
            const SizedBox(height: 16),

            if (!_isCash) ...[
              _buildTextField(
                context.t('card_number'),
                'XXXX-XXXX-XXXX-XXXX',
                _numberController,
                type: TextInputType.number,
                isCardNumber: true,
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                if (!_isCash) ...[
                  Flexible(
                    fit: FlexFit.tight,
                    child: _buildTextField(
                      context.t('expiration'),
                      'MM/YY',
                      _expiryController,
                      type: TextInputType.number,
                      isExpiry: true,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Flexible(
                  fit: FlexFit.tight,
                  child: _buildTextField(
                    context.t('initial_balance'),
                    '0.00',
                    _balanceController,
                    type: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Currency Selector
            Text(
              context.t('currency_label'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 50,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: Provider.of<AppProvider>(context).availableCurrencies
                    .map((c) {
                      final isSelected = _selectedCurrency == c.code;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedCurrency = c.code),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.deepPurple
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              c.code,
                              style: GoogleFonts.outfit(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    })
                    .toList(),
              ),
            ),

            const SizedBox(height: 24),
            // Color Selector
            Text(
              context.t('color_label'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: _cardColors.map((color) {
                final isSelected = _selectedColorValue == color.toARGB32();
                return GestureDetector(
                  onTap: () =>
                      setState(() => _selectedColorValue = color.toARGB32()),
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: Colors.black, width: 3)
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 20)
                        : null,
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _saveCard,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  context.t('save_card'),
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.deepPurple : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.deepPurple : Colors.grey.shade300,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: GoogleFonts.outfit(
                color: isSelected ? Colors.white : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    String placeholder,
    TextEditingController controller, {
    TextInputType type = TextInputType.text,
    bool isCardNumber = false,
    bool isExpiry = false,
    bool isDropdown = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: isDropdown
              ? DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: controller.text,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: Theme.of(context).iconTheme.color,
                    ),
                    isExpanded: true,
                    dropdownColor: Theme.of(context).cardColor,
                    items: Provider.of<AppProvider>(context).availableBanks.map(
                      (String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(
                            value,
                            style: GoogleFonts.outfit(
                              color: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.color,
                            ),
                          ),
                        );
                      },
                    ).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        controller.text = newValue!;
                        _selectedBank = newValue;
                      });
                    },
                  ),
                )
              : TextField(
                  controller: controller,
                  keyboardType: type,
                  maxLength: isCardNumber ? 19 : (isExpiry ? 5 : null),
                  onChanged: (val) {
                    setState(() {
                      if (isCardNumber) {
                        _formatCardNumber(val);
                      } else if (isExpiry) {
                        _formatExpiryDate(val);
                      }
                    });
                  },
                  style: GoogleFonts.outfit(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    errorBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    hintText: placeholder,
                    counterText: "",
                    hintStyle: GoogleFonts.outfit(
                      color: Theme.of(context).hintColor,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
        ),
      ],
    );
  }

  void _formatCardNumber(String val) {
    // Remove all non-digits
    String text = val.replaceAll(RegExp(r'\D'), '');
    String formatted = '';
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) {
        formatted += '-';
      }
      formatted += text[i];
    }

    // Update controller if changed to avoid infinite loop
    if (_numberController.text != formatted) {
      _numberController.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    }
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
  }
}
