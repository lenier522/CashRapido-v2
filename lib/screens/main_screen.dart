import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'wallet_screen.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import '../widgets/add_transaction_modal.dart';
import '../services/localization_service.dart';
import '../services/tour_service.dart';

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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Theme.of(context).brightness == Brightness.dark
            ? Brightness.light
            : Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
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
            key: _navBarKey,
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
