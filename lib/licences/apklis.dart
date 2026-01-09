import 'dart:async';
import 'package:apklis_license_validator/apklis_license_payment_status.dart';
import 'package:apklis_license_validator/apklis_license_validator.dart';
import 'package:flutter/services.dart';

class ApklisService {
  // UUIDs for different license types
  static const String _personalLicenseId =
      'ef115f45-8736-4a21-a619-2d2f7b1d8781'; // 500 CUP
  static const String _proLicenseId =
      '1c6fa982-48e8-4b85-8bbb-56be3bb628c3'; // 1000 CUP
  static const String _enterpriseLicenseId =
      '3a72b071-a327-4336-9df9-4aebf04bd0e5'; // Enterprise
  static const String _packageId = 'cu.lenier.cashrapido';

  /// Get the UUID for a specific license type
  static String _getLicenseId(String licenseType) {
    switch (licenseType) {
      case 'personal':
        return _personalLicenseId;
      case 'pro':
        return _proLicenseId;
      case 'enterprise':
        return _enterpriseLicenseId;
      default:
        // Default to personal if unknown, or maybe throw error.
        // For safety, fallback to personal.
        return _personalLicenseId;
    }
  }

  /// Triggers the purchase flow for the specified license type.
  /// [licenseType] should be 'personal', 'pro', or 'enterprise'
  /// Returns [ApklisLicensePaymentStatus] so the caller can handle specific errors/messages.
  static Future<ApklisLicensePaymentStatus> purchase(String licenseType) async {
    final licenseId = _getLicenseId(licenseType);
    try {
      print(
        'ApklisService: Iniciando compra de $licenseType con UUID: $licenseId',
      );
      final status = await ApklisLicenseValidator.purchaseLicense(licenseId);
      print(
        'ApklisService: Respuesta recibida - paid: ${status.paid}, error: ${status.error}, statusCode: ${status.statusCode}',
      );
      return status;
    } on PlatformException catch (e) {
      print('PlatformException purchaseLicense: $e');
      return ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'Error al iniciar compra: ${e.message ?? e}',
      );
    } catch (e) {
      print('Error purchaseLicense: $e');
      return const ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'Error inesperado al comprar',
      );
    }
  }

  /// Verifies if the user has purchased the license.
  /// Returns [ApklisLicensePaymentStatus] for detailed info.
  static Future<ApklisLicensePaymentStatus> verify() async {
    try {
      final status = await ApklisLicenseValidator.verifyUserLicense(_packageId);
      return status;
    } on PlatformException catch (e) {
      print('PlatformException verifyUserLicense: $e');
      return ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'Error al verificar licencia: ${e.message ?? e}',
      );
    } catch (e) {
      print('Error verifyUserLicense: $e');
      return const ApklisLicensePaymentStatus(
        paid: false,
        username: null,
        error: 'Error inesperado al verificar',
      );
    }
  }

  /// Simple boolean check for quick validation
  static Future<bool> isPurchased() async {
    final status = await verify();
    return status.paid;
  }

  /// Maps a license UUID to its corresponding license type name
  /// Returns null if UUID doesn't match any known license
  static String? getLicenseTypeFromUUID(String? uuid) {
    if (uuid == null) return null;

    if (uuid == _personalLicenseId) return 'personal';
    if (uuid == _proLicenseId) return 'pro';
    if (uuid == _enterpriseLicenseId) return 'enterprise';

    return null;
  }
}
