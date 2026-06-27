import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/product.dart';
import '../../models/product_category.dart';
import 'barcode_scanner_screen.dart';
import 'category_manager_screen.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class ProductFormScreen extends StatefulWidget {
  final Product? product;

  const ProductFormScreen({super.key, this.product});

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;
  late TextEditingController _skuController;
  late TextEditingController _quantityController;
  late TextEditingController _costController;
  late TextEditingController _salePriceController;
  late TextEditingController _additionalCostsController;
  late DateTime _investmentDate;
  late String _currency;
  late String _selectedUnit;
  String? _selectedCategoryId;
  String? _selectedSubcategoryId;

  final List<String> _currencies = ['CUP', 'USD', 'EUR', 'MLC'];

  final List<Map<String, String>> _units = [
    {'value': 'uds', 'label': 'Unidades (uds)'},
    {'value': 'kg', 'label': 'Kilogramos (kg)'},
    {'value': 'lb', 'label': 'Libras (lb)'},
    {'value': 'L', 'label': 'Litros (L)'},
    {'value': 'g', 'label': 'Gramos (g)'},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.product?.name ?? '');
    _descriptionController = TextEditingController(
      text: widget.product?.description ?? '',
    );
    _skuController = TextEditingController(
      text: widget.product?.sku ?? '',
    );
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
    _investmentDate = widget.product?.investmentDate ?? DateTime.now();
    _currency = widget.product?.currency ?? 'CUP';
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
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(
        builder: (context) => const BarcodeScannerScreen(continuous: false),
      ),
    );
    if (code != null && code.isNotEmpty) {
      setState(() {
        _skuController.text = code;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Código escaneado: $code'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.product != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEdit ? 'Editar Producto' : 'Nuevo Producto',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Name
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Nombre del Producto',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.inventory_2),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Ingresa un nombre'
                  : null,
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Descripción',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),

            // SKU & Barcode Scanner Button
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _skuController,
                    decoration: InputDecoration(
                      labelText: 'SKU / Código de Barras',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.qr_code),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  onPressed: _scanBarcode,
                  icon: const Icon(Icons.photo_camera),
                  tooltip: 'Escanear Código de Barras',
                  style: IconButton.styleFrom(
                    padding: const EdgeInsets.all(14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // ====== CATEGORY SECTION ======
            Text(
              'Categorización del Producto',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Consumer<BusinessProvider>(
              builder: (context, provider, _) {
                final rootCats = provider.rootCategories;
                final subcats = _selectedCategoryId != null
                    ? provider.getSubcategories(_selectedCategoryId!)
                    : <ProductCategory>[];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategoryId,
                      decoration: InputDecoration(
                        labelText: 'Categoría',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        prefixIcon: const Icon(Icons.folder_outlined),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.settings),
                          tooltip: 'Gestionar categorías',
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const CategoryManagerScreen(),
                            ),
                          ),
                        ),
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('Sin categoría'),
                        ),
                        ...rootCats.map((c) => DropdownMenuItem<String>(
                          value: c.id,
                          child: Text(c.name),
                        )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                          _selectedSubcategoryId = null; // reset subcategory
                        });
                      },
                    ),
                    const SizedBox(height: 12),

                    // Subcategory Dropdown (only shown when a category is selected)
                    if (_selectedCategoryId != null && subcats.isNotEmpty)
                      DropdownButtonFormField<String>(
                        value: _selectedSubcategoryId,
                        decoration: InputDecoration(
                          labelText: 'Subcategoría',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.subdirectory_arrow_right),
                        ),
                        items: [
                          const DropdownMenuItem<String>(
                            value: null,
                            child: Text('Sin subcategoría'),
                          ),
                          ...subcats.map((s) => DropdownMenuItem<String>(
                            value: s.id,
                            child: Text(s.name),
                          )),
                        ],
                        onChanged: (value) {
                          setState(() => _selectedSubcategoryId = value);
                        },
                      ),

                    if (_selectedCategoryId != null && subcats.isEmpty)
                      TextButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategoryManagerScreen(),
                          ),
                        ),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar subcategorías a esta categoría'),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // Investment Section
            Text(
              'Inversión Inicial',
              style: GoogleFonts.outfit(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            // Investment Date
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: Colors.grey[300]!),
              ),
              leading: const Icon(Icons.calendar_today),
              title: const Text('Fecha de Inversión'),
              subtitle: Text(
                '${_investmentDate.day}/${_investmentDate.month}/${_investmentDate.year}',
              ),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _investmentDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() => _investmentDate = date);
                }
              },
            ),
            const SizedBox(height: 16),

            // Unit of Measurement Dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedUnit,
              decoration: InputDecoration(
                labelText: 'Unidad de Medida',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.scale),
              ),
              items: _units.map((u) {
                return DropdownMenuItem(
                  value: u['value'],
                  child: Text(u['label']!),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedUnit = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            // Quantity (supports decimals)
            TextFormField(
              controller: _quantityController,
              decoration: InputDecoration(
                labelText: 'Cantidad Comprada',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.numbers),
                suffixText: _selectedUnit,
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa la cantidad';
                }
                if (double.tryParse(value) == null) return 'Debe ser un número';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Cost per Unit
            TextFormField(
              controller: _costController,
              decoration: InputDecoration(
                labelText: 'Costo por Unidad',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) return 'Ingresa el costo';
                if (double.tryParse(value) == null) return 'Debe ser un número';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Currency
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: InputDecoration(
                labelText: 'Moneda',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.currency_exchange),
              ),
              items: _currencies.map((curr) {
                return DropdownMenuItem(value: curr, child: Text(curr));
              }).toList(),
              onChanged: (value) {
                if (value != null) setState(() => _currency = value);
              },
            ),
            const SizedBox(height: 16),

            // Additional Costs
            TextFormField(
              controller: _additionalCostsController,
              decoration: InputDecoration(
                labelText: 'Gastos Adicionales (transporte, tasas, etc.)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.local_shipping),
                helperText: 'Ej: flete, aduana, envase',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 16),

            // Total Investment (Auto-calculated)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Inversión en Producto:',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        '\$${_calculateProductInvestment().toFormattedString(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Gastos Adicionales:',
                        style: TextStyle(fontSize: 13),
                      ),
                      Text(
                        '\$${_additionalAmount.toFormattedString(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Inversión Total Real:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '\$${_calculateTotalInvestment().toFormattedString(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sale Price
            TextFormField(
              controller: _salePriceController,
              decoration: InputDecoration(
                labelText: 'Precio de Venta',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.sell),
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa el precio de venta';
                }
                if (double.tryParse(value) == null) return 'Debe ser un número';
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _saveProduct,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                isEdit ? 'Guardar Cambios' : 'Crear Producto',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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
        final clean = text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9 ]'), '');
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

      final prodNameSanitized = _nameController.text.trim().toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
      final shortName = prodNameSanitized.length > 6
          ? prodNameSanitized.substring(0, 6)
          : prodNameSanitized;

      final dateStr = '${_investmentDate.year.toString().substring(2)}${_investmentDate.month.toString().padLeft(2, '0')}${_investmentDate.day.toString().padLeft(2, '0')}';

      sku = '$bizInitials$catSubcatInitials$shortName$dateStr';
    }

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
      );
    } else {
      // Edit
      final double newInitialQty = double.parse(_quantityController.text);
      final double newCostPerUnit = double.parse(_costController.text);
      final double qtyDiff = newInitialQty - widget.product!.initialQuantity;
      final double calculatedStock = widget.product!.currentStock + qtyDiff;
      final double newCurrentStock = calculatedStock < 0.0 ? 0.0 : calculatedStock;

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
