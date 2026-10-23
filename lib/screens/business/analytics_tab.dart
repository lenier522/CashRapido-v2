import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../models/product.dart';
import '../../providers/business_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_section.dart';
import '../../widgets/design/cash_stat_card.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

/// Analítica del negocio.
///
/// Mantiene exactamente los mismos indicadores que la versión anterior
/// (`totalRevenue`, `totalExpenses`, `totalProfit`, `overallROI`,
/// `totalNetProfit`, `getBestSellingProducts` y `lowStockProducts`), pero
/// reorganizados por jerarquía: resultado principal, métricas secundarias y
/// desgloses. No se introduce ningún cálculo nuevo.
class AnalyticsTab extends StatelessWidget {
  const AnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<BusinessProvider>(
      builder: (context, provider, _) {
        final List<Map<String, dynamic>> bestSelling = provider
            .getBestSellingProducts(limit: 5);
        final List<Product> lowStock = provider.lowStockProducts;

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.screenVertical,
            AppSpacing.screenHorizontal,
            AppSpacing.huge,
          ),
          children: [
            CashSection(
              title: context.t('business_summary_title'),
              child: Column(
                children: [
                  _ResultHero(
                    grossProfit: provider.totalProfit,
                    income: provider.totalRevenue,
                    expenses: provider.totalExpenses,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  _SecondaryMetrics(
                    roi: provider.overallROI,
                    netProfit: provider.totalNetProfit,
                  ),
                ],
              ),
            ),
            if (bestSelling.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              CashSection(
                title: context.t('best_selling_products'),
                child: Column(
                  children: [
                    for (final item in bestSelling)
                      _ProductRow(
                        product: item['product'] as Product,
                        quantitySold: (item['quantitySold'] as num).toDouble(),
                        highlight: true,
                      ),
                  ],
                ),
              ),
            ],
            if (lowStock.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.xxl),
              CashSection(
                title: context.t('low_stock_title'),
                child: Column(
                  children: [
                    for (final product in lowStock)
                      _ProductRow(product: product, highlight: false),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Tarjeta principal: el resultado del negocio (beneficio bruto) con sus dos
/// componentes (ingresos y gastos) como contexto inmediato.
class _ResultHero extends StatelessWidget {
  final double grossProfit;
  final double income;
  final double expenses;

  const _ResultHero({
    required this.grossProfit,
    required this.income,
    required this.expenses,
  });

  @override
  Widget build(BuildContext context) {
    final bool positive = grossProfit >= 0;
    final LinearGradient gradient = positive
        ? AppColors.heroGradient
        : const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF0655F), Color(0xFFB93A34)],
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: AppRadius.radiusXl,
        boxShadow: positive ? AppShadows.primary : AppShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.t('gross_profit'),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.white.withValues(alpha: 0.85),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${grossProfit < 0 ? '-' : ''}\$${grossProfit.abs().toFormattedString(2)}',
              maxLines: 1,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppColors.white,
                fontWeight: FontWeight.w800,
                height: 1.0,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _HeroComponent(
                  icon: Icons.arrow_upward_rounded,
                  label: context.t('analytics_income'),
                  value: '\$${income.toFormattedString(2)}',
                ),
              ),
              Container(
                width: 1,
                height: 34,
                margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                color: AppColors.white.withValues(alpha: 0.25),
              ),
              Expanded(
                child: _HeroComponent(
                  icon: Icons.arrow_downward_rounded,
                  label: context.t('analytics_expense'),
                  value: '\$${expenses.toFormattedString(2)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroComponent extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeroComponent({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 15,
              color: AppColors.white.withValues(alpha: 0.85),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxs),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

/// Métricas secundarias: rentabilidad (ROI) y ganancia neta real. Se reparten
/// en dos columnas sólo cuando hay ancho suficiente para no recortar importes.
class _SecondaryMetrics extends StatelessWidget {
  final double roi;
  final double netProfit;

  const _SecondaryMetrics({required this.roi, required this.netProfit});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bool twoColumns = constraints.maxWidth >= 420;
        final double itemWidth = twoColumns
            ? (constraints.maxWidth - AppSpacing.md) / 2
            : constraints.maxWidth;

        return Wrap(
          spacing: AppSpacing.md,
          runSpacing: AppSpacing.md,
          children: [
            CashStatCard(
              width: itemWidth,
              icon: Icons.savings_outlined,
              iconColor: AppColors.primary,
              title: context.t('net_profit_real'),
              value:
                  '${netProfit < 0 ? '-' : ''}\$${netProfit.abs().toFormattedString(2)}',
            ),
            CashStatCard(
              width: itemWidth,
              icon: Icons.pie_chart_outline_rounded,
              iconColor: AppColors.purple,
              title: context.t('analytics_roi'),
              value: '${roi.toFormattedString(2)}%',
            ),
          ],
        );
      },
    );
  }
}

/// Fila de producto reutilizada para "más vendidos" y "stock bajo". El icono
/// cambia según la sección y el color acompaña, pero nunca es el único
/// indicador: la sección y la etiqueta de cantidad ya describen el estado.
class _ProductRow extends StatelessWidget {
  final Product product;
  final double? quantitySold;
  final bool highlight;

  const _ProductRow({
    required this.product,
    this.quantitySold,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    const Color accent = AppColors.warning;
    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    final String? subtitle;
    if (quantitySold != null) {
      final double qty = quantitySold!;
      final String qtyStr = qty % 1 == 0
          ? qty.toInt().toString()
          : qty.toFormattedString(2);
      subtitle = '$qtyStr ${context.t('sold_units')}';
    } else {
      subtitle = '${product.currentStock} ${context.t('stock_units')}';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: CashCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Icon(
                highlight ? Icons.star_rounded : Icons.warning_amber_rounded,
                size: 21,
                color: accent,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              '\$${product.salePrice.toFormattedString(2)}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
