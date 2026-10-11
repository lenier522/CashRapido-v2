import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/seller.dart';
import '../../models/seller_inventory.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_icon_button.dart';
import 'seller_assign_products_screen.dart';
import 'seller_form_screen.dart';

/// Ficha del vendedor: identidad, resumen financiero real, ganancias e
/// inventario asignado. No agrega métricas nuevas; sólo presenta las que ya
/// calcula [BusinessProvider].
class SellerDetailScreen extends StatelessWidget {
  final Seller seller;

  const SellerDetailScreen({super.key, required this.seller});

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        // Se relee del provider en cada build para reflejar ediciones del
        // vendedor sin tener que reabrir la ficha. El nombre local oculta el
        // campo `seller` recibido por constructor.
        final Seller seller = provider.sellers.firstWhere(
          (s) => s.id == this.seller.id,
          orElse: () => this.seller,
        );
        final Color color = _avatarColor(seller.fullName);
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              CashIconButton(
                icon: Icons.edit_outlined,
                size: 40,
                iconSize: 20,
                tooltip: context.t('seller_edit'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerFormScreen(seller: seller),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              _buildHeader(context, color, seller),
              const SizedBox(height: AppSpacing.xxl),

              _SectionTitle(context.t('seller_financial_summary')),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: context.t('seller_sold'),
                      value: '\$${totalSales.toFormattedString(2)}',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.income,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MetricTile(
                      label: context.t('seller_to_sell'),
                      value: '\$${remainingValue.toFormattedString(2)}',
                      icon: Icons.inventory_2_outlined,
                      color: AppColors.warning,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _MetricTile(
                      label: context.t('seller_assigned_value'),
                      value: '\$${assignedValue.toFormattedString(2)}',
                      icon: Icons.assignment_outlined,
                      color: AppColors.info,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _MetricTile(
                      label: context.t('seller_commission'),
                      value: '\$${commission.toFormattedString(2)}',
                      icon: Icons.percent_rounded,
                      color: AppColors.purple,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),

              _SectionTitle(context.t('seller_earnings')),
              const SizedBox(height: AppSpacing.md),
              CashCard(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  children: [
                    _EarningRow(
                      context.t('seller_base_salary'),
                      monthlySalary,
                      AppColors.info,
                    ),
                    const Divider(height: AppSpacing.xl),
                    _EarningRow(
                      '${context.t('seller_commission')} (${seller.commissionRate}%)',
                      commission,
                      AppColors.purple,
                    ),
                    const Divider(height: AppSpacing.xl),
                    _EarningRow(
                      context.t('seller_total'),
                      totalEarnings,
                      AppColors.income,
                      bold: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              _SectionTitle(context.t('seller_assigned_inventory')),
              const SizedBox(height: AppSpacing.md),
              if (inv.isEmpty)
                _buildEmptyInventory(context)
              else
                for (final item in inv)
                  _AssignedProductTile(item: item, provider: provider),
              const SizedBox(height: AppSpacing.xxl),

              CashButton(
                label: context.t('seller_manage_inventory'),
                icon: const Icon(Icons.inventory_2_outlined, size: 20),
                type: CashButtonType.outlined,
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SellerAssignProductsScreen(seller: seller),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, Color color, Seller seller) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: isDark ? 0.26 : 0.15),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(seller.name, seller.lastName),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      seller.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (seller.role.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        seller.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.sm),
                    CashChip(
                      label: context.t(
                        seller.isActive ? 'seller_active' : 'seller_inactive',
                      ),
                      icon: seller.isActive
                          ? Icons.check_circle_rounded
                          : Icons.pause_circle_outline_rounded,
                      selected: true,
                      color: seller.isActive
                          ? AppColors.income
                          : AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_hasContact(seller)) ...[
            const Divider(height: AppSpacing.xl),
            _ContactRow(icon: Icons.phone_outlined, value: seller.phone),
            if (seller.email.isNotEmpty)
              _ContactRow(icon: Icons.email_outlined, value: seller.email),
            if (seller.ci.isNotEmpty)
              _ContactRow(icon: Icons.credit_card_outlined, value: seller.ci),
            if (seller.address.isNotEmpty)
              _ContactRow(
                icon: Icons.location_on_outlined,
                value: seller.address,
              ),
          ],
        ],
      ),
    );
  }

  bool _hasContact(Seller seller) =>
      seller.phone.isNotEmpty ||
      seller.email.isNotEmpty ||
      seller.ci.isNotEmpty ||
      seller.address.isNotEmpty;

  Widget _buildEmptyInventory(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 32,
            color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.t('seller_no_products'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: secondary),
          ),
        ],
      ),
    );
  }

  static String _initials(String name, String lastName) {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '';
    final second = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final result = '$first$second';
    return result.isEmpty ? '?' : result;
  }

  /// Color estable derivado del nombre (no cambia entre reconstrucciones).
  static Color _avatarColor(String name) {
    if (name.isEmpty) return AppColors.primary;
    int hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.45, 0.62).toColor();
  }
}

// ---------------------------------------------------------------------------
// AUXILIARES
// ---------------------------------------------------------------------------

class _SectionTitle extends StatelessWidget {
  final String label;

  const _SectionTitle(this.label);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: isDark ? AppColors.primary : AppColors.primaryDark,
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return CashCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      boxShadow: const [],
      border: Border.all(color: color.withValues(alpha: 0.22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: AppSpacing.sm),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall,
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
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            '\$${amount.toFormattedString(2)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String value;

  const _ContactRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Row(
        children: [
          Icon(icon, size: 16, color: secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedProductTile extends StatelessWidget {
  final SellerInventory item;
  final BusinessProvider provider;

  const _AssignedProductTile({required this.item, required this.provider});

  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    Product? product;
    try {
      product = provider.products.firstWhere((p) => p.id == item.productId);
    } catch (_) {}
    final price = product?.salePrice ?? 0;
    final unit = product?.unit ?? '';
    final itemValue = item.assignedQuantity * price;

    return CashCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: isDark ? 0.22 : 0.12),
              borderRadius: AppRadius.radiusMd,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 20,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${_formatQty(item.assignedQuantity)}${unit.isNotEmpty ? ' $unit' : ''}'
                  '  ·  \$${price.toFormattedString(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '\$${itemValue.toFormattedString(2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: AppColors.info,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
