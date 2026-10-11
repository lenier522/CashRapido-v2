import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/seller.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_selector_field.dart';

/// Formulario de creación/edición de vendedores.
///
/// Mantiene todos los campos y la lógica de guardado originales. Sólo
/// reorganiza el contenido y aplica el Design System.
class SellerFormScreen extends StatefulWidget {
  final Seller? seller;

  const SellerFormScreen({super.key, this.seller});

  @override
  State<SellerFormScreen> createState() => _SellerFormScreenState();
}

class _SellerFormScreenState extends State<SellerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _ciCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _roleCtrl;
  late TextEditingController _salaryCtrl;
  late TextEditingController _commissionCtrl;
  late TextEditingController _notesCtrl;
  late DateTime _hireDate;
  late bool _isActive;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.seller?.name ?? '');
    _lastNameCtrl = TextEditingController(text: widget.seller?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: widget.seller?.phone ?? '');
    _emailCtrl = TextEditingController(text: widget.seller?.email ?? '');
    _ciCtrl = TextEditingController(text: widget.seller?.ci ?? '');
    _addressCtrl = TextEditingController(text: widget.seller?.address ?? '');
    _roleCtrl = TextEditingController(text: widget.seller?.role ?? '');
    _salaryCtrl = TextEditingController(
      text: widget.seller != null ? widget.seller!.salary.toString() : '',
    );
    _commissionCtrl = TextEditingController(
      text: widget.seller != null
          ? widget.seller!.commissionRate.toString()
          : '',
    );
    _notesCtrl = TextEditingController(text: widget.seller?.notes ?? '');
    _hireDate = widget.seller?.hireDate ?? DateTime.now();
    _isActive = widget.seller?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ciCtrl.dispose();
    _addressCtrl.dispose();
    _roleCtrl.dispose();
    _salaryCtrl.dispose();
    _commissionCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickHireDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _hireDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _hireDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final provider = Provider.of<BusinessProvider>(context, listen: false);

    try {
      if (widget.seller != null) {
        final updated = Seller(
          id: widget.seller!.id,
          businessId: widget.seller!.businessId,
          name: _nameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          ci: _ciCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          role: _roleCtrl.text.trim(),
          commissionRate:
              double.tryParse(_commissionCtrl.text.replaceAll(',', '.')) ?? 0.0,
          salary: double.tryParse(_salaryCtrl.text.replaceAll(',', '.')) ?? 0.0,
          hireDate: _hireDate,
          isActive: _isActive,
          notes: _notesCtrl.text.trim(),
        );
        await provider.editSeller(updated);
      } else {
        await provider.addSeller(
          name: _nameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          ci: _ciCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          role: _roleCtrl.text.trim(),
          commissionRate:
              double.tryParse(_commissionCtrl.text.replaceAll(',', '.')) ?? 0.0,
          salary: double.tryParse(_salaryCtrl.text.replaceAll(',', '.')) ?? 0.0,
          hireDate: _hireDate,
          isActive: _isActive,
          notes: _notesCtrl.text.trim(),
        );
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.seller != null
              ? context.t('seller_edit')
              : context.t('seller_new'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxxl,
            ),
            children: [
              const _SectionLabel('seller_personal_data', Icons.person_outline),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _nameCtrl,
                label: context.t('seller_name'),
                prefix: const Icon(Icons.badge_outlined),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.t('seller_validation')
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _lastNameCtrl,
                label: context.t('seller_lastname'),
                prefix: const Icon(Icons.badge_outlined),
                textCapitalization: TextCapitalization.words,
                validator: (value) => value == null || value.trim().isEmpty
                    ? context.t('seller_validation')
                    : null,
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _ciCtrl,
                label: context.t('seller_id_doc'),
                prefix: const Icon(Icons.credit_card_outlined),
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _phoneCtrl,
                label: context.t('seller_phone'),
                prefix: const Icon(Icons.phone_outlined),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _emailCtrl,
                label: context.t('seller_email'),
                prefix: const Icon(Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _addressCtrl,
                label: context.t('seller_address'),
                prefix: const Icon(Icons.location_on_outlined),
                maxLines: 2,
              ),
              const SizedBox(height: AppSpacing.xxl),

              const _SectionLabel('seller_employment_data', Icons.work_outline),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _roleCtrl,
                label: context.t('seller_role'),
                prefix: const Icon(Icons.badge_outlined),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _salaryCtrl,
                label: context.t('seller_salary'),
                prefix: const Icon(Icons.attach_money_rounded),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _commissionCtrl,
                label: context.t('seller_commission_rate'),
                prefix: const Icon(Icons.percent_rounded),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              CashSelectorField(
                label: context.t('seller_hire_date'),
                value: '${_hireDate.day}/${_hireDate.month}/${_hireDate.year}',
                icon: Icons.calendar_today_outlined,
                onTap: _pickHireDate,
              ),
              const SizedBox(height: AppSpacing.xxl),

              const _SectionLabel('seller_status', Icons.toggle_on_outlined),
              const SizedBox(height: AppSpacing.sm),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  _isActive
                      ? context.t('seller_active')
                      : context.t('seller_inactive'),
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  _isActive
                      ? context.t('seller_enabled')
                      : context.t('seller_disabled'),
                ),
                value: _isActive,
                onChanged: (val) => setState(() => _isActive = val),
              ),
              const SizedBox(height: AppSpacing.xxl),

              const _SectionLabel('seller_notes', Icons.notes_outlined),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: _notesCtrl,
                hint: context.t('seller_notes_hint'),
                prefix: const Icon(Icons.notes_outlined),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
            ],
          ),
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
            label: context.t('btn_save'),
            icon: Icon(Icons.check_rounded, size: 20),
            loading: _isSaving,
            onPressed: _isSaving ? null : _save,
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String titleKey;
  final IconData icon;

  const _SectionLabel(this.titleKey, this.icon);

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: isDark ? AppColors.primary : AppColors.primaryDark,
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            context.t(titleKey),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
