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

  // Ad Service
  final AdService _adService = AdService();
  AdService get adService => _adService;

  int _adsWatched = 0;
  int get adsWatched => _adsWatched;

  LicenseType _targetLicenseForAds = LicenseType.personal; // Default

  int get adsTarget {
    switch (_targetLicenseForAds) {
      case LicenseType.personal:
        return 10;
      case LicenseType.pro:
        return 25;
      case LicenseType.enterprise:
        return 35;
      default:
        return 10;
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
  LicenseType get licenseType => _licenseType;
  DateTime? _licenseActivationDate;
  DateTime? get licenseActivationDate => _licenseActivationDate;

  void setLicenseType(LicenseType type, {DateTime? activationDate}) {
    _licenseType = type;
    _licenseActivationDate = activationDate;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('license_type', type.index);
      if (activationDate != null) {
        prefs.setString(
          'license_activation_date',
          activationDate.toIso8601String(),
        );
      } else {
        prefs.remove('license_activation_date');
      }
    });
    notifyListeners();
  }

  void _checkLicenseExpiration() {
    if (_licenseType == LicenseType.free) return;

    if (_licenseActivationDate != null) {
      final expirationDate = _licenseActivationDate!.add(
        const Duration(days: 30),
      );
      if (DateTime.now().isAfter(expirationDate)) {
        // Expired
        setLicenseType(LicenseType.free);
      }
    }
  }

  // Payment System
  // Change this variable to build for different regions
  final bool _isCuba = false;
  bool get isCuba => _isCuba;

  List<PaymentMethod> get paymentMethods {
    if (_isCuba) {
      return [
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
          isEnabled: true,
          isVisible: true,
        ),
        PaymentMethod(
          id: 'enzona',
          name: 'EnZona',
          iconAsset: 'assets/icons/enzona.png',
          isEnabled: true,
          isVisible: true,
        ),
        PaymentMethod(
          id: 'test_cuba',
          name: 'Prueba (Test)',
          iconAsset: 'assets/icons/test.png',
          isEnabled: false,
          isVisible: false,
          isTest: true,
        ),
      ];
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
      // Map LicenseType to string for ApklisService
      String licenseTypeStr;
      switch (targetLicense) {
        case LicenseType.personal:
          licenseTypeStr = 'personal';
          break;
        case LicenseType.pro:
          licenseTypeStr = 'pro';
          break;
        case LicenseType.enterprise:
          licenseTypeStr = 'enterprise';
          break;
        default:
          licenseTypeStr = 'personal';
      }

      final status = await ApklisService.purchase(licenseTypeStr);

      // Check for strict success ONLY
      if (status.paid) {
        setLicenseType(targetLicense);
        return null; // Success
      }

      // Return the specific error from Apklis
      // This includes "Ya pagaste una licencia" if user already has one
      return status.error ?? 'Error desconocido de Apklis';
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
      // Unlock Selected License
      setLicenseType(_targetLicenseForAds, activationDate: DateTime.now());
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
        String errorMsg = status.error ?? 'No se encontró licencia activa';

        // Try to extract detail from JSON format: {"detail":"Mensaje"}
        try {
          if (errorMsg.trim().startsWith('{')) {
            final detailMatch = RegExp(
              r'"detail"\s*:\s*"([^"]+)"',
            ).firstMatch(errorMsg);
            if (detailMatch != null) {
              errorMsg = detailMatch.group(1) ?? errorMsg;
            }
          }
        } catch (_) {
          // If parsing fails, use the original message
        }

        // Clean up remaining JSON artifacts
        errorMsg = errorMsg
            .replaceAll('"}"', '')
            .replaceAll('{"', '')
            .replaceAll('"', '');

        return errorMsg;
      }

      // User has a paid license, now determine which tier
      String? licenseType = ApklisService.getLicenseTypeFromUUID(
        status.license,
      );

      licenseType ??= 'pro';

      // Map string to LicenseType enum and activate
      LicenseType targetLicense;
      switch (licenseType) {
        case 'personal':
          targetLicense = LicenseType.personal;
          break;
        case 'pro':
          targetLicense = LicenseType.pro;
          break;
        case 'enterprise':
          targetLicense = LicenseType.enterprise;
          break;
        default:
          targetLicense = LicenseType.pro;
      }

      setLicenseType(targetLicense);
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
    switch (_licenseType) {
      case LicenseType.free:
        return 1;
      case LicenseType.personal:
        return 3; // 2 + 1 free
      case LicenseType.pro:
        return 4; // Requested: 4 cards for Pro
      case LicenseType.enterprise:
        return 999;
    }
  }

  bool get canAddCard {
    if (maxCards == 999) return true;
    return _cards.length < maxCards;
  }

  bool get isPromoActive =>
      DateTime.now().isBefore(DateTime(2026, 1, 11)); // Promo ended

  // Features unlocked at PERSONAL level
  bool get canTransfer => isPromoActive || _licenseType != LicenseType.free;
  bool get canSecurizeCard =>
      isPromoActive || _licenseType != LicenseType.free; // Lock/Limit
  bool get canViewDetailedStats =>
      isPromoActive || _licenseType != LicenseType.free; // Day/Week/Year/Range
  bool get canChangePassword =>
      isPromoActive || _licenseType != LicenseType.free;
  bool get canAddCurrency => isPromoActive || _licenseType != LicenseType.free;
  bool get canImportData => isPromoActive || _licenseType != LicenseType.free;

  // Features locked at PERSONAL (Pro only)
  bool get canExportData =>
      isPromoActive || _licenseType.index >= LicenseType.pro.index;
  bool get canSyncDrive =>
      isPromoActive || _licenseType == LicenseType.enterprise;
  bool get canUseAI => isPromoActive || _licenseType == LicenseType.enterprise;
  bool get canUseBiometrics =>
      isPromoActive || _licenseType == LicenseType.enterprise;

  // Enterprise Only
  bool get canUseScanner =>
      isPromoActive || _licenseType == LicenseType.enterprise;
  bool get canUseMoreActions =>
      isPromoActive || _licenseType == LicenseType.enterprise;
  bool get canExportPDF =>
      isPromoActive || _licenseType == LicenseType.enterprise;

  // Features locked at PERSONAL (Pro only) - Newly Requested
  bool get canChangeCardPIN =>
      isPromoActive || _licenseType.index >= LicenseType.pro.index;
  bool get canChangeAppPIN =>
      isPromoActive || _licenseType.index >= LicenseType.pro.index;
  bool get canCreateCategory =>
      isPromoActive || _licenseType.index >= LicenseType.pro.index;
  bool get canFilterStatsAccount =>
      isPromoActive || _licenseType.index >= LicenseType.pro.index;
  bool get canManageBanks =>
      isPromoActive || _licenseType.index >= LicenseType.pro.index;
  bool get canExportExcel =>
      isPromoActive || _licenseType.index >= LicenseType.pro.index;
  bool get canCustomizeCharts =>
      isPromoActive || _licenseType == LicenseType.enterprise;

  // New Feature: TransferMovil Integration (Enterprise Only)
  bool _transferMovilEnabled = false;
  bool get transferMovilEnabled => _transferMovilEnabled;

  bool get canUseTransferMovil =>
      isPromoActive || _licenseType == LicenseType.enterprise;

  // Widgets (Enterprise Only)
  bool get canUseWidgets =>
      isPromoActive || _licenseType == LicenseType.enterprise;

  Future<void> setTransferMovilEnabled(bool enabled) async {
    if (enabled && !canUseTransferMovil) {
      throw Exception("Esta función requiere licencia Empresarial");
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

    final customCurrenciesJson = prefs.getStringList('custom_currencies');
    if (customCurrenciesJson != null) {
      _customCurrencies = customCurrenciesJson
          .map((e) => Currency.fromJson(jsonDecode(e)))
          .toList();
    }

    // Load License
    final licenseIndex = prefs.getInt('license_type') ?? 0;
    if (licenseIndex >= 0 && licenseIndex < LicenseType.values.length) {
      _licenseType = LicenseType.values[licenseIndex];
    }

    final activationString = prefs.getString('license_activation_date');
    if (activationString != null) {
      _licenseActivationDate = DateTime.tryParse(activationString);
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
    await _notificationService.initialize();

    // Initialize AdService
    _adsWatched = prefs.getInt('ads_watched') ?? 0;
    _adService.onAdLoadedListener = notifyListeners;
    await _adService.initialize();
    _adService.loadRewardedAd();

    if (_notificationsEnabled) {
      await _notificationService.scheduleAllNotifications(
        _currentLocale?.languageCode ?? 'es',
      );
    }

    _fetchData();
    _isLoading = false;
    notifyListeners();

    // Initialize and update widgets with current data
    await WidgetService.initialize();
    await _updateWidgetsIfNeeded();
  }

  void _fetchData() {
    _transactions = _transactionBox.values.toList().cast<InternalTransaction>();
    _categories = _categoryBox.values.toList().cast<Category>();
    _cards = _cardBox.values.toList().cast<AccountCard>();

    // Sort transactions by date desc
    _transactions.sort((a, b) => b.date.compareTo(a.date));
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
  }) async {
    final category = Category(
      id: _uuid.v4(),
      name: name,
      iconCode: iconCode,
      colorValue: colorValue,
      isCustom: true,
    );
    await _categoryBox.add(category);
    _categories.add(category);
    notifyListeners();
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
    final now = DateTime.now();
    return _transactions
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
  }

  double getIncomeThisMonth(String currency, {String? cardId}) {
    final now = DateTime.now();
    return _transactions
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
    );
  }

  Future<String> exportToPDF() async {
    return await _exportService.exportToPDF(
      transactions: _transactions,
      categories: _categories,
      cards: _cards,
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
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('ai_chat_enabled', enabled);
  }
}
