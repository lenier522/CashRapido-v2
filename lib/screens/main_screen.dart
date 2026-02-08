import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:animated_bottom_navigation_bar/animated_bottom_navigation_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import 'business/business_gatekeeper.dart';
import '../widgets/add_transaction_modal.dart'; // Re-needed for Add Transaction FAB
import '../services/tour_service.dart';
import '../services/feedback_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;

  // Tour GlobalKeys
  final GlobalKey _fabKey =
      GlobalKey(); // Refers to Business FAB now? Or Add FAB? Let's point to Business as it is primary nav.
  final GlobalKey _navBarKey = GlobalKey();

  // Screen Order: 0: Home, 1: Wallet, 2: Stats, 3: Settings. 4: Business.
  final List<Widget> _screens = const [
    HomeScreen(),
    WalletScreen(),
    StatsScreen(),
    SettingsScreen(),
    BusinessGatekeeper(), // Index 4
  ];

  // Icons for 4 tabs
  final List<IconData> _iconList = [
    Icons.grid_view,
    Icons.credit_card,
    Icons.pie_chart_outline,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstSeen();
      FeedbackService.checkAndShowFeedback(context);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      FeedbackService.checkAndShowFeedback(context);
    }
  }

  Future<void> _checkFirstSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seen = prefs.getBool('seenFeatureTour') ?? false;
    if (!seen) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        FeatureTour(
          context: context,
          fabKey: _fabKey,
          navBarKey: _navBarKey,
          onNavigate: (index) {
            if (mounted) {
              setState(() {
                _currentIndex = index;
              });
            }
          },
        ).show();
        await prefs.setBool('seenFeatureTour', true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // If currentIndex is 4 (Business), navbar index is -1 (none selected)
    final int barIndex = _currentIndex == 4 ? -1 : _currentIndex;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: Theme.of(context).scaffoldBackgroundColor,
        systemNavigationBarIconBrightness:
            Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,

        // Stack to allow Add Transaction FAB to overlay standard body
        body: Stack(
          children: [
            IndexedStack(index: _currentIndex, children: _screens),

            // "Add Transaction" Button - Positioned in Bottom Right ("Where it was")
            // Only show if NOT in Business Mode (Business has its own internal actions)
            if (_currentIndex != 4)
              Positioned(
                bottom:
                    30, // Adjust to avoid collision if needed, but endFloat is usually ~16-30
                right: 16,
                child: FloatingActionButton(
                  heroTag: "fab_add_transaction", // Unique Tag!
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => const AddTransactionModal(),
                    );
                  },
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  shape: const CircleBorder(),
                  child: const Icon(Icons.add, color: Colors.white),
                ),
              ),
          ],
        ),

        // Central FAB - "Business" ("Negocio en el medio con floating bottom")
        floatingActionButton: FloatingActionButton(
          key: _fabKey,
          heroTag: "fab_business_center", // Unique Tag!
          onPressed: () {
            setState(() {
              _currentIndex = 4; // open Business
            });
          },
          backgroundColor: _currentIndex == 4
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).cardColor,
          shape: const CircleBorder(),
          // Use elevation to define "Floating" feel
          elevation: 8,
          child: Icon(
            Icons.business_center,
            color: _currentIndex == 4
                ? Colors.white
                : Theme.of(context).colorScheme.primary,
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

        bottomNavigationBar: AnimatedBottomNavigationBar(
          icons: _iconList,
          activeIndex: barIndex,
          gapLocation: GapLocation.center,
          notchSmoothness: NotchSmoothness.softEdge,
          leftCornerRadius: 32,
          rightCornerRadius: 32,
          onTap: (index) => setState(() {
            _currentIndex = index;
          }),
          backgroundColor: Theme.of(context).cardColor,
          activeColor: Theme.of(context).colorScheme.primary,
          inactiveColor: Colors.grey,
          iconSize: 28,
        ),
      ),
    );
  }
}
