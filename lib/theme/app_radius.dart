import 'package:material_ui/material_ui.dart';

abstract final class AppRadius {
  /// Elementos prácticamente redondos.
  static const double xs = 6;

  /// Campos y botones pequeños.
  static const double sm = 10;

  /// Botones / chips / elementos compactos.
  static const double md = 14;

  /// Tarjetas estándar.
  static const double lg = 18;

  /// Tarjetas principales.
  static const double xl = 22;

  /// Tarjetas premium / hero.
  static const double xxl = 28;

  /// Bottom sheets y paneles grandes.
  static const double xxxl = 32;

  /// Forma circular.
  static const double full = 999;

  static const BorderRadius radiusXs = BorderRadius.all(Radius.circular(xs));

  static const BorderRadius radiusSm = BorderRadius.all(Radius.circular(sm));

  static const BorderRadius radiusMd = BorderRadius.all(Radius.circular(md));

  static const BorderRadius radiusLg = BorderRadius.all(Radius.circular(lg));

  static const BorderRadius radiusXl = BorderRadius.all(Radius.circular(xl));

  static const BorderRadius radiusXxl = BorderRadius.all(Radius.circular(xxl));

  static const BorderRadius radiusXxxl = BorderRadius.all(
    Radius.circular(xxxl),
  );

  /// Forma completamente redondeada (píldoras, chips, avatares).
  static const BorderRadius radiusFull = BorderRadius.all(
    Radius.circular(full),
  );
}
