import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/closing.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/export_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_amount_input.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_progress_bar.dart';
import '../../widgets/design/cash_selector_field.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

/// Pestaña de cierres del negocio.
///
/// Conserva el comportamiento original: listado histórico, detalle por cierre,
/// exportación a PDF/Excel, transferencia de la ganancia neta y generación de
/// nuevos cierres con el mismo cálculo y periodo.
class ClosingsTab extends StatelessWidget {
  const ClosingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final closings = provider.closings.reversed.toList();

        return Scaffold(
          backgroundColor: AppColors.transparent,
          body: closings.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    96,
                  ),
                  itemCount: closings.length,
                  itemBuilder: (context, index) {
                    return _ClosingCard(
                      closing: closings[index],
                      provider: provider,
                    );
                  },
                ),
          floatingActionButton: CashFloatingButton(
            heroTag: 'closing_fab',
            icon: Icons.assessment_outlined,
            label: context.t('closing_generate'),
            onPressed: () => _showGenerateClosingModal(context, provider),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CashEmptyState(
      icon: Icons.analytics_outlined,
      title: context.t('closing_empty_title'),
      message: context.t('closing_empty_desc'),
    );
  }

  void _showGenerateClosingModal(
    BuildContext context,
    BusinessProvider provider,
  ) {
    CashBottomSheet.show(
      context,
      builder: (context) => _GenerateClosingSheet(provider: provider),
    );
  }
}

// ──────────────────────────────────────────────
// Closing Card with full detailed report
// ──────────────────────────────────────────────
class _ClosingCard extends StatelessWidget {
  final Closing closing;
  final BusinessProvider provider;

  const _ClosingCard({required this.closing, required this.provider});

  Color get _periodColor {
    switch (closing.period.toLowerCase()) {
      case 'diario':
        return AppColors.info;
      case 'semanal':
        return AppColors.warning;
      case 'mensual':
        return AppColors.purple;
      default:
        return AppColors.primary;
    }
  }

