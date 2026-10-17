import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/business.dart';
import '../../models/models.dart';
import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../utils/business_icon_helper.dart';
import '../../utils/category_color_options.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_dialog.dart';
import '../../widgets/design/cash_icon_button.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_selector_field.dart';

/// Alta / edición de un negocio.
///
/// Al CREAR y al EDITAR se piden todos los datos del negocio: nombre, tipo,
/// cuenta vinculada (origen de fondos / destino de ingresos), capital inicial,
/// moneda, icono y color. La cuenta vinculada se elige mediante un selector
/// (bottom sheet) con la misma piel que el resto del Design System.
class BusinessFormScreen extends StatefulWidget {
  final Business? business; // null = create, non-null = edit

  const BusinessFormScreen({super.key, this.business});

  @override
  State<BusinessFormScreen> createState() => _BusinessFormScreenState();
}

class _BusinessFormScreenState extends State<BusinessFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _capitalController;
  String? _selectedCardId;
  late String _selectedType;
  late String _selectedIcon;
  late Color _selectedColor;
  late String _selectedCurrency;
  bool _isSaving = false;

  bool get _isEdit => widget.business != null;

  static const String _kNoLinkedAccount = '';

  static const List<String> _businessTypes = [
    'Retail',
    'Restaurante',
    'Servicios',
    'Tecnología',
    'Consultoría',
    'E-commerce',
    'Otro',
  ];

  static const List<String> _currencies = ['CUP', 'USD', 'EUR', 'MLC'];

  static const List<Color> _businessColors = <Color>[
    AppColors.primary,
    AppColors.primaryDark,
    AppColors.primaryDeep,
    AppColors.secondary,
    Color(0xFF42A5F5),
    Color(0xFF2196F3),
    Color(0xFF1565C0),
    Color(0xFF26A69A),
    Color(0xFF009688),
    Color(0xFFFF9800),
    Color(0xFFF57C00),
    Color(0xFFEF5350),
    Color(0xFFE53935),
    Color(0xFFEC407A),
    Color(0xFFD81B60),
    Color(0xFF7E57C2),
    Color(0xFF5E35B1),
    Color(0xFF455A64),
    Color(0xFF263238),
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.business?.name ?? '');
    _capitalController = TextEditingController(
      text: widget.business != null && widget.business!.initialCapital > 0
          ? widget.business!.initialCapital.toStringAsFixed(2)
          : '',
    );
    _selectedCardId = widget.business?.linkedCardId;
    _selectedCurrency = widget.business?.currency ?? 'CUP';
    _selectedType = widget.business?.type ?? _businessTypes.first;

    // Handle Icon Selection (Backward Compatibility)
    if (widget.business != null) {
      final code = widget.business!.iconCode;
      final isNumber = int.tryParse(code) != null;

      if (isNumber) {
        final codePoint = int.parse(code);
        _selectedIcon =
            BusinessIconHelper.getKeyFromCodePoint(codePoint) ??
            BusinessIconHelper.catalog.first.key;
      } else {
        if (BusinessIconHelper.legacyIconsMap.containsKey(code) ||
            BusinessIconHelper.catalog.any((o) => o.key == code)) {
          _selectedIcon = code;
        } else {
          _selectedIcon = BusinessIconHelper.catalog.first.key;
        }
      }
    } else {
      _selectedIcon = BusinessIconHelper.catalog.first.key;
    }

    _selectedColor = widget.business != null
        ? Color(widget.business!.colorValue)
        : AppColors.primary;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _capitalController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // PICKERS
  // ---------------------------------------------------------------------------

  Future<void> _pickLinkedAccount(AppProvider appProvider) async {
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('linked_account'),
        child: Column(
          children: [
            _SheetOption(
              leading: const _AccountLeading(icon: Icons.link_off_rounded),
              title: sheetContext.t('no_linked_account'),
              selected: _selectedCardId == null,
              accent: AppColors.primary,
              onTap: () => Navigator.pop(sheetContext, _kNoLinkedAccount),
            ),
            for (final card in appProvider.cards)
              _SheetOption(
                leading: _AccountLeading(
                  color: Color(card.colorValue),
                  icon: card.isCash
                      ? Icons.account_balance_wallet_rounded
                      : Icons.credit_card_rounded,
                ),
                title: card.isCash
                    ? card.name
                    : (card.bankName ?? sheetContext.t('card_default_name')),
                subtitle: _accountSubtitle(card),
                selected: _selectedCardId == card.id,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, card.id),
              ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() {
      if (selected == _kNoLinkedAccount) {
        _selectedCardId = null;
        return;
      }
      _selectedCardId = selected;
      // Auto-rellenar capital y moneda a partir de la cuenta elegida.
      final selectedCard = appProvider.cards.firstWhere(
        (c) => c.id == selected,
        orElse: () => appProvider.cards.first,
      );
      if (selectedCard.id == selected) {
        _capitalController.text = selectedCard.balance.toStringAsFixed(2);
        _selectedCurrency = selectedCard.currency;
      }
    });
  }

  Future<void> _pickCurrency() async {
    final options = <String>{..._currencies, _selectedCurrency}.toList();
    final selected = await CashBottomSheet.show<String>(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext.t('currency_label'),
        child: Column(
          children: [
            for (final currency in options)
              _SheetOption(
                leading: const _AccountLeading(icon: Icons.attach_money),
                title: currency,
                selected: _selectedCurrency == currency,
                accent: AppColors.primary,
                onTap: () => Navigator.pop(sheetContext, currency),
              ),
          ],
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedCurrency = selected);
  }

  String _accountSubtitle(AccountCard card) {
    if (card.isCash) {
      return '${card.name} · ${card.currency}';
    }
    final last4 = card.cardNumber.length >= 4
        ? card.cardNumber.substring(card.cardNumber.length - 4)
        : card.cardNumber;
    return '•• $last4 · ${card.currency}';
  }

  String _linkedAccountLabel(AppProvider appProvider) {
    final id = _selectedCardId;
    if (id == null) return '';
    for (final card in appProvider.cards) {
      if (card.id == id) {
        final bank = card.isCash
            ? card.name
            : (card.bankName ?? context.t('card_default_name'));
        final last4 = card.isCash || card.cardNumber.length < 4
            ? ''
            : ' · •• ${card.cardNumber.substring(card.cardNumber.length - 4)}';
        return '$bank$last4 · ${card.currency}';
      }
    }
    return '';
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t(_isEdit ? 'business_edit_title' : 'business_setup'),
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
        actions: _isEdit
            ? [
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: CashIconButton(
                    icon: Icons.delete_outline,
                    size: 40,
                    iconSize: 20,
                    iconColor: AppColors.error,
                    tooltip: context.t('delete'),
                    onPressed: _showDeleteDialog,
                  ),
                ),
              ]
            : null,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          children: [
            // ---- Nombre del negocio ----
            CashInput(
              controller: _nameController,
              label: context.t('label_name'),
              hint: context.t('business_name_label'),
              prefix: const Icon(Icons.store_rounded),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.t('enter_name_error');
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Cuenta vinculada (origen de fondos / destino de ingresos) ----
            const _SectionHeader(
              icon: Icons.account_balance_wallet_outlined,
              titleKey: 'linked_account',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.t('linked_account_desc'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            CashSelectorField(
              label: context.t('linked_account'),
              value: _linkedAccountLabel(appProvider),
              placeholder: context.t('select_linked_account'),
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => _pickLinkedAccount(appProvider),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Identidad: tipo ----
            const _SectionHeader(
              icon: Icons.storefront_rounded,
              titleKey: 'form_identity_section',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(context.t('label_type'), style: _pickerLabelStyle(context)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: _businessTypes.map((type) {
                return CashChip(
                  label: type,
                  selected: _selectedType == type,
                  onTap: () => setState(() => _selectedType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Finanzas: capital inicial + moneda ----
            const _SectionHeader(
              icon: Icons.savings_outlined,
              titleKey: 'business_funding_section',
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              context.t('initial_capital_desc'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            LayoutBuilder(
              builder: (context, constraints) {
                final bool wide = constraints.maxWidth >= 340;
                final Widget capital = CashInput(
                  controller: _capitalController,
                  label: context.t('initial_capital'),
                  hint: context.t('initial_capital_hint'),
                  prefix: const Icon(Icons.savings_outlined),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                );

                final Widget currency = CashSelectorField(
                  label: context.t('currency_label'),
                  value: _selectedCurrency,
                  icon: Icons.attach_money,
                  dense: true,
                  onTap: _pickCurrency,
                );

                if (wide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: capital),
                      const SizedBox(width: AppSpacing.md),
                      SizedBox(width: 126, child: currency),
                    ],
                  );
                }
                return Column(
                  children: [
                    capital,
                    const SizedBox(height: AppSpacing.md),
                    currency,
                  ],
                );
              },
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Apariencia: icono + color ----
            const _SectionHeader(
              icon: Icons.palette_outlined,
              titleKey: 'business_appearance_section',
            ),
            const SizedBox(height: AppSpacing.md),
            Text(context.t('label_icon'), style: _pickerLabelStyle(context)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: BusinessIconHelper.catalog.map((option) {
                final isSelected = _selectedIcon == option.key;
                return _buildIconOption(context, option, isSelected);
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),
            Text(context.t('label_color'), style: _pickerLabelStyle(context)),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: _businessColors.map((color) {
                final isSelected =
                    _selectedColor.toARGB32() == color.toARGB32();
                return _buildColorOption(context, color, isSelected);
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ---- Guardar ----
            CashButton(
              label: context.t(
                _isEdit ? 'business_edit_btn' : 'business_create_btn',
              ),
              icon: const Icon(Icons.check_rounded, size: 20),
              loading: _isSaving,
              onPressed: _saveBusiness,
            ),
            if (_isEdit) ...[
              const SizedBox(height: AppSpacing.sm),
              CashButton(
                label: context.t('delete'),
                icon: const Icon(Icons.delete_outline, size: 20),
                type: CashButtonType.danger,
                onPressed: _showDeleteDialog,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
  }

  TextStyle? _pickerLabelStyle(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Theme.of(context).textTheme.labelSmall?.copyWith(
      color: isDark
          ? AppColors.textSecondaryDark
          : AppColors.textSecondary,
      fontWeight: FontWeight.w500,
    );
  }

  Widget _buildIconOption(
    BuildContext context,
    BusinessIconOption option,
    bool isSelected,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return InkWell(
      borderRadius: AppRadius.radiusMd,
      onTap: () => setState(() => _selectedIcon = option.key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: isDark ? 0.24 : 0.12)
              : isDark
              ? AppColors.surfaceDark2
              : AppColors.surfaceVariantLight,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: isSelected ? AppColors.primary : border,
            width: isSelected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              option.icon,
              size: 26,
              color: isSelected ? AppColors.primary : secondary,
            ),
            if (isSelected)
              Positioned(
                right: 5,
                top: 5,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 10,
                    color: AppColors.white,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorOption(
    BuildContext context,
    Color color,
    bool isSelected,
  ) {
    final Color checkColor = CategoryColorOptions.contrastForeground(color);

    return InkWell(
      customBorder: const CircleBorder(),
      onTap: () => setState(() => _selectedColor = color),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: AppColors.white,
            width: isSelected ? 3 : 1,
          ),
        ),
        child: isSelected
            ? Icon(Icons.check, size: 18, color: checkColor)
            : null,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ACCIONES
  // ---------------------------------------------------------------------------

  Future<void> _saveBusiness() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = Provider.of<BusinessProvider>(context, listen: false);
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    final String name = _nameController.text.trim();
    final int? iconCodePoint =
        BusinessIconHelper.codePointOf(_selectedIcon) ??
        BusinessIconHelper.codePointOf(BusinessIconHelper.catalog.first.key);
    final String iconCode = (iconCodePoint ?? 0).toString();
    final double initialCapital =
        double.tryParse(
          _capitalController.text.trim().replaceAll(',', '.'),
        ) ??
        0.0;
    final int colorValue = _selectedColor.toARGB32();

    if (widget.business == null) {
      // Create
      await provider.createBusiness(
        name: name,
        type: _selectedType,
        iconCode: iconCode,
        colorValue: colorValue,
        initialCapital: initialCapital,
        linkedCardId: _selectedCardId,
        currency: _selectedCurrency,
        appProvider: appProvider,
      );
    } else {
      // Edit
      final oldCap = widget.business!.initialCapital;
      final diff = initialCapital - oldCap;
      if (_selectedCardId != null && diff.abs() > 0.005) {
        if (diff > 0) {
          await appProvider.addTransaction(
            amount: -diff,
            title: "Aumento Capital: $name",
            categoryId: 'cat_business',
            currency: _selectedCurrency,
            cardId: _selectedCardId,
            date: DateTime.now(),
          );
        } else {
          await appProvider.addTransaction(
            amount: diff.abs(),
            title: "Ajuste Capital: $name",
            categoryId: 'cat_business',
            currency: _selectedCurrency,
            cardId: _selectedCardId,
            date: DateTime.now(),
          );
        }
      }
      final updated = widget.business!.copyWith(
        name: name,
        type: _selectedType,
        iconCode: iconCode,
        colorValue: colorValue,
        initialCapital: initialCapital,
        linkedCardId: _selectedCardId,
        currency: _selectedCurrency,
      );
      await provider.editBusiness(updated);
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _showDeleteDialog() async {
    final confirmed = await showCashConfirmDialog(
      context,
      title: context.t('business_delete_title'),
      message: context.t('business_delete_confirm'),
      confirmLabel: context.t('delete'),
      cancelLabel: context.t('cancel'),
      icon: Icons.delete_outline_rounded,
    );

    if (confirmed == true && mounted) {
      final provider = Provider.of<BusinessProvider>(context, listen: false);
      await provider.deleteBusiness(widget.business!.id);
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }
}

// ---------------------------------------------------------------------------
// WIDGETS AUXILIARES
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String titleKey;

  const _SectionHeader({required this.icon, required this.titleKey});

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
            context.t(titleKey),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _AccountLeading extends StatelessWidget {
  final Color? color;
  final IconData icon;

  const _AccountLeading({this.color, required this.icon});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent =
        color ?? (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: AppRadius.radiusMd,
      ),
      child: Icon(icon, size: 20, color: accent),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _SheetOption({
    required this.leading,
    required this.title,
    required this.selected,
    required this.accent,
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
            ? Border.all(color: accent.withValues(alpha: 0.8), width: 1.4)
            : null,
        boxShadow: AppShadows.soft,
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
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (selected)
              Icon(Icons.check_circle_rounded, color: accent, size: 20)
            else
              Icon(Icons.chevron_right, size: 20, color: secondary),
          ],
        ),
      ),
    );
  }
}
