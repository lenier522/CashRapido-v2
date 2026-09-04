import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import '../../providers/business_provider.dart';
import '../../providers/app_provider.dart';
import '../../models/closing.dart';
import '../../models/seller.dart';
import '../../services/export_service.dart';
import '../../services/localization_service.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class ClosingsTab extends StatelessWidget {
  const ClosingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final closings = provider.closings.reversed.toList();

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: closings.isEmpty
              ? _buildEmptyState(context)
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                  itemCount: closings.length,
                  itemBuilder: (context, index) {
                    return _ClosingCard(
                      closing: closings[index],
                      provider: provider,
                    );
                  },
                ),
          floatingActionButton: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              FloatingActionButton.extended(
                heroTag: 'closing_import_fab',
                onPressed: () => _showImportSellerClosingModal(context, provider),
                backgroundColor: Colors.blue[700],
                foregroundColor: Colors.white,
                icon: const Icon(Icons.upload_file),
                label: Text(context.t('closing_import')),
              ),
              const SizedBox(height: 12),
              FloatingActionButton.extended(
                heroTag: 'closing_fab',
                onPressed: () => _showGenerateClosingModal(context, provider),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                icon: const Icon(Icons.assessment_outlined),
                label: Text(context.t('closing_generate')),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blueGrey.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.analytics_outlined, size: 64, color: Colors.blueGrey[300]),
          ),
          const SizedBox(height: 16),
          Text(
            context.t('closing_empty_title'),
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.t('closing_empty_desc'),
            style: TextStyle(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  void _showGenerateClosingModal(BuildContext context, BusinessProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GenerateClosingSheet(provider: provider),
    );
  }

  void _showImportSellerClosingModal(BuildContext context, BusinessProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ImportSellerClosingSheet(provider: provider),
    );
  }
}

// ──────────────────────────────────────────────
// Import Seller Closing Sheet
// ──────────────────────────────────────────────
class _ImportSellerClosingSheet extends StatefulWidget {
  final BusinessProvider provider;
  const _ImportSellerClosingSheet({required this.provider});

  @override
  State<_ImportSellerClosingSheet> createState() => _ImportSellerClosingSheetState();
}

class _ImportSellerClosingSheetState extends State<_ImportSellerClosingSheet> {
  String? _selectedSellerId;
  String? _depositCardId;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final activeSellers = widget.provider.sellers.where((s) => s.isActive).toList();

    final hasSelectedSeller = _selectedSellerId != null && activeSellers.any((s) => s.id == _selectedSellerId);
    final currentSellerValue = hasSelectedSeller ? _selectedSellerId : null;

