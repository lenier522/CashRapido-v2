import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_spacing.dart';
import '../utils/category_color_options.dart';
import '../utils/category_icon_registry.dart';
import '../utils/icon_constants.dart';
import '../widgets/design/cash_bottom_sheet.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_category_color_picker.dart';
import '../widgets/design/cash_category_icon_picker.dart';
import '../widgets/design/cash_category_preview.dart';
import '../widgets/design/cash_category_type_selector.dart';
import '../widgets/design/cash_input.dart';
import '../widgets/design/cash_selector_field.dart';
import 'profile/profile_helpers.dart';

/// Alta y edición de categorías.
///
/// Pantalla única para crear y editar: previsualización en tiempo real, tipo
/// (gasto / ingreso / ambos), nombre, selector de iconos con búsqueda y
/// grupos, selector de 64 colores y presupuesto mensual opcional para gastos y
/// ambas.
///
/// Conserva íntegras las reglas de validación, los valores por defecto y las
/// llamadas al provider. En modo edición se mantiene el mismo id y los
/// movimientos que referencian la categoría siguen intactos.
class AddCategoryScreen extends StatefulWidget {
  /// Si se pasa, la pantalla funciona en modo edición sobre esa categoría.
  final Category? category;

  const AddCategoryScreen({super.key, this.category});

  @override
  State<AddCategoryScreen> createState() => _AddCategoryScreenState();
}

class _AddCategoryScreenState extends State<AddCategoryScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _budgetController;

  late int _selectedIconCode;
  late int _selectedColorValue;
  late String _type;

  String? _nameError;
  bool _isSaving = false;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final Category? category = widget.category;
    _nameController = TextEditingController(text: category?.name ?? '');
    _budgetController = TextEditingController(
      text: _budgetText(category?.monthlyBudget),
    );
    _selectedIconCode = category?.iconCode ?? 0xe532; // Default restaurant
    _selectedColorValue = category?.colorValue ?? 0xFFFFA726; // Default Orange
    _type = CategoryTypes.normalize(category?.type);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _budgetController.dispose();
    super.dispose();
  }

  String _budgetText(double? value) {
    if (value == null) return '';
    return value % 1 == 0 ? value.toInt().toString() : value.toString();
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE NEGOCIO (reglas idénticas a la pantalla anterior)
  // ---------------------------------------------------------------------------

  Future<void> _saveCategory() async {
    if (_isSaving) return;

    if (_nameController.text.isEmpty) {
      setState(() => _nameError = context.t('enter_name_error'));
      return;
    }

    final budgetText = _budgetController.text
        .replaceAll(RegExp(r'[^0-9.,]'), '')
        .replaceAll(',', '.');
    final budget = double.tryParse(budgetText);

    final AppProvider provider = Provider.of<AppProvider>(
      context,
      listen: false,
    );

    // Crear categorías requiere licencia Pro o superior
    // ([AppProvider.canCreateCategory]). La restricción se comprueba también
    // en cada punto de entrada, pero se repite aquí para que ninguna ruta
    // nueva pueda saltársela. Editar una categoría existente sigue permitido.
    if (!_isEditing && !provider.canCreateCategory) {
      showFeatureLockedDialog(context);
      return;
    }

    setState(() {
      _nameError = null;
      _isSaving = true;
    });

    if (_isEditing) {
      final Category category = widget.category!;
      // Las categorías de solo ingreso no llevan presupuesto: se conserva el
      // que ya tuvieran para no perder datos al convertir el tipo.
      final double? effectiveBudget = _type == CategoryTypes.income
          ? category.monthlyBudget
          : (budget != null && budget > 0 ? budget : null);
      await provider.editCategory(
        categoryId: category.id,
        name: _nameController.text,
        iconCode: _selectedIconCode,
        colorValue: _selectedColorValue,
        monthlyBudget: effectiveBudget,
        type: _type,
      );
    } else {
      await provider.addCategory(
        name: _nameController.text,
        iconCode: _selectedIconCode,
        colorValue: _selectedColorValue,
        monthlyBudget: budget != null && budget > 0 ? budget : null,
        type: _type,
      );
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // Selector de icono
  // ---------------------------------------------------------------------------

  String? _selectedIconName() {
    for (final CategoryIconOption option in CategoryIconRegistry.icons) {
      if (option.codePoint == _selectedIconCode) return option.name;
    }
    return null;
  }

  Future<void> _pickIcon() async {
    final int? picked = await CashBottomSheet.show<int>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('cat_icon_select'),
        // Sin scroll externo: la cuadrícula del picker crece dentro de la hoja.
        scrollable: false,
        maxHeightFactor: 0.92,
        child: CashCategoryIconPicker(
          initialCodePoint: _selectedIconCode,
          onSelected: (code) => Navigator.pop(sheetContext, code),
        ),
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedIconCode = picked);
    }
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isEditing = _isEditing;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.t(isEditing ? 'cat_edit_title' : 'cat_create_title'),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.sm,
            AppSpacing.screenHorizontal,
            AppSpacing.xxxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CashCategoryPreview(
                name: _nameController.text,
                icon: IconConstants.getCategoryIcon(_selectedIconCode),
                color: Color(_selectedColorValue),
                type: _type,
              ),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionLabel(context.t('cat_type_label')),
              const SizedBox(height: AppSpacing.md),
              CashCategoryTypeSelector(
                selected: _type,
                onChanged: (type) => setState(() => _type = type),
              ),
              const SizedBox(height: AppSpacing.xl),
              CashInput(
                controller: _nameController,
                label: context.t('cat_name_label'),
                hint: context.t('cat_name_hint'),
                prefix: const Icon(Icons.label_outline),
                textCapitalization: TextCapitalization.sentences,
                errorText: _nameError,
                onChanged: (_) {
                  setState(() {
                    if (_nameError != null) _nameError = null;
                  });
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _buildIconSelectorField(),
              const SizedBox(height: AppSpacing.xl),
              _buildSectionLabel(context.t('cat_color_label')),
              const SizedBox(height: AppSpacing.md),
              CashCategoryColorPicker(
                selected: Color(_selectedColorValue),
                onChanged: (color) =>
                    setState(() => _selectedColorValue = color.toARGB32()),
              ),
              if (_type != CategoryTypes.income) ...[
                const SizedBox(height: AppSpacing.xl),
                CashInput(
                  controller: _budgetController,
                  label: context.t('monthly_budget'),
                  hint: context.t('monthly_budget_hint'),
                  prefix: const Icon(Icons.attach_money),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.xxxl),
              CashButton(
                label: context.t('save_category'),
                icon: const Icon(Icons.check, size: 20),
                loading: _isSaving,
                onPressed: _isSaving ? null : _saveCategory,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _buildIconSelectorField() {
    final Color color = Color(_selectedColorValue);
    final Color foreground = CategoryColorOptions.contrastForeground(color);

    return CashSelectorField(
      label: context.t('cat_icon_label'),
      value: _selectedIconName(),
      placeholder: context.t('cat_icon_label'),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(
          IconConstants.getCategoryIcon(_selectedIconCode),
          size: 20,
          color: foreground,
        ),
      ),
      onTap: _pickIcon,
    );
  }
}
