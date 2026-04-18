import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:local_auth/local_auth.dart';
import 'dart:convert';
import '../services/widget_service.dart';
import 'package:crypto/crypto.dart';
import '../models/models.dart';
import '../models/payment_method.dart';
import '../services/notification_service.dart';
import '../services/export_service.dart';
import '../services/drive_service.dart';
import '../services/ad_service.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../services/backup_service.dart';
import '../licences/apklis.dart';
import '../licences/license_type.dart';

class AppProvider with ChangeNotifier {
  late Box<InternalTransaction> _transactionBox;
  late Box<Category> _categoryBox;
  late Box<AccountCard> _cardBox;

  List<InternalTransaction> _transactions = [];
  List<Category> _categories = [];
  List<AccountCard> _cards = [];

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String _chartType = 'Pie'; // Default
  String get chartType => _chartType;

  // Biometrics
  bool _biometricsEnabled = false;
  bool get biometricsEnabled => _biometricsEnabled;
  final LocalAuthentication auth = LocalAuthentication();

  // Daily Streak
  int _streakDays = 0;
  int get streakDays => _streakDays;
  DateTime? _lastLoginDate;

  int _availableRandomPlans = 0;
  int get availableRandomPlans => _availableRandomPlans;

  List<String> _loginDates = [];
  List<String> get loginDates => _loginDates;

  // Ad Service
  final AdService _adService = AdService();
  AdService get adService => _adService;

  int _adsWatched = 0;
  int get adsWatched => _adsWatched;

  LicenseType _targetLicenseForAds = LicenseType.monthlyPersonal; // Default

  /// Obtiene la cantidad de anuncios necesarios para desbloquear una licencia
  /// - Semanales: 3, 5, 7 anuncios (Personal, Pro, Enterprise)
  /// - Mensuales: 10, 25, 35 anuncios (Personal, Pro, Enterprise)
  /// - Anuales: 50, 100, 150 anuncios (Personal, Pro, Enterprise)
  int get adsTarget {
    final level = _targetLicenseForAds.level;
    final period = _targetLicenseForAds.period;

    // Base de anuncios por nivel
    int baseAds;
    switch (level) {
      case LicenseLevel.personal:
        baseAds = 10;
        break;
      case LicenseLevel.pro:
        baseAds = 25;
        break;
      case LicenseLevel.enterprise:
        baseAds = 35;
        break;
      case LicenseLevel.free:
        return 0;
    }

    // Multiplicador por período
    switch (period) {
      case LicensePeriod.weekly:
        return (baseAds * 0.3).ceil(); // 30% de anuncios
      case LicensePeriod.monthly:
        return baseAds; // 100% de anuncios
      case LicensePeriod.annual:
        return baseAds * 5; // 500% de anuncios (más económico a largo plazo)
      case LicensePeriod.lifetime:
        return 0;
    }
  }

  void setAdTargetLicense(LicenseType type) {
    _targetLicenseForAds = type;
    notifyListeners();
  }

  // AI Chat
  bool _aiChatEnabled = false;
  bool get aiChatEnabled => _aiChatEnabled;

  // PIN & Password
  String? _appPinHash;
  String? _appPasswordHash;
  bool get hasPinSet => _appPinHash != null && _appPinHash!.isNotEmpty;
  bool get hasPasswordSet =>
      _appPasswordHash != null && _appPasswordHash!.isNotEmpty;

  // Licenses & Restrictions
  // Licenses & Restrictions
  LicenseType _licenseType = LicenseType.free;
  LicenseType get licenseType {
    if (!kIsWeb && Platform.isWindows) {
      return LicenseType
          .monthlyEnterprise; // Fully unlocked on Windows after MAC/Code Activation
    }
    return _licenseType;
  }

  DateTime? _licenseActivationDate;
  DateTime? get licenseActivationDate => _licenseActivationDate;

