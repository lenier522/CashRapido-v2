import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../services/tour_service.dart';
import '../services/feedback_service.dart';
import '../utils/tour_keys.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../widgets/design/cash_button.dart';
import 'ai_chat_screen.dart';
import 'all_transactions_screen.dart';
import 'home_screen.dart';
import 'profile/profile_screen.dart';
import 'stats_screen.dart';

/// Pestañas del [MainScreen].
///
/// El orden sigue a la navegación conceptual de la app:
/// Inicio, Movimientos, Análisis y Perfil. La acción principal ("+") no es una
/// pestaña, ocupa el slot central de la barra.
///
/// La pestaña de Movimientos reutiliza la pantalla de historial completo
/// (`AllTransactionsScreen`), ampliada con selector de período y resumen
/// financiero. La Billetera sigue existiendo y se abre desde las acciones
/// rápidas de Inicio (acción "Balances").
enum MainTab { home, movements, stats, more }

/// Solicitud global de cambio de pestaña.
///
/// La usa el catálogo de «Funciones Principales» (y cualquier pantalla abierta
/// fuera de la barra inferior) para volver a una pestaña concreta de
/// [MainScreen]: la pantalla hace `popUntil` hasta la raíz y publica aquí la
/// pestaña deseada.
final ValueNotifier<MainTab?> mainTabRequest = ValueNotifier<MainTab?>(null);

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  MainTab _currentTab = MainTab.home;

  /// Destinos del tour: la acción principal y la barra de navegación.
  final GlobalKey _primaryActionKey = GlobalKey();
  final GlobalKey _navBarKey = GlobalKey();

  /// Se conserva el IndexedStack para no reconstruir las pestañas y mantener
  /// el estado de scroll y selección de cada una.
  static const List<Widget> _screens = <Widget>[
    HomeScreen(),
    AllTransactionsScreen(),
    StatsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    mainTabRequest.addListener(_onTabRequested);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkFirstSeen();
      FeedbackService.checkAndShowFeedback(context);
    });
  }

  @override
  void dispose() {
    mainTabRequest.removeListener(_onTabRequested);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Atiende las peticiones de cambio de pestaña hechas desde pantallas
  /// secundarias (por ejemplo, el catálogo de Funciones Principales).
  void _onTabRequested() {
    final MainTab? tab = mainTabRequest.value;
    if (!mounted || tab == null) return;
    mainTabRequest.value = null;
    _selectTab(tab);
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
          fabKey: _primaryActionKey,
          navBarKey: _navBarKey,
          onNavigate: (index) => _selectTourDestination(index),
        ).show();
        await prefs.setBool('seenFeatureTour', true);
      }
    }
  }

  /// El tour navega por índice de pestaña (0 Inicio, 1 Finanzas,
  /// 2 Análisis, 3 Perfil).
  void _selectTourDestination(int index) {
    if (!mounted || index < 0 || index >= MainTab.values.length) {
      return;
    }
    setState(() => _currentTab = MainTab.values[index]);
  }

  void _selectTab(MainTab tab) {
    if (tab == _currentTab) {
      return;
    }
    setState(() => _currentTab = tab);
  }

  void _openAiChat() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (!provider.aiChatEnabled) {
      _showFeatureLocked();
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AIChatScreen()),
    );
  }

  void _showFeatureLocked() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(Icons.lock_outline, color: AppColors.warning),
        title: Text(context.t('feature_locked_title')),
        content: Text(context.t('feature_locked_desc')),
        actions: [
          CashButton(
            label: context.t('close'),
            fullWidth: false,
            height: 44,
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    // Con el teclado abierto la barra se mantiene en su sitio y la acción
    // principal se oculta para no quedar detrás del teclado.
    final bool isKeyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: theme.scaffoldBackgroundColor,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,

        // Cada pantalla interna ya aplica su propio inset de teclado, así que
        // la barra no debe saltar hacia arriba.
        resizeToAvoidBottomInset: false,

        body: IndexedStack(index: _currentTab.index, children: _screens),

        bottomNavigationBar: _MainNavigationBar(
          navBarKey: _navBarKey,
          primaryActionKey: _primaryActionKey,
          currentTab: _currentTab,
          showPrimaryAction: !isKeyboardVisible,
          onTabSelected: _selectTab,
          onPrimaryAction: _openAiChat,
        ),
      ),
    );
  }
}

