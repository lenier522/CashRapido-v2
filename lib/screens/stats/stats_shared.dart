import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Textos y distribuciones compartidos por las tres vistas de Estadísticas.
///
/// Se centralizan aquí para que Analítica, Proyección y Calendario no
/// reimplementen la sustitución de plantillas ni la rejilla de métricas: una
/// sola definición mantiene las tres vistas coherentes entre sí.
abstract final class StatsShared {
  const StatsShared._();

  /// Plantilla localizada con sustituciones.
  ///
  /// El servicio de traducción no admite parámetros, así que la sustitución se
  /// hace aquí, en un único sitio, en lugar de repetirla en cada pantalla.
  static String text(
    BuildContext context,
    String key, [
    Map<String, String>? values,
  ]) {
    String result = context.t(key);
    if (values == null) return result;
    for (final MapEntry<String, String> entry in values.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  /// Nombre del mes y el año en la lengua activa ("marzo de 2026").
  static String monthLabel(BuildContext context, DateTime month) {
    final String locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMM(locale).format(month);
  }

  /// Fecha completa en la lengua activa.
  static String fullDate(BuildContext context, DateTime date) {
    final String locale = Localizations.localeOf(context).toString();
    return DateFormat.yMMMMd(locale).format(date);
  }

  /// Hora de un movimiento ("14:30"), o cadena vacía si no procede.
  static String timeOf(BuildContext context, DateTime date) {
    final String locale = Localizations.localeOf(context).toString();
    return DateFormat.Hm(locale).format(date);
  }

  /// Rejilla de tarjetas de métrica que se adapta al ancho disponible.
  ///
  /// [maxColumns] acota las columnas: el resumen del mes lo usa para cerrar un
  /// 2×2 en lugar de dejar una tarjeta suelta en una fila propia. Las tarjetas
  /// de una misma fila comparten altura, así que la rejilla queda alineada
  /// aunque unas lleven distintivo de variación y otras no.
  ///
  /// El número de columnas se deduce del ancho disponible y no de un salto fijo
  /// de pantalla: caben las columnas que quepan con al menos [minItemWidth] por
  /// tarjeta. El importe nunca se recorta (se ajusta en la propia tarjeta), así
  /// que el mínimo sólo busca que la cifra no quede diminuta.
  static Widget statGrid(
    BuildContext context,
    List<Widget> cards, {
    int maxColumns = 3,
  }) {
    assert(maxColumns >= 1);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double spacing = AppSpacing.md;
        const double minItemWidth = 128;
        int columns = constraints.maxWidth >= 3 * minItemWidth + spacing * 2
            ? 3
            : constraints.maxWidth >= 2 * minItemWidth + spacing
            ? 2
            : 1;
        if (columns > maxColumns) columns = maxColumns;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int row = 0; row * columns < cards.length; row++) ...<Widget>[
              if (row > 0) const SizedBox(height: spacing),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    for (int column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: spacing),
                      // La última fila puede quedar incompleta: el hueco se
                      // rellena para que la tarjeta suelta conserve su ancho.
                      Expanded(
                        child: row * columns + column < cards.length
                            ? cards[row * columns + column]
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Texto secundario que respeta el modo claro y oscuro.
  static Color secondaryText(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
  }
}
