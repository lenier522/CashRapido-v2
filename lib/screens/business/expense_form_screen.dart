import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/business_expense.dart';
import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_amount_input.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_currency_field.dart';
import '../../widgets/design/cash_input.dart';

/// Formulario de creación/edición de gastos.
///
/// No cambia la lógica de guardado ([_saveExpense] se conserva tal cual, con el
/// mismo ajuste de tarjeta vinculada al editar el importe). Sólo reorganiza los
/// campos existentes en grupos legibles y usa el Design System.
class ExpenseFormScreen extends StatefulWidget {
  final BusinessExpense? expense;

  const ExpenseFormScreen({super.key, this.expense});

  @override
  State<ExpenseFormScreen> createState() => _ExpenseFormScreenState();
}

class _ExpenseFormScreenState extends State<ExpenseFormScreen> {
  late TextEditingController _amountController;
  late TextEditingController _descriptionController;
  late String _selectedCategory;
  late String _selectedCurrency;

  final List<String> _currencies = ['CUP', 'USD', 'EUR', 'MLC'];

  String? _amountError;
  String? _descriptionError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.expense?.amount.toString() ?? '',
    );
    _descriptionController = TextEditingController(
      text: widget.expense?.description ?? '',
    );
    _selectedCategory =
        widget.expense?.category ?? BusinessProvider.expenseCategories.first;
    final biz = Provider.of<BusinessProvider>(context, listen: false).activeBusiness;
    _selectedCurrency = widget.expense?.currency ?? biz?.currency ?? 'CUP';
    if (!_currencies.contains(_selectedCurrency)) {
      _currencies.add(_selectedCurrency);
    }
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  bool get _isEdit => widget.expense != null;

  String _symbolFor(AppProvider appProvider, String code) {
    for (final currency in appProvider.availableCurrencies) {
      if (currency.code == code) return currency.symbol;
    }
    return '\$';
  }

  String _nameFor(AppProvider appProvider, String code) {
    for (final currency in appProvider.availableCurrencies) {
      if (currency.code == code) return currency.name;
    }
    return code;
  }

  Future<void> _pickCurrency() async {
    final appProvider = context.read<AppProvider>();
    final picked = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: 'Moneda',
        subtitle: 'Selecciona la moneda con la que registrarás el gasto.',
        child: Column(
          children: [
            for (final code in _currencies)
              _CurrencyOptionRow(
                code: code,
                symbol: _symbolFor(appProvider, code),
                name: _nameFor(appProvider, code),
                selected: code == _selectedCurrency,
                onTap: () => Navigator.pop(sheetContext, code),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCurrency = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = context.watch<AppProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Editar gasto' : 'Nuevo gasto'),
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.xxxl,
          ),
          children: [
            const _SectionLabel(
              'Información del gasto',
              Icons.receipt_long_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            CashInput(
              controller: _descriptionController,
              label: 'Descripción *',
              hint: 'Ej. Compra de insumos',
              prefix: const Icon(Icons.description_outlined),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              errorText: _descriptionError,
              onChanged: (_) {
                if (_descriptionError != null) {
                  setState(() => _descriptionError = null);
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            const _SectionLabel('Categoría', Icons.category_outlined),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                for (final category in BusinessProvider.expenseCategories)
                  CashChip(
                    label: category,
                    icon: _categoryIcon(category),
                    selected: _selectedCategory == category,
                    color: _categoryColor(category),
                    onTap: () => setState(() => _selectedCategory = category),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.xxl),
            const _SectionLabel('Importe', Icons.attach_money_rounded),
            const SizedBox(height: AppSpacing.md),
            CashAmountInput(
              controller: _amountController,
              label: 'Monto *',
              symbol: _symbolFor(appProvider, _selectedCurrency),
              code: _selectedCurrency,
              isExpense: true,
              errorText: _amountError,
              onChanged: (_) {
                if (_amountError != null) {
                  setState(() => _amountError = null);
                }
              },
            ),
            const SizedBox(height: AppSpacing.lg),
            CashCurrencyField(
              code: _selectedCurrency,
              symbol: _symbolFor(appProvider, _selectedCurrency),
              name: _nameFor(appProvider, _selectedCurrency),
              onTap: _pickCurrency,
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.sm,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: CashButton(
            label: _isEdit ? 'Guardar cambios' : 'Registrar gasto',
            icon: Icon(_isEdit ? Icons.check_rounded : Icons.add_rounded, size: 20),
            loading: _isSaving,
            onPressed: _isSaving ? null : _saveExpense,
          ),
        ),
      ),
    );
  }

  Future<void> _saveExpense() async {
    final amount = double.tryParse(_amountController.text.trim().replaceAll(',', '.'));
    final description = _descriptionController.text.trim();

    setState(() {
      _amountError = amount == null ? 'Ingresa un monto válido' : null;
      _descriptionError = description.isEmpty ? 'Ingresa una descripción' : null;
    });
    if (_amountError != null || _descriptionError != null) return;

    setState(() => _isSaving = true);

    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    try {
      if (_isEdit) {
        final oldAmount = widget.expense!.amount;
        final newAmount = amount!;
        final diff = newAmount - oldAmount;
        if (provider.linkedCardId != null && diff.abs() > 0.005) {
          final desc = description.isNotEmpty ? description : _selectedCategory;
          await appProvider.addTransaction(
            amount: -diff,
            title: diff > 0 ? "Aumento Gasto: $desc" : "Ajuste Gasto: $desc",
            categoryId: 'cat_business',
            currency: _selectedCurrency,
            cardId: provider.linkedCardId,
            date: DateTime.now(),
            bypassBalanceCheck: true,
          );
        }
        final updated = widget.expense!.copyWith(
          amount: newAmount,
          category: _selectedCategory,
          description: description,
          currency: _selectedCurrency,
        );
        await provider.editExpense(updated);
      } else {
        await provider.addExpense(
          amount: amount!,
          category: _selectedCategory,
          description: description,
          currency: _selectedCurrency,
          appProvider: appProvider,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}

// ---------------------------------------------------------------------------
// AUXILIARES
// ---------------------------------------------------------------------------

class _SectionLabel extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionLabel(this.title, this.icon);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.expense),
        const SizedBox(width: AppSpacing.sm),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _CurrencyOptionRow extends StatelessWidget {
  final String code;
  final String symbol;
  final String name;
  final bool selected;
  final VoidCallback onTap;

  const _CurrencyOptionRow({
    required this.code,
    required this.symbol,
    required this.name,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CashCard(
        onTap: onTap,
        padding: const EdgeInsets.all(AppSpacing.md),
        border: selected
            ? Border.all(color: AppColors.primary, width: 1.4)
            : null,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  symbol,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    code,
                    style: Theme.of(
                      context,
                    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

Color _categoryColor(String category) {
  switch (category) {
    case 'Alquiler':
      return AppColors.purple;
    case 'Servicios':
      return AppColors.info;
    case 'Salarios':
      return AppColors.secondary;
    case 'Insumos':
      return AppColors.orange;
    case 'Marketing':
      return const Color(0xFFEC4899);
    case 'Transporte':
      return const Color(0xFF6366F1);
    default:
      return AppColors.textSecondary;
  }
}

IconData _categoryIcon(String category) {
  switch (category) {
    case 'Alquiler':
      return Icons.home_work_outlined;
    case 'Servicios':
      return Icons.build_outlined;
    case 'Salarios':
      return Icons.people_outline;
    case 'Insumos':
      return Icons.inventory_2_outlined;
    case 'Marketing':
      return Icons.campaign_outlined;
    case 'Transporte':
      return Icons.local_shipping_outlined;
    default:
      return Icons.receipt_outlined;
  }
}
