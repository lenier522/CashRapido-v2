import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashrapido/licences/license_type.dart';
import 'package:cashrapido/services/trial_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ventana de prueba', () {
    test('las primeras 48 horas cuentan como prueba activa', () {
      final DateTime start = DateTime.now().subtract(
        const Duration(hours: 47),
      );

      expect(TrialService.isWithinWindow(start), isTrue);
      expect(TrialService.remaining(start), greaterThan(Duration.zero));
    });

    test('al pasar las 48 horas la prueba termina', () {
      final DateTime start = DateTime.now().subtract(
        const Duration(hours: 49),
      );

      expect(TrialService.isWithinWindow(start), isFalse);
      expect(TrialService.remaining(start), Duration.zero);
      expect(
        TrialService.endsAt(start),
        start.add(const Duration(hours: 48)),
      );
    });
  });

  group('detección de plan de pago', () {
    test('sin plan, la licencia gratuita no cuenta como pago', () async {
      SharedPreferences.setMockInitialValues({
        'license_type': LicenseType.free.index,
      });
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      expect(TrialService.hasPaidPlan(prefs), isFalse);
    });

    test('un plan vigente cuenta como pago', () async {
      final DateTime expires = DateTime.now().add(const Duration(days: 10));
      SharedPreferences.setMockInitialValues({
        'license_type': LicenseType.monthlyPro.index,
        'license_expiration_date': expires.toIso8601String(),
      });
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      expect(TrialService.hasPaidPlan(prefs), isTrue);
    });

    test('un plan caducado no cuenta como pago', () async {
      final DateTime expires = DateTime.now().subtract(
        const Duration(days: 1),
      );
      SharedPreferences.setMockInitialValues({
        'license_type': LicenseType.monthlyPro.index,
        'license_expiration_date': expires.toIso8601String(),
      });
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      expect(TrialService.hasPaidPlan(prefs), isFalse);
    });

    test('convertir durante la prueba conserva los datos para siempre', () async {
      SharedPreferences.setMockInitialValues({
        'license_type': LicenseType.weeklyPersonal.index,
        'license_expiration_date': DateTime.now()
            .subtract(const Duration(days: 5))
            .toIso8601String(),
        TrialService.convertedKey: true,
      });
      final SharedPreferences prefs =
          await SharedPreferences.getInstance();

      expect(TrialService.hasPaidPlan(prefs), isTrue);
    });
  });

  group('borrado de datos al terminar la prueba', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('trial_test');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
    });

    test('dentro de las 48 horas no se borra nada', () async {
      await _seedTransactionBox();
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'license_type': LicenseType.free.index,
      });

      expect(await TrialService.enforceAtStartup(), isFalse);
      expect(await Hive.boxExists('transactions'), isTrue);
    });

    test('con plan adquirido tampoco se borra aunque pasen 48 horas', () async {
      await _seedTransactionBox();
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(hours: 72))
            .toIso8601String(),
        'license_type': LicenseType.monthlyEnterprise.index,
        'license_expiration_date': DateTime.now()
            .add(const Duration(days: 20))
            .toIso8601String(),
      });

      expect(await TrialService.enforceAtStartup(), isFalse);
      expect(await Hive.boxExists('transactions'), isTrue);
    });

    test('sin plan se borran cajas y preferencias una sola vez', () async {
      await _seedTransactionBox();
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(hours: 49))
            .toIso8601String(),
        'license_type': LicenseType.free.index,
        'custom_banks': <String>['BPA'],
        'streak_days': 12,
      });

      expect(await TrialService.enforceAtStartup(), isTrue);
      expect(await Hive.boxExists('transactions'), isFalse);

      final SharedPreferences prefs =
          await SharedPreferences.getInstance();
      expect(prefs.getBool(TrialService.wipedKey), isTrue);
      expect(prefs.getStringList('custom_banks'), isNull);
      expect(prefs.getInt('streak_days'), isNull);

      // El borrado no se repite en el siguiente arranque.
      expect(await TrialService.enforceAtStartup(), isFalse);
    });

    test('las instalaciones anteriores quedan exentas', () async {
      await _seedTransactionBox();
      SharedPreferences.setMockInitialValues({
        'seenOnboarding': true,
        'license_type': LicenseType.free.index,
      });

      expect(await TrialService.enforceAtStartup(), isFalse);
      expect(await Hive.boxExists('transactions'), isTrue);

      final SharedPreferences prefs =
          await SharedPreferences.getInstance();
      expect(prefs.getBool(TrialService.exemptKey), isTrue);
    });
  });
}

Future<void> _seedTransactionBox() async {
  final Box<dynamic> box = await Hive.openBox<dynamic>('transactions');
  await box.put('tx1', 'dato');
  await box.close();
}
