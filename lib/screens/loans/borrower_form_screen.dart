import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/borrower.dart';
import '../../providers/loan_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_input.dart';
import '../../widgets/design/cash_section.dart';
import '../../widgets/design/cash_selector_field.dart';

/// Formulario de creación y edición de prestatarios.
///
/// Conserva exactamente los campos, controladores, validaciones y llamadas al
/// [LoanProvider] de la versión anterior. El rediseño sólo reorganiza la
/// presentación con el Design System de CashRapido.
class BorrowerFormScreen extends StatefulWidget {
  final Borrower? borrower; // Null if creating, non-null if editing
  const BorrowerFormScreen({super.key, this.borrower});

  @override
  State<BorrowerFormScreen> createState() => _BorrowerFormScreenState();
}

class _BorrowerFormScreenState extends State<BorrowerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _writtenLocationController;
  late TextEditingController _referenceController;
  late TextEditingController _notesController;

  String _riskLevel = 'low';
  String? _localPhotoPath; // for camera/future image picker integration

  /// Evita crear/actualizar dos veces mientras el guardado está en curso.
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final b = widget.borrower;
    _nameController = TextEditingController(text: b?.name ?? '');
    _lastNameController = TextEditingController(text: b?.lastName ?? '');
    _phoneController = TextEditingController(text: b?.phone ?? '');
    _addressController = TextEditingController(text: b?.address ?? '');
    _writtenLocationController = TextEditingController(
      text: b?.writtenLocation ?? '',
    );
    _referenceController = TextEditingController(
      text: b?.personalReference ?? '',
    );
    _notesController = TextEditingController(text: b?.notes ?? '');
    _riskLevel = b?.riskLevel ?? 'low';
    _localPhotoPath = b?.localPhotoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _writtenLocationController.dispose();
    _referenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  String? _requiredValidator(String? val) =>
      val == null || val.trim().isEmpty ? context.t('borrower_required_field') : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.borrower != null;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          isEditing
              ? context.t('borrower_form_title_edit')
              : context.t('borrower_form_title_new'),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.screenVertical,
            AppSpacing.screenHorizontal,
            AppSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Información principal ────────────────────────────────
              CashSection(
                title: context.t('borrower_basic_info'),
                child: Column(
                  children: [
                    CashInput(
                      controller: _nameController,
                      label: context.t('borrower_first_name'),
                      hint: context.t('borrower_hint_name'),
                      prefix: const Icon(Icons.person_outline_rounded),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CashInput(
                      controller: _lastNameController,
                      label: context.t('borrower_last_name'),
                      hint: context.t('borrower_hint_last'),
                      prefix: const Icon(Icons.badge_outlined),
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CashInput(
                      controller: _phoneController,
                      label: context.t('borrower_phone'),
                      hint: context.t('borrower_hint_phone'),
                      prefix: const Icon(Icons.phone_rounded),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                      validator: _requiredValidator,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CashInput(
                      controller: _addressController,
                      label: context.t('borrower_address'),
                      hint: context.t('borrower_hint_address'),
                      prefix: const Icon(Icons.home_rounded),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      validator: _requiredValidator,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xl),

              // ── Información adicional ────────────────────────────────
              CashSection(
                title: context.t('borrower_additional_info'),
                child: Column(
                  children: [
                    CashSelectorField(
                      label: context.t('borrower_risk_level'),
                      value: _riskLabel(context, _riskLevel),
                      icon: Icons.shield_outlined,
                      accent: _riskColor(_riskLevel),
                      onTap: () => _pickRisk(context),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CashInput(
                      controller: _writtenLocationController,
                      label: context.t('borrower_location'),
                      hint: context.t('borrower_hint_location'),
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CashInput(
                      controller: _referenceController,
                      label: context.t('borrower_personal_ref'),
                      hint: context.t('borrower_hint_ref'),
                      textCapitalization: TextCapitalization.words,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CashInput(
                      controller: _notesController,
                      label: context.t('borrower_notes'),
                      hint: context.t('borrower_hint_notes'),
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppSpacing.xxl),

              CashButton(
                label: isEditing
                    ? context.t('borrower_save_changes')
                    : context.t('borrower_create'),
                icon: Icon(
                  isEditing ? Icons.save_rounded : Icons.person_add_alt_1_rounded,
                  size: 20,
                ),
                height: 54,
                loading: _isSubmitting,
                onPressed: _isSubmitting ? null : () => _saveBorrower(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRisk(BuildContext context) async {
    const levels = ['low', 'medium', 'high'];
    await CashBottomSheet.show(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: context.t('borrower_risk_level'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final level in levels)
              _RiskOption(
                label: _riskLabel(context, level),
                color: _riskColor(level),
                selected: _riskLevel == level,
                onTap: () {
                  setState(() => _riskLevel = level);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveBorrower(BuildContext context) async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final provider = Provider.of<LoanProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final successMessage = context.t('borrower_saved_msg');
    final errorMessage = context.t('error');

    try {
      if (widget.borrower != null) {
        // Editing: se conserva el identificador y la relación con préstamos.
        final updated = widget.borrower!.copyWith(
          name: _nameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          writtenLocation: _writtenLocationController.text.trim(),
          riskLevel: _riskLevel,
          personalReference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          localPhotoPath: _localPhotoPath,
        );
        await provider.editBorrower(updated);
      } else {
        // Creating.
        await provider.createBorrower(
          name: _nameController.text.trim(),
          lastName: _lastNameController.text.trim(),
          phone: _phoneController.text.trim(),
          address: _addressController.text.trim(),
          writtenLocation: _writtenLocationController.text.trim(),
          riskLevel: _riskLevel,
          personalReference: _referenceController.text.trim(),
          notes: _notesController.text.trim(),
          localPhotoPath: _localPhotoPath,
        );
      }

      if (!mounted) return;
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(content: Text(successMessage), backgroundColor: AppColors.income),
      );
    } catch (_) {
      // Si falla el guardado, no se cierra el formulario ni se pierden los
      // datos introducidos; se permite volver a intentarlo.
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      messenger.showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: AppColors.error),
      );
    }
  }
}

String _riskLabel(BuildContext context, String level) {
  switch (level) {
    case 'high':
      return context.t('borrower_risk_high');
    case 'medium':
      return context.t('borrower_risk_medium');
    case 'low':
    default:
      return context.t('borrower_risk_low');
  }
}

Color _riskColor(String level) {
  switch (level) {
    case 'high':
      return AppColors.error;
    case 'medium':
      return AppColors.warning;
    case 'low':
    default:
      return AppColors.income;
  }
}

/// Opción del selector de nivel de riesgo.
class _RiskOption extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _RiskOption({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(
        selected ? Icons.check_circle_rounded : Icons.circle_outlined,
        color: color,
      ),
      title: Text(label),
    );
  }
}
