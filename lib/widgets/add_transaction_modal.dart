import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../screens/add_card_screen.dart';
import '../screens/add_category_screen.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/app_spacing.dart';
import '../utils/icon_constants.dart';
import '../utils/number_format_utils.dart';
import 'design/cash_amount_input.dart';
import 'design/cash_bottom_sheet.dart';
import 'design/cash_button.dart';
import 'design/cash_card.dart';
import 'design/cash_empty_state.dart';
import 'design/cash_icon_button.dart';
import 'design/cash_input.dart';
import 'design/cash_selector_field.dart';

/// Formulario único de movimientos (gasto e ingreso).
///
/// La lógica financiera es exactamente la del formulario anterior: mismos
/// campos obligatorios (importe, categoría, cuenta), mismas validaciones
/// (importe > 0, categoría elegida, tarjeta bloqueada, fondos insuficientes,
/// PIN) y mismas llamadas al provider. Lo que cambia es la presentación, que
/// ordena los datos por jerarquía: importe → categoría → cuenta → fecha →
/// nota → guardar.
class AddTransactionModal extends StatefulWidget {
  final InternalTransaction? transactionToEdit;

  /// Modo inicial de la operación cuando se crea una transacción nueva.
  ///
  /// `null` conserva el comportamiento por defecto (gasto). Solo se aplica
  /// si no se está editando una transacción existente.
  final bool? startAsExpense;

  const AddTransactionModal({
    super.key,
    this.transactionToEdit,
    this.startAsExpense,
  });

  @override
  State<AddTransactionModal> createState() => _AddTransactionModalState();
}

