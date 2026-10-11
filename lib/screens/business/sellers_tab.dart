import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/seller.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_chip.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_floating_button.dart';
import 'seller_assign_products_screen.dart';
import 'seller_detail_screen.dart';
import 'seller_form_screen.dart';

/// Administración de los vendedores del negocio.
///
/// Conserva todas las acciones existentes (detalle, asignar inventario, editar
/// y eliminar) y usa únicamente los datos reales del modelo [Seller].
class SellersTab extends StatelessWidget {
  const SellersTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final sellers = provider.sellers;

        if (sellers.isEmpty) {
          return Stack(
            children: [
              _buildEmptyState(context),
              Positioned(
                right: AppSpacing.lg,
                bottom: AppSpacing.lg,
                child: CashFloatingButton(
                  heroTag: 'add_seller',
                  icon: Icons.person_add_alt_1_rounded,
                  label: context.t('seller_new'),
                  onPressed: () => _openCreate(context),
                ),
              ),
            ],
          );
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                144,
              ),
              itemCount: sellers.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeader(context, sellers.length);
                }
                return _SellerCard(seller: sellers[index - 1]);
              },
            ),
            Positioned(
              right: AppSpacing.lg,
              bottom: AppSpacing.lg,
              child: CashFloatingButton(
                heroTag: 'add_seller',
                icon: Icons.person_add_alt_1_rounded,
                label: context.t('seller_new'),
                onPressed: () => _openCreate(context),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, int total) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t('tab_sellers'),
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
              total == 1 ? '1 vendedor' : '$total vendedores',
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

  Widget _buildEmptyState(BuildContext context) {
    return CashEmptyState(
      icon: Icons.badge_outlined,
      title: context.t('no_sellers'),
      message: context.t('no_sellers_desc'),
      buttonLabel: context.t('seller_new'),
      onButtonPressed: () => _openCreate(context),
    );
  }

  void _openCreate(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SellerFormScreen()),
    );
  }
}

// ---------------------------------------------------------------------------
// TARJETA DE VENDEDOR
// ---------------------------------------------------------------------------

class _SellerCard extends StatelessWidget {
  final Seller seller;

  const _SellerCard({required this.seller});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color color = _avatarColor(seller.fullName);
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final String initials = _initials(seller.name, seller.lastName);

    return CashCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.compactPadding),
      onTap: () => _openDetail(context),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.26 : 0.15),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        seller.fullName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    _StatusChip(isActive: seller.isActive),
                  ],
                ),
                if (seller.role.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Row(
                    children: [
                      Icon(Icons.work_outline_rounded, size: 13, color: secondary),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          seller.role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: secondary),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: [
                    Icon(Icons.phone_outlined, size: 13, color: secondary),
                    const SizedBox(width: AppSpacing.xs),
                    Expanded(
                      child: Text(
                        seller.phone.isEmpty ? '—' : seller.phone,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: secondary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildMenu(context),
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
      icon: Icon(Icons.more_vert_rounded, size: 20, color: secondary),
      constraints: const BoxConstraints(minWidth: 200),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
      onSelected: (value) {
        switch (value) {
          case 'report':
            _openDetail(context);
          case 'inventory':
            _openInventory(context);
          case 'edit':
            _openEdit(context);
          case 'delete':
            _confirmDelete(context);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'report',
          child: Row(
            children: [
              Icon(Icons.assessment_outlined, size: 20, color: secondary),
              const SizedBox(width: AppSpacing.md),
              Text(context.t('seller_view_report')),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'inventory',
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                size: 20,
                color: AppColors.info,
              ),
              const SizedBox(width: AppSpacing.md),
              Flexible(child: Text(context.t('seller_assign_products'))),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: secondary),
              const SizedBox(width: AppSpacing.md),
              Text(context.t('edit')),
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
                context.t('delete'),
                style: const TextStyle(color: AppColors.error),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SellerDetailScreen(seller: seller)),
    );
  }

  void _openInventory(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SellerAssignProductsScreen(seller: seller),
      ),
    );
  }

  void _openEdit(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SellerFormScreen(seller: seller)),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final confirmed = await showDialog<bool>(
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
                context.t('seller_delete'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        content: Text(
          context.t('seller_delete_confirm').replaceAll('{name}', seller.fullName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(context.t('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
            child: Text(context.t('delete')),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Provider.of<BusinessProvider>(context, listen: false).deleteSeller(seller.id);
    }
  }

  String _initials(String name, String lastName) {
    final first = name.isNotEmpty ? name[0].toUpperCase() : '';
    final second = lastName.isNotEmpty ? lastName[0].toUpperCase() : '';
    final result = '$first$second';
    return result.isEmpty ? '?' : result;
  }

  /// Color estable derivado del nombre (no aleatorio entre reconstrucciones).
  Color _avatarColor(String name) {
    if (name.isEmpty) return AppColors.primary;
    int hash = 0;
    for (final unit in name.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    final hue = (hash % 360).toDouble();
    return HSVColor.fromAHSV(1, hue, 0.45, 0.62).toColor();
  }
}

class _StatusChip extends StatelessWidget {
  final bool isActive;

  const _StatusChip({required this.isActive});

  @override
  Widget build(BuildContext context) {
    return CashChip(
      label: context.t(isActive ? 'seller_active' : 'seller_inactive'),
      icon: isActive
          ? Icons.check_circle_rounded
          : Icons.pause_circle_outline_rounded,
      selected: true,
      color: isActive ? AppColors.income : AppColors.textSecondary,
    );
  }
}
