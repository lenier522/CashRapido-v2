import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
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
              ? (Localizations.localeOf(context).languageCode == 'es'
                    ? 'Editar Cliente'
                    : 'Edit Client')
              : (Localizations.localeOf(context).languageCode == 'es'
                    ? 'Nuevo Cliente'
                    : 'New Client'),
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
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Datos Básicos'
                    : 'Basic Information',
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
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Nombre *'
                    : 'First Name *',
                hint: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Ej. Juan'
                    : 'e.g. John',
                validator: (val) => val == null || val.trim().isEmpty
                    ? (Localizations.localeOf(context).languageCode == 'es'
                          ? 'Campo requerido'
                          : 'Required field')
                    : null,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Last Name
              _buildTextField(
                controller: _lastNameController,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Apellidos *'
                    : 'Last Name *',
                hint: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Ej. Pérez'
                    : 'e.g. Doe',
                validator: (val) => val == null || val.trim().isEmpty
                    ? (Localizations.localeOf(context).languageCode == 'es'
                          ? 'Campo requerido'
                          : 'Required field')
                    : null,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Phone
              _buildTextField(
                controller: _phoneController,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Teléfono *'
                    : 'Phone *',
                hint: 'Ej. +53 51234567',
                keyboardType: TextInputType.phone,
                validator: (val) => val == null || val.trim().isEmpty
                    ? (Localizations.localeOf(context).languageCode == 'es'
                          ? 'Campo requerido'
                          : 'Required field')
                    : null,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Address
              _buildTextField(
                controller: _addressController,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Dirección Física *'
                    : 'Physical Address *',
                hint: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Calle, número, entre calles...'
                    : 'Street, number, details...',
                maxLines: 2,
                validator: (val) => val == null || val.trim().isEmpty
                    ? (Localizations.localeOf(context).languageCode == 'es'
                          ? 'Campo requerido'
                          : 'Required field')
                    : null,
                isDark: isDark,
              ),
              const SizedBox(height: 24),

              // Additional Details Title
              Text(
                Localizations.localeOf(context).languageCode == 'es'
                    ? 'Datos Adicionales y de Seguridad'
                    : 'Additional Information',
                style: GoogleFonts.outfit(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // Risk Level Dropdown
              _buildDropdownField(
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Nivel de Riesgo'
                    : 'Risk Level',
                value: _riskLevel,
                items: [
                  DropdownMenuItem(
                    value: 'low',
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'es'
                          ? 'Riesgo Bajo (Seguro)'
                          : 'Low Risk',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'medium',
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'es'
                          ? 'Riesgo Medio (Moderar)'
                          : 'Medium Risk',
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'high',
                    child: Text(
                      Localizations.localeOf(context).languageCode == 'es'
                          ? 'Riesgo Alto (Peligroso)'
                          : 'High Risk',
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
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Ubicación Escrita / Referencias visuales'
                    : 'Location / Visual references',
                hint: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Ej. Casa azul de rejas blancas al lado de la bodega...'
                    : 'e.g. Blue house with white fence next to the store...',
                maxLines: 2,
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Personal Reference
              _buildTextField(
                controller: _referenceController,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Referencia Personal (Familiar o Amigo)'
                    : 'Personal Reference (Name and Phone)',
                hint: 'Ej. María Pérez (Madre) - +53 58765432',
                isDark: isDark,
              ),
              const SizedBox(height: 16),

              // Notes
              _buildTextField(
                controller: _notesController,
                label: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Notas / Observaciones del prestamista'
                    : 'Notes / Observations',
                hint: Localizations.localeOf(context).languageCode == 'es'
                    ? 'Ej. Buen cliente, paga a tiempo pero prefiere transferencias...'
                    : 'e.g. Good client, pays on time...',
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
                        ? (Localizations.localeOf(context).languageCode == 'es'
                              ? 'Guardar Cambios'
                              : 'Save Changes')
                        : (Localizations.localeOf(context).languageCode == 'es'
                              ? 'Registrar Cliente'
                              : 'Create Client Profile'),
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
    final lang = Localizations.localeOf(context).languageCode;

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
          content: Text(
            lang == 'es'
                ? 'Cliente guardado correctamente'
                : 'Client profile saved successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
