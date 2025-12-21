import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'models/models.dart';
import 'providers/app_provider.dart';

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/localization_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await initializeDateFormatting('es', null);

  // Register Adapters
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(InternalTransactionAdapter());
  Hive.registerAdapter(AccountCardAdapter());

  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AppProvider()..init())],
      child: MyApp(seenOnboarding: seenOnboarding),
    ),
  );
}

class MyApp extends StatelessWidget {
  final bool seenOnboarding;

  const MyApp({super.key, required this.seenOnboarding});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, provider, _) {
        // Ensure we wait for init to load locale, otherwise might flash default
        return MaterialApp(
          title: 'CashRapido',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(),
            cardColor: Colors.white,
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Brightness.dark,
              surface: const Color(0xFF1E1E2C),
              onSurface: Colors.white,
              background: const Color(0xFF121212),
              secondary: const Color(0xFF2D2D44),
              primary: const Color(0xFFBB86FC), // Lighter purple for dark mode
            ),
            useMaterial3: true,
            textTheme: GoogleFonts.outfitTextTheme(
              ThemeData.dark().textTheme,
            ).apply(bodyColor: Colors.white, displayColor: Colors.white),
            scaffoldBackgroundColor: const Color(0xFF121212),
            cardColor: const Color(0xFF1E1E2C),
            canvasColor: const Color(0xFF1E1E2C),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.transparent,
              elevation: 0,
              iconTheme: IconThemeData(color: Colors.white),
              titleTextStyle: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            dividerColor: Colors.white10,
            dialogTheme: const DialogThemeData(
              backgroundColor: Color(0xFF1E1E2C),
            ),
            bottomNavigationBarTheme: const BottomNavigationBarThemeData(
              backgroundColor: Color(0xFF1E1E2C),
              selectedItemColor: Color(0xFFBB86FC),
              unselectedItemColor: Colors.white54,
              elevation: 10,
              type: BottomNavigationBarType.fixed,
            ),
          ),
          themeMode: provider.themeMode,
          // Localization
          locale: provider.currentLocale, // Can be null (system default) or set
          supportedLocales: const [Locale('es'), Locale('en'), Locale('fr')],
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AuthWrapper(seenOnboarding: seenOnboarding),
        );
      },
    );
  }
}

class AuthWrapper extends StatefulWidget {
  final bool seenOnboarding;
  const AuthWrapper({super.key, required this.seenOnboarding});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isAuthenticated = false;
  bool _isLoading = true;
  String _authMethod = ''; // 'biometric', 'pin', 'password', or ''
  final TextEditingController _pinController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkAuthentication();
  }

  Future<void> _checkAuthentication() async {
    final provider = Provider.of<AppProvider>(context, listen: false);

    // CRITICAL: Wait for provider to finish loading from SharedPreferences
    while (provider.isLoading) {
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Check what auth methods are enabled
    final bool biometricsEnabled = provider.biometricsEnabled;
    final bool hasPinSet = provider.hasPinSet;
    final bool hasPasswordSet = provider.hasPasswordSet;

    // If nothing is set, allow access
    if (!biometricsEnabled && !hasPinSet && !hasPasswordSet) {
      if (mounted) {
        setState(() {
          _isAuthenticated = true;
          _isLoading = false;
        });
      }
      return;
    }

    // Priority: Biometrics > PIN > Password
    if (biometricsEnabled) {
      bool authenticated = false;
      try {
        authenticated = await provider.authenticate();
      } catch (e) {
        // Biometric failed, fallback to PIN/Password
      }

      if (authenticated) {
        if (mounted) {
          setState(() {
            _isAuthenticated = true;
            _isLoading = false;
          });
        }
        return;
      }
    }

    // Show PIN or Password entry
    if (mounted) {
      setState(() {
        if (hasPinSet) {
          _authMethod = 'pin';
        } else if (hasPasswordSet) {
          _authMethod = 'password';
        }
        _isLoading = false;
      });
    }
  }

  void _validatePin() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.validatePin(_pinController.text)) {
      setState(() => _isAuthenticated = true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('PIN incorrecto')));
      _pinController.clear();
    }
  }

  void _validatePassword() {
    final provider = Provider.of<AppProvider>(context, listen: false);
    if (provider.validatePassword(_passwordController.text)) {
      setState(() => _isAuthenticated = true);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Contraseña incorrecta')));
      _passwordController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.deepPurple),
                const SizedBox(height: 24),
                Text(
                  "CashRapido Bloqueado",
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 32),

                // PIN Entry
                if (_authMethod == 'pin') ...[
                  TextField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: 'Ingresa tu PIN',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.pin),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    onSubmitted: (_) => _validatePin(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _validatePin,
                    icon: const Icon(Icons.lock_open),
                    label: const Text("Desbloquear"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],

                // Password Entry
                if (_authMethod == 'password') ...[
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Ingresa tu Contraseña',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.password),
                    ),
                    obscureText: true,
                    onSubmitted: (_) => _validatePassword(),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _validatePassword,
                    icon: const Icon(Icons.lock_open),
                    label: const Text("Desbloquear"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],

                // Biometric retry button
                if (Provider.of<AppProvider>(
                  context,
                  listen: false,
                ).biometricsEnabled) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: _checkAuthentication,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text("Usar Biometría"),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return widget.seenOnboarding
        ? const MainScreen()
        : const OnboardingScreen();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
