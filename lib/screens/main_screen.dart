import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import '../widgets/add_transaction_modal.dart';
import '../services/localization_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  // Tour GlobalKeys
  final GlobalKey _fabKey = GlobalKey();
  final GlobalKey _navBarKey = GlobalKey();

  late TutorialCoachMark tutorialCoachMark;
  List<TargetFocus> targets = [];

  final List<Widget> _screens = const [
    HomeScreen(),
    WalletScreen(),
    StatsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstSeen();
    });
  }

  Future<void> _checkFirstSeen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool seen = prefs.getBool('seenFeatureTour') ?? false;
    if (!seen) {
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) {
        _showTutorial();
        await prefs.setBool('seenFeatureTour', true);
      }
    }
  }

  void _showTutorial() {
    _initTargets();
    tutorialCoachMark = TutorialCoachMark(
      targets: targets,
      colorShadow: Theme.of(context).colorScheme.primary.withOpacity(0.8),
      textSkip: "SALTAR",
      paddingFocus: 10,
      opacityShadow: 0.8,
      onFinish: () {
        print("Tour finished");
      },
      onClickTarget: (target) {
        print('Clicked: $target');
      },
      onSkip: () {
        print("Tour skipped");
        return true;
      },
    )..show(context: context);
  }

  void _initTargets() {
    targets.clear();

    // 1. FAB - Add Transaction
    targets.add(
      TargetFocus(
        identify: "fabKey",
        keyTarget: _fabKey,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTourContent(
                context.t('tour_fab_title'),
                context.t('tour_fab_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 2. Bottom Navigation
    targets.add(
      TargetFocus(
        identify: "navBarKey",
        keyTarget: _navBarKey,
        shape: ShapeLightFocus.RRect,
        radius: 5,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTourContent(
                context.t('tour_navbar_title'),
                context.t('tour_navbar_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 3. Navigate to Wallet tab
    targets.add(
      TargetFocus(
        identify: "walletTab",
        keyTarget: _navBarKey,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Auto-navigate to Wallet
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _currentIndex = 1;
                  });
                }
              });
              return _buildTourContent(
                context.t('tour_wallet_nav_title'),
                context.t('tour_wallet_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 4. Navigate to Stats tab
    targets.add(
      TargetFocus(
        identify: "statsTab",
        keyTarget: _navBarKey,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Auto-navigate to Stats
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _currentIndex = 2;
                  });
                }
              });
              return _buildTourContent(
                context.t('tour_stats_nav_title'),
                context.t('tour_stats_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 5. Navigate to Settings tab
    targets.add(
      TargetFocus(
        identify: "settingsTab",
        keyTarget: _navBarKey,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Auto-navigate to Settings
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _currentIndex = 3;
                  });
                }
              });
              return _buildTourContent(
                context.t('tour_settings_nav_title'),
                context.t('tour_settings_nav_desc'),
              );
            },
          ),
        ],
      ),
    );

    // 6. Final step - Return to Home
    targets.add(
      TargetFocus(
        identify: "finalStep",
        keyTarget: _navBarKey,
        shape: ShapeLightFocus.RRect,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              // Return to Home
              Future.delayed(const Duration(milliseconds: 300), () {
                if (mounted) {
                  setState(() {
                    _currentIndex = 0;
                  });
                }
              });
              return _buildTourContent(
                "¡Tour Completado!",
                "Has explorado todas las funciones principales de CashRapido. ¡Comienza a gestionar tus finanzas!",
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTourContent(String title, String description) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 20,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: GoogleFonts.outfit(color: Colors.white, fontSize: 14),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        body: IndexedStack(index: _currentIndex, children: _screens),
        floatingActionButton: FloatingActionButton(
          key: _fabKey,
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
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: NavigationBarTheme(
          key: _navBarKey,
          data: NavigationBarThemeData(
            indicatorColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.2),
            labelTextStyle: WidgetStateProperty.all(
              GoogleFonts.outfit(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            iconTheme: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return IconThemeData(
                  color: Theme.of(context).colorScheme.primary,
                );
              }
              return IconThemeData(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              );
            }),
          ),
          child: NavigationBar(
            height: 70,
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            elevation: 0,
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) =>
                setState(() => _currentIndex = index),
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.grid_view),
                selectedIcon: const Icon(Icons.grid_view),
                label: context.t('nav_home'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.credit_card),
                selectedIcon: const Icon(Icons.credit_card),
                label: context.t('nav_wallet'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.pie_chart_outline),
                selectedIcon: const Icon(Icons.pie_chart),
                label: context.t('statistics'),
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined),
                selectedIcon: const Icon(Icons.settings),
                label: context.t('settings_title'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
