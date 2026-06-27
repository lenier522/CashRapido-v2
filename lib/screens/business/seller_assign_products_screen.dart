import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/seller.dart';
import '../../models/seller_inventory.dart';

class SellerAssignProductsScreen extends StatefulWidget {
  final Seller seller;

  const SellerAssignProductsScreen({super.key, required this.seller});

  @override
  State<SellerAssignProductsScreen> createState() => _SellerAssignProductsScreenState();
}

class _SellerAssignProductsScreenState extends State<SellerAssignProductsScreen> {
  final Map<String, TextEditingController> _controllers = {};

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    super.dispose();
  }

  void _saveAssignment(
    BusinessProvider provider,
    String productId,
    String productName,
    List<SellerInventory> assigned,
  ) {
    final ctrl = _controllers[productId];
    if (ctrl == null) return;
    final qty = double.tryParse(ctrl.text) ?? 0.0;
    if (qty > 0) {
      provider.assignProductToSeller(
        sellerId: widget.seller.id,
        productId: productId,
        productName: productName,
        quantity: qty,
      );
    } else {
      final existing = assigned.where((a) => a.productId == productId);
      if (existing.isNotEmpty) {
        provider.removeProductFromSeller(existing.first.id);
      }
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          qty > 0
              ? '$qty unidades asignadas a ${widget.seller.fullName}'
              : 'Producto desasignado',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final products = provider.products;
        final assigned = provider.getSellerInventoryBySeller(widget.seller.id);
        final assignedMap = {
          for (var a in assigned) a.productId: a.assignedQuantity,
        };

        for (final p in products) {
          _controllers.putIfAbsent(
            p.id,
            () => TextEditingController(
              text: assignedMap[p.id] != null && assignedMap[p.id]! > 0
                  ? assignedMap[p.id].toString()
                  : '',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Inventario: ${widget.seller.fullName}',
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          body: products.isEmpty
              ? const Center(child: Text('No hay productos disponibles'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final assignedQty = assignedMap[product.id] ?? 0.0;
                    final ctrl = _controllers[product.id]!;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    product.name,
                                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Stock: ${product.currentStock.toStringAsFixed(product.currentStock % 1 == 0 ? 0 : 2)} ${product.unit}',
                                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: 100,
                              child: TextField(
                                controller: ctrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  hintText: '0',
                                  labelText: assignedQty > 0 ? '$assignedQty' : 'Asignar',
                                  border: const OutlineInputBorder(),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                  suffixText: product.unit,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.check, color: Colors.green),
                              onPressed: () => _saveAssignment(
                                provider,
                                product.id,
                                product.name,
                                assigned,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
