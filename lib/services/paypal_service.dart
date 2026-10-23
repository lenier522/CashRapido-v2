import '../licences/license_type.dart';

/// Servicio de integración con PayPal.
///
/// Proporciona precios en USD para cada [LicenseType] y construye
/// la estructura de transacciones compatible con `flutter_paypal_payment`.
///
/// ⚠️  En producción sustituye [clientId] y [secretKey] por variables
/// de entorno o por una llamada a tu backend para no exponer las credenciales.
class PayPalService {
  // ---------------------------------------------------------------------------
  // Credenciales (reemplaza con tus valores reales del Developer Dashboard)
  // ---------------------------------------------------------------------------

  /// Client ID de la app en PayPal Developer Dashboard.
  /// Cambia a tu Client ID real cuando vayas a producción.
  static const String clientId =
      'Acxin9eEE6_KKUYwt0Cr-99WYfNrjmvvK4wWFcKbQBoAmq1HxEnMWcAD-eUrEJOWxtAme1_ZzsFq612h'; // TODO: reemplazar

  /// Secret Key de la app en PayPal Developer Dashboard.
  /// ⚠️  No expongas este valor en producción: muévelo a un backend seguro.
  static const String secretKey =
      'EAOCzd83o9OKSK-mw6XMVNwwM3shJ2iezOE4eZuzH1cw_KJJ24gyHiD8UXuFK9GeLIt6DxESPLvu0yt9'; // TODO: reemplazar

  /// `true` = usa el entorno Sandbox de PayPal (pruebas).
  /// `false` = usa el entorno Live (producción real).
  static const bool sandboxMode = true; // TODO: cambiar a false en producción

  // ---------------------------------------------------------------------------
  // Precios en USD para cada tipo de licencia
  // Comentados en license_type.dart:
  //   Semanales  →  Personal $0.15 | Pro $0.25 | Enterprise $0.35
  //   Mensuales  →  Personal $0.50 | Pro $1.00 | Enterprise $1.50
  //   Anuales    →  Personal $5.00 | Pro $10.00 | Enterprise $15.00
  // ---------------------------------------------------------------------------
  static double priceUsd(LicenseType licenseType) {
    switch (licenseType) {
      case LicenseType.weeklyPersonal:
        return 0.15;
      case LicenseType.weeklyPro:
        return 0.25;
      case LicenseType.weeklyEnterprise:
        return 0.35;
      case LicenseType.monthlyPersonal:
        return 0.50;
      case LicenseType.monthlyPro:
        return 1.00;
      case LicenseType.monthlyEnterprise:
        return 1.50;
      case LicenseType.annualPersonal:
        return 5.00;
      case LicenseType.annualPro:
        return 10.00;
      case LicenseType.annualEnterprise:
        return 15.00;
      case LicenseType.free:
        return 0.00;
    }
  }

  /// Nombre legible del plan para mostrarlo en el checkout de PayPal.
  static String planName(LicenseType licenseType) {
    final period = licenseType.period;
    final level = licenseType.level;

    final periodLabel = switch (period) {
      LicensePeriod.weekly => 'Semanal',
      LicensePeriod.monthly => 'Mensual',
      LicensePeriod.annual => 'Anual',
      LicensePeriod.lifetime => 'Gratuita',
    };

    final levelLabel = switch (level) {
      LicenseLevel.personal => 'Personal',
      LicenseLevel.pro => 'Pro',
      LicenseLevel.enterprise => 'Enterprise',
      LicenseLevel.free => 'Free',
    };

    return 'CashRapido $levelLabel $periodLabel';
  }

  /// Construye la lista de transacciones requerida por `flutter_paypal_payment`.
  ///
  /// El formato sigue la especificación de PayPal REST API v1.
  static List<Map<String, dynamic>> buildTransactions(LicenseType licenseType) {
    final price = priceUsd(licenseType).toStringAsFixed(2);
    final name = planName(licenseType);

    return [
      {
        'amount': {
          'total': price,
          'currency': 'USD',
          'details': {'subtotal': price, 'shipping': '0.00', 'tax': '0.00'},
        },
        'description': 'Licencia CashRapido – $name',
        'item_list': {
          'items': [
            {'name': name, 'quantity': 1, 'price': price, 'currency': 'USD'},
          ],
        },
      },
    ];
  }
}
