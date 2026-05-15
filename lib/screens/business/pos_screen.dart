import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../services/localization_service.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Map<String, int> _cart = {}; // ProductId -> Quantity
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final products = provider.products.where((p) {
          return p.name.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        final total = _calculateTotal(provider);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.t('pos_title'),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            centerTitle: true,
            elevation: 0,
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: context.t('inventory_title'),
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // Product Grid
              Expanded(
                child: products.isEmpty
                    ? Center(
                        child: Text(
                          context.t('no_products'),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.8,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final qtyInCart = _cart[product.id] ?? 0;
                          return _buildProductCard(context, product, qtyInCart);
                        },
                      ),
              ),

              // Cart Summary Bar
              if (_cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
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
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_cart.values.fold(0, (a, b) => a + b)} items',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            Text(
                              '\$${total.toFormattedString(2)}',
                              style: GoogleFonts.outfit(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () =>
                              _showCheckoutDialog(context, provider, total),
                          icon: const Icon(Icons.shopping_cart_checkout),
                          label: Text(context.t('checkout')),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProductCard(BuildContext context, Product product, int qty) {
    final color = Theme.of(context).primaryColor;

    return GestureDetector(
      onTap: () {
        if (product.currentStock > qty) {
          setState(() {
            _cart[product.id] = qty + 1;
          });
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: qty > 0 ? color : Colors.grey.withOpacity(0.1),
            width: qty > 0 ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: color.withOpacity(0.05),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(15),
                  ),
                ),
                child: Center(
                  child: Text(
                    product.name.substring(0, 1).toUpperCase(),
                    style: GoogleFonts.outfit(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${product.salePrice}',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Stock: ${product.currentStock}',
                        style: TextStyle(
                          fontSize: 10,
                          color: product.currentStock < 5
                              ? Colors.red
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (qty > 0)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(14),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    InkWell(
                      onTap: () {
                        setState(() {
                          if (qty > 1) {
                            _cart[product.id] = qty - 1;
                          } else {
                            _cart.remove(product.id);
                          }
                        });
                      },
                      child: const Icon(
                        Icons.remove,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '$qty',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        if (product.currentStock > qty) {
                          setState(() {
                            _cart[product.id] = qty + 1;
                          });
                        }
                      },
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  double _calculateTotal(BusinessProvider provider) {
    double total = 0;
    _cart.forEach((id, qty) {
      final product = provider.products.firstWhere((p) => p.id == id);
      total += product.salePrice * qty;
    });
    return total;
  }

  void _showCheckoutDialog(
    BuildContext context,
    BusinessProvider provider,
    double initialTotal,
  ) {
    String paymentMethod = 'Efectivo';
    String status = 'paid';
    double discount = 0.0;
    final discountCtrl = TextEditingController();
    String currentClientName = '';

    final clientNames = provider.sales
        .map((s) => s.clientName)
        .where((name) => name != null && name.trim().isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = (initialTotal - discount) > 0
              ? (initialTotal - discount)
              : 0.0;

          return Padding(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.t('confirm_sale'),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // Discount
                  TextField(
                    controller: discountCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Descuento (\$) (Opcional)',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.money_off),
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (val) {
                      setModalState(() {
                        discount = double.tryParse(val) ?? 0.0;
                      });
                    },
                  ),
                  const SizedBox(height: 12),

                  // Client
                  Autocomplete<String>(
                    optionsBuilder: (TextEditingValue textEditingValue) {
                      currentClientName = textEditingValue.text;
                      if (textEditingValue.text.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      return clientNames.where((String option) {
                        return option.toLowerCase().contains(
                          textEditingValue.text.toLowerCase(),
                        );
                      });
                    },
                    onSelected: (String selection) {
                      currentClientName = selection;
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                          return TextField(
                            controller: controller,
                            focusNode: focusNode,
                            onChanged: (val) {
                              currentClientName = val;
                            },
                            decoration: const InputDecoration(
                              labelText: 'Nombre del Cliente (Opcional)',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.person),
                            ),
                          );
                        },
                  ),
                  const SizedBox(height: 16),

                  // Payment Method
                  DropdownButtonFormField<String>(
                    initialValue: paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Método de Pago',
                      border: OutlineInputBorder(),
                    ),
                    items: ['Efectivo', 'Tarjeta', 'Transferencia', 'Crédito']
                        .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                        .toList(),
                    onChanged: (val) {
                      setModalState(() {
                        paymentMethod = val!;
                        if (paymentMethod == 'Crédito') {
                          status = 'pending';
                        } else {
                          status = 'paid';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),

                  // Total summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total a Pagar',
                        style: TextStyle(color: Colors.grey[600], fontSize: 16),
                      ),
                      Text(
                        '\$${total.toFormattedString(2)}',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: status == 'pending'
                              ? Colors.orange
                              : Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      if (paymentMethod == 'Crédito' &&
                          currentClientName.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Debe ingresar un cliente para ventas a crédito.',
                            ),
                          ),
                        );
                        return;
                      }

                      _processSale(
                        provider,
                        discount: discount,
                        clientName: currentClientName.trim(),
                        paymentMethod: paymentMethod,
                        status: status,
                      );
                      Navigator.pop(context); // Close sheet
                      Navigator.pop(context); // Close POS
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: status == 'pending'
                          ? Colors.orange
                          : Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      status == 'pending'
                          ? 'Confirmar Fiado'
                          : context.t('confirm_sale'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _processSale(
    BusinessProvider provider, {
    required double discount,
    required String clientName,
    required String paymentMethod,
    required String status,
  }) {
    final List<SaleItem> items = [];
    _cart.forEach((id, qty) {
      final product = provider.products.firstWhere((p) => p.id == id);
      items.add(
        SaleItem(
          productId: id,
          productName: product.name,
          quantity: qty,
          unitPrice: product.salePrice,
          subtotal: product.salePrice * qty,
        ),
      );
    });

    provider.addSale(
      items: items,
      paymentMethod: paymentMethod,
      discount: discount,
      clientName: clientName.isEmpty ? null : clientName,
      status: status,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('sale_success')),
        backgroundColor: Colors.green,
      ),
    );
  }
}
