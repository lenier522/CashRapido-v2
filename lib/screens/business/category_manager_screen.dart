import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product_category.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import '../../widgets/design/cash_icon_button.dart';
import '../../widgets/design/cash_input.dart';

class CategoryManagerScreen extends StatelessWidget {
  const CategoryManagerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          context.t('category_manager_title'),
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        centerTitle: true,
      ),
      body: Consumer<BusinessProvider>(
        builder: (context, provider, _) {
          final categories = provider.rootCategories;

          if (categories.isEmpty) {
            return CashEmptyState(
              icon: Icons.category_outlined,
              title: context.t('category_empty_title'),
              message: context.t('category_empty_desc'),
              buttonLabel: context.t('category_add_category'),
              onButtonPressed: () =>
                  _showCategoryDialog(context, provider),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              120,
            ),
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryCard(
                category: category,
                subcategories: provider.getSubcategories(category.id),
                provider: provider,
              );
            },
          );
        },
      ),
      floatingActionButton: CashFloatingButton(
        heroTag: 'cat_fab',
        icon: Icons.add_rounded,
        label: context.t('category_add_category'),
        onPressed: () {
          final provider = context.read<BusinessProvider>();
          _showCategoryDialog(context, provider);
        },
      ),
    );
  }

  /// Diálogo de alta/edición de categoría o subcategoría.
  static Future<void> _showCategoryDialog(
    BuildContext context,
    BusinessProvider provider, {
    ProductCategory? editing,
    String? parentId,
  }) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final TextEditingController nameController = TextEditingController(
      text: editing?.name ?? '',
    );
    final GlobalKey<FormState> formKey = GlobalKey<FormState>();
    final bool isSubcat = parentId != null;
    final bool isEditing = editing != null;

    final String title = isEditing
        ? (isSubcat
              ? context.t('category_edit_sub_title')
              : context.t('category_edit_title'))
        : (isSubcat
              ? context.t('category_new_sub_title')
              : context.t('category_new_title'));

    final String placeholder = isSubcat
        ? context.t('category_sub_name_placeholder')
        : context.t('category_name_placeholder');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        title: Row(
          children: [
            Icon(
              isSubcat ? Icons.subdirectory_arrow_right_rounded : Icons.category_outlined,
              color: AppColors.primary,
              size: 22,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: CashInput(
            controller: nameController,
            autofocus: true,
            label: placeholder,
            hint: placeholder,
            prefix: Icon(
              isSubcat ? Icons.label_outline_rounded : Icons.folder_outlined,
            ),
            textCapitalization: TextCapitalization.words,
            validator: (value) => value == null || value.trim().isEmpty
                ? context.t('product_enter_name')
                : null,
          ),
        ),
        actions: [
          CashButton(
            label: context.t('cancel'),
            type: CashButtonType.outlined,
            fullWidth: false,
            height: 44,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          const SizedBox(width: AppSpacing.sm),
          CashButton(
            label: context.t('save'),
            fullWidth: false,
            height: 44,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
          ),
        ],
      ),
    );

    if (saved != true || !nameController.text.trim().isNotEmpty) return;

    final String name = nameController.text.trim();

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

  int get _productCount => widget.provider.products
      .where((p) => p.categoryId == widget.category.id)
      .length;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final int subCount = widget.subcategories.length;

    final String subtitle = [
      context
          .t('product_total_products')
          .replaceAll('{count}', '$_productCount'),
      if (subCount > 0)
        context
            .t('category_subcategories_count')
            .replaceAll('{count}', '$subCount'),
    ].join(' · ');

    return CashCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.compactPadding,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _CategoryAvatar(isSubcategory: false),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (subCount > 0)
                CashIconButton(
                  icon: _expanded
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  size: 34,
                  iconSize: 18,
                  tooltip: '',
                  onPressed: () => setState(() => _expanded = !_expanded),
                ),
              _buildMenu(context),
            ],
          ),
          if (_expanded && subCount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Divider(
              color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
            ),
            const SizedBox(height: AppSpacing.xs),
            ...widget.subcategories.map(
              (sub) => _SubcategoryTile(
                subcategory: sub,
                parentCategory: widget.category,
                provider: widget.provider,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => CategoryManagerScreen._showCategoryDialog(
                  context,
                  widget.provider,
                  parentId: widget.category.id,
                ),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(
                  context.t('category_add_subcategory'),
                  style: const TextStyle(fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenu(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return PopupMenuButton<String>(
      tooltip: '',
      constraints: const BoxConstraints(minWidth: 168),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
      onSelected: (value) {
        switch (value) {
          case 'add_sub':
            CategoryManagerScreen._showCategoryDialog(
              context,
              widget.provider,
              parentId: widget.category.id,
            );
          case 'edit':
            CategoryManagerScreen._showCategoryDialog(
              context,
              widget.provider,
              editing: widget.category,
            );
          case 'delete':
            _confirmDelete(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'add_sub',
          child: Row(
            children: [
              Icon(Icons.create_new_folder_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Text(context.t('category_add_subcategory')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: secondary),
              const SizedBox(width: AppSpacing.md),
              Text(context.t('category_edit')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(Icons.delete_outline, size: 20, color: AppColors.error),
              const SizedBox(width: AppSpacing.md),
              Text(
                context.t('category_delete'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
      child: Icon(Icons.more_vert_rounded, size: 20, color: secondary),
    );
  }

  void _confirmDelete(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.t('category_delete_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          context
              .t('category_confirm_delete')
              .replaceAll('{name}', widget.category.name),
        ),
        actions: [
          CashButton(
            label: context.t('cancel'),
            type: CashButtonType.outlined,
            fullWidth: false,
            height: 44,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          const SizedBox(width: AppSpacing.sm),
          CashButton(
            label: context.t('delete'),
            type: CashButtonType.danger,
            fullWidth: false,
            height: 44,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await widget.provider.deleteProductCategory(widget.category.id);
      }
    });
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(
            Icons.subdirectory_arrow_right_rounded,
            size: 16,
            color: secondary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              subcategory.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          CashIconButton(
            icon: Icons.edit_outlined,
            size: 32,
            iconSize: 15,
            tooltip: context.t('category_edit'),
            onPressed: () => CategoryManagerScreen._showCategoryDialog(
              context,
              provider,
              editing: subcategory,
              parentId: parentCategory.id,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          CashIconButton(
            icon: Icons.delete_outline,
            size: 32,
            iconSize: 15,
            tooltip: context.t('category_delete'),
            iconColor: AppColors.error,
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        backgroundColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.t('category_delete_sub_title'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          context
              .t('category_confirm_delete_sub')
              .replaceAll('{name}', subcategory.name),
        ),
        actions: [
          CashButton(
            label: context.t('cancel'),
            type: CashButtonType.outlined,
            fullWidth: false,
            height: 44,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          const SizedBox(width: AppSpacing.sm),
          CashButton(
            label: context.t('delete'),
            type: CashButtonType.danger,
            fullWidth: false,
            height: 44,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    ).then((confirmed) async {
      if (confirmed == true) {
        await provider.deleteProductCategory(subcategory.id);
      }
    });
  }
}

/// Avatar de carpeta para categorías y subcategorías.
class _CategoryAvatar extends StatelessWidget {
  final bool isSubcategory;

  const _CategoryAvatar({this.isSubcategory = false});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.primary.withValues(alpha: 0.18)
            : AppColors.primaryLight,
        borderRadius: AppRadius.radiusSm,
      ),
      child: Icon(
        isSubcategory
            ? Icons.subdirectory_arrow_right_rounded
            : Icons.folder_rounded,
        size: 20,
        color: isDark ? AppColors.primary : AppColors.primaryDark,
      ),
    );
  }
}