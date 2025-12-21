import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import '../screens/card_scanner_screen.dart';
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
      _selectedColorValue = card.colorValue;
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
    if (_holderController.text.isEmpty || _numberController.text.length < 19) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('complete_data_error'))));
      return;
    }

    if (_expiryController.text.length != 5 ||
        !_expiryController.text.contains('/')) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('invalid_date_format'))));
      return;
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
        cardNumber: _numberController.text,
        expiryDate: _expiryController.text,
        colorValue: _selectedColorValue,
        bankName: _selectedBank,
        isLocked: widget.cardToEdit!.isLocked,
        pin: widget.cardToEdit!.pin,
        spendingLimit: widget.cardToEdit!.spendingLimit,
      );
      provider.editCard(updatedCard);
    } else {
      // New Mode
      final newCard = AccountCard(
        id: const Uuid().v4(),
        name: _holderController.text.toUpperCase(),
        balance: balance,
        currency: _selectedCurrency,
        cardNumber: _numberController.text,
        expiryDate: _expiryController.text.isEmpty
            ? '12/28'
            : _expiryController.text,
        colorValue: _selectedColorValue,
        bankName: _selectedBank,
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
          if (widget.cardToEdit == null) // Only for new cards
            IconButton(
              onPressed: _scanCard,
              icon: const Icon(
                Icons.document_scanner_outlined,
                color: Colors.deepPurple,
              ),
              tooltip: context.t('scan_card'),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
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
                        _selectedBank,
                        style: GoogleFonts.outfit(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.contactless, color: Colors.white70),
                    ],
                  ),
                  Text(
                    '\$ ${_balanceController.text.isEmpty ? '0.00' : _balanceController.text}',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                                ? context.t('card_holder_placeholder')
                                : _holderController.text.toUpperCase(),
                            style: GoogleFonts.outfit(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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
            _buildTextField(
              context.t('bank_label'),
              context.t('select_bank'),
              TextEditingController(text: _selectedBank),
              isDropdown: true,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              context.t('card_holder'),
              context.t('full_name'),
              _holderController,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              context.t('card_number'),
              'XXXX-XXXX-XXXX-XXXX',
              _numberController,
              type: TextInputType.number,
              isCardNumber: true,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
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
