import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/business_provider.dart';
import '../../models/business.dart';
import '../../utils/business_icon_helper.dart';
import '../../services/localization_service.dart';
import 'package:flutter/services.dart';
import 'business_form_screen.dart'; // Import for navigation
import 'products_tab.dart';
import 'sales_tab.dart';
import 'expenses_tab.dart';
import 'closings_tab.dart';
import 'analytics_tab.dart';
import 'break_even_screen.dart';
import 'pos_screen.dart'; // Added for direct access
import 'sellers_tab.dart';
import '../../providers/app_provider.dart';
import '../../models/models.dart';
import 'package:cashrapido/utils/number_format_utils.dart';

class BusinessDetailScreen extends StatefulWidget {
  final Business business;

  const BusinessDetailScreen({super.key, required this.business});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  static const _sellerTypes = {'Retail', 'Restaurante', 'E-commerce'};

  bool get _hasSellers => _sellerTypes.contains(widget.business.type);

  @override
  void initState() {
    super.initState();
    final tabCount = _hasSellers ? 7 : 6;
    _tabController = TabController(length: tabCount, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Color(widget.business.colorValue);

    // Dynamic translation access
    final tabs = [
      context.t('tab_products'),
      context.t('tab_sales'),
      context.t('tab_expenses'),
      if (_hasSellers) context.t('tab_sellers'),
      context.t('tab_closings'),
      context.t('tab_analytics'),
      context.t('break_even_title'),
    ];

    return Scaffold(
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 220,
                pinned: true,
                backgroundColor: color,
                elevation: 0,
                // systemOverlayStyle removed here as AnnotatedRegion handles it
                iconTheme: const IconThemeData(
                  color: Colors.white,
                ), // Fix Back Button
                flexibleSpace: FlexibleSpaceBar(
                  titlePadding: const EdgeInsets.only(left: 16, bottom: 16),
                  title: Text(
                    widget.business.name,
                    style: GoogleFonts.outfit(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Main Gradient
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [color, color.withOpacity(0.7)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      // Glassmorphism Overlay Effect
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.1),
                              Colors.white.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                      // Icon Background
                      Center(
                        child: Icon(
                          BusinessIconHelper.getIcon(widget.business.iconCode),
                          size: 100,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(
                      Icons.point_of_sale_outlined,
                      color: Colors.white,
                    ),
                    tooltip: context.t('pos_title'),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PosScreen()),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.edit_outlined, // Changed icon to Edit for clarity
                      color: Colors.white,
                    ),
                    tooltip: context.t('business_edit_btn'),
                    onPressed: () {
                      // Navigate to Edit Business
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              BusinessFormScreen(business: widget.business),
                        ),
                      );
                    },
                  ),
                ],
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverAppBarDelegate(
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    labelColor: color,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: color,
                    indicatorWeight: 3,
                    labelStyle: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                    unselectedLabelStyle: GoogleFonts.outfit(),
                    tabs: tabs.map((t) => Tab(text: t)).toList(),
                  ),
                ),
              ),
            ];
          },
          body: Consumer<BusinessProvider>(
            builder: (context, provider, _) {
              return Column(
                children: [
                  // Key Metrics & Inventory Fund
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Column(
                      children: [
                        _buildInventoryFundCard(context, provider, color),
                        const SizedBox(height: 10),
                        _buildMetricsRow(context, provider, color),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        const ProductsTab(),
                        const SalesTab(),
                        const ExpensesTab(),
                        if (_hasSellers) const SellersTab(),
                        const ClosingsTab(),
                        const AnalyticsTab(),
                        const BreakEvenScreen(),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ), // Close NestedScrollView
      ), // Close AnnotatedRegion
    ); // Close Scaffold
  }

  Widget _buildMetricsRow(
    BuildContext context,
    BusinessProvider provider,
    Color color,
  ) {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            context,
            context.t('metrics_revenue'),
            '\$${provider.totalRevenue.toFormattedString(2)}',
            Icons.trending_up_rounded,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            context,
            context.t('metrics_expenses'),
            '\$${provider.totalExpenses.toFormattedString(2)}',
            Icons.trending_down_rounded,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            context,
            context.t('metrics_roi'),
            '${provider.overallROI.toFormattedString(1)}%',
            Icons.pie_chart_rounded,
            color,
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).textTheme.bodyLarge?.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryFundCard(
    BuildContext context,
    BusinessProvider provider,
    Color color,
  ) {
    final appProvider = Provider.of<AppProvider>(context);
    final currency = provider.activeBusiness?.currency ?? 'CUP';
    final initialCapital = provider.initialCapital;
    final purchases = provider.totalInventoryPurchases;
    final expenses = provider.totalExpenses;
    final sales = provider.totalSalesRevenue;
    final available = provider.availableInventoryBalance;
    final isPositive = available >= 0;

    AccountCard? linkedCard;
    if (provider.linkedCardId != null) {
      for (final c in appProvider.cards) {
        if (c.id == provider.linkedCardId) {
          linkedCard = c;
          break;
        }
      }
    }

    final cardLabel = linkedCard != null
        ? '${linkedCard.isCash ? linkedCard.name : (linkedCard.bankName ?? 'Tarjeta')} (...${linkedCard.isCash ? 'CASH' : (linkedCard.cardNumber.length >= 4 ? linkedCard.cardNumber.substring(linkedCard.cardNumber.length - 4) : linkedCard.cardNumber)})'
        : context.t('no_linked_account');

    final statusColor = isPositive ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: color.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.all_inclusive_rounded, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('inventory_fund_title'),
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          linkedCard != null ? Icons.credit_card : Icons.link_off,
                          size: 12,
                          color: linkedCard != null ? color : Colors.grey,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            cardLabel,
                            style: TextStyle(
                              fontSize: 11,
                              color: linkedCard != null
                                  ? (Theme.of(context).brightness == Brightness.dark
                                      ? Colors.grey.shade300
                                      : Colors.grey.shade700)
                                  : Colors.grey,
                              fontWeight: linkedCard != null ? FontWeight.w500 : FontWeight.normal,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              InkWell(
                onTap: () => _showAdjustCapitalDialog(context, provider, appProvider),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.tune_rounded, size: 14, color: color),
                      const SizedBox(width: 4),
                      Text(
                        'Ajustar',
                        style: GoogleFonts.outfit(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Main Balance Display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('available_balance'),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '\$${available.toFormattedString(2)} $currency',
                      style: GoogleFonts.outfit(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ],
                ),
                Icon(
                  isPositive ? Icons.check_circle_outline_rounded : Icons.warning_amber_rounded,
                  color: statusColor,
                  size: 26,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Mini breakdown row
          Row(
            children: [
              Expanded(
                child: _buildFundMetricPill(
                  context,
                  label: context.t('assigned_capital'),
                  value: '\$${initialCapital.toFormattedString(2)}',
                  color: Colors.indigo,
                  icon: Icons.savings_outlined,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildFundMetricPill(
                  context,
                  label: context.t('inventory_purchases'),
                  value: '-\$${purchases.toFormattedString(2)}',
                  color: Colors.orange.shade700,
                  icon: Icons.inventory_2_outlined,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildFundMetricPill(
                  context,
                  label: context.t('metrics_expenses'),
                  value: '-\$${expenses.toFormattedString(2)}',
                  color: Colors.red.shade700,
                  icon: Icons.receipt_long_outlined,
                ),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: _buildFundMetricPill(
                  context,
                  label: context.t('sales_revenue'),
                  value: '+\$${sales.toFormattedString(2)}',
                  color: Colors.green,
                  icon: Icons.point_of_sale_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFundMetricPill(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: GoogleFonts.outfit(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  void _showAdjustCapitalDialog(
    BuildContext context,
    BusinessProvider provider,
    AppProvider appProvider,
  ) {
    final activeBiz = provider.activeBusiness;
    if (activeBiz == null) return;

    final capitalController = TextEditingController(
      text: activeBiz.initialCapital > 0 ? activeBiz.initialCapital.toStringAsFixed(2) : '',
    );
    String? selectedCardId = activeBiz.linkedCardId;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.savings_outlined, color: Colors.green),
                      const SizedBox(width: 8),
                      Text(
                        context.t('edit_capital_title'),
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.t('initial_capital_desc'),
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: capitalController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: context.t('initial_capital'),
                      prefixText: '\$ ',
                      prefixIcon: const Icon(Icons.monetization_on_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String?>(
                    value: appProvider.cards.any((c) => c.id == selectedCardId)
                        ? selectedCardId
                        : null,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: context.t('linked_account'),
                      prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          context.t('no_linked_account'),
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ),
                      ...appProvider.cards.map((c) {
                        final last4 = c.isCash
                            ? 'EFECTIVO'
                            : (c.cardNumber.length >= 4
                                ? c.cardNumber.substring(c.cardNumber.length - 4)
                                : c.cardNumber);
                        return DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(
                            '${c.isCash ? c.name : (c.bankName ?? 'Tarjeta')} (...$last4) - ${c.currency}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }),
                    ],
                    onChanged: (val) {
                      setModalState(() {
                        selectedCardId = val;
                        if (val != null) {
                          final card = appProvider.cards.firstWhere((c) => c.id == val);
                          capitalController.text = card.balance.toStringAsFixed(2);
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final cap = double.tryParse(
                          capitalController.text.trim().replaceAll(',', '.'),
                        ) ?? 0.0;
                        String? newCurrency;
                        if (selectedCardId != null) {
                          final card = appProvider.cards.firstWhere((c) => c.id == selectedCardId);
                          newCurrency = card.currency;
                        }
                        await provider.updateBusinessCapital(
                          businessId: activeBiz.id,
                          initialCapital: cap,
                          linkedCardId: selectedCardId,
                          currency: newCurrency,
                          appProvider: appProvider,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Capital de inventario actualizado'),
                              backgroundColor: Colors.green,
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(activeBiz.colorValue),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        context.t('btn_save'),
                        style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height + 1; // +1 to fix potential layout issues
  @override
  double get maxExtent => _tabBar.preferredSize.height + 1;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