class _AddTransactionModalState extends State<AddTransactionModal> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();

  String _selectedCategoryId = '';
  String? _selectedCardId;
  AccountCard? _selectedCard;
  String _selectedCurrency = 'USD';
  bool _isExpense = true;

  /// Fecha del movimiento. Por defecto es "hoy", igual que antes; el usuario
  /// puede cambiarla al crear, pero no al editar (`editTransaction` no acepta
  /// una fecha nueva, así que en edición se conserva la del movimiento).
  DateTime _selectedDate = DateTime.now();

  /// Errores contextuales: el mensaje aparece junto al campo que lo provoca.
  String? _amountError;
  String? _categoryError;
  bool _hasAccountError = false;

  /// Protección frente a dobles pulsaciones mientras se guarda.
  bool _isSaving = false;

  bool get _isEditing => widget.transactionToEdit != null;

  @override
  void initState() {
    super.initState();
    // If editing, populate fields
    if (widget.transactionToEdit != null) {
      final tx = widget.transactionToEdit!;
      _amountController.text = tx.amount.abs().toFormattedString(2);
      _titleController.text = tx.title;
      _selectedCategoryId = tx.categoryId;
      _selectedCardId = tx.cardId;
      _selectedCurrency = tx.currency;
      _isExpense = tx.amount < 0;
      _selectedDate = tx.date;
    } else if (widget.startAsExpense != null) {
      // Nueva transacción: respeta el modo pedido por quien la abre.
      _isExpense = widget.startAsExpense!;
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE NEGOCIO (idéntica al formulario anterior)
  // ---------------------------------------------------------------------------

  /// Parseo idéntico al original: se limpia todo lo que no sea dígito, punto o
  /// coma y la coma se interpreta como separador decimal.
  double _parseAmount() {
    final amountText = _amountController.text.replaceAll(
      RegExp(r'[^0-9.,]'),
      '',
    );
    return double.tryParse(amountText.replaceAll(',', '.')) ?? 0.0;
  }

  String _displayCategoryName(BuildContext context, Category category) {
    if (category.id.startsWith('cat_')) {
      return context.t(category.id);
    }
    return category.name;
  }

  void _saveTransaction() {
    if (_isSaving) return;

    final amount = _parseAmount();

    // Mismas reglas que antes, pero el error se muestra junto a su campo y el
    // modal sigue abierto para poder corregir sin volver a escribir nada.
    final String? amountError = amount <= 0
        ? context.t('form_error_amount')
        : null;
    final String? categoryError = _selectedCategoryId.isEmpty
        ? context.t('form_error_category')
        : null;

    if (amountError != null || categoryError != null) {
      setState(() {
        _amountError = amountError;
        _categoryError = categoryError;
      });
      return;
    }

    // Determine sign based on transaction type
    final finalAmount = _isExpense ? -amount : amount;

    final provider = Provider.of<AppProvider>(context, listen: false);

    // Use Category Name if title is empty
    String title = _titleController.text;
    if (title.isEmpty) {
      final category = provider.categories.firstWhere(
        (cat) => cat.id == _selectedCategoryId,
        orElse: () => provider.categories.first,
      );
      title = category.name;
    }

    // Validate Card Security
    if (_selectedCardId != null) {
      try {
        final card = provider.cards.firstWhere((c) => c.id == _selectedCardId);

        if (card.isLocked) {
          setState(() => _hasAccountError = true);
          _showFeedback(context.t('card_locked'), isError: true);
          return;
        }

        // Check Insufficient Funds (Only for Expenses, and only when adding new
        // transactions)
        if (_isExpense && !_isEditing && (amount - card.balance) > 0.005) {
          setState(() => _hasAccountError = true);
          _showFeedback(
            '${context.t('insufficient_funds')} (${context.t('balance')}: '
            '${card.balance.toFormattedString(2)} ${card.currency})',
            isError: true,
          );
          return;
        }

        if (card.pin != null && card.pin!.isNotEmpty) {
          final expectedPin = card.pin!;
          _showPinDialog(context, expectedPin, (pin) {
            if (pin == expectedPin) {
              _executeTransaction(provider, finalAmount, title);
            } else {
              _showFeedback(context.t('incorrect_pin'), isError: true);
            }
          });
          return;
        }
      } catch (e) {
        // Card might not exist or other error
      }
    }

    _executeTransaction(provider, finalAmount, title);
  }

  Future<void> _executeTransaction(
    AppProvider provider,
    double amount,
    String title,
  ) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color successBackground = isDark
        ? AppColors.surfaceDark3
        : AppColors.primaryDark;
    final Color successForeground = isDark
        ? AppColors.textPrimaryDark
        : AppColors.white;

    if (_isEditing) {
      try {
        await provider.editTransaction(
          widget.transactionToEdit!.id,
          newAmount: amount,
          newTitle: title,
          newCategoryId: _selectedCategoryId,
          newCurrency: _selectedCurrency,
        );
        if (!mounted) return;
        Navigator.pop(context);
        messenger.showSnackBar(
          _resultSnackBar(
            context.t('form_updated'),
            background: successBackground,
            foreground: successForeground,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        _showFeedback(
          e.toString().replaceAll('Exception: ', ''),
          isError: true,
        );
      }
      return;
    }

    // Add mode. El provider no escribe nada y devuelve un código de error si la
    // cuenta quedaría en negativo; antes se ignoraba ese retorno, ahora se
    // espera para poder avisar en lugar de cerrar el modal en silencio.
    final String? error = await provider.addTransaction(
      amount: amount,
      title: title,
      categoryId: _selectedCategoryId,
      currency: _selectedCurrency,
      cardId: _selectedCardId,
      date: _selectedDate,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSaving = false;
        _hasAccountError = true;
      });
      _showFeedback(context.t('insufficient_funds'), isError: true);
      return;
    }

    // Check Budget Alerts
    if (amount < 0) {
      final category = provider.categories.firstWhere(
        (c) => c.id == _selectedCategoryId,
        orElse: () => provider.categories.first,
      );
      if (category.monthlyBudget != null && category.monthlyBudget! > 0) {
        final spentNow = provider.getSpentForCategoryThisMonth(category.id);
        final ratio = spentNow / category.monthlyBudget!;

        if (ratio >= 1.0) {
          _showFeedback(
            '${context.t('budget_alert_100')} ${category.name}',
            isError: true,
          );
        } else if (ratio >= 0.8) {
          _showFeedback(
            '${context.t('budget_alert_80')} ${category.name}',
            isWarning: true,
          );
        }
      }
    }

    Navigator.pop(context);

    messenger.showSnackBar(
      _resultSnackBar(
        context.t('form_saved'),
        background: successBackground,
        foreground: successForeground,
      ),
    );
  }

  SnackBar _resultSnackBar(
    String message, {
    required Color background,
    required Color foreground,
  }) {
    return SnackBar(
      content: Row(
        children: [
          Icon(Icons.check_circle, size: 18, color: foreground),
          const SizedBox(width: AppSpacing.sm),
          Expanded(child: Text(message)),
        ],
      ),
      backgroundColor: background,
    );
  }

  void _showFeedback(
    String message, {
    bool isError = false,
    bool isWarning = false,
  }) {
    if (!mounted) return;
    final ThemeData theme = Theme.of(context);
    final bool useOnSurface = !isError && !isWarning;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline
                  : isWarning
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle,
              size: 18,
              color: useOnSurface
                  ? theme.colorScheme.onSurface
                  : AppColors.white,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: isError
            ? AppColors.error
            : isWarning
            ? AppColors.warning
            : theme.colorScheme.surfaceContainerHighest,
      ),
    );
  }

  void _showPinDialog(
    BuildContext context,
    String expectedPin,
    Function(String) onConfirm,
  ) {
    final controller = TextEditingController();
    String? pinError;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            void submit() {
              if (controller.text == expectedPin) {
                Navigator.pop(dialogContext);
                onConfirm(controller.text);
              } else {
                setDialogState(() => pinError = context.t('incorrect_pin'));
              }
            }

            return AlertDialog(
              shape: const RoundedRectangleBorder(
                borderRadius: AppRadius.radiusXl,
              ),
              icon: const Icon(Icons.lock_outline, color: AppColors.primary),
              title: Text(context.t('form_pin_title')),
              content: CashInput(
                controller: controller,
                label: context.t('enter_pin'),
                hint: '****',
                errorText: pinError,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                obscureText: true,
                maxLength: 4,
                autofocus: true,
                onChanged: (_) {
                  if (pinError != null) setDialogState(() => pinError = null);
                },
                onSubmitted: (_) => submit(),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(context.t('cancel')),
                ),
                CashButton(
                  label: context.t('confirm'),
                  fullWidth: false,
                  height: 44,
                  onPressed: submit,
                ),
              ],
            );
          },
        );
      },
    ).whenComplete(controller.dispose);
  }

  // ---------------------------------------------------------------------------
  // SELECTORES
  // ---------------------------------------------------------------------------

  AccountCard? _cardById(List<AccountCard> cards, String? id) {
    if (id == null) return null;
    for (final card in cards) {
      if (card.id == id) return card;
    }
    return null;
  }

  Currency? _currencyByCode(String code) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    for (final currency in provider.availableCurrencies) {
      if (currency.code == code) return currency;
    }
    return null;
  }

  Future<void> _pickAccount(AppProvider provider) async {
    if (provider.cards.isEmpty) {
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const AddCardScreen()),
      );
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
              _AccountOption(
                card: card,
                isSelected: card.id == _selectedCardId,
                onTap: () => Navigator.pop(sheetContext, card.id),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;

    final AccountCard card =
        _cardById(provider.cards, selected) ?? provider.cards.first;

    setState(() {
      _selectedCardId = card.id;
      _selectedCard = card;
      _selectedCurrency = card.currency;
      _hasAccountError = false;
    });
  }

  Future<void> _pickCategory(AppProvider provider) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('form_select_category'),
        child: Column(
          children: [
            // Crear categoría al principio: visible sin necesidad de desplazarse.
            CashButton(
              label: sheetContext.t('create'),
              icon: const Icon(Icons.add, size: 20),
              type: CashButtonType.outlined,
              onPressed: () {
                if (!provider.canCreateCategory) {
                  _showFeatureLocked(sheetContext);
                  return;
                }
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
                );
              },
            ),
            const SizedBox(height: AppSpacing.md),
            for (final cat in provider.categoriesFor(_isExpense)) ...[
              _CategoryOption(
                category: cat,
                name: _displayCategoryName(sheetContext, cat),
                isSelected: cat.id == _selectedCategoryId,
                onTap: () => Navigator.pop(sheetContext, cat.id),
                onEdit: () {
                  Navigator.pop(sheetContext);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddCategoryScreen(category: cat),
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() {
      _selectedCategoryId = selected;
      _categoryError = null;
    });
  }

  void _showFeatureLocked(BuildContext dialogContext) {
    showDialog(
      context: dialogContext,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(Icons.lock_outline, color: AppColors.warning),
        title: Text(context.t('feature_locked_title')),
        content: Text(context.t('feature_locked_desc')),
        actions: [
          CashButton(
            label: context.t('close'),
            fullWidth: false,
            height: 44,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    if (_isEditing) return;

    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);

    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: context.t('form_date'),
      cancelText: context.t('cancel'),
      confirmText: context.t('confirm'),
    );

    if (picked == null || !mounted) return;
    setState(() => _selectedDate = picked);
  }

  String _dateLabel() {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime day = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
    );
    final int diff = day.difference(today).inDays;
    if (diff == 0) return context.t('form_today');
    if (diff == -1) return context.t('form_yesterday');
    return '${_selectedDate.day.toString().padLeft(2, '0')}/'
        '${_selectedDate.month.toString().padLeft(2, '0')}/'
        '${_selectedDate.year}';
  }

  String _accountLabel(AccountCard card) {
    if (card.isCash) {
      return '${context.t('card_cash')} · ${card.name}';
    }
    final String bank = card.bankName == 'Efectivo'
        ? context.t('card_cash')
        : (card.bankName ?? context.t('card_default_name'));
    final String last4 = card.cardNumber.length >= 4
        ? card.cardNumber.substring(card.cardNumber.length - 4)
        : '';
    return last4.isEmpty ? bank : '$bank ···$last4';
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    // Sólo categorías compatibles con el flujo actual: gasto → expense+both,
    // ingreso → income+both. Las categorías antiguas (sin `type`) se
    // comportan como `both`.
    final categories = provider.categoriesFor(_isExpense);

    // Categoría por defecto compatible con el flujo. En edición se respeta
    // siempre la categoría del movimiento original.
    if (categories.isNotEmpty &&
        (_selectedCategoryId.isEmpty ||
            (!_isEditing &&
                !categories.any((c) => c.id == _selectedCategoryId)))) {
      _selectedCategoryId = categories.first.id;
    }

    // Selección por defecto de la cuenta, idéntica a la del formulario
    // anterior: la primera cuenta y su moneda.
    if (_selectedCardId == null && provider.cards.isNotEmpty) {
      _selectedCardId = provider.cards.first.id;
      _selectedCard = provider.cards.first;
      _selectedCurrency = provider.cards.first.currency;
    }

    // La moneda sigue a la cuenta elegida; en edición manda la moneda que
    // tenía el movimiento.
    final String currencyCode =
        (_selectedCard != null && _selectedCard!.id == _selectedCardId)
        ? _selectedCard!.currency
        : _selectedCurrency;

    final AccountCard? card = _cardById(provider.cards, _selectedCardId);
    final Currency? currency = _currencyByCode(currencyCode);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final double bottomSafe = keyboardInset > 0
        ? 0.0
        : MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xxxl),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(context),
              Flexible(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    0,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildTypeToggle(),
                      const SizedBox(height: AppSpacing.xl),
                      CashAmountInput(
                        controller: _amountController,
                        label: context.t('amount'),
                        symbol: currency?.symbol ?? '',
                        code: currencyCode,
                        isExpense: _isExpense,
                        errorText: _amountError,
                        onChanged: (_) {
                          setState(() {
                            if (_amountError != null) {
                              _amountError = null;
                            }
                          });
                        },
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      _buildAccountField(provider, card),
                      const SizedBox(height: AppSpacing.lg),
                      _buildCategorySection(provider, categories),
                      const SizedBox(height: AppSpacing.lg),
                      _buildDateRow(),
                      const SizedBox(height: AppSpacing.md),
                      _buildNoteField(),
                    ],
                  ),
                ),
              ),
              _buildFooter(context, bottomSafe),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final Color secondary = Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formTitle(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  _isExpense
                      ? context.t('form_expense_hint')
                      : context.t('form_income_hint'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CashIconButton(
            icon: Icons.close,
            tooltip: context.t('close'),
            size: 42,
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  String _formTitle(BuildContext context) {
    if (_isEditing) {
      return _isExpense
          ? context.t('form_edit_expense')
          : context.t('form_edit_income');
    }
    return _isExpense ? context.t('type_expense') : context.t('type_income');
  }

  Widget _buildTypeToggle() {
    return Row(
      children: [
        Expanded(
          child: _TypeOption(
            label: context.t('type_expense'),
            icon: Icons.trending_down_rounded,
            selected: _isExpense,
            accent: AppColors.expense,
            onTap: () => setState(() => _isExpense = true),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: _TypeOption(
            label: context.t('type_income'),
            icon: Icons.trending_up_rounded,
            selected: !_isExpense,
            accent: AppColors.income,
            onTap: () => setState(() => _isExpense = false),
          ),
        ),
      ],
    );
  }

  Widget _buildAccountField(AppProvider provider, AccountCard? card) {
    if (provider.cards.isEmpty) {
      return CashCard(
        padding: const EdgeInsets.all(AppSpacing.lg),
        border: Border.all(
          color: _hasAccountError
              ? AppColors.error
              : Theme.of(context).brightness == Brightness.dark
              ? AppColors.borderDark
              : AppColors.borderLight,
        ),
        child: Row(
          children: [
            const Icon(Icons.account_balance_wallet_outlined),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                context.t('form_no_accounts'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return CashSelectorField(
      label: context.t('form_account'),
      value: card == null ? null : _accountLabel(card),
      placeholder: context.t('form_select_account'),
      leading: _AccountAvatar(card: card),
      trailing: card == null
          ? null
          : '${card.balance.toFormattedString(2)} ${card.currency}',
      helperText: context.t('form_balance_label'),
      errorText: _hasAccountError ? context.t('insufficient_funds') : null,
      onTap: () => _pickAccount(provider),
    );
  }

  Widget _buildCategorySection(
    AppProvider provider,
    List<Category> categories,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.t('form_category'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: CashButton(
                label: _selectedCategoryId.isEmpty
                    ? context.t('form_select_category')
                    : _selectedCategoryName(categories),
                icon: const Icon(Icons.unfold_more_rounded, size: 18),
                type: CashButtonType.outlined,
                height: 40,
                // Compacto: dentro de este Row el ancho del hijo es infinito,
                // por eso no puede intentar ocupar todo el espacio.
                fullWidth: false,
                onPressed: () => _pickCategory(provider),
              ),
            ),
          ],
        ),
        if (_categoryError != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(Icons.error_outline, size: 16, color: AppColors.error),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  _categoryError!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _buildCategoryGrid(provider, categories),
      ],
    );
  }

  String _selectedCategoryName(List<Category> categories) {
    if (categories.isEmpty) return '';
    for (final cat in categories) {
      if (cat.id == _selectedCategoryId) {
        return _displayCategoryName(context, cat);
      }
    }
    return _displayCategoryName(context, categories.first);
  }

  Widget _buildCategoryGrid(AppProvider provider, List<Category> categories) {
    if (categories.isEmpty) {
      return CashEmptyState(
        icon: Icons.category_outlined,
        title: context.t('rec_empty_categories'),
        message: context.t('form_error_category'),
      );
    }

    final double width = MediaQuery.sizeOf(context).width;
    final int columns = width >= 400 ? 4 : 3;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: categories.length + 1,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: AppSpacing.sm,
        crossAxisSpacing: AppSpacing.sm,
        childAspectRatio: 0.92,
      ),
      itemBuilder: (context, index) {
        // El botón "crear categoría" va siempre al principio, para no tener
        // que bajar hasta el final cuando hay muchas categorías.
        if (index == 0) {
          return _CategoryTile(
            label: context.t('create'),
            icon: Icons.add,
            color: AppColors.primary,
            isSelected: false,
            isLocked: !provider.canCreateCategory,
            onTap: () {
              if (provider.canCreateCategory) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddCategoryScreen()),
                );
              } else {
                _showFeatureLocked(context);
              }
            },
          );
        }

        final Category cat = categories[index - 1];
        return _CategoryTile(
          label: _displayCategoryName(context, cat),
          icon: IconConstants.getCategoryIcon(cat.iconCode),
          color: Color(cat.colorValue),
          isSelected: _selectedCategoryId == cat.id,
          onTap: () => setState(() {
            _selectedCategoryId = cat.id;
            _categoryError = null;
          }),
        );
      },
    );
  }

  Widget _buildDateRow() {
    return CashSelectorField(
      label: context.t('form_date'),
      value: _dateLabel(),
      icon: Icons.calendar_today_outlined,
      showChevron: !_isEditing,
      onTap: _isEditing ? null : _pickDate,
    );
  }

  Widget _buildNoteField() {
    return CashInput(
      controller: _titleController,
      label: context.t('form_note'),
      hint: context.t('form_note_optional'),
      prefix: const Icon(Icons.notes_rounded),
      textCapitalization: TextCapitalization.sentences,
    );
  }

  Widget _buildFooter(BuildContext context, double bottomSafe) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.xl,
        AppSpacing.md,
        AppSpacing.xl,
        bottomSafe > 0 ? bottomSafe + AppSpacing.md : AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.dividerLight,
          ),
        ),
      ),
      child: CashButton(
        label: _saveLabel(),
        icon: Icon(
          _isExpense ? Icons.arrow_downward : Icons.arrow_upward,
          size: 20,
        ),
        loading: _isSaving,
        onPressed: _isSaving ? null : _saveTransaction,
      ),
    );
  }

  String _saveLabel() {
    if (_isSaving) return context.t('form_saving');
    if (_isEditing) {
      return _isExpense
          ? context.t('form_edit_expense')
          : context.t('form_edit_income');
    }
    return _isExpense
        ? context.t('form_save_expense')
        : context.t('form_save_income');
  }
}

