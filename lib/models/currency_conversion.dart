/// Conversión entre dos monedas.
///
/// Se guarda una fila por par de monedas. La dirección original es la que
/// eligió el usuario, pero la conversión inversa siempre se puede calcular
/// dividiendo `1 / rate`. Así `USD -> CUP` y `CUP -> USD` funcionan sin
/// necesidad de guardar dos tasas distintas.
class CurrencyConversion {
  const CurrencyConversion({
    required this.fromCode,
    required this.toCode,
    required this.rate,
  });

  /// Código de la moneda de origen (ej. `USD`).
  final String fromCode;

  /// Código de la moneda de destino (ej. `CUP`).
  final String toCode;

  /// Cuántas unidades de [toCode] equivalen a una de [fromCode].
  final double rate;

  /// `true` cuando la tasa es un número positivo y finito.
  bool get isValid =>
      fromCode.isNotEmpty &&
      toCode.isNotEmpty &&
      fromCode != toCode &&
      rate.isFinite &&
      rate > 0;

  /// Tasa inversa (`toCode -> fromCode`).
  double get inverseRate => rate > 0 ? 1 / rate : 0;

  /// `true` si [other] representa el mismo par, sin importar la dirección.
  bool samePair(CurrencyConversion other) =>
      (fromCode == other.fromCode && toCode == other.toCode) ||
      (fromCode == other.toCode && toCode == other.fromCode);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'from': fromCode,
    'to': toCode,
    'rate': rate,
  };

  factory CurrencyConversion.fromJson(Map<String, dynamic> json) {
    final dynamic rawRate = json['rate'];
    return CurrencyConversion(
      fromCode: (json['from'] as String? ?? '').trim().toUpperCase(),
      toCode: (json['to'] as String? ?? '').trim().toUpperCase(),
      rate: rawRate is num
          ? rawRate.toDouble()
          : double.tryParse('$rawRate') ?? 0,
    );
  }

  @override
  String toString() => '1 $fromCode = $rate $toCode';
}
