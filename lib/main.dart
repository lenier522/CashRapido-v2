import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_screen.dart';
import 'models/models.dart';
import 'models/product.dart';
import 'models/business.dart';
import 'models/sale.dart';
import 'models/business_expense.dart';
import 'models/closing.dart';
import 'providers/app_provider.dart';
import 'dart:io' show Platform, Process;
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/localization_service.dart';

import 'providers/business_provider.dart';
import 'services/gemma_manager.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await GemmaManager.initialize();
  await Hive.initFlutter();
  await initializeDateFormatting('es', null);

  // Register Adapters
  Hive.registerAdapter(CategoryAdapter());
  Hive.registerAdapter(InternalTransactionAdapter());
  Hive.registerAdapter(AccountCardAdapter());
  Hive.registerAdapter(ProductAdapter());

  // Business Module Adapters
  Hive.registerAdapter(BusinessAdapter());
  Hive.registerAdapter(SaleAdapter());
  Hive.registerAdapter(SaleItemAdapter());
  Hive.registerAdapter(BusinessExpenseAdapter());
  Hive.registerAdapter(ClosingAdapter());

  final prefs = await SharedPreferences.getInstance();
  final bool seenOnboarding = prefs.getBool('seenOnboarding') ?? false;

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppProvider()..init()),
        ChangeNotifierProvider(create: (_) => BusinessProvider()..init()),
      ],
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
  final TextEditingController _activationCodeController =
      TextEditingController();

  // Hardware Lock State
  bool _isMacValid = true;
  bool _isDeviceAuthorized = true;
  bool _isCheckingMac = true;
  String? _hardwareLockError;

  // 1. MAC addresses authorized by the user for Windows clients
  final List<String> _allowedMacAddresses = [
    "6C-02-E0-C4-3B-C7".replaceAll(':', '-').toUpperCase(),
    "18-47-3D-86-5C-C9".replaceAll(':', '-').toUpperCase(),
    "18-47-3D-86-5C-CA".replaceAll(':', '-').toUpperCase(),
    // Add more MACs here...
  ];

  // 2. Predefined Activation Codes for manual unlocking
  final List<String> _validActivationCodes = [
    "CASH-W1ND-8XQ9",
    "RAPIDO-PC1-V2",
    "ADMIN-ROOT-X7",
    // Add more codes here...
  ];

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

    // --- HARDWARE LOCK FOR WINDOWS ---
    if (!kIsWeb && Platform.isWindows) {
      bool macMatch = false;
      try {
        final result = await Process.run('getmac', []);
        final String output = result.stdout.toString().toUpperCase().replaceAll(
          ':',
          '-',
        );

        // 1. Check if any of the allowed MACs exist in the getmac output
        for (String allowedMac in _allowedMacAddresses) {
          if (output.contains(allowedMac)) {
            macMatch = true;
            break;
          }
        }
      } catch (e) {
        debugPrint("Error reading MAC address: \$e");
        _hardwareLockError = e.toString();
      }

      // If MAC is not valid, hard block.
      if (!macMatch) {
        if (mounted) {
          setState(() {
            _isMacValid = false;
            _isCheckingMac = false;
            _isLoading = false;
          });
        }
        return;
      }

      // If MAC is valid, check if they have provided an activation code yet
      final prefs = await SharedPreferences.getInstance();
      final bool isManuallyActivated =
          prefs.getBool('windows_activated') ?? false;

      if (!isManuallyActivated) {
        if (mounted) {
          setState(() {
            _isDeviceAuthorized = false;
            _isCheckingMac = false;
            _isLoading = false;
          });
        }
        return; // Wait for activation code
      }
    }

    if (mounted) {
      setState(() {
        _isCheckingMac = false;
      });
    }
    // ---------------------------------

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
    if (biometricsEnabled && (!Platform.isWindows || kIsWeb)) {
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

  Future<void> _validateActivationCode() async {
    final code = _activationCodeController.text.trim().toUpperCase();
    if (_validActivationCodes.contains(code)) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('windows_activated', true);

      // Successfully activated, resume normal startup
      setState(() {
        _isDeviceAuthorized = true;
        // Resume _checkAuthentication to handle PIN/Passwords normally
        _checkAuthentication();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Equipo Activado Exitosamente!')),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Código de activación inválido')),
      );
      _activationCodeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isCheckingMac) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isMacValid) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.block, size: 80, color: Colors.redAccent),
                const SizedBox(height: 24),
                Text(
                  "Equipo No Autorizado",
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Esta aplicación no está autorizada para ejecutarse en este equipo. La dirección física (MAC) no está registrada.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                if (_hardwareLockError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      "Error de Diagnóstico: \$_hardwareLockError",
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_isDeviceAuthorized) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.vpn_key, size: 80, color: Colors.blueAccent),
                const SizedBox(height: 24),
                Text(
                  "Activación Requerida",
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  "Este equipo está registrado pero requiere un código de activación inicial para comenzar a usar CashRapido.",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Theme.of(context).textTheme.bodyMedium?.color,
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _activationCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Código de Activación',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.key),
                    ),
                    onSubmitted: (_) => _validateActivationCode(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _validateActivationCode,
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text("Activar Equipo"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
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
    _activationCodeController.dispose();
    super.dispose();
  }
}