  IconData get _periodIcon {
    switch (closing.period.toLowerCase()) {
      case 'diario':
        return Icons.today;
      case 'semanal':
        return Icons.date_range;
      case 'mensual':
        return Icons.calendar_month;
      default:
        return Icons.insert_chart;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final color = _periodColor;
    final profitColor = closing.profit >= 0
        ? AppColors.income
        : AppColors.expense;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final appProvider = Provider.of<AppProvider>(context);

    return Dismissible(
      key: Key(closing.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        bool confirmed = false;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(context.t('closing_delete_title')),
            content: Text(context.t('closing_delete_confirm')),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.t('cancel')),
              ),
              CashButton(
                label: context.t('delete'),
                type: CashButtonType.danger,
                fullWidth: false,
                height: 44,
                onPressed: () {
                  confirmed = true;
                  Navigator.pop(ctx);
                },
              ),
            ],
          ),
        );
        return confirmed;
      },
      onDismissed: (_) => provider.deleteClosing(closing.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: AppColors.expense,
          borderRadius: AppRadius.radiusXl,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete_outline, color: AppColors.white),
            const SizedBox(height: AppSpacing.xs),
            Text(
              context.t('delete'),
              style: theme.textTheme.labelSmall?.copyWith(
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
      child: CashCard(
        margin: const EdgeInsets.only(bottom: AppSpacing.lg),
        padding: EdgeInsets.zero,
        child: Theme(
          data: theme.copyWith(dividerColor: AppColors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            childrenPadding: EdgeInsets.zero,
            iconColor: color,
            collapsedIconColor: secondary,
            leading: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_periodIcon, color: color, size: 22),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    closing.period,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xxs,
                  ),
                  decoration: BoxDecoration(
                    color: profitColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    closing.profit >= 0
                        ? context.t('closing_profit')
                        : context.t('closing_loss'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: profitColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xxs),
              child: Text(
                '${DateFormat('dd MMM yyyy – HH:mm').format(closing.startDate)}  →  ${DateFormat('dd MMM yyyy – HH:mm').format(closing.endDate)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(color: secondary),
              ),
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Summary (income / expenses / gross profit) ──
                    _SummaryRow(closing: closing),
                    const SizedBox(height: AppSpacing.lg),

                    // ── Extra stats row ──
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatCard(
                            icon: Icons.shopping_bag_outlined,
                            label: context.t('closing_sales_label'),
                            value: '${closing.salesCount}',
                            color: AppColors.income,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _MiniStatCard(
                            icon: Icons.receipt_long,
                            label: context.t('closing_expenses_count_label'),
                            value: '${closing.expensesCount}',
                            color: AppColors.expense,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: _MiniStatCard(
                            icon: Icons.trending_up,
                            label: context.t('closing_roi_label'),
                            value: '${closing.roi.toFormattedString(1)}%',
                            color: AppColors.info,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSpacing.md),
                    _InfoRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: context.t('net_profit'),
                      value:
                          '${closing.netProfit < 0 ? '-\$' : '\$'}${closing.netProfit.abs().toFormattedString(2)}',
                      color: closing.netProfit >= 0
                          ? AppColors.income
                          : AppColors.expense,
                    ),

                    if (closing.totalDiscounts > 0) ...[
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.discount_outlined,
                        label: context.t('closing_discounts'),
                        value:
                            '\$${closing.totalDiscounts.toFormattedString(2)}',
                        color: AppColors.warning,
                      ),
                    ],

                    // ── Best Seller ──
                    if (closing.bestSellerName.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      _SectionTitle(
                        icon: Icons.star,
                        label: context.t('closing_best_seller'),
                        color: AppColors.warning,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _InfoRow(
                        icon: Icons.inventory_2_outlined,
                        label: closing.bestSellerName,
                        value: context
                            .t('closing_units')
                            .replaceAll('{qty}', '${closing.bestSellerQty}'),
                        color: AppColors.warning,
                      ),
                    ],

                    // ── Sold Products ──
                    _SoldProductsSection(jsonData: closing.soldProductsJson),

                    // ── Added Products ──
                    _AddedProductsSection(jsonData: closing.addedProductsJson),

                    // ── Payment Methods ──
                    _PaymentMethodsSection(
                      jsonData: closing.paymentMethodsJson,
                    ),

                    // ── Expense Categories ──
                    _ExpenseCategoriesSection(
                      jsonData: closing.expenseCategoriesJson,
                    ),

                    // ── Seller Stats ──
                    _SellerStatsSection(jsonData: closing.sellerStatsJson),

                    // ── Export Buttons ──
                    const SizedBox(height: AppSpacing.xl),
                    _ClosingExportButtons(closing: closing, provider: provider),

                    // ── Transfer Profit (only when net profit > 0) ──
                    if (closing.netProfit > 0) ...[
                      const SizedBox(height: AppSpacing.md),
                      _TransferProfitButton(
                        closing: closing,
                        provider: provider,
                        appProvider: appProvider,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Export buttons for a Closing
// ──────────────────────────────────────────────
class _ClosingExportButtons extends StatefulWidget {
  final Closing closing;
  final BusinessProvider provider;

  const _ClosingExportButtons({required this.closing, required this.provider});

  @override
  State<_ClosingExportButtons> createState() => _ClosingExportButtonsState();
}

class _ClosingExportButtonsState extends State<_ClosingExportButtons> {
  bool _exportingPdf = false;
  bool _exportingXls = false;
  final _exportService = ExportService();

  String get _businessName =>
      widget.provider.activeBusiness?.name ??
      context.t('closing_business_fallback');

  String get _mainCurrency => widget.provider.mainCurrency;

  Future<void> _exportPdf() async {
    setState(() => _exportingPdf = true);
    try {
      final path = await _exportService.exportBusinessClosingToPDF(
        closing: widget.closing,
        businessName: _businessName,
        mainCurrency: _mainCurrency,
      );
      if (mounted) _showSuccessBar(context.t('closing_pdf_generated'), path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.t('closing_export_pdf_error')}: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _exportXls() async {
    setState(() => _exportingXls = true);
    try {
      final path = await _exportService.exportBusinessClosingToExcel(
        closing: widget.closing,
        businessName: _businessName,
        mainCurrency: _mainCurrency,
      );
      if (mounted) _showSuccessBar(context.t('closing_excel_generated'), path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.t('closing_export_excel_error')}: $e'),
            backgroundColor: AppColors.expense,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportingXls = false);
    }
  }

  void _showSuccessBar(String label, String path) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context
              .t('closing_export_ready')
              .replaceAll('{label}', label)
              .replaceAll('{path}', path),
        ),
        backgroundColor: AppColors.income,
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: context.t('closing_share'),
          textColor: AppColors.white,
          onPressed: () => _exportService.shareFile(path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return CashCard(
      color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceVariantLight,
      boxShadow: const [],
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            icon: Icons.ios_share,
            label: context.t('closing_export_title'),
            color: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: CashButton(
                  label: 'PDF',
                  type: CashButtonType.outlined,
                  height: 46,
                  loading: _exportingPdf,
                  icon: const Icon(
                    Icons.picture_as_pdf_outlined,
                    size: 18,
                    color: AppColors.expense,
                  ),
                  onPressed: _exportingPdf ? null : _exportPdf,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: CashButton(
                  label: 'Excel',
                  type: CashButtonType.outlined,
                  height: 46,
                  loading: _exportingXls,
                  icon: const Icon(
                    Icons.table_chart_outlined,
                    size: 18,
                    color: AppColors.income,
                  ),
                  onPressed: _exportingXls ? null : _exportXls,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Summary Row: Income / Expenses / Profit
// ──────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final Closing closing;
  const _SummaryRow({required this.closing});

  @override
  Widget build(BuildContext context) {
    final profitColor = closing.profit >= 0
        ? AppColors.income
        : AppColors.expense;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                label: context.t('closing_income_label'),
                value: closing.income,
                color: AppColors.income,
                icon: Icons.arrow_upward,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _SummaryCard(
                label: context.t('closing_expenses_label'),
                value: closing.expenses,
                color: AppColors.expense,
                icon: Icons.arrow_downward,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: profitColor.withValues(alpha: 0.09),
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: profitColor.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(
                closing.profit >= 0 ? Icons.trending_up : Icons.trending_down,
                color: profitColor,
                size: 18,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.t('gross_profit'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    '${closing.profit < 0 ? '-\$' : '\$'}${closing.profit.abs().toFormattedString(2)}',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: profitColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              '${value < 0 ? '-\$' : '\$'}${value.abs().toFormattedString(2)}',
              maxLines: 1,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Mini Stat Card
// ──────────────────────────────────────────────
class _MiniStatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.sm,
        horizontal: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: AppRadius.radiusSm,
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textSecondaryDark
                  : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Section Title
// ──────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _SectionTitle({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Info Row
// ──────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
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
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Sold Products Section
// ──────────────────────────────────────────────
class _SoldProductsSection extends StatelessWidget {
  final String jsonData;
  const _SoldProductsSection({required this.jsonData});

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    try {
      final decoded = jsonDecode(jsonData);
      if (decoded is List) items = decoded;
    } catch (_) {}

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(
          icon: Icons.sell_outlined,
          label: context.t('closing_products_sold'),
          color: AppColors.income,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.map((item) {
          if (item is! Map) return const SizedBox.shrink();
          final name = item['name'] as String? ?? '—';
          final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
          final qtyStr = qty % 1 == 0
              ? qty.toInt().toString()
              : qty.toStringAsFixed(2);
          final revenue = (item['revenue'] as num?)?.toDouble() ?? 0.0;
          return _ProgressRow(
            label: name,
            valueLabel:
                '${context.t('closing_units').replaceAll('{qty}', qtyStr)}  ·  \$${revenue.toFormattedString(2)}',
            value: 0,
            color: AppColors.income,
            showBar: false,
          );
        }),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Added Products Section
// ──────────────────────────────────────────────
class _AddedProductsSection extends StatelessWidget {
  final String jsonData;
  const _AddedProductsSection({required this.jsonData});

  @override
  Widget build(BuildContext context) {
    List<dynamic> items = [];
    try {
      final decoded = jsonDecode(jsonData);
      if (decoded is List) items = decoded;
    } catch (_) {}

    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(
          icon: Icons.add_box_outlined,
          label: context.t('closing_products_added'),
          color: AppColors.secondary,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...items.map((item) {
          if (item is! Map) return const SizedBox.shrink();
          final name = item['name'] as String? ?? '—';
          final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
          final qtyStr = qty % 1 == 0
              ? qty.toInt().toString()
              : qty.toStringAsFixed(2);
          final cost = (item['cost'] as num?)?.toDouble() ?? 0.0;
          return _ProgressRow(
            label: name,
            valueLabel:
                '${context.t('closing_units').replaceAll('{qty}', qtyStr)}  ·  \$${cost.toFormattedString(2)}/u',
            value: 0,
            color: AppColors.secondary,
            showBar: false,
          );
        }),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Payment Methods Section
// ──────────────────────────────────────────────
class _PaymentMethodsSection extends StatelessWidget {
  final String jsonData;
  const _PaymentMethodsSection({required this.jsonData});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(jsonData);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.values.fold<double>(0.0, (s, v) {
      if (v is num) return s + v.toDouble();
      return s + (double.tryParse(v.toString()) ?? 0.0);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(
          icon: Icons.payment,
          label: context.t('closing_payment_methods'),
          color: AppColors.info,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...data.entries.map((entry) {
          final method = entry.key;
          final amount = (entry.value is num)
              ? (entry.value as num).toDouble()
              : (double.tryParse(entry.value.toString()) ?? 0.0);
          final pct = total > 0
              ? (amount / total * 100).toStringAsFixed(0)
              : '0';
          return _ProgressRow(
            label: method,
            valueLabel: '\$${amount.toFormattedString(2)} ($pct%)',
            value: total > 0 ? amount / total : 0,
            color: AppColors.info,
          );
        }),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Expense Categories Section
// ──────────────────────────────────────────────
class _ExpenseCategoriesSection extends StatelessWidget {
  final String jsonData;
  const _ExpenseCategoriesSection({required this.jsonData});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(jsonData);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.values.fold<double>(0.0, (s, v) {
      if (v is num) return s + v.toDouble();
      return s + (double.tryParse(v.toString()) ?? 0.0);
    });

    const colors = [
      AppColors.expense,
      AppColors.orange,
      AppColors.purple,
      AppColors.info,
      AppColors.warning,
      AppColors.secondary,
    ];
    int colorIdx = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(
          icon: Icons.pie_chart_outline,
          label: context.t('closing_expense_categories'),
          color: AppColors.expense,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...data.entries.map((entry) {
          final category = entry.key;
          final amount = (entry.value is num)
              ? (entry.value as num).toDouble()
              : (double.tryParse(entry.value.toString()) ?? 0.0);
          final pct = total > 0
              ? (amount / total * 100).toStringAsFixed(0)
              : '0';
          final color = colors[colorIdx % colors.length];
          colorIdx++;
          return _ProgressRow(
            label: category,
            valueLabel: '\$${amount.toFormattedString(2)} ($pct%)',
            value: total > 0 ? amount / total : 0,
            color: color,
          );
        }),
      ],
    );
  }
}

// ──────────────────────────────────────────────
// Seller Stats Section
// ──────────────────────────────────────────────
class _SellerStatsSection extends StatelessWidget {
  final String jsonData;
  const _SellerStatsSection({required this.jsonData});

  @override
  Widget build(BuildContext context) {
    Map<String, dynamic> data = {};
    try {
      final decoded = jsonDecode(jsonData);
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {}

    if (data.isEmpty) return const SizedBox.shrink();

    final total = data.values.fold<double>(0.0, (s, v) {
      if (v is Map) {
        return s + ((v['total'] as num?)?.toDouble() ?? 0.0);
      } else if (v is num) {
        return s + v.toDouble();
      }
      return s;
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.lg),
        _SectionTitle(
          icon: Icons.people_outline,
          label: context.t('closing_by_seller'),
          color: AppColors.purple,
        ),
        const SizedBox(height: AppSpacing.sm),
        ...data.entries.map((entry) {
          final name = entry.key;
          double amount = 0.0;
          int count = 0;
          if (entry.value is Map) {
            final stats = entry.value as Map<String, dynamic>;
            amount = (stats['total'] as num?)?.toDouble() ?? 0.0;
            count = (stats['count'] as num?)?.toInt() ?? 0;
          } else if (entry.value is num) {
            amount = (entry.value as num).toDouble();
            count = 1;
          }
          final pct = total > 0
              ? (amount / total * 100).toStringAsFixed(0)
              : '0';
          return _ProgressRow(
            label: name,
            valueLabel: '$count  ·  \$${amount.toFormattedString(2)} ($pct%)',
            value: total > 0 ? amount / total : 0,
            color: AppColors.purple,
          );
        }),
      ],
    );
  }
}

/// Fila con barra de proporción opcional. Se reutiliza para los desgloses que
/// representan partes de un total y para listas simples (productos vendidos).
class _ProgressRow extends StatelessWidget {
  final String label;
  final String valueLabel;
  final double value;
  final Color color;
  final bool showBar;

  const _ProgressRow({
    required this.label,
    required this.valueLabel,
    required this.value,
    required this.color,
    this.showBar = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBar) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Row(
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
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
                valueLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: CashProgressBar(
        value: value,
        color: color,
        label: label,
        valueLabel: valueLabel,
        valueColor: color,
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Generate Closing Sheet
// ──────────────────────────────────────────────
class _GenerateClosingSheet extends StatefulWidget {
  final BusinessProvider provider;
  const _GenerateClosingSheet({required this.provider});

  @override
  State<_GenerateClosingSheet> createState() => _GenerateClosingSheetState();
}

class _GenerateClosingSheetState extends State<_GenerateClosingSheet> {
  String _selectedPeriod = 'daily';
  Map<String, double>? _previewStats;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _calculateStats();
  }

  void _calculateStats() {
    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = now;
    }

    // Subtract 1 second to include records right at midnight
    final effectiveStart = startDate.subtract(const Duration(seconds: 1));
    final stats = widget.provider.calculatePeriodStats(effectiveStart, now);
    if (mounted) {
      setState(() => _previewStats = stats);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CashBottomSheet(
      title: context.t('closing_generate'),
      trailing: IconButton(
        icon: const Icon(Icons.close),
        onPressed: () => Navigator.pop(context),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Period Selector
          _SegmentedPeriod(
            selected: _selectedPeriod,
            options: [
              _SegmentOption('daily', context.t('freq_daily')),
              _SegmentOption('weekly', context.t('freq_weekly')),
              _SegmentOption('monthly', context.t('freq_monthly')),
            ],
            onChanged: (value) {
              setState(() => _selectedPeriod = value);
              _calculateStats();
            },
          ),
          const SizedBox(height: AppSpacing.xl),

          // Preview
          if (_previewStats != null)
            CashCard(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark2
                  : AppColors.surfaceVariantLight,
              boxShadow: const [],
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  Text(
                    context.t('closing_preview'),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildPreviewStat(
                        context.t('closing_income_label'),
                        _previewStats!['income'] ?? 0.0,
                        AppColors.income,
                      ),
                      _buildPreviewStat(
                        context.t('closing_expenses_label'),
                        _previewStats!['expenses'] ?? 0.0,
                        AppColors.expense,
                      ),
                      _buildPreviewStat(
                        context.t('net_profit'),
                        _previewStats!['profit'] ?? 0.0,
                        AppColors.info,
                      ),
                    ],
                  ),
                ],
              ),
            ),

          const SizedBox(height: AppSpacing.xl),
          CashButton(
            label: context.t('closing_confirm_save'),
            loading: _isSaving,
            onPressed: _isSaving ? null : _saveClosing,
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewStat(String label, double value, Color color) {
    return Column(
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          '${value < 0 ? '-\$' : '\$'}${value.abs().toFormattedString(2)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Future<void> _saveClosing() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final now = DateTime.now();
    DateTime startDate;

    switch (_selectedPeriod) {
      case 'daily':
        startDate = DateTime(now.year, now.month, now.day);
        break;
      case 'weekly':
        startDate = now.subtract(Duration(days: now.weekday - 1));
        startDate = DateTime(startDate.year, startDate.month, startDate.day);
        break;
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        break;
      default:
        startDate = now;
    }

    final effectiveStart = startDate.subtract(const Duration(seconds: 1));

    String label = context.t('freq_daily');
    if (_selectedPeriod == 'weekly') label = context.t('freq_weekly');
    if (_selectedPeriod == 'monthly') label = context.t('freq_monthly');

    try {
      await widget.provider.createClosing(
        period: label,
        startDate: effectiveStart,
        endDate: now,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('closing_generated_ok')),
          backgroundColor: AppColors.income,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('closing_generated_error')}: $e'),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }
}

// ──────────────────────────────────────────────
// Segmented period selector
// ──────────────────────────────────────────────
class _SegmentOption {
  final String value;
  final String label;
  const _SegmentOption(this.value, this.label);
}

class _SegmentedPeriod extends StatelessWidget {
  final String selected;
  final List<_SegmentOption> options;
  final ValueChanged<String> onChanged;

  const _SegmentedPeriod({
    required this.selected,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceVariantLight,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: options.map((option) {
          final bool isSelected = selected == option.value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(option.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.transparent,
                  borderRadius: AppRadius.radiusMd,
                ),
                child: Text(
                  option.label,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: isSelected
                        ? AppColors.white
                        : (isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Transfer Profit to Personal Account
// ──────────────────────────────────────────────
class _TransferProfitButton extends StatelessWidget {
  final Closing closing;
  final BusinessProvider provider;
  final AppProvider appProvider;

  const _TransferProfitButton({
    required this.closing,
    required this.provider,
    required this.appProvider,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = closing.netProfit - closing.transferredAmount;
    final fullyTransferred =
        closing.transferredAmount >= closing.netProfit - 0.005;

    // Already fully transferred -> static badge
    if (fullyTransferred) {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.income.withValues(alpha: 0.12),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.income.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, size: 18, color: AppColors.income),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                context.t('transfer_profit_fully_transferred'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.income,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final bool hasAccounts = appProvider.cards.isNotEmpty;

    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: () {
          if (!hasAccounts) return;
          CashBottomSheet.show(
            context,
            builder: (ctx) => _TransferProfitSheet(
              closing: closing,
              provider: provider,
              appProvider: appProvider,
            ),
          );
        },
        borderRadius: AppRadius.radiusMd,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: hasAccounts
                ? AppColors.primary
                : (Theme.of(context).brightness == Brightness.dark
                      ? AppColors.surfaceDark3
                      : AppColors.surfaceVariantLight),
            borderRadius: AppRadius.radiusMd,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet,
                    size: 18,
                    color: hasAccounts
                        ? AppColors.white
                        : AppColors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      context.t('transfer_profit_button'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: hasAccounts
                            ? AppColors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                hasAccounts
                    ? context
                          .t('transfer_profit_available')
                          .replaceAll(
                            '{amount}',
                            '\$${remaining.toFormattedString(2)}',
                          )
                    : context.t('transfer_profit_no_accounts'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: hasAccounts
                      ? AppColors.white.withValues(alpha: 0.85)
                      : AppColors.textSecondary,
                ),
              ),
              // Show partial-transfer progress line when relevant
              if (closing.transferredAmount > 0) ...[
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  context
                      .t('transfer_profit_partial')
                      .replaceAll(
                        '{transferred}',
                        '\$${closing.transferredAmount.toFormattedString(2)}',
                      )
                      .replaceAll(
                        '{total}',
                        '\$${closing.netProfit.toFormattedString(2)}',
                      ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: hasAccounts
                        ? AppColors.white.withValues(alpha: 0.85)
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferProfitSheet extends StatefulWidget {
  final Closing closing;
  final BusinessProvider provider;
  final AppProvider appProvider;

  const _TransferProfitSheet({
    required this.closing,
    required this.provider,
    required this.appProvider,
  });

  @override
  State<_TransferProfitSheet> createState() => _TransferProfitSheetState();
}

class _TransferProfitSheetState extends State<_TransferProfitSheet> {
  String? _targetCardId;
  final _amountController = TextEditingController();
  final _rateController = TextEditingController(text: '1.0');
  bool _saving = false;

  double get _remaining =>
      widget.closing.netProfit - widget.closing.transferredAmount;

  double get _rate => double.tryParse(_rateController.text) ?? 1.0;

  AccountCard? get _targetCard {
    final id = _targetCardId;
    if (id == null) return null;
    for (final c in widget.appProvider.cards) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final cards = widget.appProvider.cards;
    if (cards.isNotEmpty) _targetCardId = cards.first.id;
    _amountController.text = _remaining % 1 == 0
        ? _remaining.toInt().toString()
        : _remaining.toString();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _rateController.dispose();
    super.dispose();
  }

  bool _needsRate(BuildContext context) {
    final card = _targetCard;
    if (card == null) return false;
    final businessCurrency =
        widget.provider.activeBusiness?.currency ??
        widget.appProvider.mainCurrency;
    return card.currency != businessCurrency;
  }

  String _cardLabel(AccountCard c) {
    final String origin = c.isCash ? c.name : (c.bankName ?? 'Tarjeta');
    final String number;
    if (c.isCash) {
      number = 'CASH';
    } else {
      number = c.cardNumber.length >= 4
          ? c.cardNumber.substring(c.cardNumber.length - 4)
          : c.cardNumber;
    }
    return '$origin (...$number) - ${c.currency}';
  }

  Future<void> _pickAccount(BuildContext context) async {
    final selected = await CashBottomSheet.show<AccountCard>(
      context,
      builder: (ctx) => CashBottomSheet(
        title: context.t('transfer_profit_select_account'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final c in widget.appProvider.cards)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  c.isCash
                      ? Icons.payments_outlined
                      : Icons.credit_card_outlined,
                  color: AppColors.primary,
                ),
                title: Text(
                  _cardLabel(c),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: c.id == _targetCardId
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, c),
              ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() => _targetCardId = selected.id);
    }
  }

  Future<void> _confirm() async {
    if (_saving) return;
    final amount = double.tryParse(_amountController.text) ?? 0.0;
    final remaining = _remaining;

    if (_targetCard == null || amount <= 0 || amount > remaining + 0.005) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('transfer_profit_error')),
          backgroundColor: AppColors.expense,
        ),
      );
      return;
    }

    final provider = widget.provider;
    final businessName =
        provider.activeBusiness?.name ?? context.t('closing_business_fallback');
    final title = context
        .t('transfer_profit_title_tx')
        .replaceAll('{name}', businessName);

    setState(() => _saving = true);
    final error = await provider.transferProfitToAccount(
      closingId: widget.closing.id,
      targetCardId: _targetCardId!,
      amount: amount,
      exchangeRate: _rate,
      title: title,
      appProvider: widget.appProvider,
    );
    if (!mounted) return;

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('transfer_profit_success')),
          backgroundColor: AppColors.income,
        ),
      );
      Navigator.pop(context);
    } else {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.t('transfer_profit_error')),
          backgroundColor: AppColors.expense,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final businessName =
        widget.provider.activeBusiness?.name ??
        context.t('closing_business_fallback');
    final businessCurrency =
        widget.provider.activeBusiness?.currency ??
        widget.appProvider.mainCurrency;
    final AccountCard? card = _targetCard;
    final bool needsRate = _needsRate(context);

    return CashBottomSheet(
      title: context.t('transfer_profit_button'),
      subtitle: context
          .t('transfer_profit_title_tx')
          .replaceAll('{name}', businessName),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Profit summary ──
          _InfoRow(
            icon: Icons.trending_up,
            label: context.t('net_profit'),
            value:
                '\$${widget.closing.netProfit.toFormattedString(2)} ($businessCurrency)',
            color: AppColors.income,
          ),
          const SizedBox(height: AppSpacing.xs),
          _InfoRow(
            icon: Icons.savings_outlined,
            label: context.t('transfer_profit_available'),
            value: '\$${_remaining.toFormattedString(2)}',
            color: AppColors.primary,
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Destination account ──
          CashSelectorField(
            label: context.t('transfer_profit_select_account'),
            value: card == null ? null : _cardLabel(card),
            placeholder: context.t('transfer_profit_select_account'),
            icon: Icons.wallet_outlined,
            onTap: () => _pickAccount(context),
          ),

          const SizedBox(height: AppSpacing.lg),

          // ── Amount ──
          CashAmountInput(
            controller: _amountController,
            label: context.t('transfer_profit_amount'),
            symbol: '\$',
            code: businessCurrency,
            isExpense: false,
            fontSize: 32,
            compact: true,
          ),

          // ── Exchange rate when currencies differ ──
          if (needsRate) ...[
            const SizedBox(height: AppSpacing.lg),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 16,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    context.t('transfer_profit_exchange_rate'),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.warning),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            CashInput(
              controller: _rateController,
              label: context.t('transfer_profit_exchange_rate'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // ── Confirm ──
          CashButton(
            label: context.t('transfer_profit_confirm'),
            loading: _saving,
            onPressed: () => _confirm(),
          ),
        ],
      ),
    );
  }
}
