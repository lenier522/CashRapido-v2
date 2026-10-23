import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../models/seller.dart';
import '../../models/seller_inventory.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_input.dart';

/// Asignación de inventario a un vendedor.
///
/// Conserva la validación de stock autorizado, la eliminación de asignaciones
/// existentes y la persistencia del provider. Sólo mejora la presentación,
/// añade búsqueda local (sin tocar el modelo) y evita guardados duplicados
/// bloqueando el botón mientras la operación está en curso.
class SellerAssignProductsScreen extends StatefulWidget {
  final Seller seller;

  const SellerAssignProductsScreen({super.key, required this.seller});

  @override
  State<SellerAssignProductsScreen> createState() =>
      _SellerAssignProductsScreenState();
}

class _SellerAssignProductsScreenState
    extends State<SellerAssignProductsScreen> {
  final Map<String, TextEditingController> _controllers = {};
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _errorIds = {};
  final Set<String> _savingIds = {};

  String _searchQuery = '';

  @override
  void dispose() {
    for (final ctrl in _controllers.values) {
      ctrl.dispose();
    }
    _searchController.dispose();
    super.dispose();
  }

  String _formatQty(double qty) =>
      qty % 1 == 0 ? qty.toInt().toString() : qty.toStringAsFixed(2);

  double _parseQty(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.')) ?? 0.0;

  void _step(TextEditingController ctrl, String productId, double delta) {
    final current = _parseQty(ctrl.text);
    final next = current + delta;
    final value = next < 0 ? 0.0 : next;
    setState(() {
      _errorIds.remove(productId);
      ctrl.text = value <= 0 ? '' : _formatQty(value);
    });
  }

  Future<void> _saveAssignment(
    BusinessProvider provider,
    String productId,
    String productName,
    List<SellerInventory> assigned,
  ) async {
    if (_savingIds.contains(productId)) return;

    final ctrl = _controllers[productId];
    if (ctrl == null) return;
    final qty = _parseQty(ctrl.text);
    final maxAllowed = provider.getMaxAssignableToSeller(
      productId,
      widget.seller.id,
    );

    if (qty > maxAllowed) {
      setState(() => _errorIds.add(productId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context
                .t('seller_assign_exceeds')
                .replaceAll('{max}', _formatQty(maxAllowed)),
          ),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      ctrl.text = maxAllowed > 0 ? _formatQty(maxAllowed) : '';
      return;
    }

    setState(() {
      _savingIds.add(productId);
      _errorIds.remove(productId);
    });

    try {
      bool changed = false;
      if (qty > 0) {
        await provider.assignProductToSeller(
          sellerId: widget.seller.id,
          productId: productId,
          productName: productName,
          quantity: qty,
        );
        changed = true;
      } else {
        final existing = assigned.where((a) => a.productId == productId);
        if (existing.isNotEmpty) {
          await provider.removeProductFromSeller(existing.first.id);
          changed = true;
        }
      }

      if (!changed || !mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            qty > 0
                ? context
                      .t('seller_assign_success')
                      .replaceAll('{qty}', _formatQty(qty))
                      .replaceAll('{name}', widget.seller.fullName)
                : context.t('seller_assign_removed'),
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _savingIds.remove(productId));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final products = provider.products;

        if (products.isEmpty) {
          return Scaffold(
            appBar: _appBar(context),
            body: CashEmptyState(
              icon: Icons.inventory_2_outlined,
              title: context.t('seller_no_products_available'),
              message: 'Agrega productos al negocio para poder asignarlos.',
            ),
          );
        }

        final assigned = provider.getSellerInventoryBySeller(widget.seller.id);
        final assignedMap = {
          for (var a in assigned) a.productId: a.assignedQuantity,
        };

        // Se prepara un controlador por producto existente (evita perder la
        // cantidad asignada al reconstruir la pantalla).
        for (final p in products) {
          _controllers.putIfAbsent(
            p.id,
            () => TextEditingController(
              text: assignedMap[p.id] != null && assignedMap[p.id]! > 0
                  ? _formatQty(assignedMap[p.id]!)
                  : '',
            ),
          );
        }

        final query = _searchQuery.trim().toLowerCase();
        final filtered = query.isEmpty
            ? products
            : products
                  .where(
                    (p) =>
                        p.name.toLowerCase().contains(query) ||
                        p.sku.toLowerCase().contains(query),
                  )
                  .toList();

        return Scaffold(
          appBar: _appBar(context),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
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
              ),
              Expanded(
                child: filtered.isEmpty
                    ? CashEmptyState(
                        icon: Icons.search_off_rounded,
                        title: context.t('product_no_search_results'),
                        action: TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                          icon: const Icon(
                            Icons.filter_alt_off_rounded,
                            size: 18,
                          ),
                          label: Text(context.t('product_clear_filters')),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xxxl,
                        ),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final product = filtered[index];
                          return _buildProductCard(
                            context,
                            provider,
                            product,
                            assigned,
                            assignedMap,
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context) {
    return AppBar(
      title: Text(
        context
            .t('seller_assign_title')
            .replaceAll('{name}', widget.seller.fullName),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  Widget _buildProductCard(
    BuildContext context,
    BusinessProvider provider,
    Product product,
    List<SellerInventory> assigned,
    Map<String, double> assignedMap,
  ) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double assignedQty = assignedMap[product.id] ?? 0.0;
    final double totalAssigned = provider.getTotalAssignedQuantityForProduct(
      product.id,
    );
    final double maxAssignable = provider.getMaxAssignableToSeller(
      product.id,
      widget.seller.id,
    );
    final ctrl = _controllers[product.id]!;
    final hasError = _errorIds.contains(product.id);
    final isSaving = _savingIds.contains(product.id);
    final available = product.currentStock - totalAssigned;

    return CashCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.compactPadding),
      border: assignedQty > 0
          ? Border.all(
              color: AppColors.primary.withValues(alpha: 0.45),
              width: 1.2,
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (product.sku.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'SKU ${product.sku}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              if (assignedQty > 0)
                _MiniChip(
                  label:
                      '${_formatQty(assignedQty)}${product.unit.isNotEmpty ? ' ${product.unit}' : ''}',
                  color: AppColors.primary,
                  icon: Icons.check_circle_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              _MiniChip(
                label: context
                    .t('seller_assign_total_stock')
                    .replaceAll('{stock}', _formatQty(product.currentStock))
                    .replaceAll('{unit}', product.unit),
                color: AppColors.info,
                icon: Icons.inventory_2_outlined,
              ),
              _MiniChip(
                label: context
                    .t('seller_assign_available')
                    .replaceAll('{max}', _formatQty(maxAssignable))
                    .replaceAll('{unit}', product.unit),
                color: available <= 0 ? AppColors.warning : AppColors.income,
                icon: available <= 0
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: _QuantityControl(
                  controller: ctrl,
                  unit: product.unit,
                  onChanged: () {
                    if (_errorIds.contains(product.id)) {
                      setState(() => _errorIds.remove(product.id));
                    }
                  },
                  onDecrement: () => _step(ctrl, product.id, -1),
                  onIncrement: () => _step(ctrl, product.id, 1),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              IconButton.filled(
                onPressed: isSaving
                    ? null
                    : () => _saveAssignment(
                        provider,
                        product.id,
                        product.name,
                        assigned,
                      ),
                tooltip: context.t('seller_assign_save'),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded, size: 20),
              ),
            ],
          ),
          if (hasError) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 15,
                  color: AppColors.error,
                ),
                const SizedBox(width: AppSpacing.xs),
                Expanded(
                  child: Text(
                    context
                        .t('seller_assign_exceeds')
                        .replaceAll('{max}', _formatQty(maxAssignable)),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.error),
                  ),
                ),
              ],
            ),
          ],
          if (totalAssigned > 0) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              context
                  .t('seller_assign_distributed')
                  .replaceAll('{total}', _formatQty(totalAssigned))
                  .replaceAll('{stock}', _formatQty(product.currentStock))
                  .replaceAll('{unit}', product.unit),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark
                    ? AppColors.textTertiaryDark
                    : AppColors.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CONTROLES AUXILIARES
// ---------------------------------------------------------------------------

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;

  const _MiniChip({
    required this.label,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: AppSpacing.xxs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuantityControl extends StatelessWidget {
  final TextEditingController controller;
  final String unit;
  final VoidCallback onChanged;
  final VoidCallback onDecrement;
  final VoidCallback onIncrement;

  const _QuantityControl({
    required this.controller,
    required this.unit,
    required this.onChanged,
    required this.onDecrement,
    required this.onIncrement,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceVariantLight,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onDecrement,
            tooltip: 'Quitar',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.remove_rounded, size: 20),
          ),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: (_) => onChanged(),
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: '0',
                suffixText: unit,
              ),
            ),
          ),
          IconButton(
            onPressed: onIncrement,
            tooltip: 'Agregar',
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            icon: const Icon(Icons.add_rounded, size: 20),
          ),
        ],
      ),
    );
  }
}
