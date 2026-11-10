import '../models/currency_conversion.dart';

/// Cálculo de conversiones entre monedas a partir de una lista de tasas.
///
/// Las tasas guardadas no tienen que formar una estrella alrededor de la
/// moneda principal: cualquier par se puede conectar mediante otras monedas.
/// Por ejemplo, con `USD -> CUP = 320` y `EUR -> CUP = 340`, el servicio
/// deduce `USD -> EUR = 320 / 340` sin guardar esa tasa.
abstract final class CurrencyConversionService {
  /// Devuelve cuántas unidades de [toCode] vale una de [fromCode], o `null`
  /// si no existe un camino entre ambas monedas.
  static double? findRate(
    List<CurrencyConversion> conversions,
    String fromCode,
    String toCode,
  ) {
    final String from = _normalize(fromCode);
    final String to = _normalize(toCode);
    if (from.isEmpty || to.isEmpty) return null;
    if (from == to) return 1;

    // Grafo bidireccional: cada tasa se puede recorrer en ambos sentidos.
    final Map<String, List<MapEntry<String, double>>> graph =
        <String, List<MapEntry<String, double>>>{};
    for (final CurrencyConversion conversion in conversions) {
      if (!conversion.isValid) continue;
      graph
          .putIfAbsent(conversion.fromCode, () => <MapEntry<String, double>>[])
          .add(MapEntry(conversion.toCode, conversion.rate));
      graph
          .putIfAbsent(conversion.toCode, () => <MapEntry<String, double>>[])
          .add(MapEntry(conversion.fromCode, conversion.inverseRate));
    }

    // BFS: el primer camino encontrado es el más corto y estable.
    final Map<String, double> rates = <String, double>{from: 1};
    final List<String> queue = <String>[from];
    while (queue.isNotEmpty) {
      final String current = queue.removeAt(0);
      final double currentRate = rates[current]!;
      final List<MapEntry<String, double>>? edges = graph[current];
      if (edges == null) continue;

      for (final MapEntry<String, double> edge in edges) {
        if (rates.containsKey(edge.key)) continue;
        final double nextRate = currentRate * edge.value;
        if (!nextRate.isFinite || nextRate <= 0) continue;
        if (edge.key == to) return nextRate;
        rates[edge.key] = nextRate;
        queue.add(edge.key);
      }
    }

    return null;
  }

  /// Convierte [amount] de [fromCode] a [toCode].
  ///
  /// Si no hay una tasa configurada devuelve [amount] sin cambios, que es el
  /// comportamiento histórico de la app.
  static double convert(
    List<CurrencyConversion> conversions,
    double amount,
    String fromCode,
    String toCode,
  ) {
    final double? rate = findRate(conversions, fromCode, toCode);
    return rate == null ? amount : amount * rate;
  }

  static String _normalize(String code) => code.trim().toUpperCase();

  /// Convierte el mapa antiguo `moneda -> principal` en pares de conversión.
  ///
  /// Se usa para migrar instalaciones que ya tenían tasas guardadas antes de
  /// existir las conversiones entre pares arbitrarios.
  static List<CurrencyConversion> fromLegacyRates(
    Map<String, double> rates,
    String mainCurrency,
  ) {
    final String main = _normalize(mainCurrency);
    return rates.entries
        .where(
          (entry) =>
              _normalize(entry.key).isNotEmpty && _normalize(entry.key) != main,
        )
        .where((entry) => entry.value.isFinite && entry.value > 0)
        .map(
          (entry) => CurrencyConversion(
            fromCode: _normalize(entry.key),
            toCode: main,
            rate: entry.value,
          ),
        )
        .toList();
  }
}
