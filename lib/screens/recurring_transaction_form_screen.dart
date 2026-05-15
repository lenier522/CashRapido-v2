import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/app_provider.dart';
import '../models/recurring_transaction.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

class RecurringTransactionFormScreen extends StatefulWidget {
  final RecurringTransaction? transaction;
  final bool isIncome;
  const RecurringTransactionFormScreen({super.key, this.transaction, this.isIncome = true});

  @override
  State<RecurringTransactionFormScreen> createState() => _RecurringTransactionFormScreenState();
}

class _RecurringTransactionFormScreenState extends State<RecurringTransactionFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _amountController = TextEditingController();
  
  String? _selectedCategory;
  String? _selectedAccount;
  String _recurrence = 'mensual';
  bool _autoRegister = true;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();

  final List<String> _recurrenceOptions = [
    'diario', 'semanal', 'quincenal', 'mensual', 'trimestral', 'anual'
  ];

  @override
  void initState() {
    super.initState();
    if (widget.transaction != null) {
      _titleController.text = widget.transaction!.title;
      _descController.text = widget.transaction!.description;
      _amountController.text = widget.transaction!.amount.toString();
      _selectedCategory = widget.transaction!.categoryId;
      _selectedAccount = widget.transaction!.accountId;
      _recurrence = widget.transaction!.recurrence;
      _autoRegister = widget.transaction!.autoRegister;
      _selectedDate = widget.transaction!.nextExecutionDate;
      _selectedTime = TimeOfDay.fromDateTime(widget.transaction!.nextExecutionDate);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime(2050),
    );
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (time != null) {
      setState(() => _selectedTime = time);
    }
  }

  void _save() {
    if (_formKey.currentState!.validate()) {
      if (_selectedCategory == null || _selectedAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona una categoría y una cuenta.')),
        );
        return;
      }

      final provider = context.read<AppProvider>();
      final dt = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

      final rt = RecurringTransaction(
        id: widget.transaction?.id ?? const Uuid().v4(),
        title: _titleController.text.trim(),
        description: _descController.text.trim(),
        amount: double.parse(_amountController.text),
        categoryId: _selectedCategory!,
        accountId: _selectedAccount!,
        nextExecutionDate: dt,
        recurrence: _recurrence,
        autoRegister: _autoRegister,
        isIncome: widget.isIncome,
      );

      if (widget.transaction == null) {
        provider.addRecurringTransaction(rt);
      } else {
        provider.updateRecurringTransaction(rt);
      }

      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppProvider>();
    final categories = provider.categories;
    final accounts = provider.cards;

    if (_selectedCategory == null && categories.isNotEmpty) {
      _selectedCategory = categories.first.id;
    }
    if (_selectedAccount == null && accounts.isNotEmpty) {
      _selectedAccount = accounts.first.id;
    }

    final themeColor = widget.isIncome ? Colors.green : Colors.redAccent;
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Text(widget.transaction == null 
            ? (widget.isIncome ? 'Nuevo Ingreso' : 'Nuevo Gasto') 
            : (widget.isIncome ? 'Editar Ingreso' : 'Editar Gasto'),
            style: GoogleFonts.outfit(fontWeight: FontWeight.bold, fontSize: 24)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Header Amount Area
              Container(
                padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
                child: Column(
                  children: [
                    Text(
                      'Monto Total',
                      style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text('\$ ', style: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.bold, color: themeColor)),
                        IntrinsicWidth(
                          child: TextFormField(
                            controller: _amountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: GoogleFonts.outfit(fontSize: 48, fontWeight: FontWeight.bold),
                            decoration: const InputDecoration(
                              hintText: '0.00',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                            validator: (v) {
                              if (v == null || v.isEmpty) return 'Req';
                              if (double.tryParse(v) == null) return 'Inválido';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel('Título'),
                        _buildTextField(_titleController, 'Ej. Salario mensual', Icons.title),
                        const SizedBox(height: 20),
                        
                        Row(
                          children: [
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Categoría'),
                                _buildDropdown(
                                  value: _selectedCategory,
                                  items: categories.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _selectedCategory = v),
                                  icon: Icons.category_outlined,
                                ),
                              ],
                            )),
                            const SizedBox(width: 16),
                            Expanded(child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildLabel('Cuenta destino'),
                                _buildDropdown(
                                  value: _selectedAccount,
                                  items: accounts.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name, overflow: TextOverflow.ellipsis))).toList(),
                                  onChanged: (v) => setState(() => _selectedAccount = v),
                                  icon: Icons.account_balance_wallet_outlined,
                                ),
                              ],
                            )),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('Recurrencia'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _recurrenceOptions.map((r) {
                            final isSelected = _recurrence == r;
                            return ChoiceChip(
                              label: Text(r.toUpperCase(), style: GoogleFonts.outfit(fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                              selected: isSelected,
                              selectedColor: themeColor.withValues(alpha: 0.2),
                              backgroundColor: Colors.grey.withValues(alpha: 0.1),
                              labelStyle: TextStyle(color: isSelected ? themeColor : Colors.grey),
                              onSelected: (val) {
                                if (val) setState(() => _recurrence = r);
                              },
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('Fecha del próximo registro'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: _pickDate,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today, color: themeColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text(DateFormat('dd MMM yyyy').format(_selectedDate), style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: _pickTime,
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time, color: themeColor, size: 20),
                                      const SizedBox(width: 8),
                                      Text(_selectedTime.format(context), style: GoogleFonts.outfit(fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        _buildLabel('Descripción (Opcional)'),
                        _buildTextField(_descController, 'Detalles adicionales...', Icons.notes, maxLines: 2),
                        const SizedBox(height: 24),

                        Container(
                          decoration: BoxDecoration(
                            color: themeColor.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: themeColor.withValues(alpha: 0.2)),
                          ),
                          child: SwitchListTile(
                            title: Text('Registro Automático', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
                            subtitle: Text('Registra la transacción y notifica automáticamente en la fecha indicada.', style: GoogleFonts.outfit(fontSize: 12)),
                            value: _autoRegister,
                            onChanged: (v) => setState(() => _autoRegister = v),
                            activeTrackColor: themeColor.withValues(alpha: 0.5),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 32),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _save,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                            ),
                            child: Text(
                              widget.transaction == null ? 'Guardar' : 'Actualizar',
                              style: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
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

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, left: 4),
      child: Text(
        text,
        style: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey[600]),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, IconData icon, {int maxLines = 1}) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: GoogleFonts.outfit(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.outfit(color: Colors.grey[400]),
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
      validator: (v) => v!.isEmpty && maxLines == 1 ? 'Requerido' : null,
    );
  }

  Widget _buildDropdown({required String? value, required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged, required IconData icon}) {
    return DropdownButtonFormField<String>(
      isExpanded: true,
      initialValue: value,
      items: items,
      onChanged: onChanged,
      icon: const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.grey[500]),
        filled: true,
        fillColor: Colors.grey.withValues(alpha: 0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      ),
    );
  }
}
