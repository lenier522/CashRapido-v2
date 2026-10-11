import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/product_category.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../utils/number_format_utils.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import '../../widgets/design/cash_icon_button.dart';
import '../../widgets/design/cash_input.dart';
import 'category_manager_screen.dart';
import 'product_form_screen.dart';

/// Estados visuales de stock.
///
/// La regla del umbral NO se inventa aquí: un producto está en "stock bajo"
/// si el provider ya lo incluye en [BusinessProvider.lowStockProducts]
/// (currentStock < 10). El estado "agotado" es solo una distinción visual
/// dentro de ese mismo umbral cuando el stock es 0.
enum _StockStatus { normal, low, out }

class ProductsTab extends StatefulWidget {
  const ProductsTab({super.key});

  @override
  State<ProductsTab> createState() => _ProductsTabState();
}

class _ProductsTabState extends State<ProductsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategoryId;
  String _sortBy = 'name'; // 'name', 'stock', 'price'

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ESTADO DE STOCK
  // ---------------------------------------------------------------------------

  Set<String> _lowStockIds(BusinessProvider provider) =>
      provider.lowStockProducts.map((p) => p.id).toSet();

  _StockStatus _statusOf(Product product, Set<String> lowIds) {
    if (product.currentStock <= 0) return _StockStatus.out;
    if (lowIds.contains(product.id)) return _StockStatus.low;
    return _StockStatus.normal;
  }

  Color _statusColor(_StockStatus status) {
    switch (status) {
      case _StockStatus.out:
        return AppColors.error;
      case _StockStatus.low:
        return AppColors.warning;
      case _StockStatus.normal:
        return AppColors.income;
    }
  }

  String _statusLabel(BuildContext context, _StockStatus status) {
    switch (status) {
      case _StockStatus.out:
        return context.t('product_stock_out');
      case _StockStatus.low:
        return context.t('product_stock_low');
      case _StockStatus.normal:
        return context.t('product_stock_normal');
    }
  }

  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);

  String _currency(BusinessProvider provider) =>
      provider.activeBusiness?.currency ?? 'CUP';

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final categories = provider.rootCategories;
        final allProducts = provider.products;
        final lowIds = _lowStockIds(provider);

        List<Product> filtered = allProducts.where((p) {
          final q = _searchQuery.trim().toLowerCase();
          final matchesSearch =
              q.isEmpty ||
              p.name.toLowerCase().contains(q) ||
              p.sku.toLowerCase().contains(q);
          final matchesCategory =
              _selectedCategoryId == null ||
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
            filtered.sort(
              (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
            );
        }

        if (allProducts.isEmpty) {
          return _buildEmptyState(context);
        }

        return Stack(
          children: [
            // Un único scroll permite que cabecera, filtros y lista se muevan
            // juntos: sin "Expanded" fijo, la pantalla nunca desborda aunque la
            // altura disponible sea pequeña o la escala de texto grande.
            CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: _buildHeader(context, allProducts.length),
                ),
                SliverToBoxAdapter(child: _buildFundBanner(context, provider)),
                SliverToBoxAdapter(child: _buildSearchField(context)),
                if (categories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _buildCategoryChips(context, categories),
                  ),
                SliverToBoxAdapter(child: _buildSortRow(context)),
                if (filtered.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildNoResults(context),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.xs,
                      AppSpacing.lg,
                      144,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _buildProductCard(
                          context,
                          filtered[index],
                          provider,
                          lowIds,
                        ),
                        childCount: filtered.length,
                      ),
                    ),
                  ),
              ],
            ),
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FloatingActionButton.small(
                    heroTag: 'manage_categories',
                    backgroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? AppColors.surfaceDark2
                        : AppColors.primaryLight,
                    foregroundColor: AppColors.primary,
                    onPressed: () => _openCategoryManager(context),
                    tooltip: context.t('category_manager_title'),
                    child: const Icon(Icons.category_outlined),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CashFloatingButton(
                    heroTag: 'add_product',
                    icon: Icons.add_rounded,
                    label: context.t('product_add'),
                    onPressed: () => _openCreate(context),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CABECERA / BÚSQUEDA / FILTROS
  // ---------------------------------------------------------------------------

  Widget _buildHeader(BuildContext context, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t('products_title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.surfaceDark2
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              context
                  .t('product_total_products')
                  .replaceAll('{count}', '$total'),
              maxLines: 1,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFundBanner(BuildContext context, BusinessProvider provider) {
    final available = provider.availableInventoryBalance;
    final currency = _currency(provider);
    final isPositive = available >= 0;
    final Color color = isPositive ? AppColors.income : AppColors.expense;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.savings_outlined, color: color, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.t('available_to_renew'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Text(
              '\$${available.toFormattedString(2)} $currency',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.sm,
      ),
      child: CashInput(
        controller: _searchController,
        hint: context.t('product_search_hint'),
        prefix: const Icon(Icons.search_rounded),
        suffix: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
        onChanged: (val) => setState(() => _searchQuery = val),
      ),
    );
  }

  Widget _buildCategoryChips(
    BuildContext context,
    List<ProductCategory> categories,
  ) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        children: [
          CashChip(
            label: context.t('product_filter_all'),
            icon: Icons.apps_rounded,
            selected: _selectedCategoryId == null,
            onTap: () => setState(() => _selectedCategoryId = null),
          ),
          for (final category in categories)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.sm),
              child: CashChip(
                label: category.name,
                icon: Icons.folder_outlined,
                selected: _selectedCategoryId == category.id,
                onTap: () => setState(
                  () => _selectedCategoryId = _selectedCategoryId == category.id
                      ? null
                      : category.id,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSortRow(BuildContext context) {
    final chips = <(String, String)>[
      (context.t('product_sort_name'), 'name'),
      (context.t('product_sort_stock'), 'stock'),
      (context.t('product_sort_price'), 'price'),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.lg,
        AppSpacing.xs,
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.xs),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_vert_rounded,
                  size: 16,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
                const SizedBox(width: AppSpacing.xs),
                Text(
                  context.t('product_sort_by'),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          for (final (label, value) in chips)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: CashChip(
                label: label,
                selected: _sortBy == value,
                onTap: () => setState(() => _sortBy = value),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // EMPTY STATES
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context) {
    return CashEmptyState(
      icon: Icons.inventory_2_outlined,
      title: context.t('product_empty_title'),
      message: context.t('product_empty_desc'),
      buttonLabel: context.t('product_add'),
      onButtonPressed: () => _openCreate(context),
    );
  }

  Widget _buildNoResults(BuildContext context) {
    return CashEmptyState(
      icon: Icons.search_off_rounded,
      title: context.t('product_no_search_results'),
      message: context.t('product_no_search_results_desc'),
      action: TextButton.icon(
        onPressed: () {
          _searchController.clear();
          setState(() {
            _searchQuery = '';
            _selectedCategoryId = null;
          });
        },
        icon: const Icon(Icons.filter_alt_off_rounded, size: 18),
        label: Text(context.t('product_clear_filters')),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TARJETA DE PRODUCTO
  // ---------------------------------------------------------------------------

  Widget _buildProductCard(
    BuildContext context,
    Product product,
    BusinessProvider provider,
    Set<String> lowIds,
  ) {
    final status = _statusOf(product, lowIds);
    final Color statusColor = _statusColor(status);
    final String currency = _currency(provider);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final category = product.categoryId != null
        ? provider.getCategoryById(product.categoryId!)
        : null;
    final subcategory = product.subcategoryId != null
        ? provider.getCategoryById(product.subcategoryId!)
        : null;

    String categoryLabel = '';
    if (category != null) {
      categoryLabel = subcategory != null
          ? '${category.name} › ${subcategory.name}'
          : category.name;
    }

    final String meta = [
      if (product.sku.isNotEmpty) 'SKU ${product.sku}',
      if (categoryLabel.isNotEmpty) categoryLabel,
    ].join(' · ');

    return CashCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.compactPadding),
      onTap: () => _openEdit(context, product),
      child: Row(
        children: [
          _buildStockAvatar(context, product, statusColor),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (meta.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: [
                    _buildStatusChip(context, status),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '\$${product.salePrice.toFormattedString(2)} $currency',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.right,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: isDark
                              ? AppColors.primary
                              : AppColors.primaryDark,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CashIconButton(
                icon: Icons.add_box_rounded,
                size: 38,
                iconSize: 19,
                tooltip: context.t('product_restock'),
                backgroundColor: statusColor.withValues(alpha: 0.12),
                iconColor: statusColor,
                onPressed: () => _showRestockSheet(context, product, provider),
              ),
              const SizedBox(height: AppSpacing.xs),
              _buildMoreMenu(context, product, provider),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStockAvatar(BuildContext context, Product product, Color color) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.12),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          child: Text(
            _formatQty(product.currentStock),
            maxLines: 1,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, _StockStatus status) {
    final Color color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status == _StockStatus.out
                ? Icons.block_rounded
                : status == _StockStatus.low
                ? Icons.warning_amber_rounded
                : Icons.check_circle_rounded,
            size: 12,
            color: color,
          ),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            _statusLabel(context, status),
            maxLines: 1,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoreMenu(
    BuildContext context,
    Product product,
    BusinessProvider provider,
  ) {
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
          case 'edit':
            _openEdit(context, product);
          case 'restock':
            _showRestockSheet(context, product, provider);
          case 'delete':
            _confirmDelete(context, product, provider);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'restock',
          child: Row(
            children: [
              Icon(Icons.add_box_outlined, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Text(context.t('product_restock')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: secondary),
              const SizedBox(width: AppSpacing.md),
              Text(context.t('product_edit')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'delete',
          child: Row(
            children: [
              const Icon(
                Icons.delete_outline,
                size: 20,
                color: AppColors.error,
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                context.t('product_delete'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
      child: Icon(Icons.more_vert_rounded, size: 20, color: secondary),
    );
  }

  // ---------------------------------------------------------------------------
  // ACCIONES
  // ---------------------------------------------------------------------------

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProductFormScreen()),
    );
  }

  void _openEdit(BuildContext context, Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProductFormScreen(product: product)),
    );
  }

  void _openCategoryManager(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const CategoryManagerScreen()),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Product product,
    BusinessProvider provider,
  ) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        backgroundColor: isDark
            ? AppColors.surfaceDark
            : AppColors.surfaceLight,
        title: Row(
          children: [
            const Icon(Icons.delete_outline, color: AppColors.error, size: 22),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                context.t('delete_product'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          context
              .t('product_form_delete_confirm')
              .replaceAll('{name}', product.name),
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
    );

    if (confirmed == true) {
      await provider.deleteProduct(product.id);
    }
  }

  void _showRestockSheet(
    BuildContext context,
    Product product,
    BusinessProvider provider,
  ) {
    final TextEditingController controller = TextEditingController();

    CashBottomSheet.show(
      context,
      builder: (sheetContext) => CashBottomSheet(
        title: sheetContext
            .t('product_restock_title')
            .replaceAll('{name}', product.name),
        subtitle:
            '${sheetContext.t('product_form_current_stock_label')}: '
            '${_formatQty(product.currentStock)} ${product.unit}',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CashInput(
              controller: controller,
              autofocus: true,
              label: sheetContext
                  .t('product_restock_label')
                  .replaceAll('{unit}', product.unit),
              hint: sheetContext.t('product_restock_hint'),
              prefix: const Icon(Icons.add_box_outlined),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            CashButton(
              label: sheetContext.t('product_restock_add'),
              icon: const Icon(Icons.add_rounded, size: 20),
              onPressed: () async {
                final qty = double.tryParse(controller.text);
                if (qty == null || qty <= 0) return;
                final messenger = ScaffoldMessenger.of(context);
                final successMessage = context
                    .t('product_restock_success')
                    .replaceAll('{qty}', _formatQty(qty))
                    .replaceAll('{unit}', product.unit);
                await provider.updateStock(
                  product.id,
                  product.currentStock + qty,
                );
                if (!sheetContext.mounted) return;
                Navigator.pop(sheetContext);
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(successMessage),
                    backgroundColor: AppColors.primary,
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ).whenComplete(controller.dispose);
  }
}