// ===========================================================================
// Sub-widgets locales del formulario
// ===========================================================================

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.18 : 0.10)
                : isDark
                ? AppColors.surfaceDark2
                : AppColors.surfaceVariantLight,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(
              color: selected ? accent : AppColors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? accent
                    : isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? accent : null,
                  ),
                ),
              ),
              // La selección no se comunica sólo con color: también con icono.
              if (selected) ...[
                const SizedBox(width: AppSpacing.xs),
                Icon(Icons.check_circle, size: 16, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final bool isLocked;
  final VoidCallback onTap;

  const _CategoryTile({
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color surface = isDark
        ? AppColors.surfaceDark2
        : AppColors.surfaceVariantLight;

    // El icono y el nombre se escalan a la caja real de la celda del grid:
    // el avatar crece con la celda y el texto usa un tamaño mayor para
    // aprovechar el ancho disponible.
    return LayoutBuilder(
      builder: (context, constraints) {
        final double cellWidth = constraints.maxWidth;
        final double avatarSize = (cellWidth * 0.50)
            .clamp(40.0, 56.0)
            .toDouble();
        final double iconSize = avatarSize * 0.52;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: AppRadius.radiusMd,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.xs,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.14) : surface,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(
                  color: isSelected
                      ? color.withValues(alpha: 0.75)
                      : isDark
                      ? AppColors.borderDark
                      : AppColors.borderLight,
                  width: isSelected ? 1.4 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: avatarSize,
                        height: avatarSize,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, size: iconSize, color: color),
                      ),
                      if (isSelected)
                        Positioned(
                          right: -6,
                          top: -6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(color: surface, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.check,
                              size: 10,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                      if (isLocked)
                        Positioned(
                          right: -6,
                          bottom: -6,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              shape: BoxShape.circle,
                              border: Border.all(color: surface, width: 1.5),
                            ),
                            child: const Icon(
                              Icons.lock,
                              size: 9,
                              color: AppColors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Expanded(
                    child: Center(
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: isSelected
                              ? FontWeight.w700
                              : FontWeight.w600,
                          height: 1.15,
                          color: isSelected
                              ? color
                              : isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AccountAvatar extends StatelessWidget {
  final AccountCard? card;

  const _AccountAvatar({this.card});

  @override
  Widget build(BuildContext context) {
    final bool isCash = card?.isCash ?? false;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primaryDark.withValues(alpha: 0.2)
            : AppColors.primarySurface,
        borderRadius: AppRadius.radiusMd,
      ),
      child: Icon(
        isCash ? Icons.payments_outlined : Icons.credit_card_rounded,
        size: 20,
        color: isDark ? AppColors.primary : AppColors.primaryDark,
      ),
    );
  }
}

class _AccountOption extends StatelessWidget {
  final AccountCard card;
  final bool isSelected;
  final VoidCallback onTap;

  const _AccountOption({
    required this.card,
    required this.isSelected,
    required this.onTap,
  });

  /// Título visible de la cuenta en la lista.
  ///
  /// Nunca queda vacío: una cuenta guardada sin banco (por ejemplo la de
  /// efectivo que crea la app al empezar) se muestra con su nombre o, en su
  /// defecto, con la etiqueta localizada de cuenta por defecto.
  String _title(BuildContext context) {
    if (card.isCash) {
      return '${context.t('card_cash')} · ${card.name}';
    }
    final String bank = card.bankName == 'Efectivo'
        ? context.t('card_cash')
        : (card.bankName?.trim().isNotEmpty ?? false
              ? card.bankName!.trim()
              : card.name.trim().isNotEmpty
              ? card.name.trim()
              : context.t('card_default_name'));
    return bank;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return CashCard(
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpacing.md),
      border: isSelected
          ? Border.all(color: AppColors.primary, width: 1.4)
          : null,
      boxShadow: AppShadows.soft,
      child: Row(
        children: [
          _AccountAvatar(card: card),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title(context),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '${card.balance.toFormattedString(2)} ${card.currency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (card.isLocked)
            const Icon(Icons.lock, size: 16, color: AppColors.warning)
          else if (isSelected)
            const Icon(Icons.check_circle, color: AppColors.primary)
          else
            Icon(Icons.chevron_right, size: 20, color: secondary),
        ],
      ),
    );
  }
}

class _CategoryOption extends StatelessWidget {
  final Category category;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryOption({
    required this.category,
    required this.name,
    required this.isSelected,
    required this.onTap,
    this.onEdit,
  });

  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final Color color = Color(category.colorValue);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CashCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        border: isSelected
            ? Border.all(color: color.withValues(alpha: 0.8), width: 1.4)
            : null,
        boxShadow: AppShadows.soft,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(
                IconConstants.getCategoryIcon(category.iconCode),
                size: 20,
                color: color,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (onEdit != null) ...[
              IconButton(
                onPressed: onEdit,
                tooltip: context.t('edit'),
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.all(4),
                constraints: const BoxConstraints(),
                iconSize: 18,
                icon: Icon(Icons.edit_outlined, color: secondary),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            if (isSelected)
              Icon(Icons.check_circle, color: color, size: 20)
            else
              Icon(Icons.chevron_right, size: 20, color: secondary),
          ],
        ),
      ),
    );
  }
}
