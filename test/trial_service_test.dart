import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:cashrapido/licences/license_type.dart';
import 'package:cashrapido/services/trial_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ventana de prueba', () {
    test('los primeros 7 días cuentan como prueba activa', () {
      final DateTime start = DateTime.now().subtract(
        const Duration(days: 6, hours: 23),
      );

      expect(TrialService.isWithinWindow(start), isTrue);
      expect(TrialService.remaining(start), greaterThan(Duration.zero));
      expect(TrialService.duration, const Duration(days: 7));
    });

    test('al pasar los 7 días la prueba termina', () {
      final DateTime start = DateTime.now().subtract(
        const Duration(days: 7, hours: 1),
      );

      expect(TrialService.isWithinWindow(start), isFalse);
      expect(TrialService.remaining(start), Duration.zero);
      expect(TrialService.endsAt(start), start.add(TrialService.duration));
    });
  });

  group('detección de plan de pago', () {
    test('sin plan, la licencia gratuita no cuenta como pago', () async {
      SharedPreferences.setMockInitialValues({
        'license_type': LicenseType.free.index,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(TrialService.hasPaidPlan(prefs), isFalse);
      expect(TrialService.hasActivePlan(prefs), isFalse);
    });

    test('un plan vigente cuenta como pago', () async {
      final DateTime expires = DateTime.now().add(const Duration(days: 10));
      SharedPreferences.setMockInitialValues({
        'license_type': LicenseType.monthlyPro.index,
        'license_expiration_date': expires.toIso8601String(),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(TrialService.hasPaidPlan(prefs), isTrue);
      expect(TrialService.hasActivePlan(prefs), isTrue);
    });

    test('un plan caducado no cuenta como pago', () async {
      final DateTime expires = DateTime.now().subtract(const Duration(days: 1));
      SharedPreferences.setMockInitialValues({
        'license_type': LicenseType.monthlyPro.index,
        'license_expiration_date': expires.toIso8601String(),
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(TrialService.hasPaidPlan(prefs), isFalse);
      expect(TrialService.hasActivePlan(prefs), isFalse);
    });

    test('convertir durante la prueba conserva los datos, pero no desbloquea '
        'cuentas si el plan caducó', () async {
      SharedPreferences.setMockInitialValues({
        'license_type': LicenseType.weeklyPersonal.index,
        'license_expiration_date': DateTime.now()
            .subtract(const Duration(days: 5))
            .toIso8601String(),
        TrialService.convertedKey: true,
      });
      final SharedPreferences prefs = await SharedPreferences.getInstance();

      expect(TrialService.hasPaidPlan(prefs), isTrue);
      expect(TrialService.hasActivePlan(prefs), isFalse);
    });
  });

  group('estado de vencimiento', () {
    test('una prueba vencida sin plan requiere bloqueo', () async {
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
        'license_type': LicenseType.free.index,
      });

      expect(await TrialService.isExpiredWithoutPlan(), isTrue);
    });

    test('una prueba vencida con plan vigente no requiere bloqueo', () async {
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
        'license_type': LicenseType.monthlyPro.index,
        'license_expiration_date': DateTime.now()
            .add(const Duration(days: 10))
            .toIso8601String(),
      });

      expect(await TrialService.isExpiredWithoutPlan(), isFalse);
    });

    test('una instalación exenta no requiere bloqueo', () async {
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
        'license_type': LicenseType.free.index,
        TrialService.exemptKey: true,
      });

      expect(await TrialService.isExpiredWithoutPlan(), isFalse);
    });
  });

  group('fin de prueba sin borrado', () {
    late Directory tempDir;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('trial_test');
      Hive.init(tempDir.path);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await tempDir.delete(recursive: true).catchError((_) => tempDir);
    });

    test('dentro de los 7 días no se bloquea ni se borra nada', () async {
      await _seedTransactionBox();
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
        'license_type': LicenseType.free.index,
      });

      expect(await TrialService.enforceAtStartup(), isFalse);
      expect(await Hive.boxExists('transactions'), isTrue);
      await _expectSeedStillThere();
    });

    test('con plan vigente tampoco se bloquea aunque pasen 7 días', () async {
      await _seedTransactionBox();
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
        'license_type': LicenseType.monthlyEnterprise.index,
        'license_expiration_date': DateTime.now()
            .add(const Duration(days: 20))
            .toIso8601String(),
      });

      expect(await TrialService.enforceAtStartup(), isFalse);
      expect(await Hive.boxExists('transactions'), isTrue);
      await _expectSeedStillThere();
    });

    test('sin plan se avisa y los datos siguen intactos', () async {
      await _seedTransactionBox();
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
        'license_type': LicenseType.free.index,
        'custom_banks': <String>['BPA'],
        'streak_days': 12,
      });

      expect(await TrialService.enforceAtStartup(), isTrue);
      expect(await Hive.boxExists('transactions'), isTrue);
      await _expectSeedStillThere();

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(TrialService.lockedNoticeKey), isTrue);
      expect(prefs.getStringList('custom_banks'), <String>['BPA']);
      expect(prefs.getInt('streak_days'), 12);

      // El aviso no se repite en el siguiente arranque.
      expect(await TrialService.enforceAtStartup(), isFalse);
      expect(await Hive.boxExists('transactions'), isTrue);
      await _expectSeedStillThere();
    });

    test('el vencimiento en caliente solo avisa una vez', () async {
      SharedPreferences.setMockInitialValues({
        'trial_start_date': DateTime.now()
            .subtract(const Duration(days: 8))
            .toIso8601String(),
        'license_type': LicenseType.free.index,
      });

      expect(await TrialService.lockIfExpired(), isTrue);
      expect(await TrialService.lockIfExpired(), isFalse);
    });

    test('las instalaciones anteriores quedan exentas', () async {
      await _seedTransactionBox();
      SharedPreferences.setMockInitialValues({
        'seenOnboarding': true,
        'license_type': LicenseType.free.index,
      });

      expect(await TrialService.enforceAtStartup(), isFalse);
      expect(await Hive.boxExists('transactions'), isTrue);

      final SharedPreferences prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(TrialService.exemptKey), isTrue);
    });
  });
}

Future<void> _seedTransactionBox() async {
  final Box<dynamic> box = await Hive.openBox<dynamic>('transactions');
  await box.put('tx1', 'dato');
  await box.close();
}

Future<void> _expectSeedStillThere() async {
  final Box<dynamic> box = await Hive.openBox<dynamic>('transactions');
  expect(box.get('tx1'), 'dato');
  await box.close();
}
