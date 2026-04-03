import 'package:artpay_lib/artpay_lib.dart';
import 'package:flutter/material.dart';
import 'license_type.dart';

/// Servicio para gestionar las licencias y pagos mediante Art-Pay
///
/// Art-Pay es una plataforma de pago que permite la compra de licencias
/// mediante archivos .lic que contienen la información de la licencia.
///
/// ## Tipos de Licencia Disponibles:
/// - Semanales (7 días): Personal, Pro, Enterprise
/// - Mensuales (30 días): Personal, Pro, Enterprise
/// - Anuales (365 días): Personal, Pro, Enterprise
class ArtPayService {
  // Package ID para CashRapido en Art-Pay
  static const String packageId = 'cu.lenier.cashrapido';

  // ========================================
  // TOKENS DE PRODUCTO PARA ART-PAY
  // ========================================

  // Licencias Semanales (7 días)
  static const String _weeklyPersonalToken =
      '297a956a-0d15-403c-9900-f48ab53b5bd7'; // 15 CUP / $0.15 USD
  static const String _weeklyProToken =
      'ebefde22-25e5-4c26-9b98-61ac51814fe7'; // 25 CUP / $0.25 USD
  static const String _weeklyEnterpriseToken =
      'e7af2c8e-6a41-42de-b49e-4bd064294dba'; // 35 CUP / $0.35 USD

  // Licencias Mensuales (30 días)
  static const String _monthlyPersonalToken =
      '00113e86-6bed-4e1c-a38e-d3130a536878'; // 50 CUP / $0.50 USD
  static const String _monthlyProToken =
      '1d9f9688-6ac6-42b1-8274-334c64e2a875'; // 75 CUP / $1 USD
  static const String _monthlyEnterpriseToken =
      'c5f52c39-f316-4bb6-8d91-914089fc1c78'; // 110 CUP / $1.50 USD

  // Licencias Anuales (365 días)
  static const String _annualPersonalToken =
      '4b4bb56e-7c52-47d6-b268-2e2d37a51be2'; // 500 CUP / $5 USD
  static const String _annualProToken =
      '29fa34c7-cfff-4980-9567-4084d616e839'; // 750 CUP / $10 USD
  static const String _annualEnterpriseToken =
      '411b70af-1bda-45db-bf93-5a8eddf5a7df'; // 1000 CUP / $15 USD

  /// Obtiene el token de producto Art-Pay para un tipo de licencia específico
  static String _getProductToken(LicenseType licenseType) {
    switch (licenseType) {
      // Semanales
      case LicenseType.weeklyPersonal:
        return _weeklyPersonalToken;
      case LicenseType.weeklyPro:
        return _weeklyProToken;
      case LicenseType.weeklyEnterprise:
        return _weeklyEnterpriseToken;

      // Mensuales
      case LicenseType.monthlyPersonal:
        return _monthlyPersonalToken;
      case LicenseType.monthlyPro:
        return _monthlyProToken;
      case LicenseType.monthlyEnterprise:
        return _monthlyEnterpriseToken;

      // Anuales
      case LicenseType.annualPersonal:
        return _annualPersonalToken;
      case LicenseType.annualPro:
        return _annualProToken;
      case LicenseType.annualEnterprise:
        return _annualEnterpriseToken;

      // Gratuita no tiene token
      case LicenseType.free:
        return '';
    }
  }

  /// Inicia el flujo de pago para una licencia específica usando Art-Pay
  ///
  /// [context] - Contexto de Flutter para mostrar el diálogo de pago
  /// [licenseType] - Tipo de licencia a adquirir
  /// [onSuccess] - Callback que se ejecuta cuando el pago es exitoso
  /// [onError] - Callback que se ejecuta cuando ocurre un error
  static void handlePayment({
    required BuildContext context,
    required LicenseType licenseType,
    required Function(ArtPayVerificationResult result) onSuccess,
    required Function(String error) onError,
  }) {
    if (licenseType == LicenseType.free) {
      onError('No se puede comprar una licencia gratuita');
      return;
    }

    final productToken = _getProductToken(licenseType);

    if (productToken.isEmpty) {
      onError(
        'Token de producto no configurado para ${getLicenseName(licenseType)}',
      );
      return;
    }

    debugPrint(
      'ArtPayService: Iniciando pago para ${licenseType.name} con token: $productToken',
    );

    ArtPayPayment.handlePayment(
      context: context,
      expectedProductToken: productToken,
      onSuccess: (result) {
        debugPrint(
          'ArtPayService: Pago exitoso - Licencia activada hasta: ${result.accessExpiresAt}',
        );
        onSuccess(result);
      },
      onError: (error) {
        debugPrint('ArtPayService: Error en el pago - $error');
        onError(error);
      },
    );
  }

