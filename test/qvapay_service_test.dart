import 'package:cashrapido/licences/license_type.dart';
import 'package:cashrapido/services/qvapay_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QvaPayService planes', () {
    test(
      'todos los planes de pago tienen un identificador y vuelven igual',
      () {
        for (final LicenseType type in LicenseType.values) {
          if (type == LicenseType.free) continue;

          final String planId = QvaPayService.planIdFor(type);
          expect(planId, isNotEmpty);
          expect(QvaPayService.licenseTypeForPlanId(planId), type);
        }
      },
    );

    test('la licencia gratuita no se puede comprar', () {
      expect(
        () => QvaPayService.planIdFor(LicenseType.free),
        throwsA(isA<QvaPayException>()),
      );
    });

    test('un plan desconocido no devuelve licencia', () {
      expect(QvaPayService.licenseTypeForPlanId('otro_plan'), isNull);
    });
  });

  group('QvaPayService fechas', () {
    test('interpreta la fecha del servidor como UTC', () {
      final DateTime? parsed = QvaPayService.parseExpiresAt(
        '2026-12-31 23:59:59',
      );

      expect(parsed, isNotNull);
      expect(parsed, DateTime.utc(2026, 12, 31, 23, 59, 59).toLocal());
    });

    test('devuelve null si la fecha no es válida', () {
      expect(QvaPayService.parseExpiresAt(null), isNull);
      expect(QvaPayService.parseExpiresAt(''), isNull);
      expect(QvaPayService.parseExpiresAt('no-es-fecha'), isNull);
    });
  });
}
