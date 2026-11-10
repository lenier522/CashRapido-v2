import 'package:cashrapido/models/currency_conversion.dart';
import 'package:cashrapido/services/currency_conversion_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurrencyConversionService', () {
    final List<CurrencyConversion> conversions = <CurrencyConversion>[
      const CurrencyConversion(fromCode: 'USD', toCode: 'CUP', rate: 320),
      const CurrencyConversion(fromCode: 'EUR', toCode: 'CUP', rate: 340),
      const CurrencyConversion(fromCode: 'MLC', toCode: 'USD', rate: 0.9),
    ];

    test('convierte de USD a CUP', () {
      expect(
        CurrencyConversionService.findRate(conversions, 'USD', 'CUP'),
        320,
      );
    });

    test('convierte de CUP a USD usando la inversa', () {
      expect(
        CurrencyConversionService.findRate(conversions, 'CUP', 'USD'),
        closeTo(1 / 320, 1e-12),
      );
    });

    test('calcula cruces entre monedas sin tasa directa', () {
      expect(
        CurrencyConversionService.findRate(conversions, 'USD', 'EUR'),
        closeTo(320 / 340, 1e-12),
      );
      expect(
        CurrencyConversionService.findRate(conversions, 'EUR', 'USD'),
        closeTo(340 / 320, 1e-12),
      );
    });

    test('usa cadenas de más de una tasa', () {
      expect(
        CurrencyConversionService.findRate(conversions, 'MLC', 'CUP'),
        closeTo(0.9 * 320, 1e-12),
      );
    });

    test('devuelve null si no hay camino entre las monedas', () {
      expect(
        CurrencyConversionService.findRate(
          const <CurrencyConversion>[
            CurrencyConversion(fromCode: 'USD', toCode: 'CUP', rate: 320),
          ],
          'EUR',
          'CUP',
        ),
        isNull,
      );
    });

    test('convierte el monto y conserva el valor sin tasa', () {
      expect(
        CurrencyConversionService.convert(conversions, 10, 'USD', 'CUP'),
        3200,
      );
      expect(
        CurrencyConversionService.convert(conversions, 10, 'JPY', 'CUP'),
        10,
      );
    });

    test('migra el mapa antiguo de tasas contra la moneda principal', () {
      final List<CurrencyConversion> migrated =
          CurrencyConversionService.fromLegacyRates(<String, double>{
            'USD': 320,
            'EUR': 340,
            'CUP': 1,
          }, 'CUP');

      expect(migrated.length, 2);
      expect(migrated[0].fromCode, 'USD');
      expect(migrated[0].toCode, 'CUP');
      expect(migrated[0].rate, 320);
      expect(migrated[1].fromCode, 'EUR');
    });
  });

  group('CurrencyConversion', () {
    test('detecta el mismo par en ambas direcciones', () {
      const CurrencyConversion usdCup = CurrencyConversion(
        fromCode: 'USD',
        toCode: 'CUP',
        rate: 320,
      );
      const CurrencyConversion cupUsd = CurrencyConversion(
        fromCode: 'CUP',
        toCode: 'USD',
        rate: 0.003125,
      );

      expect(usdCup.samePair(cupUsd), isTrue);
      expect(usdCup.inverseRate, closeTo(0.003125, 1e-12));
    });

    test('sobrevive a la serialización JSON', () {
      const CurrencyConversion original = CurrencyConversion(
        fromCode: 'USD',
        toCode: 'CUP',
        rate: 320,
      );
      final CurrencyConversion restored = CurrencyConversion.fromJson(
        original.toJson(),
      );

      expect(restored.fromCode, 'USD');
      expect(restored.toCode, 'CUP');
      expect(restored.rate, 320);
      expect(restored.isValid, isTrue);
    });
  });
}
