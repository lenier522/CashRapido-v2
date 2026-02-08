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
import 'pos_screen.dart'; // Added for direct access

class BusinessDetailScreen extends StatefulWidget {
  final Business business;

  const BusinessDetailScreen({super.key, required this.business});

  @override
  State<BusinessDetailScreen> createState() => _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends State<BusinessDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      context.t('tab_closings'),
      context.t('tab_analytics'),
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
                  // Key Metrics
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: _buildMetricsRow(context, provider, color),
                  ),
                  const Divider(height: 1),
                  // Tab Content
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: const [
                        ProductsTab(),
                        SalesTab(),
                        ExpensesTab(),
                        ClosingsTab(),
                        AnalyticsTab(),
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
            '\$${provider.totalRevenue.toStringAsFixed(2)}',
            Icons.trending_up_rounded,
            Colors.green,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            context,
            context.t('metrics_expenses'),
            '\$${provider.totalExpenses.toStringAsFixed(2)}',
            Icons.trending_down_rounded,
            Colors.red,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            context,
            context.t('metrics_roi'),
            '${provider.overallROI.toStringAsFixed(1)}%',
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
