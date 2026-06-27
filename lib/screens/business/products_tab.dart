import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/product.dart';
import 'product_form_screen.dart';
import 'category_manager_screen.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  String _searchQuery = '';
  String? _selectedCategoryId;
  String _sortBy = 'name'; // 'name', 'stock', 'price'

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final categories = provider.rootCategories;
        final allProducts = provider.products;

        List<Product> filtered = allProducts.where((p) {
          final matchesSearch = _searchQuery.isEmpty ||
              p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
          final matchesCategory = _selectedCategoryId == null ||
              p.categoryId == _selectedCategoryId;
          return matchesSearch && matchesCategory;
        }).toList();

        switch (_sortBy) {
          case 'stock':
            filtered.sort((a, b) => a.currentStock.compareTo(b.currentStock));
            break;
          case 'price':
            filtered.sort((a, b) => a.salePrice.compareTo(b.salePrice));
            break;
          default:
            filtered.sort((a, b) => a.name.compareTo(b.name));
        }

        if (allProducts.isEmpty) {
          return _buildEmptyState(context);
        }

        return Stack(
          children: [
            Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar por nombre / SKU',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      filled: true,
                      fillColor: Theme.of(context).cardColor,
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),

                // Category chips
                if (categories.isNotEmpty)
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        _buildCategoryChip('Todas', null),
                        ...categories.map((c) => _buildCategoryChip(c.name, c.id)),
                      ],
                    ),
                  ),

                // Sort controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    children: [
                      Text('Orden:', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                      const SizedBox(width: 8),
                      _buildSortChip('Nombre', 'name'),
                      const SizedBox(width: 6),
                      _buildSortChip('Stock', 'stock'),
                      const SizedBox(width: 6),
                      _buildSortChip('Precio', 'price'),
                    ],
                  ),
                ),

                // Product list
                Expanded(
                  child: filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No se encontraron productos',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final product = filtered[index];
                            return _buildProductCard(context, product, provider);
                          },
                        ),
                ),
              ],
            ),
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'manage_categories',
                    backgroundColor: Colors.blueGrey[700],
                    foregroundColor: Colors.white,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CategoryManagerScreen(),
                        ),
                      );
                    },
                    tooltip: 'Categorías',
                    child: const Icon(Icons.category_outlined),
                  ),
                  const SizedBox(height: 12),
                  FloatingActionButton(
                    heroTag: 'add_product',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductFormScreen(),
                        ),
                      );
                    },
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(String label, String? id) {
    final selected = _selectedCategoryId == id;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedCategoryId = selected ? null : id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: selected ? Theme.of(context).primaryColor : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey[700],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortChip(String label, String value) {
    final selected = _sortBy == value;
    return GestureDetector(
      onTap: () => setState(() => _sortBy = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.blueGrey[100] : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? Colors.blueGrey[800] : Colors.grey[600],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inventory_2_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay productos',
            style: GoogleFonts.outfit(fontSize: 18, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProductFormScreen()),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar Producto'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    BusinessProvider provider,
  ) {
    final lowStock = product.currentStock < 10;
    final String formattedStock = product.currentStock % 1 == 0
        ? product.currentStock.toInt().toString()
        : product.currentStock.toStringAsFixed(2);

    final category = product.categoryId != null ? provider.getCategoryById(product.categoryId!) : null;
    final subcategory = product.subcategoryId != null ? provider.getCategoryById(product.subcategoryId!) : null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: lowStock ? Colors.orange : Colors.green,
          child: FittedBox(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Text(
                formattedStock,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
        title: Text(
          product.name,
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text('SKU: ${product.sku.length > 16 ? product.sku.substring(0, 16) : product.sku}'),
            if (category != null) ...[
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(Icons.folder_open_outlined, size: 12, color: Colors.blueGrey[400]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      subcategory != null ? '${category.name} > ${subcategory.name}' : category.name,
                      style: TextStyle(color: Colors.blueGrey[600], fontSize: 11, fontWeight: FontWeight.w500),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 2),
            Text(
              'Precio: \$${product.salePrice} | Stock: $formattedStock ${product.unit}',
              style: TextStyle(color: Colors.green[700], fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              'Margen: ${product.profitMarginPercentage.toFormattedString(1)}%',
              style: TextStyle(color: Colors.blueGrey[600], fontSize: 11),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.add_circle_outline, size: 20, color: Colors.blue),
              tooltip: 'Reabastecer (Restock)',
              onPressed: () => _showRestockDialog(context, product, provider),
            ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProductFormScreen(product: product),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, size: 20, color: Colors.red),
              onPressed: () => _confirmDelete(context, product, provider),
            ),
          ],
        ),
        isThreeLine: true,
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Product product,
    BusinessProvider provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Producto'),
        content: Text('¿Eliminar "${product.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await provider.deleteProduct(product.id);
    }
  }

  void _showRestockDialog(BuildContext context, Product product, BusinessProvider provider) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reabastecer ${product.name}'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: 'Cantidad a añadir (${product.unit})',
            border: const OutlineInputBorder(),
            suffixText: product.unit,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              final qty = double.tryParse(ctrl.text);
              if (qty != null && qty > 0) {
                provider.updateStock(product.id, product.currentStock + qty);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Stock actualizado exitosamente')),
                );
              }
            },
            child: const Text('Añadir'),
          ),
        ],
      ),
    );
  }
}