  void setLicenseType(LicenseType type, {DateTime? expirationDate}) {
    _licenseType = type;
    if (type != LicenseType.free) {
      if (expirationDate != null) {
        // Art-Pay/Apklis provides exact expiration date
        _licenseActivationDate = expirationDate;
      } else {
        // Legacy: activation date is now. Expiration is based on license duration
        final durationDays = type.durationDays;
        _licenseActivationDate = DateTime.now().add(
          Duration(days: durationDays),
        );
      }
    } else {
      _licenseActivationDate = null;
    }

    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('license_type', type.index);
      if (expirationDate != null) {
        prefs.setString(
          'license_expiration_date',
          expirationDate.toIso8601String(),
        );
        prefs.remove('license_activation_date');
      } else if (_licenseActivationDate != null) {
        prefs.setString(
          'license_activation_date',
          _licenseActivationDate!.toIso8601String(),
        );
        prefs.remove('license_expiration_date');
      } else {
        prefs.remove('license_activation_date');
        prefs.remove('license_expiration_date');
      }
    });
    notifyListeners();
  }

  void _checkLicenseExpiration() {
    // Windows logic uses MAC address and Activation Codes, ignoring traditional Android/iOS Licenses.
    if (!kIsWeb && Platform.isWindows) {
      return;
    }

    if (_licenseType == LicenseType.free) return;

    if (_licenseActivationDate != null) {
      // _licenseActivationDate now holds the exact expiration date because we parse it in _init()
      if (DateTime.now().isAfter(_licenseActivationDate!)) {
        // Expired
        setLicenseType(LicenseType.free);
      }
    }
  }

  // Payment System
  // Change this variable to build for different regions
  final bool _isCuba = true;
  bool get isCuba => _isCuba;

  List<PaymentMethod> get paymentMethods {
    if (_isCuba) {
      final cubaMethods = [
        PaymentMethod(
          id: 'apklis',
          name: 'Apklis',
          iconAsset: 'assets/icons/apklis.png', // Placeholder
          isEnabled: true,
          isVisible: true,
        ),
        PaymentMethod(
          id: 'transfermovil',
          name: 'Transfermóvil',
          iconAsset: 'assets/icons/transfermovil.png',
          isEnabled: false,
          isVisible: false,
        ),
        PaymentMethod(
          id: 'enzona',
          name: 'EnZona',
          iconAsset: 'assets/icons/enzona.png',
          isEnabled: false,
          isVisible: false,
        ),
        PaymentMethod(
          id: 'test_cuba',
          name: 'Prueba (Test)',
          iconAsset: 'assets/icons/test.png',
          isEnabled: false,
          isVisible: false,
          isTest: true,
        ),
        PaymentMethod(
          id: 'art_pay',
          name: 'Art-Pay (.lic)',
          iconAsset:
              'assets/icons/art_pay.png', // Fallback to Icons.payment if not found
          isEnabled: true,
          isVisible: true,
        ),
      ];
      if (kIsWeb || Platform.isWindows) {
        cubaMethods.removeWhere(
          (m) => m.id == 'apklis' || m.id == 'transfermovil',
        );
      }
      return cubaMethods;
    } else {
      return [
        PaymentMethod(
          id: 'watch_ads',
          name: 'Ver Anuncios (Gratis)',
          iconAsset: 'assets/icons/video_ads.png',
          isEnabled: true,
          isVisible: true,
        ),
        PaymentMethod(
          id: 'stripe',
          name: 'Stripe',
          iconAsset: 'assets/icons/stripe.png',
          isEnabled: false,
          isVisible: false,
        ),
        PaymentMethod(
          id: 'paypal',
          name: 'PayPal',
          iconAsset: 'assets/icons/paypal.png',
          isEnabled: false,
          isVisible: false,
        ),
        PaymentMethod(
          id: 'google_play',
          name: 'Google Play',
          iconAsset: 'assets/icons/google_play.png',
          isEnabled: false,
          isVisible: false,
        ),
        PaymentMethod(
          id: 'test_intl',
          name: 'Prueba (Test)',
          iconAsset: 'assets/icons/test.png',
          isEnabled: false,
          isVisible: false,
          isTest: true,
        ),
        PaymentMethod(
          id: 'art_pay',
          name: 'Art-Pay (.lic)',
          iconAsset:
              'assets/icons/art_pay.png', // Fallback to Icons.payment if not found
          isEnabled: false,
          isVisible: false,
        ),
      ];
    }
  }

  Future<String?> simulatePayment(
    String methodId,
    LicenseType targetLicense,
  ) async {
    if (methodId == 'test_cuba' || methodId == 'test_intl') {
      // Simulate network delay only for test methods
      await Future.delayed(const Duration(seconds: 2));
      setLicenseType(targetLicense);
      return null; // Success
    }

    if (methodId == 'apklis') {
      final status = await ApklisService.purchase(targetLicense);

      // Check for strict success ONLY
      if (status.paid) {
        setLicenseType(targetLicense);
        return null; // Success
      }

      // Return the specific error from Apklis
      return ApklisService.humanizeError(status.error);
    }

    // Default error for unknown methods
    return 'Método no implementado';
  }

  // Ad Logic
  Future<void> watchAdForLicense() async {
    // This just prepares tracking, verification happens after ad view callback
    // Actually, we need a callback from UI.
    // But we can expose a method to increment.
  }

  Future<void> incrementAdsWatched() async {
    _adsWatched++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('ads_watched', _adsWatched);

    if (_adsWatched >= adsTarget) {
      // Unlock Selected License with proper duration
      setLicenseType(
        _targetLicenseForAds,
        expirationDate: DateTime.now().add(
          Duration(days: _targetLicenseForAds.durationDays),
        ),
      );
      // Reset counter
      _adsWatched = 0;
      await prefs.setInt('ads_watched', 0);
    }
    notifyListeners();
  }

  /// Verifies if user has an active Apklis license and restores it
  /// This is used when user reinstalls the app to recover their purchased license
  Future<String?> verifyAndRestoreLicense() async {
    try {
      final status = await ApklisService.verify();

      if (!status.paid) {
        // User doesn't have an active license
        // Clean up the error message if it comes as JSON
        String errorMsg = ApklisService.humanizeError(status.error);

        return errorMsg;
      }

      // User has a paid license, now determine which tier
      final licenseType = ApklisService.getLicenseTypeFromUUID(status.license);

      if (licenseType == null) {
        return 'Licencia no reconocida. Contacta con soporte.';
      }

      setLicenseType(licenseType);
      return null; // Success
    } catch (e) {
      // Clean up error message
      String errorMsg = e.toString();

      // Remove "Exception: " prefix if present
      errorMsg = errorMsg.replaceFirst('Exception: ', '');

      return 'Error al verificar: $errorMsg';
    }
  }

  // Capability Getters

  bool get isPremium {
    // For backward compatibility or general "Not Free" check
    // Holiday Promo: Free Premium (PRO) until Jan 10, 2026
    final isPromoActive = DateTime.now().isBefore(
      DateTime(2026, 1, 11),
    ); // Promo ended
    if (isPromoActive) return true;
    return _licenseType != LicenseType.free;
  }

  // Specific Capabilities

  int get maxCards {
    if (isPromoActive) return 999;
    final level = _licenseType.level;
    switch (level) {
      case LicenseLevel.free:
        return 1;
      case LicenseLevel.personal:
        return 3; // 2 + 1 free
      case LicenseLevel.pro:
        return 4; // Requested: 4 cards for Pro
      case LicenseLevel.enterprise:
        return 999;
    }
  }

  bool get canAddCard {
    if (maxCards == 999) return true;
    return _cards.length < maxCards;
  }

  bool get isPromoActive =>
      DateTime.now().isBefore(DateTime(2026, 1, 11)); // Promo ended

  // Features unlocked at PERSONAL level or higher
  bool get canTransfer =>
      isPromoActive || _licenseType.level != LicenseLevel.free;
  bool get canSecurizeCard =>
      isPromoActive || _licenseType.level != LicenseLevel.free; // Lock/Limit
  bool get canViewDetailedStats =>
      isPromoActive ||
      _licenseType.level != LicenseLevel.free; // Day/Week/Year/Range
  bool get canChangePassword =>
      isPromoActive || _licenseType.level != LicenseLevel.free;
  bool get canAddCurrency =>
      isPromoActive || _licenseType.level != LicenseLevel.free;
  bool get canImportData =>
      isPromoActive || _licenseType.level != LicenseLevel.free;

  // Features locked at Pro level or higher
  bool get canExportData =>
      isPromoActive || _licenseType.level.index >= LicenseLevel.pro.index;
  bool get canSyncDrive =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;
  bool get canUseAI =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;
  bool get canUseBiometrics =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;

  // Enterprise Only
  bool get canUseScanner =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;
  bool get canUseMoreActions =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;
  bool get canExportPDF =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;

  // Features locked at Pro level or higher
  bool get canChangeCardPIN =>
      isPromoActive || _licenseType.level.index >= LicenseLevel.pro.index;
  bool get canChangeAppPIN =>
      isPromoActive || _licenseType.level.index >= LicenseLevel.pro.index;
  bool get canCreateCategory =>
      isPromoActive || _licenseType.level.index >= LicenseLevel.pro.index;
  bool get canFilterStatsAccount =>
      isPromoActive || _licenseType.level.index >= LicenseLevel.pro.index;
  bool get canManageBanks =>
      isPromoActive || _licenseType.level.index >= LicenseLevel.pro.index;
  bool get canExportExcel =>
      isPromoActive || _licenseType.level.index >= LicenseLevel.pro.index;
  bool get canCustomizeCharts =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;

  // New Feature: TransferMovil Integration (Personal or higher)
  bool _transferMovilEnabled = false;
  bool get transferMovilEnabled => _transferMovilEnabled;

  bool get canUseTransferMovil =>
      isPromoActive || _licenseType.level.index >= LicenseLevel.personal.index;

  // Widgets (Enterprise Only)
  bool get canUseWidgets =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;

  bool get canUseBusinessModule =>
      isPromoActive || _licenseType.level == LicenseLevel.enterprise;

  Future<void> setTransferMovilEnabled(bool enabled) async {
    if (enabled && !canUseTransferMovil) {
      throw Exception("Esta función requiere licencia Personal o superior");
    }
    _transferMovilEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('transfermovil_enabled', enabled);
    notifyListeners();
  }

  // Notifications
  bool _notificationsEnabled = false;
  bool get notificationsEnabled => _notificationsEnabled;
  final NotificationService _notificationService = NotificationService();

  // Export
  final ExportService _exportService = ExportService();

  // Localization
  Locale? _currentLocale;
  Locale? get currentLocale => _currentLocale;

  // Currency
  String _mainCurrency = 'CUP';
  String get mainCurrency => _mainCurrency;

  Map<String, double> _exchangeRates = {};
  Map<String, double> get exchangeRates => _exchangeRates;

  double getExchangeRate(String currencyCode) =>
      _exchangeRates[currencyCode] ?? 1.0;

  Future<void> setExchangeRate(String currencyCode, double rate) async {
    _exchangeRates[currencyCode] = rate;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('exchange_rates', jsonEncode(_exchangeRates));
    notifyListeners();
  }

  List<Currency> _customCurrencies = [];
  List<Currency> get customCurrencies => _customCurrencies;

  List<Currency> get availableCurrencies {
    final defaults = [
      Currency(code: 'CUP', symbol: '₱', name: 'Peso Cubano'),
      Currency(code: 'USD', symbol: '\$', name: 'US Dollar'),
      Currency(code: 'EUR', symbol: '€', name: 'Euro'),
      Currency(code: 'MLC', symbol: '\$', name: 'MLC'),
    ];
    return [...defaults, ..._customCurrencies];
  }

  List<InternalTransaction> get transactions => _transactions;
  List<Category> get categories => _categories;
  List<AccountCard> get cards => _cards;

  final Uuid _uuid = const Uuid();

  Future<void> init() async {
    try {
      _transactionBox = await Hive.openBox<InternalTransaction>('transactions');
      _categoryBox = await Hive.openBox<Category>('categories');
      _cardBox = await Hive.openBox<AccountCard>('cards');

      // Ensure Default Categories exist
      await _seedDefaultCategories();

      // Initialize Default Wallet if empty (Optional, for easy start)
      if (_cardBox.isEmpty) {
        await _seedDefaultCards();
      }

      if (_cardBox.isEmpty) {
        await _seedDefaultCards();
      }

      final prefs = await SharedPreferences.getInstance();
      _aiChatEnabled = prefs.getBool('ai_chat_enabled') ?? false;

      _chartType = prefs.getString('chart_type') ?? 'Pie';
      _biometricsEnabled = prefs.getBool('biometrics_enabled') ?? false;
      _appPinHash = prefs.getString('app_pin_hash');
      _appPasswordHash = prefs.getString('app_password_hash');
      _notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      _transferMovilEnabled = prefs.getBool('transfermovil_enabled') ?? false;

      // Handle daily streak
      _streakDays = prefs.getInt('streak_days') ?? 0;
      _availableRandomPlans = prefs.getInt('available_random_plans') ?? 0;
      _loginDates = prefs.getStringList('login_dates') ?? [];

      final lastLoginStr = prefs.getString('last_login_date');
      if (lastLoginStr != null) {
        _lastLoginDate = DateTime.tryParse(lastLoginStr);
      }
      _calculateStreak(prefs);

      final themeString = prefs.getString('theme_mode');
      if (themeString != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (e) => e.toString() == themeString,
          orElse: () => ThemeMode.system,
        );
      }

      // Load Locale
      final String? langCode = prefs.getString('app_language');
      if (langCode != null) {
        _currentLocale = Locale(langCode);
      } // else ... existing fallback logic

      // Load Currency
      _mainCurrency = prefs.getString('main_currency') ?? 'CUP';
      // Load Custom Exchange Rates
      final ratesJson = prefs.getString('exchange_rates');
      if (ratesJson != null) {
        try {
          final decoded = jsonDecode(ratesJson) as Map<String, dynamic>;
          _exchangeRates = decoded.map(
            (key, value) => MapEntry(key, (value as num).toDouble()),
          );
        } catch (e) {
          _exchangeRates = {};
        }
      } else {
        // Fallback for previous single setting or defaults
        final oldRate = prefs.getDouble('exchange_rate');
        if (oldRate != null) {
          _exchangeRates = {'USD': oldRate};
        } else {
          _exchangeRates = {
            'USD': 320.0,
            'EUR': 340.0,
            'MLC': 270.0,
          }; // Default example rates
        }
      }

      final customCurrenciesJson = prefs.getStringList('custom_currencies');
      if (customCurrenciesJson != null) {
        _customCurrencies = customCurrenciesJson
            .map((e) => Currency.fromJson(jsonDecode(e)))
            .toList();
      }

      // Load License
      final licenseIndex =
          prefs.getInt('license_type') ?? LicenseType.free.index;
      if (licenseIndex >= 0 && licenseIndex < LicenseType.values.length) {
        _licenseType = LicenseType.values[licenseIndex];
      }

      final exactExpirationString = prefs.getString('license_expiration_date');
      if (exactExpirationString != null) {
        _licenseActivationDate = DateTime.tryParse(exactExpirationString);
      } else {
        final activationString = prefs.getString('license_activation_date');
        if (activationString != null) {
          final parsedActivation = DateTime.tryParse(activationString);
          if (parsedActivation != null) {
            // Use dynamic duration based on license type
            final durationDays = _licenseType.durationDays > 0
                ? _licenseType.durationDays
                : 30; // Default fallback
            _licenseActivationDate = parsedActivation.add(
              Duration(days: durationDays),
            );
          }
        }
      }

      // Check Expiration
      _checkLicenseExpiration();

      // Fallback locale logic if not set above
      if (_currentLocale == null) {
        final systemLoc = ui.window.locale;
        if (['es', 'en', 'fr'].contains(systemLoc.languageCode)) {
          _currentLocale = Locale(systemLoc.languageCode);
        } else {
          _currentLocale = const Locale('es');
        }
      }

      // Load Custom Banks
      _customBanks = prefs.getStringList('custom_banks') ?? [];

      // Initialize NotificationService
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          await _notificationService.initialize();
        } catch (e) {
          print('Notification init error: \$e');
        }
      }

      // Initialize AdService
      _adsWatched = prefs.getInt('ads_watched') ?? 0;
      _adService.onAdLoadedListener = notifyListeners;
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          await _adService.initialize();
          _adService.loadRewardedAd();
        } catch (e) {
          print('AdService init error: \$e');
        }
      }

      if (_notificationsEnabled &&
          (!kIsWeb && (Platform.isAndroid || Platform.isIOS))) {
        try {
          await _notificationService.scheduleAllNotifications(
            _currentLocale?.languageCode ?? 'es',
          );
        } catch (e) {
          print('Notification schedule error: \$e');
        }
      }

      _fetchData();
    } catch (e) {
      print(
        'Critical error during AppProvider initialization: \$e\\n\$stacktrace',
      );
      try {
        _fetchData();
      } catch (_) {}
    } finally {
      _isLoading = false;
      notifyListeners();

      // Initialize and update widgets with current data
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        try {
          await WidgetService.initialize();
          await _updateWidgetsIfNeeded();
        } catch (e) {
          print('WidgetService init error: \$e');
        }
      }
    }
  }

  void _fetchData() {
    _transactions = _transactionBox.values.toList().cast<InternalTransaction>();
    _categories = _categoryBox.values.toList().cast<Category>();
    _cards = _cardBox.values.toList().cast<AccountCard>();

    // Sort transactions by date desc
    _transactions.sort((a, b) => b.date.compareTo(a.date));
    _invalidateCaches();
  }

  void _calculateStreak(SharedPreferences prefs) {
    final now = DateTime.now();
    final todayStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    if (!_loginDates.contains(todayStr)) {
      _loginDates.add(todayStr);
      prefs.setStringList('login_dates', _loginDates);
    }

    if (_lastLoginDate == null) {
      _streakDays = 1;
    } else {
      final today = DateTime(now.year, now.month, now.day);
      final lastLoginDay = DateTime(
        _lastLoginDate!.year,
        _lastLoginDate!.month,
        _lastLoginDate!.day,
      );
      final diffDays = today.difference(lastLoginDay).inDays;

      if (diffDays == 1) {
        _streakDays++;
        // Reward every 50 days
        if (_streakDays % 50 == 0) {
          _availableRandomPlans++;
          prefs.setInt('available_random_plans', _availableRandomPlans);
        }
      } else if (diffDays > 1) {
        _streakDays = 1;
      }
      // If diffDays == 0, already logged in today, keep streak the same.
    }
    _lastLoginDate = now;
    prefs.setInt('streak_days', _streakDays);
    prefs.setString('last_login_date', _lastLoginDate!.toIso8601String());
  }

  Future<void> claimRandomPlan() async {
    if (_availableRandomPlans > 0) {
      final types = LicenseType.values
          .where((t) => t != LicenseType.free)
          .toList();
      types.shuffle();
      final randomType = types.first;
      _availableRandomPlans--;

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('available_random_plans', _availableRandomPlans);

      final durationDays = randomType.durationDays > 0
          ? randomType.durationDays
          : 30;
      setLicenseType(
        randomType,
        expirationDate: DateTime.now().add(Duration(days: durationDays)),
      );
    }
  }

  // --- Caching ---
  final Map<String, double> _spentCache = {};
  final Map<String, double> _incomeCache = {};

  void _invalidateCaches() {
    _spentCache.clear();
    _incomeCache.clear();
  }

  // --- Transactions ---

  bool validateCardForTransaction(String cardId, {String? pin}) {
    final cardIndex = _cards.indexWhere((c) => c.id == cardId);
    if (cardIndex == -1) return false;

    final card = _cards[cardIndex];
    if (card.isLocked) {
      throw Exception("La tarjeta está bloqueada.");
    }

    if (card.pin != null && card.pin!.isNotEmpty) {
      if (pin == null || pin != card.pin) {
        throw Exception("PIN incorrecto.");
      }
    }
    return true;
  }

  Future<String?> addTransaction({
    required double amount,
    required String title,
    required String categoryId,
    required String currency, // 'CUP', 'USD', 'EUR'
    String? cardId, // Optional link to card
    DateTime? date,
  }) async {
    // Validate balance before adding expense
    if (cardId != null && amount < 0) {
      final cardIndex = _cards.indexWhere((c) => c.id == cardId);
      if (cardIndex != -1) {
        final card = _cards[cardIndex];
        double newBalance = card.balance + amount;

        // Check if expense would cause negative balance
        if (newBalance < 0) {
          return "saldo_insuficiente"; // Return error code
        }
      }
    }

    final transaction = InternalTransaction(
      id: _uuid.v4(),
      amount: amount,
      title: title,
      categoryId: categoryId,
      currency: currency,
      date: date ?? DateTime.now(),
      cardId: cardId, // Save the link
    );

    await _transactionBox.add(transaction);
    _transactions.insert(0, transaction);
    _invalidateCaches();

    // Update Card Balance if linked
    if (cardId != null) {
      final cardIndex = _cards.indexWhere((c) => c.id == cardId);
      if (cardIndex != -1) {
        final card = _cards[cardIndex];
        double newBalance = card.balance + amount;

        final updatedCard = AccountCard(
          id: card.id,
          name: card.name,
          balance: newBalance,
          currency: card.currency,
          cardNumber: card.cardNumber,
          expiryDate: card.expiryDate,
          colorValue: card.colorValue,
          isLocked: card.isLocked,
          pin: card.pin,
          spendingLimit: card.spendingLimit,
          bankName: card.bankName,
          isCash: card.isCash, // Preserve isCash
        );

        await editCard(updatedCard);
      }
    }

    notifyListeners();

    // Update balance widget if enabled
    _updateWidgetsIfNeeded();

    return null; // Success
  }

  /// Update widgets with current main card balance
  Future<void> _updateWidgetsIfNeeded() async {
    if (_cards.isEmpty) return;

    // Find main card (first card or explicitly marked main)
    final mainCard = _cards.first;
    await WidgetService.updateAllWidgets(mainCard.balance, mainCard.currency);
  }

  Future<void> deleteTransaction(String transactionId) async {
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) return;

    final transaction = _transactions[index];

    // Revert Balance
    if (transaction.cardId != null) {
      final cardIndex = _cards.indexWhere((c) => c.id == transaction.cardId);
      if (cardIndex != -1) {
        final card = _cards[cardIndex];
        // If it was Income (+), we subtract. If Expense (-), we add (subtracting negative).
        double newBalance = card.balance - transaction.amount;
        final updatedCard = card.copyWith(balance: newBalance);
        await editCard(updatedCard);
      }
    }

    // Delete from Hive
    final key = _transactionBox.keys.firstWhere(
      (k) => _transactionBox.get(k)?.id == transactionId,
      orElse: () => null,
    );
    if (key != null) {
      await _transactionBox.delete(key);
    }

    _transactions.removeAt(index);
    _invalidateCaches();
    notifyListeners();
  }

  Future<void> editTransaction(
    String transactionId, {
    required double newAmount,
    required String newTitle,
    required String newCategoryId,
    required String newCurrency,
  }) async {
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index == -1) return;

    final oldTransaction = _transactions[index];

    // Update Card Balance if linked
    if (oldTransaction.cardId != null) {
      final cardIndex = _cards.indexWhere((c) => c.id == oldTransaction.cardId);
      if (cardIndex != -1) {
        final card = _cards[cardIndex];

        // Calculate what the balance would be without the old transaction
        double baseBalance = card.balance - oldTransaction.amount;

        // Calculate new balance with the new transaction
        double proposedBalance = baseBalance + newAmount;

        // If proposed balance would be negative, adjust the transaction amount
        double finalAmount = newAmount;
        double finalBalance = proposedBalance;

        if (proposedBalance < 0) {
          // Adjust so balance stays at 0
          // baseBalance + finalAmount = 0
          // finalAmount = -baseBalance
          finalAmount = -baseBalance;
          finalBalance = 0;
        }

        final updatedCard = card.copyWith(balance: finalBalance);

        // Update card in Hive and list
        final hiveIndex = _cardBox.values.toList().indexWhere(
          (c) => c.id == updatedCard.id,
        );
        if (hiveIndex != -1) {
          await _cardBox.putAt(hiveIndex, updatedCard);
          _cards[cardIndex] = updatedCard;
        }

        // Update the newAmount parameter for transaction save
        newAmount = finalAmount;
      }
    }

    // Update Transaction
    final updatedTx = InternalTransaction(
      id: oldTransaction.id,
      amount: newAmount,
      title: newTitle,
      categoryId: newCategoryId,
      currency: newCurrency,
      date: oldTransaction.date,
      cardId: oldTransaction.cardId,
    );

    // Save to Hive
    final key = _transactionBox.keys.firstWhere(
      (k) => _transactionBox.get(k)?.id == transactionId,
      orElse: () => null,
    );
    if (key != null) {
      await _transactionBox.put(key, updatedTx);
    }
    _transactions[index] = updatedTx;
    _invalidateCaches();
    notifyListeners();
  }

  Future<void> transferBetweenCards({
    required String fromCardId,
    required String toCardId,
    required double amount,
  }) async {
    final fromCardIndex = _cards.indexWhere((c) => c.id == fromCardId);
    final toCardIndex = _cards.indexWhere((c) => c.id == toCardId);

    if (fromCardIndex == -1 || toCardIndex == -1) return;

    final fromCard = _cards[fromCardIndex];
    final toCard = _cards[toCardIndex];

    // 1. Deficit from Source
    await addTransaction(
      amount: -amount,
      title:
          "Transferencia a ${toCard.bankName} (...${toCard.cardNumber.substring(toCard.cardNumber.length - 4)})",
      categoryId: "transfer_out", // Need a valid ID or handle this
      currency: fromCard.currency,
      cardId: fromCardId,
    );

    // 2. Add to Destination
    await addTransaction(
      amount: amount,
      title:
          "Recibido de ${fromCard.bankName} (...${fromCard.cardNumber.substring(fromCard.cardNumber.length - 4)})",
      categoryId: "transfer_in",
      currency: toCard.currency,
      cardId: toCardId,
    );
  }

  // --- Categories ---

  Future<void> addCategory({
    required String name,
    required int iconCode,
    required int colorValue,
    double? monthlyBudget,
  }) async {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      iconCode: iconCode,
      colorValue: colorValue,
      isCustom: true,
      monthlyBudget: monthlyBudget,
    );
    await _categoryBox.add(category);
    _categories.add(category);
    notifyListeners();
  }

  Future<void> editCategoryBudget(String categoryId, double budget) async {
    final index = _categories.indexWhere((c) => c.id == categoryId);
    if (index != -1) {
      final old = _categories[index];
      final updated = Category(
        id: old.id,
        name: old.name,
        iconCode: old.iconCode,
        colorValue: old.colorValue,
        isCustom: old.isCustom,
        monthlyBudget: budget,
      );
      final key = _categoryBox.keys.firstWhere(
        (k) => _categoryBox.get(k)?.id == categoryId,
        orElse: () => null,
      );
      if (key != null) {
        await _categoryBox.put(key, updated);
      }
      _categories[index] = updated;
      notifyListeners();
    }
  }

  // --- Cards ---

  Future<void> addCard(AccountCard card) async {
    await _cardBox.add(card);
    _cards.add(card);
    notifyListeners();
  }

  // --- Card Management ---

  Future<void> editCard(AccountCard updatedCard) async {
    final index = _cardBox.values.toList().indexWhere(
      (c) => c.id == updatedCard.id,
    );
    if (index != -1) {
      await _cardBox.putAt(index, updatedCard);

      final listIndex = _cards.indexWhere((c) => c.id == updatedCard.id);
      if (listIndex != -1) {
        _cards[listIndex] = updatedCard;
      }
      notifyListeners();

      // Update widgets if main card changed
      await _updateWidgetsIfNeeded();
    }
  }

  Future<void> deleteCard(String cardId) async {
    final index = _cardBox.values.toList().indexWhere((c) => c.id == cardId);
    if (index != -1) {
      await _cardBox.deleteAt(index);
      _cards.removeWhere((c) => c.id == cardId);
      notifyListeners();

      // Update widgets since card list changed
      await _updateWidgetsIfNeeded();
    }
  }

  Future<void> toggleCardLock(String cardId) async {
    final index = _cardBox.values.toList().indexWhere((c) => c.id == cardId);
    if (index != -1) {
      final card = _cardBox.getAt(index);
      if (card != null) {
        final updatedCard = AccountCard(
          id: card.id,
          name: card.name,
          balance: card.balance,
          currency: card.currency,
          cardNumber: card.cardNumber,
          expiryDate: card.expiryDate,
          colorValue: card.colorValue,
          isLocked: !card.isLocked,
          pin: card.pin,
          spendingLimit: card.spendingLimit,
          bankName: card.bankName,
          isCash: card.isCash,
        );
        await _cardBox.putAt(index, updatedCard);

        // Update local list
        final listIndex = _cards.indexWhere((c) => c.id == cardId);
        if (listIndex != -1) {
          _cards[listIndex] = updatedCard;
        }
        notifyListeners();
      }
    }
  }

  Future<void> setCardPin(String cardId, String pin) async {
    final index = _cardBox.values.toList().indexWhere((c) => c.id == cardId);
    if (index != -1) {
      final card = _cardBox.getAt(index);
      if (card != null) {
        final updatedCard = AccountCard(
          id: card.id,
          name: card.name,
          balance: card.balance,
          currency: card.currency,
          cardNumber: card.cardNumber,
          expiryDate: card.expiryDate,
          colorValue: card.colorValue,
          isLocked: card.isLocked,
          pin: pin,
          spendingLimit: card.spendingLimit,
          bankName: card.bankName,
          isCash: card.isCash,
        );
        await _cardBox.putAt(index, updatedCard);

        final listIndex = _cards.indexWhere((c) => c.id == cardId);
        if (listIndex != -1) {
          _cards[listIndex] = updatedCard;
        }
        notifyListeners();
      }
    }
  }

  Future<void> setCardLimit(String cardId, double limit) async {
    final index = _cardBox.values.toList().indexWhere((c) => c.id == cardId);
    if (index != -1) {
      final card = _cardBox.getAt(index);
      if (card != null) {
        final updatedCard = AccountCard(
          id: card.id,
          name: card.name,
          balance: card.balance,
          currency: card.currency,
          cardNumber: card.cardNumber,
          expiryDate: card.expiryDate,
          colorValue: card.colorValue,
          isLocked: card.isLocked,
          pin: card.pin,
          spendingLimit: limit,
          bankName: card.bankName,
          isCash: card.isCash,
        );
        await _cardBox.putAt(index, updatedCard);

        final listIndex = _cards.indexWhere((c) => c.id == cardId);
        if (listIndex != -1) {
          _cards[listIndex] = updatedCard;
        }
        notifyListeners();
      }
    }
  }

  // --- Helpers / Seed ---

  Future<void> _seedDefaultCategories() async {
    // 1. Clean up existing duplicates first
    await _cleanupDuplicateCategories();

    final defaults = [
      Category(
        id: 'cat_food',
        name: 'Comida',
        iconCode: 0xe532,
        colorValue: 0xFFFFA726,
      ), // restaurant
      Category(
        id: 'cat_transport',
        name: 'Transporte',
        iconCode: 0xe1d5,
        colorValue: 0xFF42A5F5,
      ), // directions_car
      Category(
        id: 'cat_home',
        name: 'Hogar',
        iconCode: 0xe318,
        colorValue: 0xFFAB47BC,
      ), // home
      Category(
        id: 'cat_health',
        name: 'Salud',
        iconCode: 0xe396,
        colorValue: 0xFFEF5350,
      ), // favorite
      Category(
        id: 'cat_entertainment',
        name: 'Entretenimiento',
        iconCode: 0xe3a1,
        colorValue: 0xFFEC407A,
      ), // movie
      // Income Categories
      Category(
        id: 'cat_salary',
        name: 'Salario',
        iconCode: 0xe0b2, // attach_money or similar work icon
        colorValue: 0xFF4CAF50, // Green
      ),
      Category(
        id: 'cat_business',
        name: 'Negocio',
        iconCode: 0xe11c, // business_center or similar
        colorValue: 0xFF2196F3, // Blue
      ),
      Category(
        id: 'cat_gifts',
        name: 'Regalos',
        iconCode: 0xe13e, // card_giftcard
        colorValue: 0xFF9C27B0, // Purple
      ),
      Category(
        id: 'cat_rent',
        name: 'Alquiler',
        iconCode: 0xe31d, // home
        colorValue: 0xFFFF9800, // Orange
      ),
      Category(
        id: 'cat_investment',
        name: 'Inversiones',
        iconCode: 0xe59f, // show_chart
        colorValue: 0xFF009688, // Teal
      ),
      Category(
        id: 'cat_other_income',
        name: 'Otros Ingresos',
        iconCode: 0xe482, // attach_money usually
        colorValue: 0xFF607D8B, // BlueGrey
      ),
      Category(
        id: 'cat_transfermovil',
        name: 'Transfermóvil',
        iconCode: 0xe5f0, // smartphone (Material Icons)
        colorValue: 0xFF2196F3, // Blue
      ),
    ];

    for (var cat in defaults) {
      // Check by ID first, then by Name to prevent re-adding with new ID if we changed schema
      final bool existsById = _categoryBox.values.any((c) => c.id == cat.id);
      final bool existsByName = _categoryBox.values.any(
        (c) => c.name == cat.name,
      );

      if (!existsById && !existsByName) {
        await _categoryBox.add(cat);
        _categories.add(cat);
      } else if (!existsById && existsByName) {
        // If exists by name but has different ID (old format), we keep the old one
        // OR we could migrate it. For now, let's just NOT add a duplicate.
        // Ideally, we'd want to migrate to fixed IDs, but that's complex since we just cleaned up.
        // The cleanup logic below handles merging by name, so we should be good.
      }
    }
  }

  Future<void> _cleanupDuplicateCategories() async {
    final allCategories = _categoryBox.values.toList();
    final Map<String, List<Category>> byName = {};

    for (var cat in allCategories) {
      byName.putIfAbsent(cat.name, () => []).add(cat);
    }

    for (var entry in byName.entries) {
      if (entry.value.length > 1) {
        // We have duplicates!
        final duplicates = entry.value;

        // Pick a survivor.
        // Preference:
        // 1. One with a "fixed" ID (starts with 'cat_' or 'transfer_')
        // 2. The first one found
        final survivor = duplicates.firstWhere(
          (c) => c.id.startsWith('cat_') || c.id.startsWith('transfer_'),
          orElse: () => duplicates.first,
        );

        final toDelete = duplicates.where((c) => c.id != survivor.id).toList();

        for (var victim in toDelete) {
          // 1. Reassign Transactions
          final victimTransactions = _transactionBox.values
              .where((t) => t.categoryId == victim.id)
              .toList();

          for (var tx in victimTransactions) {
            // Create a copy with new category ID
            final updatedTx = InternalTransaction(
              id: tx.id,
              amount: tx.amount,
              title: tx.title,
              date: tx.date,
              categoryId: survivor.id, // Reassign
              currency: tx.currency,
              cardId: tx.cardId,
            );
            // Find key to update in Hive (assuming auto-increment keys or similar, but we iterate values)
            // We need the key. Hive 'values' doesn't give keys directly.
            // We have to find key by object or ID.
            // Since we don't have the key easily, valid approach:
            // Map keys to values.
            final key = _transactionBox.keys.firstWhere(
              (k) => _transactionBox.get(k)?.id == tx.id,
              orElse: () => null,
            );
            if (key != null) {
              await _transactionBox.put(key, updatedTx);
            }
          }

          // 2. Delete Category
          final catKey = _categoryBox.keys.firstWhere(
            (k) => _categoryBox.get(k)?.id == victim.id,
            orElse: () => null,
          );
          if (catKey != null) {
            await _categoryBox.delete(catKey);
          }
        }
      }
    }

    // Refresh local list
    _categories = _categoryBox.values.toList().cast<Category>();
  }

  Future<void> _seedDefaultCards() async {
    // Add a default CUP card
    final card = AccountCard(
      id: _uuid.v4(),
      name: 'Efectivo',
      balance: 0.0,
      currency: 'CUP',
      cardNumber: '0000',
      expiryDate: 'N/A',
      colorValue: 0xFF4CAF50,
    );
    await _cardBox.add(card);
  }

  // --- Getters ---

  double getTotalBalance(String currency) {
    // Sum of all cards of that currency
    return _cards
        .where((c) => c.currency == currency)
        .fold(0.0, (sum, item) => sum + item.balance);
  }

  double getSpentThisMonth(String currency, {String? cardId}) {
    final cacheKey = "\${currency}_\${cardId ?? 'all'}";
    if (_spentCache.containsKey(cacheKey)) {
      return _spentCache[cacheKey]!;
    }

    final now = DateTime.now();
    final spent = _transactions
        .where(
          (t) =>
              t.currency == currency &&
              (cardId == null ||
                  t.cardId == cardId) && // Filter by card if provided
              t.amount < 0 &&
              t.date.month == now.month &&
              t.date.year == now.year,
        )
        .fold(0.0, (sum, item) => sum + item.amount.abs());

    _spentCache[cacheKey] = spent;
    return spent;
  }

  double getSpentForCategoryThisMonth(String categoryId) {
    // Need to get the primary currency here or just sum it up.
    // Since budgets don't specify currency in the requirement, we will sum the converted or just use mainCurrency.
    // If we only care about spending in general without complex conversions, we filter by mainCurrency.
    // But since transactions can be in USD, EUR, etc. and there is no conversion rate in AppProvider,
    // let's sum everything using 1:1 for now, or just focus on mainCurrency.
    // To be precise and safe, we sum all negative transactions regardless of currency?
    // "CashRapido" usually uses mainCurrency for stats.
    final now = DateTime.now();
    return _transactions
        .where(
          (t) =>
              t.categoryId == categoryId &&
              t.amount < 0 &&
              t.date.month == now.month &&
              t.date.year == now.year,
        )
        .fold(0.0, (sum, item) => sum + item.amount.abs());
  }

  double getIncomeThisMonth(String currency, {String? cardId}) {
    final cacheKey = "\${currency}_\${cardId ?? 'all'}";
    if (_incomeCache.containsKey(cacheKey)) {
      return _incomeCache[cacheKey]!;
    }

    final now = DateTime.now();
    final income = _transactions
        .where(
          (t) =>
              t.currency == currency &&
              (cardId == null ||
                  t.cardId == cardId) && // Filter by card if provided
              t.amount > 0 &&
              t.date.month == now.month &&
              t.date.year == now.year,
        )
        .fold(0.0, (sum, item) => sum + item.amount);

    _incomeCache[cacheKey] = income;
    return income;
  }

  Future<void> setChartType(String type) async {
    _chartType = type;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chart_type', type);
  }

  // --- Currency ---

  Future<void> setMainCurrency(String code) async {
    _mainCurrency = code;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('main_currency', code);
  }

  Future<void> addCustomCurrency(Currency currency) async {
    // Check if code exists
    if (_customCurrencies.any((c) => c.code == currency.code) ||
        ['CUP', 'USD', 'EUR', 'MLC'].contains(currency.code)) {
      throw 'Currency already exists';
    }

    _customCurrencies.add(currency);
    await _saveCustomCurrencies();
    notifyListeners();
  }

  bool isCurrencyInUse(String currencyCode) {
    return _cards.any((card) => card.currency == currencyCode);
  }

  Future<void> deleteCustomCurrency(String code) async {
    if (isCurrencyInUse(code)) {
      throw 'Currency In Use';
    }

    _customCurrencies.removeWhere((c) => c.code == code);

    // If deleted currency was selected as main, revert to CUP
    if (_mainCurrency == code) {
      _mainCurrency = 'CUP';
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('main_currency', 'CUP');
    }

    await _saveCustomCurrencies();
    notifyListeners();
  }

  Future<void> editCustomCurrency(String oldCode, Currency newCurrency) async {
    // If code is changing, check for conflict with existing
    if (oldCode != newCurrency.code) {
      if (_customCurrencies.any((c) => c.code == newCurrency.code) ||
          ['CUP', 'USD', 'EUR', 'MLC'].contains(newCurrency.code)) {
        throw 'Currency Code Exists';
      }

      // Also check if old code is in use (prevent code change if in use)
      // Or technically we could update all cards, but user requested restriction.
      if (isCurrencyInUse(oldCode)) {
        throw 'Currency In Use';
      }
    }

    final index = _customCurrencies.indexWhere((c) => c.code == oldCode);
    if (index != -1) {
      _customCurrencies[index] = newCurrency;
      await _saveCustomCurrencies();
      notifyListeners();
    }
  }

  Future<void> _saveCustomCurrencies() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> jsonList = _customCurrencies
        .map((c) => jsonEncode(c.toJson()))
        .toList();
    await prefs.setStringList('custom_currencies', jsonList);
  }

  // --- Banks ---

  List<String> _customBanks = [];
  List<String> get customBanks => _customBanks;

  List<String> get availableBanks {
    final defaults = [
      'VISA',
      'MasterCard',
      'Metropolitano',
      'BPA',
      'BANDEC',
      'American Express',
    ];
    return [...defaults, ..._customBanks];
  }

  Future<void> addCustomBank(String name) async {
    if (availableBanks.contains(name)) {
      throw 'Bank already exists';
    }
    _customBanks.add(name);
    await _saveCustomBanks();
    notifyListeners();
  }

  bool isBankInUse(String name) {
    return _cards.any((card) => card.bankName == name);
  }

  Future<void> deleteCustomBank(String name) async {
    if (isBankInUse(name)) {
      throw 'Bank In Use';
    }
    _customBanks.remove(name);
    await _saveCustomBanks();
    notifyListeners();
  }

  Future<void> editCustomBank(String oldName, String newName) async {
    if (oldName != newName) {
      if (availableBanks.contains(newName)) {
        throw 'Bank Name Exists';
      }
      if (isBankInUse(oldName)) {
        throw 'Bank In Use';
      }
    }

    final index = _customBanks.indexOf(oldName);
    if (index != -1) {
      _customBanks[index] = newName;
      await _saveCustomBanks();
      notifyListeners();
    }
  }

  Future<void> _saveCustomBanks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('custom_banks', _customBanks);
  }

  // --- Theme ---
  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', mode.toString());
  }

  // --- Biometrics ---

  Future<bool> authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Por favor autentícate para acceder a CashRapido',
      );
      return didAuthenticate;
    } catch (e) {
      if (kDebugMode) {
        print("Auth Error: $e");
      }
      return false;
    }
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    _biometricsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometrics_enabled', enabled);
  }

  // --- PIN & Password ---

  String _hashString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> setAppPin(String pin) async {
    _appPinHash = _hashString(pin);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_pin_hash', _appPinHash!);
  }

  Future<void> clearAppPin() async {
    _appPinHash = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_pin_hash');
  }

  bool validatePin(String pin) {
    if (_appPinHash == null) return true; // No PIN set
    return _hashString(pin) == _appPinHash;
  }

  Future<void> setAppPassword(String password) async {
    _appPasswordHash = _hashString(password);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_password_hash', _appPasswordHash!);
  }

  Future<void> clearAppPassword() async {
    _appPasswordHash = null;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('app_password_hash');
  }

  bool validatePassword(String password) {
    if (_appPasswordHash == null) return true; // No password set
    return _hashString(password) == _appPasswordHash;
  }

  // --- Notifications ---

  Future<void> setNotificationsEnabled(bool enabled) async {
    // Request permissions if enabling
    if (enabled) {
      final granted = await _notificationService.requestPermissions();
      if (!granted) {
        // Permission denied, don't enable
        return;
      }
      await _notificationService.scheduleAllNotifications(
        _currentLocale?.languageCode ?? 'es',
      );
    } else {
      await _notificationService.cancelAllNotifications();
    }

    _notificationsEnabled = enabled;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notifications_enabled', enabled);
  }

  // --- Export ---

  Future<String> exportToExcel() async {
    return await _exportService.exportToExcel(
      transactions: _transactions,
      categories: _categories,
      cards: _cards,
      exchangeRates: _exchangeRates,
      mainCurrency: _mainCurrency,
    );
  }

  Future<String> exportToPDF() async {
    return await _exportService.exportToPDF(
      transactions: _transactions,
      categories: _categories,
      cards: _cards,
      exchangeRates: _exchangeRates,
      mainCurrency: _mainCurrency,
    );
  }

  Future<void> shareFile(String filePath) async {
    await _exportService.shareFile(filePath);
  }

  // --- Google Drive Backup ---
  final DriveService _driveService = DriveService();
  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  GoogleSignInAccount? get currentUser => _driveService.currentUser;
  DateTime? _lastBackupDate;
  DateTime? get lastBackupDate => _lastBackupDate;

  Future<void> signInToGoogle() async {
    try {
      if (kIsWeb) return; // Not supported properly in this flow yet
      final user = await _driveService.signInToGoogle();
      if (user != null) {
        await _checkLastBackup();
      }
      notifyListeners();
    } catch (e) {
      print('Sign In Error: $e');
      rethrow;
    }
  }

  Future<void> signOutFromGoogle() async {
    await _driveService.signOut();
    _lastBackupDate = null;
    notifyListeners();
  }

  Future<void> _checkLastBackup() async {
    _lastBackupDate = await _driveService.getLastBackupDate();
    notifyListeners();
  }

  Future<void> backupToCloud() async {
    _isSyncing = true;
    notifyListeners();
    try {
      await _driveService.backupData();
      await _checkLastBackup();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> restoreFromCloud() async {
    _isSyncing = true;
    notifyListeners();
    try {
      // 1. Close boxes to release file locks
      // But wait! verification showed we need paths BEFORE closing?
      // Actually, .path property might rely on box being open?
      // Yes. So we must get paths, THEN close boxes?

      await _closeBoxes();

      // 2. Overwrite files
      await _driveService.restoreData();

      // 3. Reopen and reload
      await _openBoxes();
    } catch (e) {
      // Try to recover if something blew up
      if (!_transactionBox.isOpen) await _openBoxes();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  // --- Local Backup & Restore ---
  final BackupService _backupService = BackupService();

  Future<void> backupToLocal() async {
    try {
      final file = await _backupService.createBackup();
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Copia de Seguridad CashRapido');
    } catch (e) {
      print("Local Backup Error: $e");
      rethrow;
    }
  }

  Future<void> restoreFromLocal() async {
    try {
      // Pick file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result != null && result.files.single.path != null) {
        _isSyncing = true;
        notifyListeners();

        try {
          final file = File(result.files.single.path!);

          await _closeBoxes();
          await _backupService.restoreBackup(file);
          await _openBoxes();
        } catch (e) {
          if (!_transactionBox.isOpen) await _openBoxes();
          rethrow;
        }

        _isSyncing = false;
        notifyListeners();
      }
    } catch (e) {
      _isSyncing = false;
      notifyListeners();
      print("Local Restore Error: $e");
      rethrow;
    }
  }

  Future<void> _closeBoxes() async {
    await _transactionBox.close();
    await _categoryBox.close();
    await _cardBox.close();
  }

  Future<void> _openBoxes() async {
    _transactionBox = await Hive.openBox<InternalTransaction>('transactions');
    _categoryBox = await Hive.openBox<Category>('categories');
    _cardBox = await Hive.openBox<AccountCard>('cards');
    _fetchData();
  }

  Future<void> setLanguage(String languageCode) async {
    if (!['es', 'en', 'fr'].contains(languageCode)) return;

    _currentLocale = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', languageCode);
    notifyListeners();
  }

  Future<void> setAIChatEnabled(bool enabled) async {
    _aiChatEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_chat_enabled', enabled);
    notifyListeners();
  }
}