  /// Verifica si un token de producto está configurado (no es placeholder)
  static bool isTokenConfigured(LicenseType licenseType) {
    final token = _getProductToken(licenseType);
    return token.isNotEmpty &&
        !token.contains('TOKEN_') &&
        !token.contains('AQUI');
  }

  /// Mapea un tipo de licencia a su precio en CUP
  static String getPriceCUP(LicenseType licenseType) {
    switch (licenseType) {
      // Semanales
      case LicenseType.weeklyPersonal:
        return '20';
      case LicenseType.weeklyPro:
        return '50';
      case LicenseType.weeklyEnterprise:
        return '70';

      // Mensuales
      case LicenseType.monthlyPersonal:
        return '50';
      case LicenseType.monthlyPro:
        return '75';
      case LicenseType.monthlyEnterprise:
        return '110';

      // Anuales
      case LicenseType.annualPersonal:
        return '150';
      case LicenseType.annualPro:
        return '230';
      case LicenseType.annualEnterprise:
        return '300';

      // Gratuita
      case LicenseType.free:
        return '0';
    }
  }

  /// Mapea un tipo de licencia a su precio en USD
  static String getPriceUSD(LicenseType licenseType) {
    switch (licenseType) {
      // Semanales
      case LicenseType.weeklyPersonal:
        return '0.15';
      case LicenseType.weeklyPro:
        return '0.25';
      case LicenseType.weeklyEnterprise:
        return '0.35';

      // Mensuales
      case LicenseType.monthlyPersonal:
        return '0.50';
      case LicenseType.monthlyPro:
        return '1';
      case LicenseType.monthlyEnterprise:
        return '1.5';

      // Anuales
      case LicenseType.annualPersonal:
        return '5';
      case LicenseType.annualPro:
        return '10';
      case LicenseType.annualEnterprise:
        return '15';

      // Gratuita
      case LicenseType.free:
        return '0';
    }
  }

  /// Obtiene el nombre legible del tipo de licencia
  static String getLicenseName(LicenseType licenseType) {
    final period = licenseType.period;
    final level = licenseType.level;

    String periodName;
    switch (period) {
      case LicensePeriod.weekly:
        periodName = 'Semanal';
        break;
      case LicensePeriod.monthly:
        periodName = 'Mensual';
        break;
      case LicensePeriod.annual:
        periodName = 'Anual';
        break;
      case LicensePeriod.lifetime:
        periodName = '';
        break;
    }

    String levelName;
    switch (level) {
      case LicenseLevel.free:
        return 'Gratuita';
      case LicenseLevel.personal:
        levelName = 'Personal';
        break;
      case LicenseLevel.pro:
        levelName = 'Pro';
        break;
      case LicenseLevel.enterprise:
        levelName = 'Empresarial';
        break;
    }

    if (period == LicensePeriod.lifetime) {
      return levelName;
    }

    return '$periodName $levelName';
  }

  /// Obtiene la descripción corta de la licencia
  static String getLicenseDescription(LicenseType licenseType) {
    final days = licenseType.durationDays;
    final priceCUP = getPriceCUP(licenseType);
    final priceUSD = getPriceUSD(licenseType);

    if (licenseType == LicenseType.free) {
      return 'Versión básica con funcionalidades limitadas';
    }

    return '$days días - $priceCUP CUP / \$$priceUSD USD';
  }

  /// Obtiene la duración de la licencia en días
  static int getLicenseDurationDays(LicenseType licenseType) {
    return licenseType.durationDays;
  }

  /// Obtiene el icono recomendado para el tipo de licencia
  static IconData getLicenseIcon(LicenseType licenseType) {
    if (licenseType == LicenseType.free) {
      return Icons.free_breakfast;
    }

    switch (licenseType.level) {
      case LicenseLevel.free:
        return Icons.free_breakfast;
      case LicenseLevel.personal:
        return Icons.person;
      case LicenseLevel.pro:
        return Icons.workspace_premium;
      case LicenseLevel.enterprise:
        return Icons.business;
    }
  }

  /// Obtiene el color recomendado para el tipo de licencia
  static Color getLicenseColor(LicenseType licenseType) {
    if (licenseType == LicenseType.free) {
      return Colors.grey;
    }

    switch (licenseType.level) {
      case LicenseLevel.free:
        return Colors.grey;
      case LicenseLevel.personal:
        return Colors.blue;
      case LicenseLevel.pro:
        return Colors.purple;
      case LicenseLevel.enterprise:
        return Colors.amber;
    }
  }

  /// Obtiene el badge de período (Semanal, Mensual, Anual)
  static String getPeriodBadge(LicenseType licenseType) {
    switch (licenseType.period) {
      case LicensePeriod.weekly:
        return 'SEMANAL';
      case LicensePeriod.monthly:
        return 'MENSUAL';
      case LicensePeriod.annual:
        return 'ANUAL';
      case LicensePeriod.lifetime:
        return 'GRATIS';
    }
  }
}
