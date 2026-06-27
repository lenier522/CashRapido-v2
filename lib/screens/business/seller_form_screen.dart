import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/seller.dart';
import '../../services/localization_service.dart';

class SellerFormScreen extends StatefulWidget {
  final Seller? seller;

  const SellerFormScreen({super.key, this.seller});

  @override
  State<SellerFormScreen> createState() => _SellerFormScreenState();
}

class _SellerFormScreenState extends State<SellerFormScreen> {
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
      text: widget.seller != null ? widget.seller!.commissionRate.toString() : '',
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

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _lastNameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.t('seller_validation'))),
      );
      return;
    }

    setState(() => _isSaving = true);

    final provider = Provider.of<BusinessProvider>(context, listen: false);

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
        commissionRate: double.tryParse(_commissionCtrl.text) ?? 0.0,
        salary: double.tryParse(_salaryCtrl.text) ?? 0.0,
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
        commissionRate: double.tryParse(_commissionCtrl.text) ?? 0.0,
        salary: double.tryParse(_salaryCtrl.text) ?? 0.0,
        hireDate: _hireDate,
        isActive: _isActive,
        notes: _notesCtrl.text.trim(),
      );
    }

    setState(() => _isSaving = false);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.seller != null ? context.t('seller_edit') : context.t('seller_new'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Guardar'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(context.t('seller_personal_data'), Icons.person),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('seller_name'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.badge),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _lastNameCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('seller_lastname'),
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ciCtrl,
              decoration: InputDecoration(
                labelText: context.t('seller_id_doc'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneCtrl,
              decoration: InputDecoration(
                labelText: context.t('seller_phone'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailCtrl,
              decoration: InputDecoration(
                labelText: context.t('seller_email'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressCtrl,
              decoration: InputDecoration(
                labelText: context.t('seller_address'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            _buildSection(context.t('seller_employment_data'), Icons.work),
            const SizedBox(height: 12),
            TextField(
              controller: _roleCtrl,
              decoration: InputDecoration(
                labelText: context.t('seller_role'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _salaryCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('seller_salary'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _commissionCtrl,
                    decoration: InputDecoration(
                      labelText: context.t('seller_commission_rate'),
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.percent),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_today),
              title: Text('${context.t('seller_hire_date')}: ${_hireDate.day}/${_hireDate.month}/${_hireDate.year}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _hireDate,
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) setState(() => _hireDate = picked);
              },
            ),
            const SizedBox(height: 24),
            _buildSection(context.t('seller_status'), Icons.toggle_on),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(_isActive ? context.t('seller_active') : context.t('seller_inactive')),
              subtitle: Text(_isActive ? context.t('seller_enabled') : context.t('seller_disabled')),
              value: _isActive,
              onChanged: (val) => setState(() => _isActive = val),
            ),
            const SizedBox(height: 24),
            _buildSection(context.t('seller_notes'), Icons.note),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: InputDecoration(
                hintText: context.t('seller_notes_hint'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).primaryColor),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
