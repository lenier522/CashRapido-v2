import 'package:cashrapido/models/currency_conversion.dart';
import 'package:cashrapido/providers/app_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('guarda pares, calcula inversas y cruces', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final AppProvider provider = AppProvider();

    await provider.replaceCurrencyConversions(const <CurrencyConversion>[
      CurrencyConversion(fromCode: 'USD', toCode: 'CUP', rate: 320),
      CurrencyConversion(fromCode: 'EUR', toCode: 'CUP', rate: 340),
    ]);

    expect(provider.currencyConversions.length, 2);
    expect(provider.getExchangeRate('USD'), 320);
    expect(provider.getExchangeRate('EUR'), 340);
    expect(provider.getConversionRate('CUP', 'USD'), closeTo(1 / 320, 1e-12));
    expect(provider.getConversionRate('USD', 'EUR'), closeTo(320 / 340, 1e-12));
    expect(provider.convertCurrency(10, 'USD', 'CUP'), 3200);

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('exchange_rate_pairs')?.length, 2);
    expect(prefs.getString('exchange_rates'), isNotNull);
  });
}
