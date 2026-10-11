import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../providers/loan_provider.dart';
import '../../providers/app_provider.dart';
import '../../services/export_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_progress_bar.dart';
import '../../widgets/design/cash_section.dart';
import '../../widgets/design/cash_stat_card.dart';

/// Informe del módulo de préstamos.
///
/// El rediseño es exclusivamente visual: todas las métricas, el cálculo del
/// riesgo, la proyección a 7 días y las operaciones de exportación/importación
/// son idénticas a las originales. Cada indicador proviene del [LoanProvider];
/// aquí no se recalcula ninguna fórmula financiera.
class LoanReportsScreen extends StatelessWidget {
  const LoanReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final loanProvider = Provider.of<LoanProvider>(context);
    final appProvider = Provider.of<AppProvider>(context);
    final currency = appProvider.mainCurrency;
    final symbol = _currencySymbol(appProvider, currency);

    // Metrics (sin cambios).
    final totalLoaned = loanProvider.getMetricTotalLoaned(currency);
    final outstanding = loanProvider.getMetricOutstandingBalance(currency);
    final collected = loanProvider.getMetricTotalCollected(currency);
    final gainGenerated = loanProvider.getMetricGainGenerated(currency);

    final morososCount = loanProvider.getMorososCount();
    final activeLoansCount = loanProvider.activeLoans.length;
    final riskRate = activeLoansCount > 0
        ? (morososCount / activeLoansCount) * 100
        : 0.0;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('loan_reports_title')),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.screenVertical,
        ),
        children: [
          CashSection(
            title: context.t('reports_portfolio'),
            child: _buildPortfolioCard(
              context,
              totalLoaned: totalLoaned,
              collected: collected,
              outstanding: outstanding,
              profit: gainGenerated,
              currency: currency,
              symbol: symbol,
              hasLoans: loanProvider.loans.isNotEmpty,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          CashSection(
            title: context.t('reports_risk'),
            child: _buildRiskCard(
              context,
              morososCount: morososCount,
              activeLoansCount: activeLoansCount,
              riskRate: riskRate,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          CashSection(
            title: context.t('reports_projections'),
            child: _buildProjectionsCard(
              context,
              loanProvider,
              currency,
              symbol,
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),

          CashSection(
            title: context.t('reports_backup_section'),
            child: _buildBackupAndExportSection(context, loanProvider),
          ),
          const SizedBox(height: AppSpacing.xxxl),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   HELPERS
  // ──────────────────────────────────────────
  String _currencySymbol(AppProvider appProvider, String code) {
    for (final currency in appProvider.availableCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  // ──────────────────────────────────────────
  //   CARTERA
  // ──────────────────────────────────────────
  Widget _buildPortfolioCard(
    BuildContext context, {
    required double totalLoaned,
    required double collected,
    required double outstanding,
    required double profit,
    required String currency,
    required String symbol,
    required bool hasLoans,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    if (!hasLoans) {
      return CashCard(
        child: Column(
          children: [
            Icon(Icons.insights_rounded, size: 36, color: secondary),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.t('no_loans_title'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(
              context.t('no_data'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ],
        ),
      );
    }

    return CashCard(
      child: Column(
        children: [
          _buildReportRow(
            context,
            icon: Icons.account_balance_wallet_outlined,
            label: context.t('reports_total_loaned'),
            value: '$symbol ${totalLoaned.toFormattedString(2)} $currency',
            color: AppColors.info,
          ),
          _divider(isDark),
          _buildReportRow(
            context,
            icon: Icons.check_circle_outline_rounded,
            label: context.t('reports_total_collected'),
            value: '$symbol ${collected.toFormattedString(2)} $currency',
            color: AppColors.income,
          ),
          _divider(isDark),
          _buildReportRow(
            context,
            icon: Icons.pending_actions_rounded,
            label: context.t('reports_outstanding'),
            value: '$symbol ${outstanding.toFormattedString(2)} $currency',
            color: AppColors.warning,
          ),
          _divider(isDark),
          _buildReportRow(
            context,
            icon: Icons.trending_up_rounded,
            label: context.t('reports_expected_interest'),
            value: '$symbol ${profit.toFormattedString(2)} $currency',
            color: AppColors.primary,
          ),
        ],
      ),
    );
  }

  Widget _divider(bool isDark) => Divider(
    height: AppSpacing.xxl,
    color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
  );

  Widget _buildReportRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: AppRadius.radiusMd,
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          flex: 2,
          child: Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   RIESGO
  // ──────────────────────────────────────────
  Widget _buildRiskCard(
    BuildContext context, {
    required int morososCount,
    required int activeLoansCount,
    required double riskRate,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Mismos umbrales y etiquetas que la implementación original.
    Color indicatorColor = AppColors.income;
    String riskLabel = context.t('reports_risk_healthy');

    if (riskRate > 25.0) {
      indicatorColor = AppColors.error;
      riskLabel = context.t('reports_risk_critical');
    } else if (riskRate > 10.0) {
      indicatorColor = AppColors.warning;
      riskLabel = context.t('reports_risk_moderate');
    }

    return CashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('reports_default_rate'),
            style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.sm),
          CashChip(
            label: '${riskRate.toStringAsFixed(1)}% - $riskLabel',
            selected: true,
            color: indicatorColor,
          ),
          const SizedBox(height: AppSpacing.lg),
          CashProgressBar(
            value: riskRate / 100,
            color: indicatorColor,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: CashStatCard(
                  title: context.t('reports_delinquent_clients'),
                  value: morososCount.toString(),
                  icon: Icons.warning_amber_rounded,
                  iconColor: AppColors.error,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: CashStatCard(
                  title: context.t('reports_active_portfolio'),
                  value: activeLoansCount.toString(),
                  icon: Icons.people_alt_outlined,
                  iconColor: AppColors.info,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   PROYECCIONES
  // ──────────────────────────────────────────
  Widget _buildProjectionsCard(
    BuildContext context,
    LoanProvider provider,
    String currency,
    String symbol,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Proyecciones de cobro para los siguientes 7 días (misma lógica).
    double next7DaysExpected = 0.0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next7Days = today.add(const Duration(days: 8));

    for (var l in provider.loans) {
      if (l.currency == currency &&
          (l.status == 'active' || l.status == 'overdue')) {
        for (var inst in l.installments) {
          if (inst.status != 'paid') {
            final instDate = DateTime(
              inst.dueDate.year,
              inst.dueDate.month,
              inst.dueDate.day,
            );
            if (!instDate.isBefore(today) && instDate.isBefore(next7Days)) {
              next7DaysExpected += inst.remainingAmount;
            }
          }
        }
      }
    }

    return CashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('reports_expected_7days'),
            style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$symbol ${next7DaysExpected.toFormattedString(2)} $currency',
              maxLines: 1,
              style: theme.textTheme.headlineSmall?.copyWith(
                color: AppColors.income,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            context.t('reports_projections_footnote'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   EXPORTACIÓN / RESPALDO
  // ──────────────────────────────────────────
  Widget _buildBackupAndExportSection(
    BuildContext context,
    LoanProvider lp,
  ) {
    return CashCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        children: [
          _ExportTile(
            icon: Icons.grid_on_rounded,
            color: AppColors.income,
            title: context.t('reports_export_excel'),
            subtitle: context.t('reports_export_excel_desc'),
            onTap: () async {
              try {
                final service = ExportService();
                final path = await service.exportLoansToExcel(lp.loans);
                await service.shareFile(path);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.t('error')}: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
          _ExportTile(
            icon: Icons.table_chart_rounded,
            color: AppColors.info,
            title: context.t('reports_export_csv'),
            subtitle: context.t('reports_export_csv_desc'),
            onTap: () async {
              try {
                final service = ExportService();
                final path = await service.exportLoansToCSV(lp.loans);
                await service.shareFile(path);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.t('error')}: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
          _ExportTile(
            icon: Icons.cloud_upload_rounded,
            color: AppColors.primary,
            title: context.t('reports_export_json'),
            subtitle: context.t('reports_export_json_desc'),
            onTap: () async {
              final shareText = context.t('reports_share_text');
              try {
                final jsonString = lp.exportBackupData();
                final dir = await getTemporaryDirectory();
                final file = File(
                  '${dir.path}/cashrapido_prestamos_backup.json',
                );
                await file.writeAsString(jsonString);
                await SharePlus.instance.share(
                  ShareParams(
                    files: [XFile(file.path)],
                    text: shareText,
                  ),
                );
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.t('error')}: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
          _ExportTile(
            icon: Icons.cloud_download_rounded,
            color: AppColors.warning,
            title: context.t('reports_import_json'),
            subtitle: context.t('reports_import_json_desc'),
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.t('reports_import_success')),
                          backgroundColor: AppColors.income,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(context.t('reports_import_error')),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${context.t('error')}: $e'),
                      backgroundColor: AppColors.error,
                    ),
                  );
                }
              }
            },
          ),
        ],
      ),
    );
  }
}

/// Fila accionable de exportación/respaldo.
class _ExportTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ExportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.radiusMd,
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 14,
                color: secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
