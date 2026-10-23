import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../providers/business_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/sale.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_dialog.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import 'pos_screen.dart';
import 'package:cashrapido/utils/number_format_utils.dart';
import '../../utils/receipt_helper.dart';

class SalesTab extends StatefulWidget {
  const SalesTab({super.key});

  @override
  State<SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<SalesTab> {
  String _dateFilter = 'all'; // 'all', 'today', 'week', 'month', 'custom'
  DateTime? _customStart;
  DateTime? _customEnd;
  bool _markingPaid = false;

  void _setDateFilter(String filter) {
    setState(() => _dateFilter = filter);
  }

  void _showDateRangePicker(BuildContext context) {
    showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: _customStart != null && _customEnd != null
          ? DateTimeRange(start: _customStart!, end: _customEnd!)
          : null,
    ).then((range) {
      if (!mounted) return;
      if (range != null) {
        setState(() {
          _dateFilter = 'custom';
          _customStart = range.start;
          _customEnd = range.end;
        });
      }
    });
  }

  List<Sale> _filterSales(List<Sale> sales) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    switch (_dateFilter) {
      case 'today':
        return sales
            .where(
              (s) => s.date.isAfter(
                todayStart.subtract(const Duration(seconds: 1)),
              ),
            )
            .toList();
      case 'week':
        final weekStart = todayStart.subtract(
          Duration(days: todayStart.weekday - 1),
        );
        return sales
            .where(
              (s) => s.date.isAfter(
                weekStart.subtract(const Duration(seconds: 1)),
              ),
            )
            .toList();
      case 'month':
        final monthStart = DateTime(now.year, now.month, 1);
        return sales
            .where(
              (s) => s.date.isAfter(
                monthStart.subtract(const Duration(seconds: 1)),
              ),
            )
            .toList();
      case 'custom':
        if (_customStart != null && _customEnd != null) {
          return sales
              .where(
                (s) =>
                    s.date.isAfter(
                      _customStart!.subtract(const Duration(seconds: 1)),
                    ) &&
                    s.date.isBefore(_customEnd!.add(const Duration(days: 1))),
              )
              .toList();
        }
        return sales;
      default:
        return sales;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final filteredSales = _filterSales(provider.sales);
        final sortedSales = List<Sale>.from(filteredSales)
          ..sort((a, b) => b.date.compareTo(a.date));

        final income = filteredSales.fold<double>(
          0.0,
          (sum, s) => sum + s.total,
        );

        return Column(
          children: [
            _buildFilterBar(context, income),
            Expanded(child: _buildSalesList(context, provider, sortedSales)),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // FILTROS Y RESUMEN
  // ---------------------------------------------------------------------------

  Widget _buildFilterBar(BuildContext context, double income) {
    final filters = [
      {
        'key': 'all',
        'label': 'sales_filter_all',
        'icon': Icons.storefront_outlined,
      },
      {
        'key': 'today',
        'label': 'sales_filter_today',
        'icon': Icons.today_outlined,
      },
      {
        'key': 'week',
        'label': 'sales_filter_week',
        'icon': Icons.date_range_outlined,
      },
      {
        'key': 'month',
        'label': 'sales_filter_month',
        'icon': Icons.calendar_month_outlined,
      },
      {
        'key': 'custom',
        'label': 'sales_filter_custom',
        'icon': Icons.tune_rounded,
      },
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: filters.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.sm),
              itemBuilder: (context, index) {
                final f = filters[index];
                final selected = _dateFilter == f['key'];
                return CashChip(
                  label: context.t(f['label'] as String),
                  icon: f['icon'] as IconData,
                  selected: selected,
                  onTap: () {
                    if (f['key'] == 'custom') {
                      _showDateRangePicker(context);
                    } else {
                      _setDateFilter(f['key'] as String);
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.income.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusSm,
                ),
                child: const Icon(
                  Icons.trending_up_rounded,
                  size: 18,
                  color: AppColors.income,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                context.t('sales_income_label'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  '\$${income.toFormattedString(2)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: AppColors.income,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LISTA DE VENTAS
  // ---------------------------------------------------------------------------

  Widget _buildSalesList(
    BuildContext context,
    BusinessProvider provider,
    List<Sale> sortedSales,
  ) {
    if (provider.sales.isEmpty) {
      return CashEmptyState(
        icon: Icons.storefront_outlined,
        title: context.t('sales_empty_title'),
        message: context.t('sales_empty_all_desc'),
      );
    }

    if (sortedSales.isEmpty) {
      return CashEmptyState(
        icon: Icons.event_busy_outlined,
        title: context.t('sales_empty_title'),
        message: context.t('sales_empty_filtered_desc'),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            88,
          ),
          itemCount: sortedSales.length,
          itemBuilder: (context, index) {
            final sale = sortedSales[index];
            return _buildSaleCard(context, provider, sale);
          },
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: CashFloatingButton(
            heroTag: 'pos_fab',
            icon: Icons.point_of_sale,
            label: context.t('pos_title'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PosScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaleCard(
    BuildContext context,
    BusinessProvider provider,
    Sale sale,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPending = sale.status == 'pending';
    final statusColor = isPending ? AppColors.warning : AppColors.income;
    final statusBg = isPending
        ? AppColors.warning.withValues(alpha: 0.12)
        : AppColors.income.withValues(alpha: 0.12);

    final String title = '\$${sale.total.toFormattedString(2)}';

    final List<String> detailParts = [
      '${DateFormat('dd/MM HH:mm').format(sale.date)} • ${sale.paymentMethod}',
      if (sale.clientName != null)
        '${context.t('sale_client_label')}: ${sale.clientName}',
      if (sale.sellerName != null && sale.sellerName!.isNotEmpty)
        '${context.t('sale_seller_label')}: ${sale.sellerName}',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: () => _showSaleDetail(context, provider, sale),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.md,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPending
                        ? Icons.access_time_rounded
                        : Icons.check_circle_rounded,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...detailParts
                          .take(2)
                          .map(
                            (part) => Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                part,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DETALLE DE VENTA
  // ---------------------------------------------------------------------------

  void _showSaleDetail(
    BuildContext context,
    BusinessProvider provider,
    Sale sale,
  ) {
    final isPending = sale.status == 'pending';
    final statusColor = isPending ? AppColors.warning : AppColors.income;
    final subtotal = sale.total + sale.discount;
    final currency = provider.activeBusiness?.currency ?? 'CUP';

    CashBottomSheet.show(
      context,
      builder: (context) => CashBottomSheet(
        title: context.t('sale_detail_title'),
        subtitle:
            '${DateFormat('dd/MM/yyyy HH:mm').format(sale.date)} • ${sale.paymentMethod}',
        trailing: CashChip(
          label: isPending
              ? context.t('sale_status_pending')
              : context.t('sale_status_paid'),
          selected: true,
          color: statusColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Datos identificativos
            _infoRow(
              context,
              context.t('sale_receipt_label'),
              sale.id.substring(0, 8).toUpperCase(),
            ),
            _infoRow(
              context,
              context.t('sale_payment_label'),
              sale.paymentMethod,
            ),
            if (sale.clientName != null)
              _infoRow(
                context,
                context.t('sale_client_label'),
                sale.clientName!,
              ),
            if (sale.sellerName != null && sale.sellerName!.isNotEmpty)
              _infoRow(
                context,
                context.t('sale_seller_label'),
                sale.sellerName!,
              ),
            const SizedBox(height: AppSpacing.md),

            // Artículos
            ...sale.items.map((item) {
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.productName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            '${_formatQty(item.quantity)} x \$${item.unitPrice.toFormattedString(2)}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '\$${item.subtotal.toFormattedString(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isPending ? AppColors.warning : AppColors.income,
                      ),
                    ),
                  ],
                ),
              );
            }),

            const SizedBox(height: AppSpacing.sm),
            Divider(color: Theme.of(context).dividerColor, height: 1),
            const SizedBox(height: AppSpacing.sm),

            // Resumen económico
            _summaryRow(
              context,
              context.t('pos_subtotal'),
              '\$${subtotal.toFormattedString(2)} $currency',
            ),
            if (sale.discount > 0)
              _summaryRow(
                context,
                context.t('sale_discount_label'),
                '-\$${sale.discount.toFormattedString(2)} $currency',
                valueColor: AppColors.error,
              ),
            const SizedBox(height: AppSpacing.xs),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    context.t('total'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    '\$${sale.total.toFormattedString(2)} $currency',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),

            // Acciones
            CashButton(
              label: context.t('sale_share_label'),
              icon: const Icon(Icons.share_outlined, size: 18),
              type: CashButtonType.secondary,
              onPressed: () {
                final activeBusiness = provider.activeBusiness;
                if (activeBusiness != null) {
                  ReceiptHelper.shareReceipt(context, sale, activeBusiness);
                }
              },
            ),
            const SizedBox(height: AppSpacing.md),
            if (sale.status == 'pending')
              CashButton(
                label: context.t('sale_mark_paid_label'),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                onPressed: () async {
                  if (_markingPaid) return;
                  _markingPaid = true;
                  try {
                    final appProvider = Provider.of<AppProvider>(
                      context,
                      listen: false,
                    );
                    await provider.markSaleAsPaid(
                      sale.id,
                      appProvider: appProvider,
                    );
                    if (context.mounted) Navigator.pop(context);
                  } finally {
                    _markingPaid = false;
                  }
                },
              )
            else
              CashButton(
                label: context.t('sale_delete_label'),
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                type: CashButtonType.danger,
                onPressed: () async {
                  final confirm = await showCashConfirmDialog(
                    context,
                    title: context.t('delete_sale_confirm_title'),
                    message: context.t('delete_sale_confirm_msg'),
                    confirmLabel: context.t('sale_delete_label'),
                    cancelLabel: context.t('cancel'),
                    icon: Icons.delete_outline_rounded,
                  );
                  if (confirm == true && context.mounted) {
                    final appProvider = Provider.of<AppProvider>(
                      context,
                      listen: false,
                    );
                    await provider.deleteSale(
                      sale.id,
                      appProvider: appProvider,
                    );
                    if (context.mounted) Navigator.pop(context);
                  }
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: isDark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color effectiveColor =
        valueColor ??
        (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                color: effectiveColor,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
}
