import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cashrapido/services/localization_service.dart';
import '../../providers/loan_provider.dart';
import '../../models/borrower.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.borrower != null;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0A14) : Colors.grey[50],
      appBar: AppBar(
        title: Text(
          isEditing
              ? context.t('borrower_form_title_edit')
              : context.t('borrower_form_title_new'),
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
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Subsection Title
              Text(
                context.t('borrower_basic_info'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Name
              _buildTextField(
                controller: _nameController,
                label: context.t('borrower_first_name'),
                hint: context.t('borrower_hint_name'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? context.t('borrower_required_field')
                    : null,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Last Name
              _buildTextField(
                controller: _lastNameController,
                label: context.t('borrower_last_name'),
                hint: context.t('borrower_hint_last'),
                validator: (val) => val == null || val.trim().isEmpty
                    ? context.t('borrower_required_field')
                    : null,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Phone
              _buildTextField(
                controller: _phoneController,
                label: context.t('borrower_phone'),
                hint: context.t('borrower_hint_phone'),
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty
                    ? context.t('borrower_required_field')
                    : null,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Address
              _buildTextField(
                controller: _addressController,
                label: context.t('borrower_address'),
                hint: context.t('borrower_hint_address'),
                maxLines: 2,
                validator: (val) => val == null || val.trim().isEmpty
                    ? context.t('borrower_required_field')
                    : null,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Additional Details Title
              Text(
                context.t('borrower_additional_info'),
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Risk Level Dropdown
              _buildDropdownField(
                label: context.t('borrower_risk_level'),
                value: _riskLevel,
                items: [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text(
                      context.t('borrower_risk_low'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text(
                      context.t('borrower_risk_medium'),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text(
                      context.t('borrower_risk_high'),
                    ),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _riskLevel = val;
                    });
                  }
                },
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Written Location / References
              _buildTextField(
                controller: _writtenLocationController,
                label: context.t('borrower_location'),
                hint: context.t('borrower_hint_location'),
                maxLines: 2,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Personal Reference
              _buildTextField(
                controller: _referenceController,
                label: context.t('borrower_personal_ref'),
                hint: context.t('borrower_hint_ref'),
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Notes
              _buildTextField(
                controller: _notesController,
                label: context.t('borrower_notes'),
                hint: context.t('borrower_hint_notes'),
                maxLines: 3,
                isDark: isDark,
              ),
              const SizedBox(height: 40),

              // Save button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () => _saveBorrower(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isEditing
                        ? context.t('borrower_save_changes')
                        : context.t('borrower_create'),
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    String? Function(String?)? validator,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141428) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            maxLines: maxLines,
            validator: validator,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.outfit(color: Colors.grey, fontSize: 13),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>> items,
    required void Function(String?) onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141428) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              initialValue: value,
              items: items,
              onChanged: onChanged,
              dropdownColor: isDark ? const Color(0xFF141428) : Colors.white,
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black87,
              ),
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ),
      ],
    );
  }

  void _saveBorrower(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;

    final provider = Provider.of<LoanProvider>(context, listen: false);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    if (widget.borrower != null) {
      // Editing
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
      // Creating
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

    if (mounted) {
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(context.t('borrower_saved_msg')),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
