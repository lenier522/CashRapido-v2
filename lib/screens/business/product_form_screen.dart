import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_icon_button.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_section.dart';
import '../../widgets/design/cash_selector_field.dart';
import 'barcode_scanner_screen.dart';
import 'category_manager_screen.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  /// Valor centinela devuelto por la hoja de categorías cuando el usuario
  /// quiere abrir el gestor de categorías.
  static const String _kManageCategories = '__manage_categories__';

  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _skuController;
  late TextEditingController _quantityController;
  late TextEditingController _costController;
  late TextEditingController _salePriceController;
  late TextEditingController _additionalCostsController;
  late TextEditingController _addStockController;
  late DateTime _investmentDate;
  late String _currency;
  late String _selectedUnit;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;

  final List<String> _currencies = ['CUP', 'USD', 'EUR', 'MLC'];

  List<Map<String, String>> _buildUnits(BuildContext context) => [
    {'value': 'uds', 'label': context.t('unit_uds')},
    {'value': 'kg', 'label': context.t('unit_kg')},
    {'value': 'lb', 'label': context.t('unit_lb')},
    {'value': 'L', 'label': context.t('unit_l')},
    {'value': 'g', 'label': context.t('unit_g')},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _skuController = TextEditingController(text: widget.product?.sku ?? '');
    _quantityController = TextEditingController(
      text: widget.product != null
          ? (widget.product!.initialQuantity % 1 == 0
                ? widget.product!.initialQuantity.toInt().toString()
                : widget.product!.initialQuantity.toString())
          : '',
    );
    _costController = TextEditingController(
      text: widget.product?.costPerUnit.toString() ?? '',
    );
    _salePriceController = TextEditingController(
      text: widget.product?.salePrice.toString() ?? '',
    );
    _additionalCostsController = TextEditingController(
      text: widget.product?.additionalCosts.toString() ?? '',
    );
    _addStockController = TextEditingController();
    _investmentDate = widget.product?.investmentDate ?? DateTime.now();
    _selectedUnit = widget.product?.unit ?? 'uds';
    _selectedCategoryId = widget.product?.categoryId;
    _selectedSubcategoryId = widget.product?.subcategoryId;

    _additionalCostsController.addListener(() {
      if (mounted) setState(() {});
    });
    _quantityController.addListener(() {
      if (mounted) setState(() {});
    });
    _costController.addListener(() {
      if (mounted) setState(() {});
    });

    final biz = Provider.of<BusinessProvider>(
      context,
      listen: false,
    ).activeBusiness;
    _currency = widget.product?.currency ?? biz?.currency ?? 'CUP';
    if (!_currencies.contains(_currency)) {
      _currencies.add(_currency);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _skuController.dispose();
    _quantityController.dispose();
    _costController.dispose();
    _salePriceController.dispose();
    _additionalCostsController.dispose();
    _addStockController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // HELPERS
  // ---------------------------------------------------------------------------

  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);

  String _unitLabel(BuildContext context) {
    for (final u in _buildUnits(context)) {
      if (u['value'] == _selectedUnit) return u['label']!;
    }
    return _selectedUnit;
  }

  String get _formattedDate =>
      '${_investmentDate.day}/${_investmentDate.month}/${_investmentDate.year}';

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(continuous: false),
      ),
    );
    if (code == null || code.isEmpty) return;
    // Tras el `await` del escáner la pantalla puede haberse desmontado: el
    // guard evita llamar a `setState` y usar `context` sobre un widget ya
    // desechado (línea que antes quedaba sin proteger).
    if (!mounted) return;

    setState(() {
      _skuController.text = code;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          context.t('product_barcode_scanned').replaceAll('{code}', code),
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PICKERS (bottom sheets + date picker)
  // ---------------------------------------------------------------------------

  Future<void> _pickCurrency() async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('product_form_currency_label'),
        child: Column(
          children: [
            for (final currency in _currencies)
              _FormSheetOption(
                icon: Icons.currency_exchange_rounded,
                title: currency,
                selected: currency == _currency,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, currency),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _currency = selected);
  }

  Future<void> _pickUnit() async {
    final options = _buildUnits(context);
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('product_form_unit_label'),
        child: Column(
          children: [
            for (final u in options)
              _FormSheetOption(
                icon: Icons.scale_outlined,
                title: u['label']!,
                selected: u['value'] == _selectedUnit,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, u['value']),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedUnit = selected);
  }

  Future<void> _pickCategory(
    BuildContext context,
    BusinessProvider provider,
  ) async {
    final NavigatorState navigator = Navigator.of(context);
    final result = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('product_form_category_label'),
        child: Column(
          children: [
            _FormSheetOption(
              icon: Icons.folder_off_outlined,
              title: sheetContext.t('product_form_no_category'),
              selected: _selectedCategoryId == null,
              accent: AppColors.primary,
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final category in provider.rootCategories)
              _FormSheetOption(
                icon: Icons.folder_outlined,
                title: category.name,
                selected: category.id == _selectedCategoryId,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, category.id),
              ),
            const Divider(),
            _FormSheetOption(
              icon: Icons.settings_outlined,
              title: sheetContext.t('product_category_manage'),
              selected: false,
              accent: AppColors.primary,
              onTap: () => Navigator.pop(sheetContext, _kManageCategories),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    if (result == _kManageCategories) {
      await navigator.push(
        MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
      );
      return;
    }
    setState(() {
      _selectedCategoryId = result.isEmpty ? null : result;
      _selectedSubcategoryId = null; // reset subcategory
    });
  }

  Future<void> _pickSubcategory(
    BuildContext context,
    BusinessProvider provider,
  ) async {
    final categoryId = _selectedCategoryId;
    if (categoryId == null) return;

    final subcategories = provider.getSubcategories(categoryId);
    final result = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('product_form_subcategory_label'),
        child: Column(
          children: [
            _FormSheetOption(
              icon: Icons.subdirectory_arrow_right_rounded,
              title: sheetContext.t('product_form_no_subcategory'),
              selected: _selectedSubcategoryId == null,
              accent: AppColors.primary,
              onTap: () => Navigator.pop(sheetContext, ''),
            ),
            for (final sub in subcategories)
              _FormSheetOption(
                icon: Icons.subdirectory_arrow_right_rounded,
                title: sub.name,
                selected: sub.id == _selectedSubcategoryId,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, sub.id),
              ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _selectedSubcategoryId = result.isEmpty ? null : result);
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _investmentDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date != null && mounted) {
      setState(() => _investmentDate = date);
    }
  }

  // ---------------------------------------------------------------------------
  // CÁLCULOS (misma lógica existente)
  // ---------------------------------------------------------------------------

  double get _additionalAmount =>
      double.tryParse(_additionalCostsController.text) ?? 0.0;

  double _calculateProductInvestment() {
    final quantity = double.tryParse(_quantityController.text) ?? 0.0;
    final cost = double.tryParse(_costController.text) ?? 0.0;
    return quantity * cost;
  }

  double _calculateTotalInvestment() {
    return _calculateProductInvestment() + _additionalAmount;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;
    final provider = context.watch<BusinessProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? context.t('edit_product') : context.t('product_new'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            _buildBasicSection(context, provider),
            const SizedBox(height: AppSpacing.xxl),
            _buildPricingSection(context),
            const SizedBox(height: AppSpacing.xxl),
            _buildInventorySection(context, isEdit),
            const SizedBox(height: AppSpacing.xxl),
            _buildOtherSection(context),
            const SizedBox(height: AppSpacing.xxl),
            CashButton(
              label: isEdit
                  ? context.t('product_form_save_btn')
                  : context.t('product_form_create_btn'),
              icon: const Icon(Icons.check_rounded, size: 20),
              onPressed: _saveProduct,
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  // SECCIÓN 1 · INFORMACIÓN BÁSICA
  Widget _buildBasicSection(BuildContext context, BusinessProvider provider) {
    final isEdit = widget.product != null;

    return CashSection(
      title: context.t('product_form_section_basic'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CashInput(
            controller: _nameController,
            label: context.t('product_form_name_label'),
            hint: context.t('product_form_name_hint'),
            prefix: const Icon(Icons.inventory_2_outlined),
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            validator: (value) => value == null || value.trim().isEmpty
                ? context.t('product_enter_name')
                : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CashInput(
                  controller: _skuController,
                  label: context.t('product_form_sku_label'),
                  hint: context.t('product_form_sku_hint'),
                  prefix: const Icon(Icons.qr_code_2_rounded),
                  helperText: isEdit && (widget.product?.sku ?? '').isNotEmpty
                      ? context.t('product_form_sku_edit_hint')
                      : context.t('product_form_sku_auto'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              CashIconButton(
                icon: Icons.photo_camera_rounded,
                size: 58,
                iconSize: 24,
                tooltip: context.t('product_scan_barcode'),
                backgroundColor: AppColors.primary,
                iconColor: AppColors.white,
                onPressed: _scanBarcode,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CashSelectorField(
            label: context.t('product_form_category_label'),
            value: _selectedCategoryId == null
                ? null
                : provider.getCategoryById(_selectedCategoryId!)?.name,
            placeholder: context.t('product_form_no_category'),
            icon: Icons.folder_outlined,
            onTap: () => _pickCategory(context, provider),
          ),
          if (_selectedCategoryId != null) ...[
            const SizedBox(height: AppSpacing.md),
            CashSelectorField(
              label: context.t('product_form_subcategory_label'),
              value: _selectedSubcategoryId == null
                  ? null
                  : provider.getCategoryById(_selectedSubcategoryId!)?.name,
              placeholder: context.t('product_form_no_subcategory'),
              icon: Icons.subdirectory_arrow_right_rounded,
              onTap: () => _pickSubcategory(context, provider),
            ),
            if (provider.getSubcategories(_selectedCategoryId!).isEmpty)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CategoryManagerScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(context.t('product_add_subcategories')),
                ),
              ),
          ],
        ],
      ),
    );
  }

  // SECCIÓN 2 · PRECIOS
  Widget _buildPricingSection(BuildContext context) {
    return CashSection(
      title: context.t('product_form_section_pricing'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CashInput(
            controller: _salePriceController,
            label: context.t('product_form_sale_price_label'),
            prefix: const Icon(Icons.sell_outlined),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.t('product_enter_sale_price');
              }
              if (double.tryParse(value) == null) {
                return context.t('product_must_be_number');
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          CashInput(
            controller: _costController,
            label: context.t('product_form_cost_label'),
            prefix: const Icon(Icons.attach_money_rounded),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.t('product_enter_cost');
              }
              if (double.tryParse(value) == null) {
                return context.t('product_must_be_number');
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          CashInput(
            controller: _additionalCostsController,
            label: context.t('product_form_additional_costs_label'),
            hint: context.t('product_form_additional_costs_hint'),
            prefix: const Icon(Icons.local_shipping_outlined),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppSpacing.lg),
          CashSelectorField(
            label: context.t('product_form_currency_label'),
            value: _currency,
            icon: Icons.currency_exchange_rounded,
            onTap: _pickCurrency,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildInvestmentSummary(context),
        ],
      ),
    );
  }

  Widget _buildInvestmentSummary(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.compactPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.primarySurface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.primaryLight,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('product_investment_label'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: secondary),
              ),
              Flexible(
                child: Text(
                  '\$${_calculateProductInvestment().toFormattedString(2)} $_currency',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('product_additional_label'),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: secondary),
              ),
              Flexible(
                child: Text(
                  '\$${_additionalAmount.toFormattedString(2)} $_currency',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                context.t('product_total_investment_label'),
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              Flexible(
                child: Text(
                  '\$${_calculateTotalInvestment().toFormattedString(2)} $_currency',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: isDark ? AppColors.primary : AppColors.primaryDark,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // SECCIÓN 3 · INVENTARIO
  Widget _buildInventorySection(BuildContext context, bool isEdit) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return CashSection(
      title: context.t('product_form_section_inventory'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CashInput(
            controller: _quantityController,
            enabled: !isEdit, // En edición la cantidad comprada es informativa.
            label: context.t('product_form_initial_qty_label'),
            prefix: const Icon(Icons.numbers_rounded),
            suffix: Text(
              _selectedUnit,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return context.t('product_enter_qty');
              }
              if (double.tryParse(value) == null) {
                return context.t('product_must_be_number');
              }
              return null;
            },
          ),
          const SizedBox(height: AppSpacing.lg),
          CashSelectorField(
            label: context.t('product_form_unit_label'),
            value: _unitLabel(context),
            icon: Icons.scale_outlined,
            onTap: _pickUnit,
          ),
          const SizedBox(height: AppSpacing.lg),
          CashSelectorField(
            label: context.t('product_form_investment_date_label'),
            value: _formattedDate,
            icon: Icons.calendar_month_outlined,
            onTap: _pickDate,
          ),
          if (isEdit) ...[
            const SizedBox(height: AppSpacing.lg),
            _buildEditStockCard(context),
          ],
        ],
      ),
    );
  }

  Widget _buildEditStockCard(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final product = widget.product!;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.compactPadding),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.primarySurface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.primaryLight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: AppColors.info,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.t('product_original_investment'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.info,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildInfoChip(
                  context,
                  context.t('product_qty_purchased'),
                  '${_formatQty(product.initialQuantity)} ${product.unit}',
                  Icons.inventory_2_outlined,
                ),
              ),
              Expanded(
                child: _buildInfoChip(
                  context,
                  context.t('product_unit_cost'),
                  '\$${product.costPerUnit.toFormattedString(2)} ${product.currency}',
                  Icons.attach_money_rounded,
                ),
              ),
              Expanded(
                child: _buildInfoChip(
                  context,
                  context.t('product_current_stock'),
                  '${_formatQty(product.currentStock)} ${product.unit}',
                  Icons.warehouse_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                color: AppColors.income,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  context.t('product_add_stock'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.income,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          CashInput(
            controller: _addStockController,
            label: context.t('product_units_to_add'),
            helperText: context.t('product_units_to_add_helper'),
            prefix: const Icon(Icons.add_rounded),
            suffix: Text(
              _selectedUnit,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ),
    );
  }

  // SECCIÓN 4 · OTROS
  Widget _buildOtherSection(BuildContext context) {
    return CashSection(
      title: context.t('product_form_section_other'),
      child: CashInput(
        controller: _descriptionController,
        label: context.t('product_form_description_label'),
        hint: context.t('product_form_description_hint'),
        prefix: const Icon(Icons.notes_rounded),
        maxLines: 3,
      ),
    );
  }

  Widget _buildInfoChip(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(AppSpacing.sm),
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark3 : AppColors.white,
            borderRadius: AppRadius.radiusSm,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: isDark ? 0.3 : 0.04),
                blurRadius: 4,
              ),
            ],
          ),
          child: Icon(icon, size: 20, color: AppColors.primary),
        ),
        const SizedBox(height: AppSpacing.xs),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            maxLines: 1,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: secondary, fontSize: 10),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // GUARDAR (misma lógica existente)
  // ---------------------------------------------------------------------------

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<BusinessProvider>(context, listen: false);

    // Auto-generate SKU if empty — uses business initials, category/subcategory initials, product name, date, cost and sale price
    String sku = _skuController.text.trim();
    if (sku.isEmpty) {
      final biz = provider.activeBusiness;
      final bizName = biz?.name ?? 'BIZ';

      String getInitials(String text) {
        if (text.trim().isEmpty) return '';
        final clean = text.trim().toUpperCase().replaceAll(
          RegExp(r'[^A-Z0-9 ]'),
          '',
        );
        final parts = clean.split(' ').where((w) => w.isNotEmpty).toList();
        if (parts.isEmpty) return '';
        return parts.map((w) => w[0]).join();
      }

      final bizInitials = getInitials(bizName).padRight(2, 'X').substring(0, 2);

      String catSubcatInitials = '';
      if (_selectedCategoryId != null) {
        final cat = provider.getCategoryById(_selectedCategoryId!);
        if (cat != null) {
          catSubcatInitials += getInitials(cat.name);
        }
      }
      if (_selectedSubcategoryId != null) {
        final subcat = provider.getCategoryById(_selectedSubcategoryId!);
        if (subcat != null) {
          catSubcatInitials += getInitials(subcat.name);
        }
      }
      if (catSubcatInitials.isEmpty) {
        catSubcatInitials = 'GEN';
      }

      final prodNameSanitized = _nameController.text
          .trim()
          .toUpperCase()
          .replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final shortName = prodNameSanitized.length > 6
          ? prodNameSanitized.substring(0, 6)
          : prodNameSanitized;

      final dateStr =
          '${_investmentDate.year.toString().substring(2)}${_investmentDate.month.toString().padLeft(2, '0')}${_investmentDate.day.toString().padLeft(2, '0')}';

      sku = '$bizInitials$catSubcatInitials$shortName$dateStr';
    }

    final appProvider = Provider.of<AppProvider>(context, listen: false);

    if (widget.product == null) {
      // Create
      await provider.addProduct(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        sku: sku,
        investmentDate: _investmentDate,
        initialQuantity: double.parse(_quantityController.text),
        costPerUnit: double.parse(_costController.text),
        currency: _currency,
        salePrice: double.parse(_salePriceController.text),
        additionalCosts: _additionalAmount,
        unit: _selectedUnit,
        categoryId: _selectedCategoryId,
        subcategoryId: _selectedSubcategoryId,
        appProvider: appProvider,
      );
    } else {
      // Edit: investment data never changes sold units.
      // "Cantidad Comprada" stays read-only = initialQuantity.
      // Only _addStockController qty is added to currentStock.
      final double stockToAdd =
          double.tryParse(_addStockController.text) ?? 0.0;
      final double newCurrentStock = widget.product!.currentStock + stockToAdd;
      final double newInitialQty = widget.product!.initialQuantity + stockToAdd;
      final double newCostPerUnit =
          double.tryParse(_costController.text) ?? widget.product!.costPerUnit;

      // Deduct restocking cost from linked card if stock is added
      if (stockToAdd > 0 && provider.linkedCardId != null) {
        final restockCost = stockToAdd * newCostPerUnit;
        if (restockCost > 0) {
          await appProvider.addTransaction(
            amount: -restockCost,
            title: "Reabastecimiento: ${_nameController.text.trim()}",
            categoryId: 'cat_business',
            currency: _currency,
            cardId: provider.linkedCardId,
            date: DateTime.now(),
          );
        }
      }

      final updated = widget.product!.copyWith(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        sku: sku,
        investmentDate: _investmentDate,
        initialQuantity: newInitialQty,
        costPerUnit: newCostPerUnit,
        currency: _currency,
        totalInvestment: newInitialQty * newCostPerUnit,
        additionalCosts: _additionalAmount,
        currentStock: newCurrentStock,
        salePrice: double.parse(_salePriceController.text),
        unit: _selectedUnit,
        categoryId: _selectedCategoryId,
        subcategoryId: _selectedSubcategoryId,
      );
      await provider.editProduct(updated);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }
}

/// Opción reutilizable para las hojas de selección del formulario de producto.
class _FormSheetOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _FormSheetOption({
    required this.icon,
    required this.title,
    required this.selected,
    required this.accent,
    required this.onTap,
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
            ? Border.all(color: accent.withValues(alpha: 0.8), width: 1.4)
            : null,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                borderRadius: AppRadius.radiusSm,
              ),
              child: Icon(icon, size: 20, color: accent),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent, size: 20)
            else
              Icon(Icons.chevron_right_rounded, size: 20, color: secondary),
          ],
        ),
      ),
    );
  }
}
