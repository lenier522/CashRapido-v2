import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import 'pos_screen.dart';
import 'package:cashrapido/utils/number_format_utils.dart';
import '../../utils/receipt_helper.dart';

class SalesTab extends StatelessWidget {
  const SalesTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        if (provider.sales.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.point_of_sale_rounded,
                    size: 60,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  context.t('no_sales'),
                  style: GoogleFonts.outfit(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('no_sales_desc'),
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        final sortedSales = provider.sales
          ..sort((a, b) => b.date.compareTo(a.date));

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
              itemCount: sortedSales.length,
              itemBuilder: (context, index) {
                final sale = sortedSales[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: ExpansionTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: sale.status == 'pending' 
                            ? Colors.orange.withOpacity(0.1) 
                            : Colors.green.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        sale.status == 'pending' ? Icons.access_time : Icons.check_circle,
                        color: sale.status == 'pending' ? Colors.orange : Colors.green,
                        size: 24,
                      ),
                    ),
                    title: Text(
                      '\$${sale.total.toFormattedString(2)}',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: sale.status == 'pending' ? Colors.orange[700] : Colors.green[700],
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${DateFormat('dd/MM HH:mm').format(sale.date)} • ${sale.paymentMethod}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        if (sale.clientName != null)
                          Text(
                            'Cliente: ${sale.clientName}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.bold),
                          ),
                      ],
                    ),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    children: [
                      ...sale.items.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.productName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    '${item.quantity} x \$${item.unitPrice.toFormattedString(2)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '\$${item.subtotal.toFormattedString(2)}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                      if (sale.discount > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Descuento', style: TextStyle(color: Colors.red)),
                              Text('-\$${sale.discount.toFormattedString(2)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton.icon(
                            onPressed: () {
                              final activeBusiness = provider.activeBusiness;
                              if (activeBusiness != null) {
                                ReceiptHelper.shareReceipt(context, sale, activeBusiness);
                              }
                            },
                            icon: const Icon(Icons.share, size: 18),
                            label: const Text('Compartir'),
                          ),
                          if (sale.status == 'pending')
                            ElevatedButton.icon(
                              onPressed: () => provider.markSaleAsPaid(sale.id),
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Marcar Pagado'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                              ),
                            )
                          else
                            TextButton.icon(
                              onPressed: () => provider.deleteSale(sale.id),
                              icon: const Icon(Icons.delete, size: 18, color: Colors.red),
                              label: const Text('Eliminar', style: TextStyle(color: Colors.red)),
                            ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                heroTag: 'pos_fab',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PosScreen()),
                  );
                },
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.point_of_sale),
                label: Text(context.t('pos_title')),
                elevation: 4,
              ),
            ),
          ],
        );
      },
    );
  }
}
