import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/loan.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_amount_input.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_selector_field.dart';

/// Registro de un cobro/pago sobre un préstamo.
///
/// El rediseño es exclusivamente visual y de usabilidad: se conserva la misma
/// operación de registro ([LoanProvider.addPayment]), las mismas validaciones
/// del importe, el selector de fecha con sus límites, la opción de depositar el
/// cobro en una cuenta y el mismo comportamiento posterior (aviso y regreso).
/// El préstamo se identifica siempre por su `id`; la pantalla lee el estado
/// vigente del provider y nunca confía en una copia potencialmente obsoleta.
class LoanPaymentFormScreen extends StatefulWidget {
  final Loan loan;
  const LoanPaymentFormScreen({super.key, required this.loan});

  @override
  State<LoanPaymentFormScreen> createState() => _LoanPaymentFormScreenState();
}

class _LoanPaymentFormScreenState extends State<LoanPaymentFormScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  DateTime _paymentDate = DateTime.now();

  // Integración con la cartera (misma funcionalidad existente).
  bool _depositToCard = false;
  String? _selectedCardId;

  /// Error de validación del importe mostrado por [CashAmountInput].
  String? _amountError;

  /// Evita registrar el cobro varias veces por pulsaciones repetidas.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    // Igual que antes: se precarga el saldo pendiente del préstamo recibido.
    _amountController = TextEditingController(
      text: widget.loan.remainingAmount.toString(),
    );
    _amountController.addListener(_onAmountChanged);
    _notesController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      // Sólo se ofrecen cuentas compatibles con la moneda del préstamo; así la
      // selección por defecto siempre es válida (antes podía apuntar a una
      // cuenta de otra moneda que no aparecía entre las opciones).
      final matching = _matchingCards(appProvider);
      if (matching.isNotEmpty) {
        setState(() => _selectedCardId = matching.first.id);
      }
    });
  }

  @override
  void dispose() {
    _amountController.removeListener(_onAmountChanged);
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _onAmountChanged() {
    if (!mounted) return;
    // Refresca el color del importe y limpia el error al editar.
    setState(() {
      if (_amountError != null) _amountError = null;
    });
  }

  // ──────────────────────────────────────────
  //   HELPERS
  // ──────────────────────────────────────────
  List<AccountCard> _matchingCards(AppProvider appProvider) {
    return appProvider.cards
        .where((c) => c.currency == widget.loan.currency)
        .toList();
  }

  String _currencySymbol(AppProvider appProvider, String code) {
    for (final currency in appProvider.availableCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return code;
  }

  String _formatDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  Loan? _currentLoan(LoanProvider loanProvider) {
    for (final loan in loanProvider.loans) {
      if (loan.id == widget.loan.id) return loan;
    }
    return null;
  }

  double? _parseAmount(String raw) {
    final cleaned = raw.trim().replaceAll(',', '.');
    return double.tryParse(cleaned);
  }

  /// Misma regla de validación que la implementación anterior.
  String? _validateAmount(double remaining) {
    final raw = _amountController.text.trim();
    if (raw.isEmpty) return context.t('complete_data_error');
    final parsed = _parseAmount(raw);
    if (parsed == null || parsed <= 0) return context.t('complete_data_error');
    if (parsed > remaining) return context.t('payment_exceeds_balance');
    return null;
  }

  // ──────────────────────────────────────────
  //   FECHA
  // ──────────────────────────────────────────
  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _paymentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: Theme.of(context).colorScheme.primary,
              onPrimary: Colors.white,
              surface: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              onSurface: isDark
                  ? AppColors.textPrimaryDark
                  : AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && mounted) {
      setState(() => _paymentDate = picked);
    }
  }

  // ──────────────────────────────────────────
  //   SELECCIÓN DE CUENTA
  // ──────────────────────────────────────────
  Future<void> _pickCard(AppProvider appProvider) async {
    final cards = _matchingCards(appProvider);
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('select_card'),
        child: Column(
          children: [
            for (final card in cards)
              _SheetOption(
                leading: _SheetLeading(
                  icon: card.isCash
                      ? Icons.account_balance_wallet_rounded
                      : Icons.credit_card_rounded,
                  color: Color(card.colorValue),
                ),
                title: card.isCash ? card.name : (card.bankName ?? card.name),
                subtitle: card.currency,
                selected: _selectedCardId == card.id,
                onTap: () => Navigator.pop(sheetContext, card.id),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedCardId = selected);
  }

  String _cardLabel(AppProvider appProvider) {
    final id = _selectedCardId;
    if (id == null) return '';
    for (final card in appProvider.cards) {
      if (card.id == id) {
        final name = card.isCash
            ? context.t('card_cash')
            : (card.bankName ?? card.name);
        final tail = card.isCash
            ? 'CASH'
            : (card.cardNumber.length >= 4
                  ? card.cardNumber.substring(card.cardNumber.length - 4)
                  : card.cardNumber);
        return '$name (…$tail)';
      }
    }
    return '';
  }

  void _payAll(Loan loan) {
    setState(() {
      _amountController.text = loan.remainingAmount.toString();
      _amountError = null;
    });
  }

  // ──────────────────────────────────────────
  //   REGISTRO
  // ──────────────────────────────────────────
  Future<void> _submitForm() async {
    if (_isSubmitting) return;

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final loanProvider = Provider.of<LoanProvider>(context, listen: false);
    final current = _currentLoan(loanProvider);
    if (current == null) return;

    final error = _validateAmount(current.remainingAmount);
    if (error != null) {
      setState(() => _amountError = error);
      return;
    }

    final amount = _parseAmount(_amountController.text)!;
    final notes = _notesController.text.trim().isEmpty
        ? null
        : _notesController.text.trim();

    setState(() {
      _isSubmitting = true;
      _amountError = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final successMsg = context.t('payment_registered_msg');
    final errorMsg = context.t('error');

    try {
      // Misma operación y mismos datos persistidos que antes.
      await loanProvider.addPayment(
        loanId: current.id,
        amount: amount,
        cardId: _selectedCardId,
        notes: notes,
        date: _paymentDate,
        appProvider: appProvider,
        depositToCard: _depositToCard,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
      );
      return;
    }

    if (!mounted) return;
    messenger.showSnackBar(SnackBar(content: Text(successMsg)));
    navigator.pop();
  }

  // ──────────────────────────────────────────
  //   BUILD
  // ──────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appProvider = context.watch<AppProvider>();
    final loanProvider = context.watch<LoanProvider>();
    final loan = _currentLoan(loanProvider);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('register_payment')),
        centerTitle: true,
      ),
      body: SafeArea(
        child: loan == null
            ? CashEmptyState(
                icon: Icons.error_outline_rounded,
                title: context.t('error'),
                message: context.t('no_data'),
                buttonLabel: context.t('close'),
                onButtonPressed: () => Navigator.pop(context),
              )
            : _buildForm(context, theme, appProvider, loan),
      ),
    );
  }

  Widget _buildForm(
    BuildContext context,
    ThemeData theme,
    AppProvider appProvider,
    Loan loan,
  ) {
    final symbol = _currencySymbol(appProvider, loan.currency);
    final cards = _matchingCards(appProvider);

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(AppSpacing.xl),
      children: [
        _buildLoanCard(context, theme, loan, symbol),
        const SizedBox(height: AppSpacing.xl),

        // Importe: elemento principal del formulario.
        CashAmountInput(
          controller: _amountController,
          label: context.t('payment_amount'),
          symbol: symbol,
          code: loan.currency,
          isExpense: false,
          errorText: _amountError,
          textInputAction: TextInputAction.next,
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: _isSubmitting ? null : () => _payAll(loan),
            icon: const Icon(Icons.done_all_rounded, size: 18),
            label: Text(context.t('payment_pay_all')),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Fecha del pago (mismos límites que antes).
        CashSelectorField(
          label: context.t('payment_date'),
          value: _formatDate(_paymentDate),
          icon: Icons.calendar_today_rounded,
          showChevron: false,
          onTap: _isSubmitting ? null : _selectDate,
        ),

        // Depósito en cuenta (misma funcionalidad existente).
        if (cards.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          CashCard(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xs,
            ),
            child: Column(
              children: [
                Material(
                  type: MaterialType.transparency,
                  child: SwitchListTile(
                    value: _depositToCard,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      context.t('deposit_check'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: _isSubmitting
                        ? null
                        : (val) => setState(() => _depositToCard = val),
                  ),
                ),
                if (_depositToCard)
                  Padding(
                    padding: const EdgeInsets.only(
                      bottom: AppSpacing.md,
                      top: AppSpacing.xs,
                    ),
                    child: CashSelectorField(
                      label: context.t('select_card'),
                      value: _cardLabel(appProvider),
                      icon: Icons.credit_card_rounded,
                      onTap: () => _pickCard(appProvider),
                    ),
                  ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),
        CashInput(
          controller: _notesController,
          label: context.t('description_hint'),
          prefix: const Icon(Icons.edit_note_rounded),
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.xxl),

        CashButton(
          label: context.t('register_payment'),
          icon: const Icon(Icons.price_check_rounded, size: 20),
          loading: _isSubmitting,
          onPressed: _submitForm,
        ),
        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  Widget _buildLoanCard(
    BuildContext context,
    ThemeData theme,
    Loan loan,
    String symbol,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final status = _statusStyle(context, loan.status);

    return CashCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('borrower_name'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      loan.borrowerName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CashChip(
                label: status.label,
                icon: status.icon,
                selected: true,
                color: status.color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Icon(Icons.tag_rounded, size: 14, color: secondary),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  '#${loan.id.length > 8 ? loan.id.substring(0, 8) : loan.id}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ),
            ],
          ),
          const Divider(height: AppSpacing.xl),
          Text(
            context.t('remaining_balance'),
            style: theme.textTheme.labelMedium?.copyWith(color: secondary),
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
                color: _statusStyle(context, loan.status).color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  _LoanStatusStyle _statusStyle(BuildContext context, String status) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    switch (status) {
      case 'paid':
        return _LoanStatusStyle(
          AppColors.income,
          Icons.check_circle_outline_rounded,
          context.t('loan_status_paid_short'),
        );
      case 'overdue':
        return _LoanStatusStyle(
          AppColors.error,
          Icons.error_outline_rounded,
          context.t('loan_status_overdue_short'),
        );
      case 'written_off':
        return _LoanStatusStyle(
          isDark ? AppColors.textTertiaryDark : AppColors.textTertiary,
          Icons.cancel_outlined,
          context.t('loan_status_written_off'),
        );
      case 'refinanced':
        return _LoanStatusStyle(
          AppColors.info,
          Icons.swap_horiz_rounded,
          context.t('loan_status_refinanced'),
        );
      case 'active':
      default:
        return _LoanStatusStyle(
          AppColors.primary,
          Icons.trending_up_rounded,
          context.t('loan_status_active'),
        );
    }
  }
}

// ─────────────────────────────────────────────
//   COMPONENTES AUXILIARES
// ─────────────────────────────────────────────
class _LoanStatusStyle {
  final Color color;
  final IconData icon;
  final String label;

  const _LoanStatusStyle(this.color, this.icon, this.label);
}

/// Opción dentro de la hoja de selección de cuenta (mismo patrón del Grupo 2).
class _SheetOption extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _SheetOption({
    required this.leading,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CashCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        border: selected
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.8), width: 1.4)
            : null,
        child: Row(
          children: [
            leading,
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
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.primary,
                size: 20,
              )
            else
              Icon(Icons.chevron_right, size: 20, color: secondary),
          ],
        ),
      ),
    );
  }
}

class _SheetLeading extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const _SheetLeading({required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent =
        color ??
        (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: AppRadius.radiusMd,
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 20, color: accent),
    );
  }
}
