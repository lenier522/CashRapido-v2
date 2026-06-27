import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/seller.dart';
import '../../models/product.dart';
import 'seller_form_screen.dart';
import 'seller_assign_products_screen.dart';
import 'package:cashrapido/utils/number_format_utils.dart';
import '../../services/localization_service.dart';

class SellerDetailScreen extends StatelessWidget {
  final Seller seller;

  const SellerDetailScreen({super.key, required this.seller});

  Color _colorFromName(String name) {
    final hash = name.hashCode;
    final hue = hash % 360;
    return HSVColor.fromAHSV(1, hue.toDouble(), 0.5, 0.8).toColor();
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFromName(seller.fullName);
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final totalSales = provider.getSellerTotalSales(seller.id);
        final assignedValue = provider.getSellerAssignedValue(seller.id);
        final remainingValue = provider.getSellerRemainingValue(seller.id);
        final commission = provider.calculateSellerCommission(seller.id);
        final monthlySalary = seller.salary;
        final totalEarnings = monthlySalary + commission;
        final inv = provider.getSellerInventoryBySeller(seller.id);

        return Scaffold(
          appBar: AppBar(
            title: Text(
              seller.fullName,
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerFormScreen(seller: seller),
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Center(
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: color,
                        child: Text(
                          '${seller.name[0].toUpperCase()}${seller.lastName[0].toUpperCase()}',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        seller.fullName,
                        style: GoogleFonts.outfit(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (seller.role.isNotEmpty)
                        Text(
                          seller.role,
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: seller.isActive
                              ? Colors.green.withOpacity(0.1)
                              : Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          seller.isActive ? context.t('seller_active') : context.t('seller_inactive'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: seller.isActive ? Colors.green : Colors.grey,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Financial Summary
                _SectionTitle(context.t('seller_financial_summary'), Icons.attach_money),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: context.t('seller_sold'),
                        value: '\$${totalSales.toFormattedString(2)}',
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: context.t('seller_to_sell'),
                        value: '\$${remainingValue.toFormattedString(2)}',
                        icon: Icons.inventory_2,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _MetricCard(
                        label: context.t('seller_assigned_value'),
                        value: '\$${assignedValue.toFormattedString(2)}',
                        icon: Icons.assignment,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MetricCard(
                        label: context.t('seller_commission'),
                        value: '\$${commission.toFormattedString(2)}',
                        icon: Icons.percent,
                        color: Colors.purple,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Earnings
                _SectionTitle(context.t('seller_earnings'), Icons.account_balance_wallet),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      _EarningRow(context.t('seller_base_salary'), monthlySalary, Colors.blue),
                      const Divider(),
                      _EarningRow('${context.t('seller_commission')} (${seller.commissionRate}%)', commission, Colors.purple),
                      const Divider(),
                      _EarningRow(context.t('seller_total'), totalEarnings, Colors.green, bold: true),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Assigned Inventory
                _SectionTitle(context.t('seller_assigned_inventory'), Icons.inventory_2_outlined),
                const SizedBox(height: 12),
                if (inv.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: Text(context.t('seller_no_products'))),
                  )
                else
                  ...inv.map((item) {
                    Product? product;
                    try {
                      product = provider.products.firstWhere(
                        (p) => p.id == item.productId,
                      );
                    } catch (_) {}
                    final price = product?.salePrice ?? 0;
                    final itemValue = item.assignedQuantity * price;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  '${item.assignedQuantity.toStringAsFixed(item.assignedQuantity % 1 == 0 ? 0 : 2)} x \$${price.toFormattedString(2)}',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '\$${itemValue.toFormattedString(2)}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[700],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                // Assign Products button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SellerAssignProductsScreen(seller: seller),
                        ),
                      );
                    },
                    icon: const Icon(Icons.inventory_2_outlined),
                    label: Text(context.t('seller_manage_inventory')),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String label;
  final IconData icon;
  const _SectionTitle(this.label, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          label,
          style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }
}

class _EarningRow extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  final bool bold;
  const _EarningRow(this.label, this.amount, this.color, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            '\$${amount.toFormattedString(2)}',
            style: GoogleFonts.outfit(
              fontWeight: bold ? FontWeight.bold : FontWeight.w600,
              fontSize: bold ? 16 : 14,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