/// Barra de navegación principal con acción central destacada.
///
/// Usa `NavigationBar` de Material 3 (por lo que hereda el
/// `navigationBarTheme` de `AppTheme`) y reserva el destino central para la
/// acción principal (IA), que se dibuja centrada dentro de la barra.
class _MainNavigationBar extends StatelessWidget {
  const _MainNavigationBar({
    required this.navBarKey,
    required this.primaryActionKey,
    required this.currentTab,
    required this.showPrimaryAction,
    required this.onTabSelected,
    required this.onPrimaryAction,
  });

  /// Diámetro del círculo interior del botón central.
  static const double _actionDiameter = 52;

  /// Grosor del anillo que separa el botón de la barra.
  static const double _actionRing = 4;

  /// Mapa destino de la barra -> pestaña. El slot central queda reservado.
  static const List<MainTab?> _tabByDestination = <MainTab?>[
    MainTab.home,
    MainTab.movements,
    null,
    MainTab.stats,
    MainTab.more,
  ];

  final GlobalKey navBarKey;
  final GlobalKey primaryActionKey;
  final MainTab currentTab;
  final bool showPrimaryAction;
  final ValueChanged<MainTab> onTabSelected;
  final VoidCallback onPrimaryAction;

  @override
  Widget build(BuildContext context) {
    return Stack(
      key: navBarKey,
      alignment: Alignment.center,
      children: [
        NavigationBar(
          selectedIndex: _tabByDestination.indexOf(currentTab),
          onDestinationSelected: _handleDestinationSelected,
          destinations: _buildDestinations(context),
        ),
        const SizedBox.shrink(),
        if (showPrimaryAction)
          _PrimaryActionButton(key: primaryActionKey, onPressed: onPrimaryAction),
      ],
    );
  }

  void _handleDestinationSelected(int index) {
    final MainTab? tab = _tabByDestination[index];
    if (tab != null) {
      onTabSelected(tab);
    }
  }

  List<Widget> _buildDestinations(BuildContext context) {
    return [
      NavigationDestination(
        key: TourKeys.homeTabKey,
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home_rounded),
        label: context.t('nav_home'),
      ),
      NavigationDestination(
        key: TourKeys.movementsTabKey,
        icon: const Icon(Icons.receipt_long_outlined),
        selectedIcon: const Icon(Icons.receipt_long_rounded),
        label: context.t('nav_movements'),
      ),
      // Slot reservado: lo ocupa la acción principal (IA).
      const NavigationDestination(
        icon: SizedBox.shrink(),
        label: '',
        enabled: false,
      ),
      NavigationDestination(
        key: TourKeys.statsTabKey,
        icon: const Icon(Icons.insights_outlined),
        selectedIcon: const Icon(Icons.insights_rounded),
        label: context.t('statistics'),
      ),
      NavigationDestination(
        key: TourKeys.profileTabKey,
        icon: const Icon(Icons.person_outline_rounded),
        selectedIcon: const Icon(Icons.person_rounded),
        label: context.t('nav_profile'),
      ),
    ];
  }
}

/// Acción principal de la app: abrir la IA (Chat).
///
/// Botón circular con la marca CashRapido, separado de la barra por un anillo
/// del color de la superficie para que se lea en modo claro y oscuro.
class _PrimaryActionButton extends StatelessWidget {
  const _PrimaryActionButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surface,
        boxShadow: AppShadows.primaryButton,
      ),
      child: Padding(
        padding: const EdgeInsets.all(_MainNavigationBar._actionRing),
        child: Tooltip(
          message: context.t('tooltip_ai'),
          child: Material(
            color: theme.colorScheme.primary,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onPressed,
              child: SizedBox(
                height: _MainNavigationBar._actionDiameter,
                width: _MainNavigationBar._actionDiameter,
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  size: 28,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
