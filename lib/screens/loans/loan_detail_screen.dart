import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../../providers/loan_provider.dart';
import '../../models/loan.dart';
import '../../models/loan_activity.dart';
import 'package:cashrapido/utils/number_format_utils.dart';
import '../../services/localization_service.dart';
import 'loan_form_screen.dart';
import 'loan_payment_form_screen.dart';

class LoanDetailScreen extends StatelessWidget {
  final Loan loan;
  const LoanDetailScreen({super.key, required this.loan});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('loan_detail_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
          ),
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
                    const SizedBox(width: 10),
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
                      color: Colors.blueAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.t('loan_refinance'),
                      style: const TextStyle(color: Colors.blueAccent),
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
                      color: Colors.redAccent,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      context.t('loan_mark_loss'),
                      style: const TextStyle(color: Colors.redAccent),
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

          Color statusColor;
          IconData statusIcon;
          String displayStatus;

          switch (currentLoan.status) {
            case 'paid':
              statusColor = Colors.green;
              statusIcon = Icons.check_circle_outline_rounded;
              displayStatus = context.t('loan_status_paid_short');
              break;
            case 'overdue':
              statusColor = Colors.red;
              statusIcon = Icons.error_outline_rounded;
              displayStatus = context.t('loan_status_overdue_short');
              break;
            case 'written_off':
              statusColor = Colors.grey;
              statusIcon = Icons.cancel_outlined;
              displayStatus = context.t('loan_status_written_off');
              break;
            case 'refinanced':
              statusColor = Colors.blueGrey;
              statusIcon = Icons.swap_horiz_rounded;
              displayStatus = context.t('loan_status_refinanced');
              break;
            case 'active':
            default:
              statusColor = theme.colorScheme.primary;
              statusIcon = Icons.trending_up_rounded;
              displayStatus = context.t('loan_status_active');
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 20),

                _buildQuickActions(context, currentLoan, loanProvider),
                const SizedBox(height: 20),

                _buildDetailsCard(context, currentLoan, loanProvider),
                const SizedBox(height: 20),

                // Installments Grid
                if (currentLoan.installments.isNotEmpty) ...[
                  _buildInstallmentsSection(context, currentLoan, isDark),
                  const SizedBox(height: 20),
                ],

                // Payment History
                _buildPaymentHistorySection(context, currentLoan, loanProvider),
                const SizedBox(height: 20),

