import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/sale.dart';
import '../../models/seller.dart';
import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_bottom_sheet.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_icon_button.dart';
import '../../widgets/design/cash_input.dart';
import 'barcode_scanner_screen.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

/// Estado visual de stock de un producto en el catálogo del POS.
///
/// El umbral de "stock bajo" NO se inventa aquí: usa exactamente el que ya
/// expone [BusinessProvider.lowStockProducts] (currentStock < 10). "Agotado"
/// es sólo la distinción visual cuando el stock es 0 dentro de ese umbral.
enum _StockState { normal, low, out }

class PosScreen extends StatefulWidget {
  const PosScreen({super.key});

  @override
  State<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends State<PosScreen> {
  final Map<String, double> _cart = {}; // ProductId -> Quantity (double)
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Product? _findProduct(BusinessProvider provider, String id) {
    for (final p in provider.products) {
      if (p.id == id) return p;
    }
    return null;
  }

  String _currency(BusinessProvider provider) =>
      provider.activeBusiness?.currency ?? 'CUP';

  String _formatQty(double value) =>
      value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);

  _StockState _stockState(Product product, bool isLow) {
    if (product.currentStock <= 0) return _StockState.out;
    if (isLow) return _StockState.low;
    return _StockState.normal;
  }

  int get _cartItemCount => _cart.length;

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final products = provider.products.where((p) {
          return p.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              p.sku.toLowerCase().contains(_searchQuery.toLowerCase());
        }).toList();

