import 'license_type.dart';

/// Configuración de métodos de pago para cada tipo de licencia
///
/// Permite habilitar o deshabilitar métodos de pago específicos
/// para cada licencia (semanal, mensual, anual)
///
/// ## Configuración Actual:
/// - Semanales: Apklis, Art-Pay, Anuncios, PayPal y QvaPay
/// - Mensuales: Apklis, Art-Pay, Anuncios, PayPal y QvaPay
/// - Anuales: Apklis, Art-Pay, PayPal y QvaPay
class LicensePaymentConfig {
  // Métodos de pago disponibles
  static const String apklis = 'apklis';
  static const String artPay = 'art_pay';
  static const String watchAds = 'watch_ads';
  static const String transferMovil = 'transfermovil';
  static const String enZona = 'enzona';
  static const String paypal = 'paypal';
  static const String qvapay = 'qvapay';
  static const String testCuba = 'test_cuba';
  static const String testIntl = 'test_intl';

  /// Configuración por defecto para cada tipo de licencia
  ///
  /// [enabledMethods] - Lista de métodos habilitados para esta licencia
  /// [isCubaOnly] - Si es true, solo muestra métodos de Cuba
  final List<String> enabledMethods;
  final bool isCubaOnly;

  const LicensePaymentConfig({
    required this.enabledMethods,
    this.isCubaOnly = false,
  });

  /// Verifica si un método está habilitado para esta licencia (instancia)
  bool isMethodEnabled(String methodId) {
    return enabledMethods.contains(methodId);
  }

  /// PERSONALIZA AQUÍ los métodos de pago para cada licencia:
  static const Map<LicenseType, LicensePaymentConfig> defaultConfigs = {
    // ========================================
    // LICENCIAS SEMANALES (7 días)
    // ========================================
    // Configuración: Art-Pay, Anuncios y PayPal (pagos bajos)
    LicenseType.weeklyPersonal: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, watchAds, paypal, qvapay],
    ),
    LicenseType.weeklyPro: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, watchAds, paypal, qvapay],
    ),
    LicenseType.weeklyEnterprise: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, watchAds, paypal, qvapay],
    ),

    // ========================================
    // LICENCIAS MENSUALES (30 días)
    // ========================================
    // Configuración: Todos los métodos disponibles
    LicenseType.monthlyPersonal: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, watchAds, paypal, qvapay],
    ),
    LicenseType.monthlyPro: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, watchAds, paypal, qvapay],
    ),
    LicenseType.monthlyEnterprise: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, watchAds, paypal, qvapay],
    ),

    // ========================================
    // LICENCIAS ANUALES (365 días)
    // ========================================
    LicenseType.annualPersonal: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, paypal, qvapay],
      isCubaOnly: false,
    ),
    LicenseType.annualPro: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, paypal, qvapay],
      isCubaOnly: false,
    ),
    LicenseType.annualEnterprise: LicensePaymentConfig(
      enabledMethods: [apklis, artPay, paypal, qvapay, testCuba],
      isCubaOnly: false,
    ),
  };

  /// Obtiene la configuración para un tipo de licencia
  static LicensePaymentConfig getConfig(LicenseType licenseType) {
    return defaultConfigs[licenseType] ??
        const LicensePaymentConfig(enabledMethods: []);
  }

  /// Obtiene los métodos habilitados para un tipo de licencia
  static List<String> getEnabledMethods(LicenseType licenseType) {
    return getConfig(licenseType).enabledMethods;
  }

  /// Verifica si un método está habilitado para una licencia específica
  static bool isMethodEnabledForLicense(
    LicenseType licenseType,
    String methodId,
  ) {
    return getConfig(licenseType).isMethodEnabled(methodId);
  }

  /// Verifica si una licencia es solo para Cuba
  static bool isLicenseCubaOnly(LicenseType licenseType) {
    return getConfig(licenseType).isCubaOnly;
  }

  /// Método helper para crear configuraciones personalizadas
  ///
  /// Ejemplo:
  /// ```dart
  /// LicensePaymentConfig.custom(
  ///   methods: [apklis, artPay],
  ///   cubaOnly: true,
  /// )
  /// ```
  static LicensePaymentConfig custom({
    required List<String> methods,
    bool cubaOnly = false,
  }) {
    return LicensePaymentConfig(enabledMethods: methods, isCubaOnly: cubaOnly);
  }
}
