import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/models.dart';
import '../models/recurring_transaction.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../utils/icon_constants.dart';
import '../widgets/design/cash_amount_input.dart';
import '../widgets/design/cash_bottom_sheet.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_input.dart';
import '../widgets/design/cash_selector_field.dart';

/// Alta y edición de transacciones recurrentes.
///
/// Se conservan íntegros el modelo `RecurringTransaction`, los valores internos
/// de periodicidad (`diario`, `semanal`, `quincenal`, `mensual`,
/// `trimestral`, `anual`), el rango del selector de fecha, las validaciones del
/// `Form` y las llamadas al provider. Lo que cambia es la presentación, que
/// hace evidente la periodicidad y la próxima ejecución.
class RecurringTransactionFormScreen extends StatefulWidget {
  final RecurringTransaction? transaction;
  final bool isIncome;
  const RecurringTransactionFormScreen({
    super.key,
    this.transaction,
    this.isIncome = true,
  });

  @override
  State<RecurringTransactionFormScreen> createState() =>
      _RecurringTransactionFormScreenState();
}

class _RecurringTransactionFormScreenState
    extends State<RecurringTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();

  String? _selectedCategory;
  String? _selectedAccount;
  String _recurrence = 'mensual';
  bool _autoRegister = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  bool _isSaving = false;

  /// Los valores internos no se tocan: son los que se guardan en Hive.
  static const List<String> _recurrenceOptions = [
    'diario',
    'semanal',
    'quincenal',
    'mensual',
    'trimestral',
    'anual',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _descController.text = widget.transaction!.description;
      _amountController.text = widget.transaction!.amount.toString();
      _selectedCategory = widget.transaction!.categoryId;
      _selectedAccount = widget.transaction!.accountId;
      _recurrence = widget.transaction!.recurrence;
      _autoRegister = widget.transaction!.autoRegister;
      _selectedDate = widget.transaction!.nextExecutionDate;
      _selectedTime = TimeOfDay.fromDateTime(
        widget.transaction!.nextExecutionDate,
      );
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE NEGOCIO (sin cambios)
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2050),
      helpText: context.t('rec_next_run'),
      cancelText: context.t('cancel'),
      confirmText: context.t('confirm'),
    );
    if (date != null && mounted) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null && mounted) {
      setState(() => _selectedTime = time);
    }
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCategory == null || _selectedAccount == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('rec_error_select'))));
      return;
    }

    setState(() => _isSaving = true);

    final provider = context.read<AppProvider>();
    final dt = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final rt = RecurringTransaction(
      id: widget.transaction?.id ?? const Uuid().v4(),
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      amount: double.parse(_amountController.text),
      categoryId: _selectedCategory!,
      accountId: _selectedAccount!,
      nextExecutionDate: dt,
      recurrence: _recurrence,
      autoRegister: _autoRegister,
      isIncome: widget.isIncome,
    );

    if (widget.transaction == null) {
      await provider.addRecurringTransaction(rt);
    } else {
      await provider.updateRecurringTransaction(rt);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  String _recurrenceLabel(String value) {
    switch (value) {
      case 'diario':
        return context.t('rec_daily');
      case 'semanal':
        return context.t('rec_weekly');
      case 'quincenal':
        return context.t('rec_biweekly');
      case 'mensual':
        return context.t('rec_monthly');
      case 'trimestral':
        return context.t('rec_quarterly');
      case 'anual':
        return context.t('rec_yearly');
    }
    return value;
  }

  String _screenTitle() {
    if (widget.transaction == null) {
      return widget.isIncome
          ? context.t('rec_new_income')
          : context.t('rec_new_expense');
    }
    return widget.isIncome
        ? context.t('rec_edit_income')
        : context.t('rec_edit_expense');
  }

  // ---------------------------------------------------------------------------
  // SELECTORES
  // ---------------------------------------------------------------------------

  Future<void> _pickCategory(AppProvider provider) async {
    final visibleCategories = provider.categoriesFor(widget.isIncome);
    if (visibleCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('rec_empty_categories'))),
      );
      return;
    }

    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('form_select_category'),
        child: Column(
          children: [
            for (final cat in visibleCategories) ...[
              CashCard(
                onTap: () => Navigator.pop(sheetContext, cat.id),
                padding: const EdgeInsets.all(AppSpacing.md),
                border: cat.id == _selectedCategory
                    ? Border.all(color: AppColors.primary, width: 1.4)
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Color(cat.colorValue).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        IconConstants.getCategoryIcon(cat.iconCode),
                        size: 20,
                        color: Color(cat.colorValue),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        cat.id.startsWith('cat_')
                            ? sheetContext.t(cat.id)
                            : cat.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(sheetContext).textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (cat.id == _selectedCategory)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedCategory = selected);
  }

  Future<void> _pickAccount(AppProvider provider) async {
    if (provider.cards.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.t('rec_empty_accounts'))));
      return;
    }

    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('form_select_account'),
        subtitle: sheetContext.t('form_select_account_hint'),
        child: Column(
          children: [
            for (final card in provider.cards) ...[
              CashCard(
                onTap: () => Navigator.pop(sheetContext, card.id),
                padding: const EdgeInsets.all(AppSpacing.md),
                border: card.id == _selectedAccount
                    ? Border.all(color: AppColors.primary, width: 1.4)
                    : null,
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.primarySurface,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        card.isCash
                            ? Icons.payments_outlined
                            : Icons.credit_card_rounded,
                        size: 20,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            card.isCash ? card.name : (card.bankName ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(sheetContext).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(
                            card.currency,
                            style: Theme.of(sheetContext).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    if (card.id == _selectedAccount)
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedAccount = selected);
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    // Categorías compatibles con el flujo (gasto → expense+both; ingreso →
    // income+both). Las categorías antiguas sin `type` se comportan como both.
    final categories = provider.categoriesFor(widget.isIncome);
    final accounts = provider.cards;

    // Categoría por defecto compatible; en edición se conserva la original.
    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first.id;
    }
    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.first.id;
    }

    final Color semantic = widget.isIncome
        ? AppColors.income
        : AppColors.expense;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          _screenTitle(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenHorizontal,
              AppSpacing.sm,
              AppSpacing.screenHorizontal,
              AppSpacing.xxxl,
            ),
            children: [
              _buildTypeBadge(semantic),
              const SizedBox(height: AppSpacing.lg),
              CashAmountInput(
                controller: _amountController,
                label: context.t('rec_amount'),
                symbol: '\$',
                isExpense: !widget.isIncome,
                compact: true,
                textInputAction: TextInputAction.next,
                onChanged: (_) {},
              ),
              const SizedBox(height: AppSpacing.xl),
              CashInput(
                controller: _titleController,
                label: context.t('rec_title'),
                hint: context.t('rec_title_hint'),
                prefix: const Icon(Icons.title),
                validator: (v) => (v == null || v.isEmpty)
                    ? context.t('rec_error_required')
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CashSelectorField(
                label: context.t('form_category'),
                value: categories.isEmpty
                    ? null
                    : _categoryName(categories, _selectedCategory),
                placeholder: context.t('form_select_category'),
                icon: Icons.category_outlined,
                onTap: () => _pickCategory(provider),
              ),
              const SizedBox(height: AppSpacing.md),
              CashSelectorField(
                label: context.t('form_destination_account'),
                value: accounts.isEmpty
                    ? null
                    : _accountName(accounts, _selectedAccount),
                placeholder: context.t('form_select_account'),
                icon: Icons.account_balance_wallet_outlined,
                onTap: () => _pickAccount(provider),
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildFrequency(),
              const SizedBox(height: AppSpacing.xl),
              _buildNextRun(),
              const SizedBox(height: AppSpacing.xl),
              CashInput(
                controller: _descController,
                label: context.t('rec_description_optional'),
                maxLines: 3,
                prefix: const Icon(Icons.notes),
              ),
              const SizedBox(height: AppSpacing.lg),
              _buildAutoRegister(semantic),
              const SizedBox(height: AppSpacing.xxl),
              CashButton(
                label: _isSaving
                    ? context.t('form_saving')
                    : widget.transaction == null
                    ? context.t('rec_save')
                    : context.t('rec_update'),
                icon: Icon(
                  widget.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 20,
                ),
                loading: _isSaving,
                onPressed: _isSaving ? null : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _categoryName(List<Category> categories, String? id) {
    for (final Category cat in categories) {
      if (cat.id == id) {
        return cat.id.startsWith('cat_') ? context.t(cat.id) : cat.name;
      }
    }
    return '';
  }

  String _accountName(List<AccountCard> accounts, String? id) {
    for (final AccountCard card in accounts) {
      if (card.id == id) {
        return card.isCash
            ? '${context.t('card_cash')} · ${card.name}'
            : (card.bankName ?? context.t('card_default_name'));
      }
    }
    return '';
  }

  Widget _buildTypeBadge(Color semantic) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: semantic.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: semantic.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.isIncome
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                size: 18,
                color: semantic,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.isIncome
                    ? context.t('type_income')
                    : context.t('type_expense'),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: semantic,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFrequency() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('rec_frequency'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        // `Wrap`: seis periodicidades nunca caben en una fila a 320 px.
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.sm,
          children: [
            for (final value in _recurrenceOptions)
              CashChip(
                label: _recurrenceLabel(value),
                selected: _recurrence == value,
                icon: _recurrence == value ? Icons.check : null,
                onTap: () => setState(() => _recurrence = value),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildNextRun() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final bool isToday = day == today;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          context.t('rec_next_run'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: AppSpacing.sm),
        CashCard(
          padding: const EdgeInsets.all(AppSpacing.md),
          onTap: _pickDate,
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.event_repeat_rounded,
                  color: AppColors.primaryDark,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      DateFormat('dd MMM yyyy').format(_selectedDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      _recurrenceLabel(_recurrence),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CashButton(
                label: _selectedTime.format(context),
                type: CashButtonType.outlined,
                height: 38,
                // Boton compacto de hora dentro de un Row: el ancho del hijo
                // es infinito, no debe intentar estirarse.
                fullWidth: false,
                onPressed: _pickTime,
              ),
            ],
          ),
        ),
        if (isToday) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            context.t('form_today'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ],
    );
  }

  Widget _buildAutoRegister(Color semantic) {
    return CashCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.sm,
      ),
      // Material transparente entre el Container decorado del CashCard y el
      // SwitchListTile: el ListTile pinta su fondo y sus ripples sobre el
      // Material mas cercano, y sin el quedarian ocultos por la decoracion.
      child: Material(
        type: MaterialType.transparency,
        child: SwitchListTile(
          contentPadding: EdgeInsets.zero,
          value: _autoRegister,
          activeThumbColor: semantic,
          onChanged: (v) => setState(() => _autoRegister = v),
          title: Text(
            context.t('rec_auto'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            context.t('rec_auto_desc'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ),
    );
  }
}
