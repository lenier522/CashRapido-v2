import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/product_category.dart';

class CategoryManagerScreen extends StatelessWidget {
  const CategoryManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Categorías de Productos',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Consumer<BusinessProvider>(
        builder: (context, provider, _) {
          final categories = provider.rootCategories;

          if (categories.isEmpty) {
            return _EmptyState(onAdd: () => _showCategoryDialog(context, provider));
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final cat = categories[index];
              final subcategories = provider.getSubcategories(cat.id);
              return _CategoryCard(
                category: cat,
                subcategories: subcategories,
                provider: provider,
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cat_fab',
        onPressed: () {
          final provider = context.read<BusinessProvider>();
          _showCategoryDialog(context, provider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva Categoría'),
      ),
    );
  }

  static void _showCategoryDialog(
    BuildContext context,
    BusinessProvider provider, {
    ProductCategory? editing,
    String? parentId,
  }) {
    final nameController = TextEditingController(text: editing?.name ?? '');
    final isSubcat = parentId != null;
    final title = editing != null
        ? (isSubcat ? 'Editar Subcategoría' : 'Editar Categoría')
        : (isSubcat ? 'Nueva Subcategoría' : 'Nueva Categoría');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              isSubcat ? Icons.subdirectory_arrow_right : Icons.category,
              color: Theme.of(context).primaryColor,
            ),
            const SizedBox(width: 8),
            Text(title, style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ],
        ),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: isSubcat ? 'Nombre de Subcategoría' : 'Nombre de Categoría',
            hintText: isSubcat ? 'Ej: Con Filtro, Sin Filtro...' : 'Ej: Cigarros, Bebidas...',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: Icon(isSubcat ? Icons.label_outline : Icons.folder_outlined),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;

              if (editing != null) {
                final updated = ProductCategory(
                  id: editing.id,
                  businessId: editing.businessId,
                  name: name,
                  parentId: editing.parentId,
                );
                await provider.editProductCategory(updated);
              } else {
                await provider.addProductCategory(name: name, parentId: parentId);
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(editing != null ? 'Guardar' : 'Crear'),
          ),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatefulWidget {
  final ProductCategory category;
  final List<ProductCategory> subcategories;
  final BusinessProvider provider;

  const _CategoryCard({
    required this.category,
    required this.subcategories,
    required this.provider,
  });

  @override
  State<_CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<_CategoryCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Column(
        children: [
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            leading: CircleAvatar(
              radius: 14,
              backgroundColor: colorScheme.primary,
              child: const Icon(Icons.folder, color: Colors.white, size: 14),
            ),
            title: Text(
              widget.category.name,
              style: GoogleFonts.outfit(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Text(
              '${widget.subcategories.length} subcategoría(s)',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 18),
                  tooltip: 'Agregar subcategoría',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => CategoryManagerScreen._showCategoryDialog(
                    context,
                    widget.provider,
                    parentId: widget.category.id,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Editar',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => CategoryManagerScreen._showCategoryDialog(
                    context,
                    widget.provider,
                    editing: widget.category,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 18),
                  tooltip: 'Eliminar',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _confirmDelete(context),
                ),
                if (widget.subcategories.isNotEmpty)
                  IconButton(
                    icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => setState(() => _expanded = !_expanded),
                  ),
              ],
            ),
          ),

          if (_expanded && widget.subcategories.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 4),
              child: Column(
                children: [
                  ...widget.subcategories.map((sub) => _SubcategoryTile(
                    subcategory: sub,
                    provider: widget.provider,
                    parentCategory: widget.category,
                  )),
                  TextButton.icon(
                    onPressed: () => CategoryManagerScreen._showCategoryDialog(
                      context,
                      widget.provider,
                      parentId: widget.category.id,
                    ),
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text('Agregar subcategoría', style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Categoría'),
        content: Text(
          'Se eliminará "${widget.category.name}" y todas sus subcategorías (${widget.subcategories.length}). Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await widget.provider.deleteProductCategory(widget.category.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  final ProductCategory subcategory;
  final ProductCategory parentCategory;
  final BusinessProvider provider;

  const _SubcategoryTile({
    required this.subcategory,
    required this.parentCategory,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      leading: Icon(Icons.subdirectory_arrow_right, color: Colors.grey[500], size: 16),
      title: Text(
        subcategory.name,
        style: GoogleFonts.outfit(fontWeight: FontWeight.w500, fontSize: 13),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 16),
            tooltip: 'Editar',
            visualDensity: VisualDensity.compact,
            onPressed: () => CategoryManagerScreen._showCategoryDialog(
              context,
              provider,
              editing: subcategory,
              parentId: parentCategory.id,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 16),
            tooltip: 'Eliminar',
            visualDensity: VisualDensity.compact,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Subcategoría'),
        content: Text('¿Eliminar la subcategoría "${subcategory.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await provider.deleteProductCategory(subcategory.id);
              if (ctx.mounted) Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined, size: 64, color: Colors.purple),
          ),
          const SizedBox(height: 16),
          Text(
            'Sin Categorías',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea categorías para organizar tus productos\ny generar SKUs automáticamente.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Crear primera categoría'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