        final total = _calculateTotal(provider);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            scrolledUnderElevation: 0,
            titleSpacing: 0,
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if ((provider.activeBusiness?.name ?? '').isNotEmpty)
                  Text(
                    provider.activeBusiness!.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                Text(
                  context.t('pos_title'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            actions: [
              CashIconButton(
                icon: Icons.qr_code_scanner_rounded,
                tooltip: context.t('pos_scan_barcode'),
                size: 42,
                iconSize: 20,
                onPressed: () => _startContinuousScanning(provider),
              ),
              const SizedBox(width: AppSpacing.sm),
              CashIconButton(
                icon: Icons.shopping_bag_outlined,
                tooltip: context.t('pos_view_cart'),
                size: 42,
                iconSize: 20,
                onPressed: _cart.isEmpty
                    ? null
                    : () => _showCartSheet(context, provider),
                badge: _cart.isEmpty
                    ? null
                    : Container(
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 5),
                        alignment: Alignment.center,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$_cartItemCount',
                          style: const TextStyle(
                            color: AppColors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.md),
            ],
          ),
          body: Column(
            children: [
              // -----------------------------------------------------------------
              // BÚSQUEDA
              // -----------------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: CashInput(
                  controller: _searchController,
                  hint: context.t('pos_search_hint'),
                  prefix: const Icon(Icons.search_rounded),
                  suffix: _searchQuery.isEmpty
                      ? null
                      : GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          child: const Icon(Icons.close_rounded),
                        ),
                  textInputAction: TextInputAction.search,
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),

              // -----------------------------------------------------------------
              // CATÁLOGO
              // -----------------------------------------------------------------
              Expanded(child: _buildCatalog(context, provider, products)),

              // -----------------------------------------------------------------
              // BARRA DE CARRITO
              // -----------------------------------------------------------------
              if (_cart.isNotEmpty) _buildCartBar(context, provider, total),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CATÁLOGO
  // ---------------------------------------------------------------------------

  Widget _buildCatalog(
    BuildContext context,
    BusinessProvider provider,
    List<Product> products,
  ) {
    if (provider.products.isEmpty) {
      return CashEmptyState(
        icon: Icons.inventory_2_outlined,
        title: context.t('no_products'),
        message: context.t('no_products_desc'),
      );
    }

    if (products.isEmpty) {
      return CashEmptyState(
        icon: Icons.search_off_rounded,
        title: context.t('pos_no_results'),
        message: context.t('pos_no_results_desc'),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width < 600
            ? 2
            : width < 900
            ? 3
            : 4;

        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.xs,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: 0.72,
            crossAxisSpacing: AppSpacing.md,
            mainAxisSpacing: AppSpacing.md,
          ),
          itemCount: products.length,
          itemBuilder: (context, index) {
            final product = products[index];
            final qtyInCart = _cart[product.id] ?? 0.0;
            final isLowStock = provider.lowStockProducts.any(
              (p) => p.id == product.id,
            );
            return _buildProductCard(
              context,
              provider,
              product,
              qtyInCart,
              isLowStock,
            );
          },
        );
      },
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    BusinessProvider provider,
    Product product,
    double qty,
    bool isLowStock,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final state = _stockState(product, isLowStock);
    final inCart = qty > 0;

    final String formattedStock = _formatQty(product.currentStock);
    final String formattedQty = _formatQty(qty);

    final Color accent = AppColors.primary;
    final Color surface = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final Color borderColor = inCart
        ? accent
        : (isDark ? AppColors.borderDark : AppColors.borderLight);
    final Color nameColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final Color stockColor = switch (state) {
      _StockState.out => AppColors.error,
      _StockState.low => AppColors.warning,
      _StockState.normal => secondaryColor,
    };

    final String nameInitial = product.name.trim().isEmpty
        ? '?'
        : product.name.trim().substring(0, 1).toUpperCase();

    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: borderColor, width: inCart ? 1.6 : 1),
        boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
      ),
      child: Material(
        color: AppColors.transparent,
        child: InkWell(
          borderRadius: AppRadius.radiusLg,
          onTap: () => _addProductToCart(product),
          // Pulsación larga: escribir la cantidad exacta (ej. 50 uds) sin
          // tener que tocar el producto varias veces.
          onLongPress: () => _showWeightDialog(product),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Text(
                        nameInitial,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (state == _StockState.out)
                      _stockBadge(
                        context.t('product_stock_out'),
                        AppColors.error,
                        isDark,
                      )
                    else if (state == _StockState.low)
                      _stockBadge(
                        context.t('product_stock_low'),
                        AppColors.warning,
                        isDark,
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: nameColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  '\$${product.salePrice.toFormattedString(2)} ${product.currency}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${context.t('pos_stock')}: $formattedStock ${product.unit}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: stockColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                if (inCart) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _qtyStepper(
                    product: product,
                    qty: qty,
                    label: '$formattedQty ${product.unit}',
                    accent: accent,
                    isDark: isDark,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _stockBadge(String label, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.22 : 0.14),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _qtyStepper({
    required Product product,
    required double qty,
    required String label,
    required Color accent,
    required bool isDark,
    void Function(VoidCallback)? apply,
  }) {
    void run(VoidCallback fn) {
      if (apply != null) {
        apply(fn);
      } else {
        setState(fn);
      }
    }

    return Container(
      height: 34,
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: AppRadius.radiusSm,
      ),
      child: Row(
        children: [
          _stepperButton(
            icon: Icons.remove_rounded,
            onTap: () => run(() => _decrementFromCart(product)),
          ),
          Expanded(
            child: InkWell(
              onTap: () {
                if (apply != null) {
                  _showWeightDialog(product, apply: apply);
                } else {
                  _showWeightDialog(product);
                }
              },
              borderRadius: AppRadius.radiusSm,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(Icons.edit_rounded, size: 12, color: accent),
                  ],
                ),
              ),
            ),
          ),
          _stepperButton(
            icon: Icons.add_rounded,
            onTap: () => run(() => _addProductToCart(product)),
          ),
        ],
      ),
    );
  }

  Widget _stepperButton({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: AppColors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusSm,
        child: SizedBox(width: 38, height: 34, child: Icon(icon, size: 18)),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BARRA DE CARRITO
  // ---------------------------------------------------------------------------

  Widget _buildCartBar(
    BuildContext context,
    BusinessProvider provider,
    double total,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppRadius.xxl),
        ),
        boxShadow: isDark ? AppShadows.darkCard : AppShadows.card,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  borderRadius: AppRadius.radiusMd,
                  onTap: () => _showCartSheet(context, provider),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$_cartItemCount ${context.t('pos_items')}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: secondaryColor),
                        ),
                        Text(
                          '\$${total.toFormattedString(2)} ${_currency(provider)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? AppColors.primary
                                : AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              CashButton(
                label: context.t('checkout'),
                icon: const Icon(
                  Icons.shopping_cart_checkout_rounded,
                  size: 18,
                ),
                fullWidth: false,
                onPressed: () => _showCheckoutDialog(context, provider, total),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CARRITO (BOTTOM SHEET)
  // ---------------------------------------------------------------------------

  void _showCartSheet(BuildContext context, BusinessProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.transparent,
      barrierColor: AppColors.black.withValues(alpha: 0.45),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final entries = _cart.entries.toList();
            final total = _calculateTotal(provider);

            void apply(VoidCallback fn) {
              setState(fn);
              setModalState(() {});
            }

            return CashBottomSheet(
              title: context.t('pos_cart_title'),
              subtitle:
                  '$_cartItemCount ${context.t('pos_items')} • \$${total.toFormattedString(2)} ${_currency(provider)}',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (entries.isEmpty)
                    CashEmptyState(
                      icon: Icons.shopping_bag_outlined,
                      title: context.t('pos_cart_empty'),
                      message: context.t('pos_cart_empty_desc'),
                    )
                  else
                    ...entries.map((entry) {
                      final product = _findProduct(provider, entry.key);
                      if (product == null) {
                        return const SizedBox.shrink();
                      }
                      final qty = entry.value;
                      return _buildCartLine(
                        context,
                        provider,
                        product,
                        qty,
                        apply,
                      );
                    }),
                  if (entries.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.sm),
                    Divider(color: Theme.of(context).dividerColor, height: 1),
                    const SizedBox(height: AppSpacing.md),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            context.t('pos_total_to_pay'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Flexible(
                          child: Text(
                            '\$${total.toFormattedString(2)} ${_currency(provider)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    CashButton(
                      label: context.t('checkout'),
                      icon: const Icon(
                        Icons.shopping_cart_checkout_rounded,
                        size: 18,
                      ),
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        _showCheckoutDialog(context, provider, total);
                      },
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCartLine(
    BuildContext context,
    BusinessProvider provider,
    Product product,
    double qty,
    void Function(VoidCallback) apply,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final accent = AppColors.primary;
    final lineTotal = product.salePrice * qty;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Theme.of(context).dividerColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: nameColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '\$${lineTotal.toFormattedString(2)}',
                style: TextStyle(
                  color: nameColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              SizedBox(
                width: 122,
                child: _qtyStepper(
                  product: product,
                  qty: qty,
                  label: '${_formatQty(qty)} ${product.unit}',
                  accent: accent,
                  isDark: isDark,
                  apply: apply,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  '\$${product.salePrice.toFormattedString(2)} / ${product.unit}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: secondaryColor),
                ),
              ),
              CashIconButton(
                icon: Icons.delete_outline_rounded,
                tooltip: context.t('pos_remove_from_cart'),
                size: 38,
                iconSize: 18,
                iconColor: AppColors.error,
                onPressed: () => apply(() => _cart.remove(product.id)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LÓGICA DE CARRITO (sin cambios funcionales)
  // ---------------------------------------------------------------------------

  void _addProductToCart(Product product) {
    if (product.unit == 'uds') {
      final currentQty = _cart[product.id] ?? 0.0;
      if (product.currentStock > currentQty) {
        setState(() {
          _cart[product.id] = currentQty + 1.0;
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.t('pos_no_stock').replaceAll('{name}', product.name),
            ),
            backgroundColor: AppColors.warning,
          ),
        );
      }
    } else {
      _showWeightDialog(product);
    }
  }

  void _decrementFromCart(Product product) {
    final currentQty = _cart[product.id] ?? 0.0;
    if (product.unit == 'uds') {
      setState(() {
        if (currentQty > 1) {
          _cart[product.id] = currentQty - 1;
        } else {
          _cart.remove(product.id);
        }
      });
    } else {
      // Basado en peso: abrir el diálogo para editar la cantidad.
      _showWeightDialog(product);
    }
  }

  void _showWeightDialog(
    Product product, {
    void Function(VoidCallback)? apply,
  }) {
    void applyChange(VoidCallback fn) {
      if (apply != null) {
        apply(fn);
      } else {
        setState(fn);
      }
    }

    final currentQty = _cart[product.id] ?? 0.0;
    final bool isUnits = product.unit == 'uds';
    final ctrl = TextEditingController(
      text: currentQty > 0.0
          ? (currentQty % 1 == 0
                ? currentQty.toInt().toString()
                : currentQty.toString())
          : (isUnits ? '1' : '1.0'),
    );
    final String stockLabel = _formatQty(product.currentStock);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        title: Text(
          context
              .t('pos_weight_dialog_title')
              .replaceAll('{name}', product.name),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context
                  .t('pos_measure_label')
                  .replaceAll('{unit}', product.unit)
                  .replaceAll('{stock}', stockLabel),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            CashInput(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              label: context
                  .t('pos_qty_label')
                  .replaceAll('{unit}', product.unit),
              suffix: Text(
                product.unit,
                style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        actions: [
          if (currentQty > 0.0)
            TextButton(
              onPressed: () {
                applyChange(() {
                  _cart.remove(product.id);
                });
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: Text(context.t('pos_remove_from_cart')),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: context.t('accept'),
            fullWidth: false,
            height: 44,
            onPressed: () {
              final qty = double.tryParse(ctrl.text);
              if (qty == null || qty <= 0.0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('pos_valid_qty'))),
                );
                return;
              }
              // Los productos por unidades se venden en cantidades enteras.
              if (isUnits && qty % 1 != 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('pos_valid_qty'))),
                );
                return;
              }
              if (product.currentStock < qty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      context
                          .t('pos_insufficient_stock')
                          .replaceAll('{stock}', stockLabel)
                          .replaceAll('{unit}', product.unit),
                    ),
                  ),
                );
                return;
              }
              applyChange(() {
                _cart[product.id] = qty;
              });
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  double _calculateTotal(BusinessProvider provider) {
    double total = 0;
    _cart.forEach((id, qty) {
      final product = _findProduct(provider, id);
      if (product != null) {
        total += product.salePrice * qty;
      }
    });
    return total;
  }

  Future<void> _startContinuousScanning(BusinessProvider provider) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BarcodeScannerScreen(
          continuous: true,
          onScan: (code) {
            final product = _findProductBySku(provider, code);
            if (product != null) {
              _addProductToCart(product);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    context
                        .t('pos_product_not_found')
                        .replaceAll('{code}', code),
                  ),
                  backgroundColor: AppColors.warning,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Product? _findProductBySku(BusinessProvider provider, String code) {
    for (final p in provider.products) {
      if (p.sku.toLowerCase() == code.toLowerCase().trim()) return p;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // CHECKOUT
  // ---------------------------------------------------------------------------

  void _showCheckoutDialog(
    BuildContext context,
    BusinessProvider provider,
    double initialTotal,
  ) {
    String paymentMethod = 'Efectivo';
    String status = 'paid';
    double discount = 0.0;
    bool processing = false;
    final discountCtrl = TextEditingController();
    String currentClientName = '';
    Seller? selectedSeller;
    final String currency = _currency(provider);

    final clientNames = provider.sales
        .map((s) => s.clientName)
        .where((name) => name != null && name.trim().isNotEmpty)
        .cast<String>()
        .toSet()
        .toList();

    final activeSellers = provider.sellers.where((s) => s.isActive).toList();

    // Sólo mostrar el selector de vendedor si algún producto del carrito tiene
    // inventario asignado a un vendedor.
    final cartHasSellerInventory = _cart.keys.any(
      (pid) => provider.sellerInventory.any(
        (si) => si.productId == pid && si.assignedQuantity > 0,
      ),
    );
    final showSellerSelector =
        activeSellers.isNotEmpty && cartHasSellerInventory;

    final methods = <Map<String, Object>>[
      {
        'value': 'Efectivo',
        'key': 'pos_pay_cash',
        'icon': Icons.payments_outlined,
      },
      {
        'value': 'Tarjeta',
        'key': 'pos_pay_card',
        'icon': Icons.credit_card_rounded,
      },
      {
        'value': 'Transferencia',
        'key': 'pos_pay_transfer',
        'icon': Icons.swap_horiz_rounded,
      },
      {
        'value': 'Crédito',
        'key': 'pos_pay_credit',
        'icon': Icons.schedule_rounded,
      },
    ];

    CashBottomSheet.show(
      context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setModalState) {
          final total = (initialTotal - discount) > 0
              ? (initialTotal - discount)
              : 0.0;

          return CashBottomSheet(
            title: context.t('confirm_sale'),
            subtitle: '\$${total.toFormattedString(2)} $currency',
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Método de pago (mismos valores persistidos)
                Text(
                  context.t('pos_payment_method'),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: methods.map((m) {
                    final value = m['value'] as String;
                    return CashChip(
                      label: context.t(m['key'] as String),
                      icon: m['icon'] as IconData,
                      selected: paymentMethod == value,
                      onTap: () {
                        setModalState(() {
                          paymentMethod = value;
                          status = paymentMethod == 'Crédito'
                              ? 'pending'
                              : 'paid';
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Descuento
                CashInput(
                  controller: discountCtrl,
                  label: context
                      .t('pos_discount')
                      .replaceAll('{currency}', currency),
                  prefix: const Icon(Icons.money_off_rounded),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (val) {
                    setModalState(() {
                      discount = double.tryParse(val) ?? 0.0;
                    });
                  },
                ),
                const SizedBox(height: AppSpacing.md),

                // Cliente
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    currentClientName = textEditingValue.text;
                    if (textEditingValue.text.isEmpty) {
                      return const Iterable<String>.empty();
                    }
                    return clientNames.where((String option) {
                      return option.toLowerCase().contains(
                        textEditingValue.text.toLowerCase(),
                      );
                    });
                  },
                  onSelected: (String selection) {
                    currentClientName = selection;
                  },
                  fieldViewBuilder:
                      (context, controller, focusNode, onFieldSubmitted) {
                        return CashInput(
                          controller: controller,
                          focusNode: focusNode,
                          label: context.t('pos_client_name'),
                          prefix: const Icon(Icons.person_outline_rounded),
                          onChanged: (val) {
                            currentClientName = val;
                          },
                        );
                      },
                ),
                const SizedBox(height: AppSpacing.md),

                // Vendedor (sólo si aplica)
                if (showSellerSelector)
                  DropdownButtonFormField<String?>(
                    decoration: InputDecoration(
                      labelText: context.t('pos_seller_label'),
                      prefixIcon: const Icon(Icons.badge_outlined),
                    ),
                    initialValue: selectedSeller?.id,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(context.t('pos_no_seller')),
                      ),
                      ...activeSellers.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.fullName),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedSeller = val != null
                            ? activeSellers.firstWhere((s) => s.id == val)
                            : null;
                      });
                    },
                  ),
                if (showSellerSelector) const SizedBox(height: AppSpacing.lg),

                // Resumen económico
                _checkoutSummaryRow(
                  context,
                  context.t('pos_subtotal'),
                  '\$${initialTotal.toFormattedString(2)} $currency',
                  Theme.of(context).textTheme.bodyMedium?.color ??
                      AppColors.textSecondary,
                ),
                if (discount > 0) ...[
                  const SizedBox(height: AppSpacing.xs),
                  _checkoutSummaryRow(
                    context,
                    context.t('sale_discount_label'),
                    '-\$${discount.toFormattedString(2)} $currency',
                    AppColors.error,
                  ),
                ],
                const SizedBox(height: AppSpacing.sm),
                Divider(color: Theme.of(context).dividerColor, height: 1),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        context.t('pos_total_to_pay'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        '\$${total.toFormattedString(2)} $currency',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: status == 'pending'
                              ? AppColors.warning
                              : AppColors.income,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),

                // Confirmar (anti doble toque + no éxito antes de completar)
                CashButton(
                  label: status == 'pending'
                      ? context.t('pos_confirm_credit')
                      : context.t('confirm_sale'),
                  loading: processing,
                  onPressed: () async {
                    if (processing) return;
                    if (paymentMethod == 'Crédito' &&
                        currentClientName.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.t('pos_credit_requires_client'),
                          ),
                        ),
                      );
                      return;
                    }

                    setModalState(() => processing = true);

                    final navigator = Navigator.of(context);
                    final sheetRoute = ModalRoute.of(context);
                    final messenger = ScaffoldMessenger.of(context);
                    final successMessage = context.t('sale_success');
                    final errorMessage = context.t('sale_error_default');

                    final ok = await _processSale(
                      provider,
                      discount: discount,
                      clientName: currentClientName.trim(),
                      paymentMethod: paymentMethod,
                      status: status,
                      sellerId: selectedSeller?.id,
                      sellerName: selectedSeller?.fullName,
                    );

                    if (!mounted) return;

                    if (ok) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(successMessage),
                          backgroundColor: AppColors.income,
                        ),
                      );
                      // Cerrar el sheet si sigue abierto (pudo descartarse
                      // mientras se procesaba la venta) y luego cerrar el POS.
                      if (sheetRoute == null || sheetRoute.isCurrent) {
                        navigator.pop();
                      }
                      navigator.pop(); // Cerrar el POS
                    } else {
                      setModalState(() => processing = false);
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(errorMessage),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _checkoutSummaryRow(
    BuildContext context,
    String label,
    String value,
    Color valueColor,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.end,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  /// Registra la venta. Devuelve `true` si la operación se completó.
  ///
  /// Se conserva exactamente la construcción de [SaleItem] y la llamada a
  /// [BusinessProvider.addSale]; sólo se espera a que termine para no mostrar
  /// un éxito antes de que la venta esté realmente persistida.
  Future<bool> _processSale(
    BusinessProvider provider, {
    required double discount,
    required String clientName,
    required String paymentMethod,
    required String status,
    String? sellerId,
    String? sellerName,
  }) async {
    final List<SaleItem> items = [];
    _cart.forEach((id, qty) {
      final product = _findProduct(provider, id);
      if (product == null) return;
      items.add(
        SaleItem(
          productId: id,
          productName: product.name,
          quantity: qty,
          unitPrice: product.salePrice,
          subtotal: product.salePrice * qty,
        ),
      );
    });

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    try {
      await provider.addSale(
        items: items,
        paymentMethod: paymentMethod,
        discount: discount,
        clientName: clientName.isEmpty ? null : clientName,
        status: status,
        sellerId: sellerId,
        sellerName: sellerName,
        appProvider: appProvider,
      );
      return true;
    } catch (_) {
      return false;
    }
  }
}
