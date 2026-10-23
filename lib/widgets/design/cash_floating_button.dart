import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

/// Botón flotante del sistema de diseño.
///
/// Sólo existe en su variante "extended" (icono + texto): es la única con la
/// que el texto nunca queda recortado a 320–430 px. Para acciones de sólo icono
/// usa `FloatingActionButton` directamente.
///
/// Nota técnica: `FloatingActionButton.extended` coloca la etiqueta dentro de
/// un `Row` con restricciones **sin acotar** (vía `_ChildOverflowBox`), por lo
/// que un `Text` con `overflow: TextOverflow.ellipsis` nunca se recorta y
/// termina desbordando en pantallas estrechas. Para evitarlo, la etiqueta se
/// envuelve aquí en un [ConstrainedBox] con un ancho máximo calculado a partir
/// del ancho real de la pantalla.
class CashFloatingButton extends StatelessWidget {
  final VoidCallback onPressed;
  final IconData icon;
  final String label;
  final String? heroTag;

  /// Color de fondo. Por defecto [AppColors.primary].
  final Color? backgroundColor;

  /// Color del icono y del texto. Por defecto blanco.
  final Color? foregroundColor;

  const CashFloatingButton({
    super.key,
    required this.onPressed,
    required this.icon,
    required this.label,
    this.heroTag,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final Color fg = foregroundColor ?? Colors.white;

    // Ancho máximo de la etiqueta: el ancho de pantalla menos el espacio que
    // ocupan el icono, los paddings del FAB y los márgenes del Scaffold.
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double maxLabelWidth = (screenWidth - 140).clamp(72.0, 320.0);

    return FloatingActionButton.extended(
      heroTag: heroTag,
      onPressed: onPressed,
      backgroundColor: backgroundColor ?? AppColors.primary,
      foregroundColor: fg,
      elevation: 4,
      highlightElevation: 8,
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
      icon: Icon(icon, size: 20, color: fg),
      label: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxLabelWidth),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: fg,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
