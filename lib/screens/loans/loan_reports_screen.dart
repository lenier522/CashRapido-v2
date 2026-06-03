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
          Localizations.localeOf(context).languageCode == 'es' ? 'Reportes Financieros' : 'Financial Reports',
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
              Localizations.localeOf(context).languageCode == 'es' ? 'Resumen de Cartera' : 'Portfolio Analytics',
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
              Localizations.localeOf(context).languageCode == 'es' ? 'Análisis de Riesgo Crediticio' : 'Credit Risk Indicators',
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
              Localizations.localeOf(context).languageCode == 'es' ? 'Proyecciones y Flujo Operativo' : 'Cash Flow Projections',
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
              Localizations.localeOf(context).languageCode == 'es' ? 'Copia de Seguridad y Exportación' : 'Backup & Data Exports',
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
              Localizations.localeOf(context).languageCode == 'es' ? 'Exportar a Excel (XLSX)' : 'Export to Excel (XLSX)',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              Localizations.localeOf(context).languageCode == 'es' ? 'Listado de préstamos y saldos' : 'Loan portfolios and balances',
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
              Localizations.localeOf(context).languageCode == 'es' ? 'Exportar a CSV' : 'Export to CSV',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              Localizations.localeOf(context).languageCode == 'es' ? 'Compatible con hojas de cálculo' : 'Spreadsheet compatible text format',
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
              Localizations.localeOf(context).languageCode == 'es' ? 'Exportar Respaldo JSON' : 'Export JSON Backup',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              Localizations.localeOf(context).languageCode == 'es' ? 'Copia cifrada de clientes y préstamos' : 'Encrypted borrower and loan database copy',
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
                  ShareParams(files: [XFile(file.path)], text: 'Respaldo de Préstamos CashRapido'),
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
              Localizations.localeOf(context).languageCode == 'es' ? 'Restaurar Respaldo JSON' : 'Restore JSON Backup',
              style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              Localizations.localeOf(context).languageCode == 'es' ? 'Importar base de datos (.json)' : 'Import database file (.json)',
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
                        content: Text(Localizations.localeOf(context).languageCode == 'es' ? 'Datos importados correctamente' : 'Data imported successfully'),
                        backgroundColor: Colors.green,
                      ));
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(Localizations.localeOf(context).languageCode == 'es' ? 'Error al procesar archivo JSON' : 'Failed to parse JSON file'),
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
            Localizations.localeOf(context).languageCode == 'es' ? 'Total Prestado (Capital)' : 'Total Loaned Out',
            totalLoaned,
            currency,
            isDark,
          ),
          const Divider(height: 24, color: Colors.white12),
          _buildReportRow(
            context,
            Icons.check_circle_outline,
            Localizations.localeOf(context).languageCode == 'es' ? 'Total Recuperado (Cobros)' : 'Total Collected Back',
            collected,
            currency,
            isDark,
            valueColor: Colors.greenAccent,
          ),
          const Divider(height: 24, color: Colors.white12),
          _buildReportRow(
            context,
            Icons.pending_actions,
            Localizations.localeOf(context).languageCode == 'es' ? 'Total Pendiente de Cobro' : 'Outstanding Balance',
            outstanding,
            currency,
            isDark,
            valueColor: Colors.orangeAccent,
          ),
          const Divider(height: 24, color: Colors.white12),
          _buildReportRow(
            context,
            Icons.trending_up_rounded,
            Localizations.localeOf(context).languageCode == 'es' ? 'Intereses / Rendimiento Esperado' : 'Expected Interest Profits',
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
    String riskLabel = Localizations.localeOf(context).languageCode == 'es' ? 'Saludable' : 'Healthy';

    if (riskRate > 25.0) {
      indicatorColor = Colors.redAccent;
      riskLabel = Localizations.localeOf(context).languageCode == 'es' ? 'Peligro Crítico' : 'Critical Hazard';
    } else if (riskRate > 10.0) {
      indicatorColor = Colors.orangeAccent;
      riskLabel = Localizations.localeOf(context).languageCode == 'es' ? 'Moderado' : 'Moderate';
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
                Localizations.localeOf(context).languageCode == 'es' ? 'Tasa de Morosidad:' : 'Default Risk Rate:',
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
                  Localizations.localeOf(context).languageCode == 'es' ? 'Clientes Morosos' : 'Overdue Debtors',
                  morososCount.toString(),
                  Colors.redAccent,
                  isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildRiskStatCard(
                  context,
                  Localizations.localeOf(context).languageCode == 'es' ? 'Cartera Activa' : 'Active Portfolio',
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
    final next7Days = now.add(const Duration(days: 7));

    for (var l in provider.loans) {
      if (l.currency == currency && (l.status == 'active' || l.status == 'overdue')) {
        for (var inst in l.installments) {
          if (inst.status != 'paid') {
            if (inst.dueDate.isAfter(now) && inst.dueDate.isBefore(next7Days)) {
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
                Localizations.localeOf(context).languageCode == 'es' ? 'Cobros Esperados (7 días):' : 'Expected Payouts (Next 7 Days):',
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
            Localizations.localeOf(context).languageCode == 'es'
                ? '* Este monto representa la suma de los saldos pendientes de cuotas programadas para vencer en la próxima semana.'
                : '* This amount represents the sum of outstanding installment balances scheduled to mature in the upcoming week.',
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 11, fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
