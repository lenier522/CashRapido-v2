import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Barra de progreso del Design System.
///
/// Se usa para dos cosas distintas en la misma pantalla: la participación de
/// una categoría dentro del total y el consumo de su presupuesto mensual. En
/// ambos casos el color por sí solo nunca basta, así que el componente puede
/// llevar etiqueta a la izquierda y valor a la derecha.
///
/// El relleno se limita a 1 para que el texto siga siendo el que informa
/// cuando la métrica supera el objetivo.
class CashProgressBar extends StatelessWidget {
  /// Progreso normalizado. Se recorta al rango 0..1 para el relleno.
  final double value;

  /// Color del relleno. Por defecto, el verde de marca.
  final Color? color;

  /// Etiqueta opcional a la izquierda (por ejemplo, el presupuesto).
  final String? label;

  /// Valor opcional a la derecha (por ejemplo, `72%`).
  final String? valueLabel;

  /// Color del texto de [label].
  final Color? labelColor;

  /// Color del texto de [valueLabel].
  final Color? valueColor;

  /// Grosor de la pista.
  final double height;

  const CashProgressBar({
    super.key,
    required this.value,
    this.color,
    this.label,
    this.valueLabel,
    this.labelColor,
    this.valueColor,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color fill = color ?? AppColors.primary;
    final Color track = isDark
        ? AppColors.surfaceDark3
        : AppColors.surfaceVariantLight;
    final Color caption =
        labelColor ??
        (isDark ? AppColors.textSecondaryDark : AppColors.textSecondary);

    final double clamped = value.isNaN ? 0 : value.clamp(0.0, 1.0);

    final Widget bar = ClipRRect(
      borderRadius: AppRadius.radiusXs,
      child: Container(
        height: height,
        color: track,
        child: Align(
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: clamped,
            child: Container(color: fill),
          ),
        ),
      ),
    );

    if (label == null && valueLabel == null) return bar;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (label != null)
              Expanded(
                child: Text(
                  label!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(color: caption),
                ),
              )
            else
              const Spacer(),
            if (valueLabel != null)
              Text(
                valueLabel!,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: valueColor ?? fill,
                  fontWeight: FontWeight.w700,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        bar,
      ],
    );
  }
}