    final hasSelectedCard = _depositCardId != null && appProvider.cards.any((c) => c.id == _depositCardId);
    final currentCardValue = hasSelectedCard ? _depositCardId : null;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.t('closing_import_title'),
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              context.t('closing_import_desc'),
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: currentSellerValue,
              decoration: InputDecoration(
                labelText: context.t('seller_optional'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(context.t('closing_detect_file'))),
                ...activeSellers.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.fullName),
                    )),
              ],
              onChanged: (val) => setState(() => _selectedSellerId = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: currentCardValue,
              decoration: InputDecoration(
                labelText: context.t('closing_deposit_in'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.account_balance_wallet),
                helperText: context.t('closing_deposit_helper'),
              ),
              items: [
                DropdownMenuItem(value: null, child: Text(context.t('closing_no_deposit'))),
                ...appProvider.cards.map((c) => DropdownMenuItem(
                      value: c.id,
                      child: Text(
                          '${c.isCash ? context.t('card_cash') : (c.bankName ?? context.t('card_default_name'))} • ${c.balance.toFormattedString(2)} ${c.currency}'),
                    )),
              ],
              onChanged: (val) => setState(() => _depositCardId = val),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: _isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.folder_open),
                label: Text(_isLoading ? context.t('importing') : context.t('select_file_json')),
                onPressed: _isLoading ? null : _pickAndImportFile,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.pop(context),
              child: Text(context.t('cancel')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndImportFile() async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) return;
    if (!mounted) return;

    setState(() => _isLoading = true);

    final file = result.files.first;
    try {
      String jsonStr;
      if (file.bytes != null) {
        jsonStr = utf8.decode(file.bytes!);
      } else if (file.path != null) {
        jsonStr = await File(file.path!).readAsString();
      } else {
        throw context.t('closing_import_read_error');
      }

      final dynamic decoded = jsonDecode(jsonStr);
      if (decoded is! Map && decoded is! List) {
        throw context.t('closing_import_format_error');
      }

      Map<String, dynamic> data;
      if (decoded is Map) {
        data = Map<String, dynamic>.from(decoded);
      } else {
        data = {'sales': decoded};
      }

      final sellerId = _selectedSellerId ?? (data['sellerId'] as String?);
      if (sellerId == null) {
        if (mounted) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.t('closing_import_select_seller')),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final Seller? seller = widget.provider.sellers.cast<Seller?>().firstWhere(
        (s) => s?.id == sellerId,
        orElse: () => null,
      );

      final sellerName = seller?.fullName ?? (data['sellerName'] as String?) ?? context.t('seller_singular');

      final closingData = {
        'sellerId': sellerId,
        'sellerName': sellerName,
        'sales': data['sales'] ?? [],
        'closing': data['closing'] ?? (data.containsKey('sales') ? {} : data),
      };

      final resultImport = await widget.provider.importSellerClosing(
        closingData: closingData,
        depositCardId: _depositCardId,
        appProvider: appProvider,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (resultImport['success'] == true) {
          Navigator.pop(context);
          final salesCount = resultImport['salesImported'] ?? 0;
          final totalIncome = (resultImport['totalIncome'] as num?)?.toDouble() ?? 0.0;
          final name = resultImport['sellerName'] ?? sellerName;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ $salesCount ${context.t('closing_import_success_count')} $name (${context.t('total_label')}: \$${totalIncome.toFormattedString(2)})',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${resultImport['error'] ?? context.t('closing_error_unknown')}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${context.t('closing_import_file_error')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
        return Colors.blue;
      case 'semanal':
        return Colors.orange;
      case 'mensual':
        return Colors.purple;
      default:
        return Colors.grey;
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
    final color = _periodColor;
    final profitColor = closing.profit >= 0 ? Colors.green : Colors.red;

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
              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.t('cancel'))),
              ElevatedButton(
                onPressed: () {
                  confirmed = true;
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: Text(context.t('delete'), style: const TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
        return confirmed;
      },
      onDismissed: (_) => provider.deleteClosing(closing.id),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.delete, color: Colors.white),
            const SizedBox(height: 4),
            Text(context.t('borrower_delete'), style: const TextStyle(color: Colors.white, fontSize: 11)),
          ],
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            leading: Container(
              padding: const EdgeInsets.all(10),
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
                    closing.period.toUpperCase(),
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 15),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: profitColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    closing.profit >= 0 ? context.t('closing_profit') : context.t('closing_loss'),
                    style: TextStyle(
                      fontSize: 11,
                      color: profitColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${DateFormat('dd MMM yyyy – HH:mm').format(closing.startDate)}  →  ${DateFormat('dd MMM yyyy – HH:mm').format(closing.endDate)}',
              style: TextStyle(color: Colors.grey[500], fontSize: 11),
            ),
            children: [
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Summary Row ──
                    _SummaryRow(closing: closing),
                    const SizedBox(height: 16),

                    // ── Extra stats row ──
                    Row(
                      children: [
                        Expanded(
                          child: _MiniStatCard(
                            icon: Icons.shopping_bag_outlined,
                            label: context.t('closing_sales_label'),
                            value: '${closing.salesCount}',
                            color: Colors.green,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStatCard(
                            icon: Icons.receipt_long,
                            label: context.t('closing_expenses_count_label'),
                            value: '${closing.expensesCount}',
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MiniStatCard(
                            icon: Icons.trending_up,
                            label: context.t('closing_roi_label'),
                            value: '${closing.roi.toFormattedString(1)}%',
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    _InfoRow(
                      icon: Icons.account_balance_wallet_outlined,
                      label: context.t('net_profit'),
                      value: '${closing.netProfit < 0 ? '-\$' : '\$'}${closing.netProfit.abs().toFormattedString(2)}',
                      color: closing.netProfit >= 0 ? Colors.teal : Colors.red,
                    ),

                    if (closing.totalDiscounts > 0) ...[
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.discount_outlined,
                        label: context.t('closing_discounts'),
                        value: '\$${closing.totalDiscounts.toFormattedString(2)}',
                        color: Colors.amber,
                      ),
                    ],

                    // ── Best Seller ──
                    if (closing.bestSellerName.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _SectionTitle(icon: Icons.star, label: context.t('closing_best_seller'), color: Colors.amber),
                      const SizedBox(height: 8),
                      _InfoRow(
                        icon: Icons.inventory_2_outlined,
                        label: closing.bestSellerName,
                        value: context.t('closing_units').replaceAll('{qty}', '${closing.bestSellerQty}'),
                        color: Colors.amber,
                      ),
                    ],

                    // ── Sold Products ──
                    _SoldProductsSection(jsonData: closing.soldProductsJson),

                    // ── Added Products ──
                    _AddedProductsSection(jsonData: closing.addedProductsJson),

                    // ── Payment Methods ──
                    _PaymentMethodsSection(jsonData: closing.paymentMethodsJson),

                    // ── Expense Categories ──
                    _ExpenseCategoriesSection(jsonData: closing.expenseCategoriesJson),

                    // ── Seller Stats ──
                    _SellerStatsSection(jsonData: closing.sellerStatsJson),

                    // ── Export Buttons ──
                    const SizedBox(height: 20),
                    _ClosingExportButtons(closing: closing, provider: provider),
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
      widget.provider.activeBusiness?.name ?? context.t('closing_business_fallback');

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
            backgroundColor: Colors.red,
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
            backgroundColor: Colors.red,
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
        content: Text(context.t('closing_export_ready').replaceAll('{label}', label).replaceAll('{path}', path)),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: context.t('closing_share'),
          textColor: Colors.white,
          onPressed: () => _exportService.shareFile(path),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('closing_export_title'),
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingPdf ? null : _exportPdf,
                  icon: _exportingPdf
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.picture_as_pdf, color: Colors.red),
                  label: const Text('PDF'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _exportingXls ? null : _exportXls,
                  icon: _exportingXls
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.table_chart, color: Colors.green),
                  label: const Text('Excel'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green,
                    side: const BorderSide(color: Colors.green),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
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
    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            label: context.t('closing_income_label'),
            value: closing.income,
            color: Colors.green,
            icon: Icons.arrow_upward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: context.t('closing_expenses_label'),
            value: closing.expenses,
            color: Colors.red,
            icon: Icons.arrow_downward,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _SummaryCard(
            label: context.t('gross_profit'),
            value: closing.profit,
            color: closing.profit >= 0 ? Colors.blue : Colors.red,
            icon: closing.profit >= 0 ? Icons.trending_up : Icons.trending_down,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          FittedBox(
            child: Text(
              '${value < 0 ? '-\$' : '\$'}${value.abs().toFormattedString(2)}',
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: color,
              ),
            ),
          ),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
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
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: GoogleFonts.outfit(
                  fontWeight: FontWeight.bold,
                  color: color,
                  fontSize: 14,
                )),
          ),
          Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[500])),
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
  const _SectionTitle({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: color,
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13)),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: color,
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
        const SizedBox(height: 16),
        _SectionTitle(icon: Icons.sell_outlined, label: context.t('closing_products_sold'), color: Colors.green),
        const SizedBox(height: 8),
        ...items.map((item) {
          if (item is! Map) return const SizedBox.shrink();
          final name = item['name'] as String? ?? '—';
          final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
          final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
          final revenue = (item['revenue'] as num?)?.toDouble() ?? 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$qtyStr uds  ·  \$${revenue.toFormattedString(2)}',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
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
        const SizedBox(height: 16),
        _SectionTitle(icon: Icons.add_box_outlined, label: context.t('closing_products_added'), color: Colors.teal),
        const SizedBox(height: 8),
        ...items.map((item) {
          if (item is! Map) return const SizedBox.shrink();
          final name = item['name'] as String? ?? '—';
          final qty = (item['qty'] as num?)?.toDouble() ?? 0.0;
          final qtyStr = qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);
          final cost = (item['cost'] as num?)?.toDouble() ?? 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$qtyStr uds  ·  \$${cost.toFormattedString(2)}/u',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.teal[700],
                  ),
                ),
              ],
            ),
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
        const SizedBox(height: 16),
        _SectionTitle(icon: Icons.payment, label: context.t('closing_payment_methods'), color: Colors.blue),
        const SizedBox(height: 8),
        ...data.entries.map((entry) {
          final method = entry.key;
          final amount = (entry.value is num)
              ? (entry.value as num).toDouble()
              : (double.tryParse(entry.value.toString()) ?? 0.0);
          final pct = total > 0 ? (amount / total * 100).toStringAsFixed(0) : '0';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(method, style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text(
                      '\$${amount.toFormattedString(2)} ($pct%)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? amount / total : 0,
                    backgroundColor: Colors.blue.withValues(alpha: 0.1),
                    valueColor: const AlwaysStoppedAnimation(Colors.blue),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
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

    const colors = [Colors.red, Colors.orange, Colors.pink, Colors.purple, Colors.brown, Colors.grey, Colors.deepOrange];
    int colorIdx = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _SectionTitle(icon: Icons.pie_chart_outline, label: context.t('closing_expense_categories'), color: Colors.red),
        const SizedBox(height: 8),
        ...data.entries.map((entry) {
          final category = entry.key;
          final amount = (entry.value is num)
              ? (entry.value as num).toDouble()
              : (double.tryParse(entry.value.toString()) ?? 0.0);
          final pct = total > 0 ? (amount / total * 100).toStringAsFixed(0) : '0';
          final color = colors[colorIdx % colors.length];
          colorIdx++;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(category, style: const TextStyle(fontSize: 12)),
                    const Spacer(),
                    Text(
                      '\$${amount.toFormattedString(2)} ($pct%)',
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: total > 0 ? amount / total : 0,
                    backgroundColor: color.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                    minHeight: 5,
                  ),
                ),
              ],
            ),
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

    final total = data.values.fold<double>(
      0.0,
      (s, v) {
        if (v is Map) {
          return s + ((v['total'] as num?)?.toDouble() ?? 0.0);
        } else if (v is num) {
          return s + v.toDouble();
        }
        return s;
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        _SectionTitle(
          icon: Icons.people_outline,
          label: context.t('closing_by_seller'),
          color: Colors.indigo,
        ),
        const SizedBox(height: 8),
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
          final pct = total > 0 ? (amount / total * 100).toStringAsFixed(0) : '0';
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  '$count ventas  ·  \$${amount.toFormattedString(2)} ($pct%)',
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.indigo[700],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  context.t('closing_generate'),
                  style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Period Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  _buildToggleOption(context.t('freq_daily'), 'daily'),
                  _buildToggleOption(context.t('freq_weekly'), 'weekly'),
                  _buildToggleOption(context.t('freq_monthly'), 'monthly'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Preview
            if (_previewStats != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      context.t('closing_preview'),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildPreviewStat(context.t('closing_income_label'), _previewStats!['income'] ?? 0.0, Colors.green),
                        _buildPreviewStat(context.t('closing_expenses_label'), _previewStats!['expenses'] ?? 0.0, Colors.red),
                        _buildPreviewStat('Neto', _previewStats!['profit'] ?? 0.0, Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSaving ? null : _saveClosing,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(context.t('closing_confirm_save')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleOption(String label, String value) {
    final isSelected = _selectedPeriod == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedPeriod = value);
          _calculateStats();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Theme.of(context).cardColor : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)]
                : [],
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              color: isSelected ? Theme.of(context).primaryColor : Colors.grey,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewStat(String label, double value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        Text(
          '${value < 0 ? '-\$' : '\$'}${value.abs().toFormattedString(2)}',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 18, color: color),
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
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${context.t('closing_generated_error')}: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
