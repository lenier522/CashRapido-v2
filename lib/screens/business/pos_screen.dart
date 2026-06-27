import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/seller.dart';
import '../../services/localization_service.dart';
import 'barcode_scanner_screen.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Map<String, double> _cart = {}; // ProductId -> Quantity (double)
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final products = provider.products.where((p) {
          return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
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
            actions: [
              IconButton(
                icon: const Icon(Icons.qr_code_scanner),
                tooltip: 'Escanear Código de Barras',
                onPressed: () => _startContinuousScanning(provider),
              ),
            ],
          ),
          body: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '${context.t('inventory_title')} / SKU',
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
                          childAspectRatio: 0.76,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          final qtyInCart = _cart[product.id] ?? 0.0;
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
                        color: Colors.black.withValues(alpha: 0.05),
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
                              '${_cart.values.fold<double>(0.0, (a, b) => a + b).toFormattedString(1)} uds',
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

  Widget _buildProductCard(BuildContext context, Product product, double qty) {
    final color = Theme.of(context).primaryColor;
    final String formattedStock = product.currentStock % 1 == 0
        ? product.currentStock.toInt().toString()
        : product.currentStock.toStringAsFixed(2);

    final String formattedQty = qty % 1 == 0
        ? qty.toInt().toString()
        : qty.toStringAsFixed(2);

    return GestureDetector(
      onTap: () => _addProductToCart(product),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: qty > 0 ? color : Colors.grey.withValues(alpha: 0.1),
            width: qty > 0 ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.05),
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
                  color: color.withValues(alpha: 0.05),
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
                      color: color.withValues(alpha: 0.3),
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
                        'Stock: $formattedStock ${product.unit}',
                        style: TextStyle(
                          fontSize: 9,
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
                          if (product.unit == 'uds') {
                            if (qty > 1) {
                              _cart[product.id] = qty - 1;
                            } else {
                              _cart.remove(product.id);
                            }
                          } else {
                            // Weight based: open edit dialog, or remove if long pressed/edit to 0
                            _showWeightDialog(product);
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
                        '$formattedQty ${product.unit}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: () => _addProductToCart(product),
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

  void _addProductToCart(Product product) {
    if (product.unit == 'uds') {
      final currentQty = _cart[product.id] ?? 0.0;
      if (product.currentStock > currentQty) {
        setState(() {
          _cart[product.id] = currentQty + 1.0;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No hay suficiente stock para ${product.name}'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      _showWeightDialog(product);
    }
  }

  void _showWeightDialog(Product product) {
    final currentQty = _cart[product.id] ?? 0.0;
    final ctrl = TextEditingController(
      text: currentQty > 0.0
          ? (currentQty % 1 == 0 ? currentQty.toInt().toString() : currentQty.toString())
          : '1.0',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Cantidad de ${product.name}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Unidad de medida: ${product.unit} (Stock: ${product.currentStock})'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad (${product.unit})',
                border: const OutlineInputBorder(),
                suffixText: product.unit,
              ),
            ),
          ],
        ),
        actions: [
          if (currentQty > 0.0)
            TextButton(
              onPressed: () {
                setState(() {
                  _cart.remove(product.id);
                });
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Eliminar del Carrito'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(ctrl.text);
              if (qty == null || qty <= 0.0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Ingresa una cantidad válida')),
                );
                return;
              }
              if (product.currentStock < qty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Stock insuficiente. Disponible: ${product.currentStock} ${product.unit}',
                    ),
                  ),
                );
                return;
              }
              setState(() {
                _cart[product.id] = qty;
              });
              Navigator.pop(context);
            },
            child: const Text('Aceptar'),
          ),
        ],
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

  Future<void> _startContinuousScanning(BusinessProvider provider) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          continuous: true,
          onScan: (code) {
            try {
              final product = provider.products.firstWhere(
                (p) => p.sku.toLowerCase() == code.toLowerCase().trim(),
              );
              _addProductToCart(product);
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Producto no encontrado para el código: $code'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
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
    Seller? selectedSeller;

    final clientNames = provider.sales
        .map((s) => s.clientName)
        .where((name) => name != null && name.trim().isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final activeSellers = provider.sellers.where((s) => s.isActive).toList();

    // Only show seller selector if at least one product in cart has seller inventory
    final cartHasSellerInventory = _cart.keys.any((pid) =>
        provider.sellerInventory.any((si) => si.productId == pid && si.assignedQuantity > 0));
    final showSellerSelector = activeSellers.isNotEmpty && cartHasSellerInventory;

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
                  const SizedBox(height: 16),
                  // Seller selector
                  if (showSellerSelector)
                    DropdownButtonFormField<String?>(
                      decoration: const InputDecoration(
                        labelText: 'Vendedor (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      value: selectedSeller?.id,
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('Sin vendedor'),
                        ),
                        ...activeSellers.map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.fullName),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        setModalState(() {
                          selectedSeller = val != null
                              ? activeSellers.firstWhere((s) => s.id == val)
                              : null;
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
                        sellerId: selectedSeller?.id,
                        sellerName: selectedSeller?.fullName,
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
    String? sellerId,
    String? sellerName,
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
      sellerId: sellerId,
      sellerName: sellerName,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.t('sale_success')),
        backgroundColor: Colors.green,
      ),
    );
  }
}
