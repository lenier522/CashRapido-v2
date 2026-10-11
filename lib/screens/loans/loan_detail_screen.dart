import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../providers/app_provider.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan.dart';
import '../../models/loan_activity.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_icon_button.dart';
import 'package:cashrapido/utils/number_format_utils.dart';
import 'loan_form_screen.dart';
import 'loan_payment_form_screen.dart';

/// Detalle de un préstamo.
///
/// Presenta la información en una jerarquía clara: cabecera con el saldo
/// pendiente y el estado real, acciones, condiciones, tabla de cuotas,
/// historial de cobros y registro de eventos. Todos los importes y estados
/// provienen de [LoanProvider] / del modelo [Loan]; aquí no se recalcula
/// ninguna fórmula financiera ni se reinterpretan los datos.
class LoanDetailScreen extends StatelessWidget {
  final Loan loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('loan_detail_title')),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // More actions: Refinanciar / Marcar como Perdido / Compartir PDF
          PopupMenuButton<String>(
            onSelected: (val) => _handleMenuAction(context, val),
            icon: const Icon(Icons.more_vert_rounded),
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'pdf',
                child: Row(
                  children: [
                    const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    const SizedBox(width: AppSpacing.md),
                    Text(context.t('loan_export_pdf')),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'refinance',
                child: Row(
                  children: [
                    const Icon(
                      Icons.swap_horiz_rounded,
                      size: 18,
                      color: AppColors.info,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      context.t('loan_refinance'),
                      style: const TextStyle(color: AppColors.info),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'lost',
                child: Row(
                  children: [
                    const Icon(
                      Icons.cancel_outlined,
                      size: 18,
                      color: AppColors.error,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Text(
                      context.t('loan_mark_loss'),
                      style: const TextStyle(color: AppColors.error),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Consumer<LoanProvider>(
        builder: (context, loanProvider, _) {
          Loan currentLoan;
          try {
            currentLoan = loanProvider.loans.firstWhere((l) => l.id == loan.id);
          } catch (e) {
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => Navigator.pop(context),
            );
            return const Center(child: CircularProgressIndicator());
          }

          final totalWithInterest = loanProvider.calculateTotalWithInterest(
            currentLoan.amount,
            currentLoan.interestRate,
            currentLoan.interestType,
            currentLoan.durationValue,
          );
          final paidAmount = totalWithInterest - currentLoan.remainingAmount;
          final progress = totalWithInterest > 0
              ? (paidAmount / totalWithInterest).clamp(0.0, 1.0)
              : 0.0;
          final progressPct = (progress * 100).toStringAsFixed(0);

          final bool isDark =
              Theme.of(context).brightness == Brightness.dark;

          Color statusColor;
          IconData statusIcon;
          String displayStatus;

          switch (currentLoan.status) {
            case 'paid':
              statusColor = AppColors.income;
              statusIcon = Icons.check_circle_outline_rounded;
              displayStatus = context.t('loan_status_paid_short');
              break;
            case 'overdue':
              statusColor = AppColors.error;
              statusIcon = Icons.error_outline_rounded;
              displayStatus = context.t('loan_status_overdue_short');
              break;
            case 'written_off':
              statusColor = isDark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiary;
              statusIcon = Icons.cancel_outlined;
              displayStatus = context.t('loan_status_written_off');
              break;
            case 'refinanced':
              statusColor = AppColors.info;
              statusIcon = Icons.swap_horiz_rounded;
              displayStatus = context.t('loan_status_refinanced');
              break;
            case 'active':
            default:
              statusColor = AppColors.primary;
              statusIcon = Icons.trending_up_rounded;
              displayStatus = context.t('loan_status_active');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.screenHorizontal,
              vertical: AppSpacing.screenVertical,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeaderCard(
                  context,
                  currentLoan,
                  totalWithInterest,
                  paidAmount,
                  progress,
                  progressPct,
                  statusColor,
                  statusIcon,
                  displayStatus,
                ),
                const SizedBox(height: AppSpacing.lg),

                _buildQuickActions(context, currentLoan, loanProvider),
                const SizedBox(height: AppSpacing.xxl),

                _buildDetailsCard(context, currentLoan, loanProvider),
                const SizedBox(height: AppSpacing.xxl),

                // Installments Grid
                if (currentLoan.installments.isNotEmpty) ...[
                  _buildInstallmentsSection(context, currentLoan),
                  const SizedBox(height: AppSpacing.xxl),
                ],

                // Payment History
                _buildPaymentHistorySection(context, currentLoan, loanProvider),
                const SizedBox(height: AppSpacing.xxl),

                // Audit Log
                _buildActivityLogSection(context, currentLoan, loanProvider),
                const SizedBox(height: AppSpacing.xxxl),
              ],
            ),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────
  //   HELPERS
  // ──────────────────────────────────────────
  String _currencySymbol(BuildContext context, String code) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    for (final currency in appProvider.availableCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  Color _primaryText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textPrimaryDark : AppColors.textPrimary;
  }

  Color _secondaryText(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? AppColors.textSecondaryDark : AppColors.textSecondary;
  }

  /// Devuelve el estado vigente del préstamo desde el provider.
  ///
  /// El [Loan] recibido por constructor es un snapshot que puede quedar
  /// obsoleto tras registrar cobros o editar el préstamo. Las acciones del menú
  /// (PDF, refinanciar, pérdida) deben operar sobre el estado actual para no
  /// mostrar ni persistir importes antiguos.
  Loan _currentLoan(LoanProvider provider) {
    return provider.loans.firstWhere(
      (l) => l.id == loan.id,
      orElse: () => loan,
    );
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  // ──────────────────────────────────────────
  //   MENU ACTIONS
  // ──────────────────────────────────────────
  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'pdf':
        _generateAndSharePDF(context);
        break;
      case 'refinance':
        _showRefinanceDialog(context);
        break;
      case 'lost':
        _confirmMarkAsLost(context);
        break;
    }
  }

  // ──────────────────────────────────────────
  //   HEADER CARD
  // ──────────────────────────────────────────
  Widget _buildHeaderCard(
    BuildContext context,
    Loan loan,
    double totalWithInterest,
    double paidAmount,
    double progress,
    String progressPct,
    Color statusColor,
    IconData statusIcon,
    String displayStatus,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final symbol = _currencySymbol(context, loan.currency);

    final Color primaryText = _primaryText(context);
    final Color secondaryText = _secondaryText(context);

    return CashCard(
      border: loan.status == 'overdue'
          ? Border.all(color: statusColor.withValues(alpha: 0.45))
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  loan.borrowerName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CashChip(
                label: displayStatus,
                icon: statusIcon,
                selected: true,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t('loan_outstanding_balance'),
            style: theme.textTheme.labelMedium?.copyWith(color: secondaryText),
          ),
          const SizedBox(height: AppSpacing.xxs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '$symbol ${loan.remainingAmount.toFormattedString(2)} ${loan.currency}',
              maxLines: 1,
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: loan.status == 'overdue' ? statusColor : primaryText,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _headerMetric(
                  context,
                  context.t('loan_collected_label'),
                  '$symbol ${paidAmount.toFormattedString(1)}',
                  AppColors.income,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _headerMetric(
                  context,
                  context.t('loan_total_label'),
                  '$symbol ${totalWithInterest.toFormattedString(1)}',
                  secondaryText,
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark
                        ? AppColors.surfaceDark3
                        : AppColors.surfaceVariantLight,
                    color: statusColor,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$progressPct%',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: statusColor,
                ),
              ),
            ],
          ),
          // Late fee indicator
          if (loan.lateFeeType != 'none') ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 15,
                  color: AppColors.warning,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    '${context.t('loan_late_fee')}: ${loan.lateFeeType == 'fixed' ? '$symbol${loan.lateFeeValue.toStringAsFixed(0)} ${context.t('loan_late_fee_flat')}' : '${loan.lateFeeValue.toStringAsFixed(0)}% ${context.t('loan_late_fee_daily')}'}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerMetric(
    BuildContext context,
    String label,
    String value,
    Color valueColor, {
    bool alignEnd = false,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: _secondaryText(context),
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: theme.textTheme.titleSmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   QUICK ACTIONS
  // ──────────────────────────────────────────
  Widget _buildQuickActions(
    BuildContext context,
    Loan loan,
    LoanProvider loanProvider,
  ) {
    final bool canCollect =
        loan.remainingAmount > 0 &&
        loan.status != 'written_off' &&
        loan.status != 'refinanced';

    return Row(
      children: [
        if (canCollect) ...[
          Expanded(
            child: CashButton(
              label: context.t('loan_collect'),
              icon: const Icon(Icons.price_check_rounded, size: 20),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LoanPaymentFormScreen(loan: loan),
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
        CashIconButton(
          icon: Icons.edit_rounded,
          tooltip: context.t('edit'),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => LoanFormScreen(loan: loan)),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        CashIconButton(
          icon: Icons.delete_outline_rounded,
          iconColor: AppColors.error,
          tooltip: context.t('delete'),
          onPressed: () => _confirmDeleteLoan(context, loanProvider),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   DETAILS CARD
  // ──────────────────────────────────────────
  Widget _buildDetailsCard(
    BuildContext context,
    Loan loan,
    LoanProvider loanProvider,
  ) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    String freqLabel;
    switch (loan.frequency) {
      case 'daily':
        freqLabel = context.t('freq_daily');
        break;
      case 'weekly':
        freqLabel = context.t('freq_weekly');
        break;
      case 'biweekly':
        freqLabel = context.t('freq_biweekly');
        break;
      case 'monthly':
        freqLabel = context.t('freq_monthly');
        break;
      default:
        freqLabel = context.t('loan_single');
        break;
    }

    String interestLabel;
    switch (loan.interestType) {
      case 'fixed':
        interestLabel = context.t('loan_interest_fixed');
        break;
      case 'compound':
        interestLabel = context.t('loan_interest_compound');
        break;
      default:
        interestLabel = context.t('loan_interest_simple');
        break;
    }

    final symbol = _currencySymbol(context, loan.currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.feed_outlined,
          title: context.t('loan_conditions'),
        ),
        const SizedBox(height: AppSpacing.md),
        CashCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow(
                context,
                context.t('loan_principal_loaned'),
                '$symbol${loan.amount.toFormattedString(2)} ${loan.currency}',
              ),
              _detailRow(
                context,
                context.t('loan_interest_rate'),
                loan.interestType == 'fixed'
                    ? '$symbol${loan.interestRate.toStringAsFixed(0)}'
                    : '${loan.interestRate.toStringAsFixed(0)}% ($interestLabel)',
              ),
              _detailRow(context, context.t('loan_frequency'), freqLabel),
              _detailRow(
                context,
                context.t('loan_term_label'),
                '${loan.durationValue} ${context.t('loan_installments_suffix')}',
              ),
              _detailRow(
                context,
                context.t('loan_start_date'),
                _formatDate(loan.startDate),
              ),
              _detailRow(
                context,
                context.t('loan_due_date'),
                _formatDate(loan.dueDate),
                highlight: loan.status == 'overdue',
              ),
              if (loan.lateFeeType != 'none')
                _detailRow(
                  context,
                  context.t('loan_late_fee_label'),
                  loan.lateFeeType == 'fixed'
                      ? '$symbol${loan.lateFeeValue.toStringAsFixed(0)} (${context.t('loan_late_fee_fixed')})'
                      : '${loan.lateFeeValue.toStringAsFixed(0)}% (${context.t('loan_late_fee_daily_label')})',
                ),
              const Divider(height: AppSpacing.xxl),
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  title: Text(
                    context.t('loan_due_alerts'),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: isDark
                          ? AppColors.textPrimaryDark
                          : AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  value: loan.isNotificationsEnabled,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (val) => loanProvider.editLoan(
                    loan.copyWith(isNotificationsEnabled: val),
                  ),
                ),
              ),
              if (loan.notes != null && loan.notes!.isNotEmpty) ...[
                const Divider(height: AppSpacing.lg),
                Text(
                  context.t('loan_notes'),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _secondaryText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  loan.notes!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: _primaryText(context),
                    height: 1.4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _secondaryText(context),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: highlight
                    ? AppColors.error
                    : _primaryText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   INSTALLMENTS GRID
  // ──────────────────────────────────────────
  Widget _buildInstallmentsSection(BuildContext context, Loan loan) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final symbol = _currencySymbol(context, loan.currency);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.table_rows_outlined,
          title: context.t('loan_installments_schedule'),
        ),
        const SizedBox(height: AppSpacing.md),
        CashCard(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: loan.installments.length,
            separatorBuilder: (_, _) => Divider(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              height: 1,
            ),
            itemBuilder: (ctx, i) {
              final inst = loan.installments[i];
              Color instColor;
              String instLabel;
              switch (inst.status) {
                case 'paid':
                  instColor = AppColors.income;
                  instLabel = context.t('loan_status_paid_short');
                  break;
                case 'overdue':
                  instColor = AppColors.error;
                  instLabel = context.t('loan_status_overdue_short');
                  break;
                case 'partial':
                  instColor = AppColors.warning;
                  instLabel = context.t('loan_status_partial');
                  break;
                default:
                  instColor = isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiary;
                  instLabel = context.t('loan_status_pending');
                  break;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: instColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${inst.number}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: instColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  _formatDate(inst.dueDate),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: _primaryText(context),
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Flexible(
                                flex: 2,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    '$symbol${inst.amount.toFormattedString(2)}',
                                    maxLines: 1,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: _primaryText(context),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (inst.paidAmount > 0 && inst.status != 'paid') ...[
                            const SizedBox(height: 2),
                            Text(
                              '${context.t('loan_payment_label')}: $symbol${inst.paidAmount.toFormattedString(2)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: AppColors.income,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: instColor.withValues(alpha: 0.12),
                        borderRadius: AppRadius.radiusXs,
                      ),
                      child: Text(
                        instLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: instColor,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   PAYMENT HISTORY
  // ──────────────────────────────────────────
  Widget _buildPaymentHistorySection(
    BuildContext context,
    Loan loan,
    LoanProvider loanProvider,
  ) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final symbol = _currencySymbol(context, loan.currency);
    final paymentsList = loanProvider.getPaymentsForLoan(loan.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.history_edu_rounded,
          title: context.t('loan_payment_history'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (paymentsList.isEmpty)
          CashCard(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 36,
                    color: _secondaryText(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.t('loan_pdf_no_payments'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _secondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          CashCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                for (int index = 0; index < paymentsList.length; index++) ...[
                  if (index > 0)
                    Divider(
                      color: isDark
                          ? AppColors.dividerDark
                          : AppColors.dividerLight,
                      height: 1,
                    ),
                  _buildPaymentTile(context, paymentsList[index], loan, loanProvider, symbol),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentTile(
    BuildContext context,
    LoanPayment payment,
    Loan loan,
    LoanProvider loanProvider,
    String symbol,
  ) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.income.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_downward_rounded,
              color: AppColors.income,
              size: 18,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '$symbol${payment.amount.toFormattedString(2)} ${loan.currency}',
                    maxLines: 1,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.income,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_formatDate(payment.date)} ${payment.date.hour.toString().padLeft(2, '0')}:${payment.date.minute.toString().padLeft(2, '0')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: _secondaryText(context),
                  ),
                ),
                if (payment.notes != null && payment.notes!.isNotEmpty)
                  Text(
                    payment.notes!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _secondaryText(context),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColors.error,
              size: 20,
            ),
            tooltip: context.t('delete'),
            onPressed: () =>
                _confirmDeletePayment(context, loanProvider, payment.id),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   ACTIVITY LOG
  // ──────────────────────────────────────────
  Widget _buildActivityLogSection(
    BuildContext context,
    Loan loan,
    LoanProvider loanProvider,
  ) {
    final theme = Theme.of(context);
    final activities = loanProvider.getActivitiesForLoan(loan.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.timeline_outlined,
          title: context.t('loan_activity_log'),
        ),
        const SizedBox(height: AppSpacing.md),
        if (activities.isEmpty)
          CashCard(
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.timeline_outlined,
                    size: 36,
                    color: _secondaryText(context),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    context.t('loan_no_events'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _secondaryText(context),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activities.length > 15 ? 15 : activities.length,
            itemBuilder: (ctx, i) {
              final act = activities[i];
              return _buildActivityItem(
                context,
                act,
                i == activities.length - 1 || i == 14,
              );
            },
          ),
      ],
    );
  }

  Widget _buildActivityItem(
    BuildContext context,
    LoanActivity activity,
    bool isLast,
  ) {
    final theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    Color iconColor;
    IconData iconData;
    switch (activity.action) {
      case 'Cobro':
        iconColor = AppColors.income;
        iconData = Icons.payment;
        break;
      case 'Mora':
        iconColor = AppColors.warning;
        iconData = Icons.warning_amber;
        break;
      case 'Vencido':
        iconColor = AppColors.error;
        iconData = Icons.event_busy;
        break;
      case 'Refinanciado':
        iconColor = AppColors.info;
        iconData = Icons.swap_horiz;
        break;
      case 'Pérdida':
        iconColor = isDark
            ? AppColors.textTertiaryDark
            : AppColors.textTertiary;
        iconData = Icons.cancel_outlined;
        break;
      default:
        iconColor = AppColors.purple;
        iconData = Icons.add_circle_outline;
        break;
    }

    // Localize the action label
    String actionLabel = activity.action;
    if (activity.action == 'Cobro') {
      actionLabel = context.t('activity_cobro');
    } else if (activity.action == 'Mora') {
      actionLabel = context.t('activity_mora');
    } else if (activity.action == 'Vencido') {
      actionLabel = context.t('activity_vencido');
    } else if (activity.action == 'Refinanciado') {
      actionLabel = context.t('activity_refinanciado');
    } else if (activity.action == 'Pérdida') {
      actionLabel = context.t('activity_perdida');
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: iconColor, size: 16),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
              ),
          ],
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        actionLabel,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: iconColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      '${activity.timestamp.hour.toString().padLeft(2, '0')}:${activity.timestamp.minute.toString().padLeft(2, '0')} ${_formatDate(activity.timestamp)}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: _secondaryText(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  activity.description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   PDF RECEIPT GENERATOR
  // ──────────────────────────────────────────
  Future<void> _generateAndSharePDF(BuildContext context) async {
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);
    // Se usa el estado vigente del préstamo (no el snapshot del constructor),
    // para que el recibo no muestre importes obsoletos tras cobros o ediciones.
    final loan = _currentLoan(loanProvider);
    final payments = loanProvider.getPaymentsForLoan(loan.id);
    final total = loanProvider.calculateTotalWithInterest(
      loan.amount,
      loan.interestRate,
      loan.interestType,
      loan.durationValue,
    );
    final paid = total - loan.remainingAmount;

    // Se resuelven antes de los `await` para no usar el BuildContext tras un
    // hueco asíncrono.
    final String safeName = loan.borrowerName.replaceAll(' ', '_');
    final String shareText = context
        .t('loan_pdf_share_text')
        .replaceAll('{name}', loan.borrowerName);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                context.t('loan_pdf_title'),
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Divider(),
              pw.SizedBox(height: 12),
              pw.Text(
                '${context.t('loan_pdf_borrower')}: ${loan.borrowerName}',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${context.t('loan_pdf_capital')}:'),
                  pw.Text(
                    '\$${loan.amount.toStringAsFixed(2)} ${loan.currency}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${context.t('loan_pdf_total')}:'),
                  pw.Text(
                    '\$${total.toStringAsFixed(2)} ${loan.currency}',
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${context.t('loan_pdf_collected')}:'),
                  pw.Text(
                    '\$${paid.toStringAsFixed(2)} ${loan.currency}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.green,
                    ),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${context.t('loan_pdf_remaining')}:'),
                  pw.Text(
                    '\$${loan.remainingAmount.toStringAsFixed(2)} ${loan.currency}',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: loan.status == 'overdue'
                          ? PdfColors.red
                          : PdfColors.orange,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${context.t('loan_pdf_status')}:'),
                  pw.Text(
                    loan.status.toUpperCase(),
                    style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('${context.t('loan_pdf_due')}:'),
                  pw.Text(_formatDate(loan.dueDate)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                '${context.t('loan_payment_history')}:',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 8),
              if (payments.isEmpty)
                pw.Text('${context.t('loan_pdf_no_payments')}.')
              else
                ...payments.map(
                  (p) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(_formatDate(p.date)),
                        pw.Text(
                          '\$${p.amount.toStringAsFixed(2)} ${loan.currency}',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              pw.SizedBox(height: 24),
              pw.Divider(),
              pw.SizedBox(height: 8),
              pw.Text(
                '${context.t('loan_pdf_footer')} • ${_formatDate(DateTime.now())}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/prestamo_$safeName.pdf');
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], text: shareText),
    );
  }

  // ──────────────────────────────────────────
  //   DIALOGS
  // ──────────────────────────────────────────
  void _showRefinanceDialog(BuildContext context) {
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);
    final current = _currentLoan(loanProvider);
    final remainingDebt = current.remainingAmount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        title: Text(context.t('loan_refinance_title')),
        content: Text(
          context
              .t('loan_refinance_desc')
              .replaceAll('{amount}', '\$${remainingDebt.toStringAsFixed(2)}')
              .replaceAll('{currency}', current.currency),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          CashButton(
            label: context.t('cancel'),
            type: CashButtonType.secondary,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          CashButton(
            label: context.t('loan_refinance'),
            fullWidth: false,
            onPressed: () async {
              Navigator.pop(ctx);
              await loanProvider.refinanceLoan(
                oldLoanId: current.id,
                newAmount: remainingDebt,
                newInterestRate: current.interestRate,
                newInterestType: current.interestType,
                newFrequency: current.frequency,
                newDurationValue: current.durationValue,
                newStartDate: DateTime.now(),
                newDueDate: DateTime.now().add(
                  Duration(days: current.durationValue * 30),
                ),
                newCurrency: current.currency,
                lateFeeType: current.lateFeeType,
                lateFeeValue: current.lateFeeValue,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t('loan_refinance_success')),
                    backgroundColor: AppColors.info,
                  ),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmMarkAsLost(BuildContext context) {
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);
    final current = _currentLoan(loanProvider);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(Icons.cancel_outlined, color: AppColors.error),
        title: Text(context.t('loan_mark_loss_title')),
        content: Text(
          context
              .t('loan_mark_loss_desc')
              .replaceAll('{name}', current.borrowerName)
              .replaceAll(
                '{amount}',
                '\$${current.remainingAmount.toStringAsFixed(2)}',
              ),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          CashButton(
            label: context.t('cancel'),
            type: CashButtonType.secondary,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          CashButton(
            label: context.t('loan_mark_loss'),
            type: CashButtonType.danger,
            fullWidth: false,
            onPressed: () async {
              Navigator.pop(ctx);
              await loanProvider.markAsLost(current.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('loan_mark_loss_success'))),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLoan(BuildContext context, LoanProvider loanProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        title: Text(context.t('loan_delete_title')),
        content: Text(
          context.t('loan_delete_desc'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          CashButton(
            label: context.t('cancel'),
            type: CashButtonType.secondary,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          CashButton(
            label: context.t('delete'),
            type: CashButtonType.danger,
            fullWidth: false,
            onPressed: () async {
              Navigator.pop(ctx);
              await loanProvider.deleteLoan(loan.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('loan_delete_success'))),
                );
                Navigator.pop(context);
              }
            },
          ),
        ],
      ),
    );
  }

  void _confirmDeletePayment(
    BuildContext context,
    LoanProvider loanProvider,
    String paymentId,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(Icons.delete_outline, color: AppColors.error),
        title: Text(context.t('loan_delete_payment_title')),
        content: Text(
          context.t('loan_delete_payment_desc'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          CashButton(
            label: context.t('cancel'),
            type: CashButtonType.secondary,
            fullWidth: false,
            onPressed: () => Navigator.pop(ctx),
          ),
          CashButton(
            label: context.t('delete'),
            type: CashButtonType.danger,
            fullWidth: false,
            onPressed: () async {
              Navigator.pop(ctx);
              await loanProvider.deletePayment(paymentId);
            },
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// WIDGETS AUXILIARES
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.primaryLight : AppColors.primaryDark,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
