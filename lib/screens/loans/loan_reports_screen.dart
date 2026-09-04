import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';
import '../../services/localization_service.dart';

class LoanReportsScreen extends StatelessWidget {
  const LoanReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final loanProvider = Provider.of<LoanProvider>(context);
    final appProvider = Provider.of<AppProvider>(context);
    final currency = appProvider.mainCurrency;

    // Metrics
    final totalLoaned = loanProvider.getMetricTotalLoaned(currency);
    final outstanding = loanProvider.getMetricOutstandingBalance(currency);
    final collected = loanProvider.getMetricTotalCollected(currency);
    final gainGenerated = loanProvider.getMetricGainGenerated(currency);
    
    final morososCount = loanProvider.getMorososCount();
    final activeLoansCount = loanProvider.activeLoans.length;
    final riskRate = activeLoansCount > 0 ? (morososCount / activeLoansCount) * 100 : 0.0;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          context.t('loan_reports_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Headline Section
            Text(
              context.t('reports_portfolio'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            // Financial Summary Block
            _buildFinancialReportGrid(context, totalLoaned, collected, outstanding, gainGenerated, currency, isDark),
            const SizedBox(height: 28),

            // Credit Risk Analysis
            Text(
              context.t('reports_risk'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            _buildCreditRiskAnalysis(context, morososCount, activeLoansCount, riskRate, isDark),
            const SizedBox(height: 28),

            // Operational Projection
            Text(
              context.t('reports_projections'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            _buildOperationalProjections(context, loanProvider, currency, isDark),
            const SizedBox(height: 28),

            // Backup & Data Exports Title
            Text(
              context.t('reports_backup_section'),
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 16),

            _buildBackupAndExportSection(context, loanProvider, isDark),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupAndExportSection(BuildContext context, LoanProvider lp, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          // Export Excel
          ListTile(
            leading: const Icon(Icons.grid_on_rounded, color: Colors.green),
            title: Text(
              context.t('reports_export_excel'),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.t('reports_export_excel_desc'),
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () async {
              final service = ExportService();
              final path = await service.exportLoansToExcel(lp.loans);
              await service.shareFile(path);
            },
          ),
          const Divider(height: 16),
          // Export CSV
          ListTile(
            leading: const Icon(Icons.table_chart_rounded, color: Colors.blue),
            title: Text(
              context.t('reports_export_csv'),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.t('reports_export_csv_desc'),
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () async {
              final service = ExportService();
              final path = await service.exportLoansToCSV(lp.loans);
              await service.shareFile(path);
            },
          ),
          const Divider(height: 16),
          // Backup Export JSON
          ListTile(
            leading: const Icon(Icons.cloud_upload_rounded, color: Colors.purpleAccent),
            title: Text(
              context.t('reports_export_json'),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.t('reports_export_json_desc'),
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () async {
              try {
                final jsonString = lp.exportBackupData();
                final dir = await getTemporaryDirectory();
                final file = File('${dir.path}/cashrapido_prestamos_backup.json');
                await file.writeAsString(jsonString);
                await SharePlus.instance.share(
                  ShareParams(files: [XFile(file.path)], text: context.t('reports_share_text')),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
          ),
          const Divider(height: 16),
          // Backup Import JSON
          ListTile(
            leading: const Icon(Icons.cloud_download_rounded, color: Colors.orangeAccent),
            title: Text(
              context.t('reports_import_json'),
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              context.t('reports_import_json_desc'),
              style: GoogleFonts.outfit(fontSize: 12, color: Colors.grey),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: () async {
              try {
                final result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ['json'],
                );

                if (result != null && result.files.single.path != null) {
                  final file = File(result.files.single.path!);
                  final jsonContent = await file.readAsString();
                  final success = await lp.importBackupData(jsonContent);

                  if (context.mounted) {
                    if (success) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.t('reports_import_success')),
                        backgroundColor: Colors.green,
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(context.t('reports_import_error')),
                        backgroundColor: Colors.red,
                      ));
                    }
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialReportGrid(
    BuildContext context,
    double totalLoaned,
    double collected,
    double outstanding,
    double profit,
    String currency,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          _buildReportRow(
            context,
            Icons.account_balance_wallet_outlined,
            context.t('reports_total_loaned'),
            totalLoaned,
            currency,
            isDark,
          ),
          const Divider(height: 24, color: Colors.white12),
          _buildReportRow(
            context,
            Icons.check_circle_outline,
            context.t('reports_total_collected'),
            collected,
            currency,
            isDark,
            valueColor: Colors.greenAccent,
          ),
          const Divider(height: 24, color: Colors.white12),
          _buildReportRow(
            context,
            Icons.pending_actions,
            context.t('reports_outstanding'),
            outstanding,
            currency,
            isDark,
            valueColor: Colors.orangeAccent,
          ),
          const Divider(height: 24, color: Colors.white12),
          _buildReportRow(
            context,
            Icons.trending_up_rounded,
            context.t('reports_expected_interest'),
            profit,
            currency,
            isDark,
            valueColor: Colors.cyanAccent,
          ),
        ],
      ),
    );
  }

  Widget _buildReportRow(
    BuildContext context,
    IconData icon,
    String label,
    double amount,
    String currency,
    bool isDark, {
    Color? valueColor,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Text(
          "\$${amount.toStringAsFixed(2)} $currency",
          style: GoogleFonts.outfit(
            color: valueColor ?? (isDark ? Colors.white : Colors.black87),
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildCreditRiskAnalysis(
    BuildContext context,
    int morososCount,
    int activeCount,
    double riskRate,
    bool isDark,
  ) {
    Color indicatorColor = Colors.greenAccent;
    String riskLabel = context.t('reports_risk_healthy');

    if (riskRate > 25.0) {
      indicatorColor = Colors.redAccent;
      riskLabel = context.t('reports_risk_critical');
    } else if (riskRate > 10.0) {
      indicatorColor = Colors.orangeAccent;
      riskLabel = context.t('reports_risk_moderate');
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('reports_default_rate'),
                style: GoogleFonts.outfit(color: Colors.grey, fontSize: 14),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: indicatorColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${riskRate.toStringAsFixed(1)}% - $riskLabel",
                  style: GoogleFonts.outfit(
                    color: indicatorColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildRiskStatCard(
                  context,
                  context.t('reports_delinquent_clients'),
                  morososCount.toString(),
                  Colors.redAccent,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRiskStatCard(
                  context,
                  context.t('reports_active_portfolio'),
                  activeCount.toString(),
                  Colors.blueAccent,
                  isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRiskStatCard(
    BuildContext context,
    String label,
    String value,
    Color color,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : Colors.black87,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOperationalProjections(
    BuildContext context,
    LoanProvider provider,
    String currency,
    bool isDark,
  ) {
    // Proyecciones de cobro para los siguientes 7 días
    double next7DaysExpected = 0.0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next7Days = today.add(const Duration(days: 8));

    for (var l in provider.loans) {
      if (l.currency == currency && (l.status == 'active' || l.status == 'overdue')) {
        for (var inst in l.installments) {
          if (inst.status != 'paid') {
            final instDate = DateTime(inst.dueDate.year, inst.dueDate.month, inst.dueDate.day);
            if (!instDate.isBefore(today) && instDate.isBefore(next7Days)) {
              next7DaysExpected += inst.remainingAmount;
            }
          }
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('reports_expected_7days'),
                style: GoogleFonts.outfit(color: isDark ? Colors.white70 : Colors.black87, fontSize: 14),
              ),
              Text(
                "\$${next7DaysExpected.toStringAsFixed(2)} $currency",
                style: GoogleFonts.outfit(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.t('reports_projections_footnote'),
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
