import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/localization_service.dart';

class MoneyCounterScreen extends StatefulWidget {
  final String currencySymbol;

  const MoneyCounterScreen({super.key, required this.currencySymbol});

  @override
  State<MoneyCounterScreen> createState() => _MoneyCounterScreenState();
}

class _MoneyItem {
  final TextEditingController valueController;
  final TextEditingController countController;
  double subtotal;

  _MoneyItem()
    : valueController = TextEditingController(),
      countController = TextEditingController(),
      subtotal = 0.0;

  void dispose() {
    valueController.dispose();
    countController.dispose();
  }
}

class _MoneyCounterScreenState extends State<MoneyCounterScreen> {
  final List<_MoneyItem> _items = [];
  double _total = 0.0;

  @override
  void initState() {
    super.initState();
    _addItem(); // Start with one empty row
  }

  @override
  void dispose() {
    for (var item in _items) {
      item.dispose();
    }
    super.dispose();
  }

  void _addItem() {
    setState(() {
      final newItem = _MoneyItem();
      newItem.valueController.addListener(_calculateTotal);
      newItem.countController.addListener(_calculateTotal);
      _items.add(newItem);
    });
  }

  void _removeItem(int index) {
    setState(() {
      final item = _items[index];
      item.valueController.removeListener(_calculateTotal);
      item.countController.removeListener(_calculateTotal);
      item.dispose();
      _items.removeAt(index);
      _calculateTotal();
    });
  }

  void _clearAll() {
    setState(() {
      for (var item in _items) {
        item.dispose();
      }
      _items.clear();
      _total = 0.0;
      _addItem();
    });
  }

  void _calculateTotal() {
    double newTotal = 0.0;
    for (var item in _items) {
      double value =
          double.tryParse(item.valueController.text.replaceAll(',', '.')) ??
          0.0;
      int count = int.tryParse(item.countController.text) ?? 0;
      item.subtotal = value * count;
      newTotal += item.subtotal;
    }
    setState(() {
      _total = newTotal;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.t('money_counter_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: context.t('clear_all'),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (context, index) {
                return _buildRow(index);
              },
            ),
          ),
          _buildTotalBar(context),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addItem,
        backgroundColor: Theme.of(context).colorScheme.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildRow(int index) {
    final item = _items[index];

    return Dismissible(
      key: ObjectKey(item),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _removeItem(index),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: Colors.redAccent,
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Bill/Coin Value
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('bill_value'),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: item.valueController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                      prefixText: widget.currencySymbol,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),

            // X multiplication sign
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                '×',
                style: GoogleFonts.outfit(
                  fontSize: 20,
                  color: Theme.of(context).disabledColor,
                ),
              ),
            ),

            // Count
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('quantity'),
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextField(
                    controller: item.countController,
                    keyboardType: TextInputType.number,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: '0',
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),

            // Subtotal
            Container(
              width: 100,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.centerRight,
              child: Text(
                '${widget.currencySymbol}${item.subtotal.toStringAsFixed(0)}', // Assume whole numbers mostly usually, but maybe not? let's stick to fixed(0) or fixed(2) if decimal.
                // Let's use clean formatting.
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTotalBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              context.t('total'),
              style: GoogleFonts.outfit(
                fontSize: 20,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            Text(
              '${widget.currencySymbol}${_total.toStringAsFixed(2)}',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