                // Audit Log
                _buildActivityLogSection(
                  context,
                  currentLoan,
                  loanProvider,
                  isDark,
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }

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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  loan.borrowerName,
                  style: GoogleFonts.outfit(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, color: statusColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      displayStatus,
                      style: GoogleFonts.outfit(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.t('loan_outstanding_balance'),
            style: GoogleFonts.outfit(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 4),
          Text(
            '\$ ${loan.remainingAmount.toFormattedString(2)} ${loan.currency}',
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: loan.status == 'overdue'
                  ? Colors.red
                  : theme.textTheme.bodyLarge?.color,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${context.t('loan_collected_label')}: \$${paidAmount.toFormattedString(1)}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.green,
                ),
              ),
              Text(
                '${context.t('loan_total_label')}: \$${totalWithInterest.toFormattedString(1)}',
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                    color: statusColor,
                    minHeight: 8,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$progressPct%',
                style: GoogleFonts.outfit(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: statusColor,
                ),
              ),
            ],
          ),
          // Late fee indicator
          if (loan.lateFeeType != 'none') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 14,
                  color: Colors.orangeAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  '${context.t('loan_late_fee')}: ${loan.lateFeeType == 'fixed' ? '\$${loan.lateFeeValue.toStringAsFixed(0)} ${context.t('loan_late_fee_flat')}' : '${loan.lateFeeValue.toStringAsFixed(0)}% ${context.t('loan_late_fee_daily')}'}',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    color: Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        if (loan.remainingAmount > 0 &&
            loan.status != 'written_off' &&
            loan.status != 'refinanced') ...[
          Expanded(
            child: SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LoanPaymentFormScreen(loan: loan),
                  ),
                ),
                icon: const Icon(
                  Icons.price_check_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  context.t('loan_collect'),
                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        SizedBox(
          height: 50,
          width: 50,
          child: OutlinedButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => LoanFormScreen(loan: loan)),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: BorderSide(
                color: isDark ? Colors.white24 : Colors.grey[300]!,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Icon(
              Icons.edit_rounded,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(
          height: 50,
          width: 50,
          child: OutlinedButton(
            onPressed: () => _confirmDeleteLoan(context, loanProvider),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.redAccent,
            ),
          ),
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
    final isDark = theme.brightness == Brightness.dark;

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

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF141428) : Colors.grey[50],
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.feed_outlined,
                size: 20,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                context.t('loan_conditions'),
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow(
            context,
            context.t('loan_principal_loaned'),
            '\$${loan.amount.toFormattedString(2)} ${loan.currency}',
          ),
          _detailRow(
            context,
            context.t('loan_interest_rate'),
            loan.interestType == 'fixed'
                ? '\$${loan.interestRate.toStringAsFixed(0)}'
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
            '${loan.startDate.day}/${loan.startDate.month}/${loan.startDate.year}',
          ),
          _detailRow(
            context,
            context.t('loan_due_date'),
            '${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}',
            highlight: loan.status == 'overdue',
          ),
          if (loan.lateFeeType != 'none')
            _detailRow(
              context,
              context.t('loan_late_fee_label'),
              loan.lateFeeType == 'fixed'
                  ? '\$${loan.lateFeeValue.toStringAsFixed(0)} (${context.t('loan_late_fee_fixed')})'
                  : '${loan.lateFeeValue.toStringAsFixed(0)}% (${context.t('loan_late_fee_daily_label')})',
            ),
          const Divider(height: 24),
          SwitchListTile(
            title: Text(
              context.t('loan_due_alerts'),
              style: GoogleFonts.outfit(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
            value: loan.isNotificationsEnabled,
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => loanProvider.editLoan(
              loan.copyWith(isNotificationsEnabled: val),
            ),
          ),
          if (loan.notes != null && loan.notes!.isNotEmpty) ...[
            const Divider(height: 16),
            Text(
              context.t('loan_notes'),
              style: GoogleFonts.outfit(
                fontSize: 12,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              loan.notes!,
              style: GoogleFonts.outfit(fontSize: 14, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _detailRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
          ),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: highlight
                  ? Colors.red
                  : Theme.of(context).textTheme.bodyMedium?.color,
            ),
          ),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────
  //   INSTALLMENTS GRID
  // ──────────────────────────────────────────
  Widget _buildInstallmentsSection(
    BuildContext context,
    Loan loan,
    bool isDark,
  ) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.table_rows_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              context.t('loan_installments_schedule'),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141428) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? Colors.white12
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: loan.installments.length,
            separatorBuilder: (_, index) => Divider(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : Colors.grey[100],
              height: 1,
            ),
            itemBuilder: (ctx, i) {
              final inst = loan.installments[i];
              Color instColor;
              String instLabel;
              switch (inst.status) {
                case 'paid':
                  instColor = Colors.green;
                  instLabel = context.t('loan_status_paid_short');
                  break;
                case 'overdue':
                  instColor = Colors.red;
                  instLabel = context.t('loan_status_overdue_short');
                  break;
                case 'partial':
                  instColor = Colors.orange;
                  instLabel = context.t('loan_status_partial');
                  break;
                default:
                  instColor = Colors.grey;
                  instLabel = context.t('loan_status_pending');
                  break;
              }
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: instColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${inst.number}',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: instColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${inst.dueDate.day}/${inst.dueDate.month}/${inst.dueDate.year}',
                        style: GoogleFonts.outfit(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '\$${inst.amount.toStringAsFixed(2)}',
                          style: GoogleFonts.outfit(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (inst.paidAmount > 0 && inst.status != 'paid')
                          Text(
                            '${context.t('loan_payment_label')}: \$${inst.paidAmount.toStringAsFixed(2)}',
                            style: GoogleFonts.outfit(
                              fontSize: 10,
                              color: Colors.green,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: instColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        instLabel,
                        style: GoogleFonts.outfit(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
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
    final isDark = theme.brightness == Brightness.dark;
    final paymentsList = loanProvider.getPaymentsForLoan(loan.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.history_edu_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              context.t('loan_payment_history'),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (paymentsList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141428) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.receipt_long_rounded,
                  size: 36,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('loan_pdf_no_payments'),
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: paymentsList.length,
            itemBuilder: (context, index) {
              final payment = paymentsList[index];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141428) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_downward,
                        color: Colors.green,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '\$${payment.amount.toFormattedString(2)} ${loan.currency}',
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Colors.green,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${payment.date.day}/${payment.date.month}/${payment.date.year} ${payment.date.hour.toString().padLeft(2, '0')}:${payment.date.minute.toString().padLeft(2, '0')}',
                            style: GoogleFonts.outfit(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                          if (payment.notes != null &&
                              payment.notes!.isNotEmpty)
                            Text(
                              payment.notes!,
                              style: GoogleFonts.outfit(
                                fontSize: 11,
                                color: Colors.grey[600],
                                fontStyle: FontStyle.italic,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      onPressed: () => _confirmDeletePayment(
                        context,
                        loanProvider,
                        payment.id,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  // ──────────────────────────────────────────
  //   ACTIVITY LOG
  // ──────────────────────────────────────────
  Widget _buildActivityLogSection(
    BuildContext context,
    Loan loan,
    LoanProvider loanProvider,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final activities = loanProvider.getActivitiesForLoan(loan.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.timeline_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              context.t('loan_activity_log'),
              style: GoogleFonts.outfit(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (activities.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141428) : Colors.grey[50],
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.timeline_outlined,
                  size: 36,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  context.t('loan_no_events'),
                  style: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
                ),
              ],
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
                isDark,
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
    bool isDark,
  ) {
    Color iconColor;
    IconData iconData;
    switch (activity.action) {
      case 'Cobro':
        iconColor = Colors.green;
        iconData = Icons.payment;
        break;
      case 'Mora':
        iconColor = Colors.orange;
        iconData = Icons.warning_amber;
        break;
      case 'Vencido':
        iconColor = Colors.red;
        iconData = Icons.event_busy;
        break;
      case 'Refinanciado':
        iconColor = Colors.blue;
        iconData = Icons.swap_horiz;
        break;
      case 'Pérdida':
        iconColor = Colors.grey;
        iconData = Icons.cancel_outlined;
        break;
      default:
        iconColor = Colors.purple;
        iconData = Icons.add_circle_outline;
        break;
    }

    // Localize the action label
    String actionLabel = activity.action;
    if (activity.action == 'Cobro')
      actionLabel = context.t('activity_cobro');
    else if (activity.action == 'Mora')
      actionLabel = context.t('activity_mora');
    else if (activity.action == 'Vencido')
      actionLabel = context.t('activity_vencido');
    else if (activity.action == 'Refinanciado')
      actionLabel = context.t('activity_refinanciado');
    else if (activity.action == 'Pérdida')
      actionLabel = context.t('activity_perdida');

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
                color: isDark ? Colors.white12 : Colors.grey[200],
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      actionLabel,
                      style: GoogleFonts.outfit(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: iconColor,
                      ),
                    ),
                    Text(
                      '${activity.timestamp.hour.toString().padLeft(2, '0')}:${activity.timestamp.minute.toString().padLeft(2, '0')} ${activity.timestamp.day}/${activity.timestamp.month}/${activity.timestamp.year}',
                      style: GoogleFonts.outfit(
                        fontSize: 10,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  activity.description,
                  style: GoogleFonts.outfit(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.black54,
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
    final payments = loanProvider.getPaymentsForLoan(loan.id);
    final total = loanProvider.calculateTotalWithInterest(
      loan.amount,
      loan.interestRate,
      loan.interestType,
      loan.durationValue,
    );
    final paid = total - loan.remainingAmount;

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
                  pw.Text(
                    '${loan.dueDate.day}/${loan.dueDate.month}/${loan.dueDate.year}',
                  ),
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
                        pw.Text('${p.date.day}/${p.date.month}/${p.date.year}'),
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
                '${context.t('loan_pdf_footer')} • ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
                style: pw.TextStyle(fontSize: 9, color: PdfColors.grey),
              ),
            ],
          );
        },
      ),
    );

    final Uint8List bytes = await pdf.save();
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/prestamo_${loan.borrowerName.replaceAll(' ', '_')}.pdf',
    );
    await file.writeAsBytes(bytes);

    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: context
            .t('loan_pdf_share_text')
            .replaceAll('{name}', loan.borrowerName),
      ),
    );
  }

  // ──────────────────────────────────────────
  //   DIALOGS
  // ──────────────────────────────────────────
  void _showRefinanceDialog(BuildContext context) {
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);
    final remainingDebt = loan.remainingAmount;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141428),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.t('loan_refinance_title'),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          context
              .t('loan_refinance_desc')
              .replaceAll('{amount}', '\$${remainingDebt.toStringAsFixed(2)}')
              .replaceAll('{currency}', loan.currency),
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.t('cancel'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await loanProvider.refinanceLoan(
                oldLoanId: loan.id,
                newAmount: remainingDebt,
                newInterestRate: loan.interestRate,
                newInterestType: loan.interestType,
                newFrequency: loan.frequency,
                newDurationValue: loan.durationValue,
                newStartDate: DateTime.now(),
                newDueDate: DateTime.now().add(
                  Duration(days: loan.durationValue * 30),
                ),
                newCurrency: loan.currency,
                lateFeeType: loan.lateFeeType,
                lateFeeValue: loan.lateFeeValue,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t('loan_refinance_success')),
                    backgroundColor: Colors.blue,
                  ),
                );
                Navigator.pop(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(context.t('loan_refinance')),
          ),
        ],
      ),
    );
  }

  void _confirmMarkAsLost(BuildContext context) {
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141428),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          context.t('loan_mark_loss_title'),
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          context
              .t('loan_mark_loss_desc')
              .replaceAll('{name}', loan.borrowerName)
              .replaceAll(
                '{amount}',
                '\$${loan.remainingAmount.toStringAsFixed(2)}',
              ),
          style: GoogleFonts.outfit(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              context.t('cancel'),
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await loanProvider.markAsLost(loan.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t('loan_mark_loss_success')),
                    backgroundColor: Colors.grey,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(context.t('loan_mark_loss')),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteLoan(BuildContext context, LoanProvider loanProvider) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('loan_delete_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.t('loan_delete_desc'),
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
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
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(context.t('delete')),
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
        title: Text(
          context.t('loan_delete_payment_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Text(
          context.t('loan_delete_payment_desc'),
          style: GoogleFonts.outfit(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await loanProvider.deletePayment(paymentId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );
  }
}
