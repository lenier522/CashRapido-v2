import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/seller.dart';
import '../../models/seller_inventory.dart';
import '../../services/localization_service.dart';

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
    final maxAllowed = provider.getMaxAssignableToSeller(productId, widget.seller.id);

    if (qty > maxAllowed) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t('seller_assign_exceeds')
                .replaceAll('{max}', maxAllowed.toStringAsFixed(maxAllowed % 1 == 0 ? 0 : 2)),
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      ctrl.text = maxAllowed > 0 ? (maxAllowed % 1 == 0 ? maxAllowed.toInt().toString() : maxAllowed.toString()) : '';
      return;
    }

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
              ? context
                  .t('seller_assign_success')
                  .replaceAll('{qty}', '$qty')
                  .replaceAll('{name}', widget.seller.fullName)
              : context.t('seller_assign_removed'),
        ),
        backgroundColor: Colors.green,
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
                  ? (assignedMap[p.id]! % 1 == 0 ? assignedMap[p.id]!.toInt().toString() : assignedMap[p.id]!.toString())
                  : '',
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(
              context.t('seller_assign_title').replaceAll('{name}', widget.seller.fullName),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
          ),
          body: products.isEmpty
              ? Center(child: Text(context.t('seller_no_products_available')))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    final product = products[index];
                    final assignedQty = assignedMap[product.id] ?? 0.0;
                    final totalAssigned = provider.getTotalAssignedQuantityForProduct(product.id);
                    final maxAssignable = provider.getMaxAssignableToSeller(product.id, widget.seller.id);
                    final ctrl = _controllers[product.id]!;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: assignedQty > 0
                              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                              : Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product.name,
                                        style: GoogleFonts.outfit(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 4,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.blue.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              context.t('seller_assign_total_stock')
                                                  .replaceAll('{stock}', product.currentStock.toStringAsFixed(product.currentStock % 1 == 0 ? 0 : 2))
                                                  .replaceAll('{unit}', product.unit),
                                              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.w600),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: (product.currentStock - totalAssigned) <= 0
                                                  ? Colors.orange.withValues(alpha: 0.1)
                                                  : Colors.green.withValues(alpha: 0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              context.t('seller_assign_available')
                                                  .replaceAll('{max}', maxAssignable.toStringAsFixed(maxAssignable % 1 == 0 ? 0 : 2))
                                                  .replaceAll('{unit}', product.unit),
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: (product.currentStock - totalAssigned) <= 0 ? Colors.orange : Colors.green,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    decoration: InputDecoration(
                                      hintText: '0',
                                      labelText: context.t('seller_assign_label'),
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                                      suffixText: product.unit,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton.filled(
                                  icon: const Icon(Icons.check, size: 18),
                                  tooltip: context.t('seller_assign_save'),
                                  onPressed: () => _saveAssignment(
                                    provider,
                                    product.id,
                                    product.name,
                                    assigned,
                                  ),
                                ),
                              ],
                            ),
                            if (totalAssigned > 0) ...[
                              const SizedBox(height: 6),
                              Text(
                                context.t('seller_assign_distributed')
                                    .replaceAll('{total}', totalAssigned.toStringAsFixed(totalAssigned % 1 == 0 ? 0 : 2))
                                    .replaceAll('{stock}', product.currentStock.toStringAsFixed(product.currentStock % 1 == 0 ? 0 : 2))
                                    .replaceAll('{unit}', product.unit),
                                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                              ),
                            ],
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
