import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'cash_button.dart';

/// Diálogo de confirmación reutilizable.
///
/// Reúne la estructura que comparten las confirmaciones de la aplicación
/// (icono opcional, título, mensaje y dos acciones que devuelven `true` o
/// `false`) sin imponer el contenido ni el resultado: los textos y la decisión
/// siguen siendo de cada pantalla.
///
/// Se apoya por completo en el `dialogTheme` de `AppTheme` (superficie, forma,
/// elevación y tipografía), así que no fija colores propios y se adapta a los
/// modos claro y oscuro.
///
/// No sustituye a los diálogos informativos ni a los formularios dentro de un
/// diálogo: sólo cubre el patrón repetido «cancelar / confirmar» que hasta
/// ahora se reescribía en cada pantalla con botones distintos.
class CashConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;

  /// Cuando es `true`, la acción principal usa el color de peligro y el icono
  /// se tiñe con el color de error. Es el valor adecuado para eliminar,
  /// restablecer o vaciar datos.
  final bool destructive;

  /// Icono opcional mostrado sobre el título.
  final IconData? icon;

  /// Color explícito del icono. Por defecto, el color de error si
  /// [destructive] es `true` y el color de marca en caso contrario.
  final Color? iconColor;

  const CashConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    this.destructive = true,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color accent = iconColor ??
        (destructive ? AppColors.error : AppColors.primary);

    return AlertDialog(
      icon: icon == null ? null : Icon(icon, color: accent, size: 28),
      title: Text(title, textAlign: TextAlign.center),
      content: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color:
                  isDark ? AppColors.textSecondaryDark : AppColors.textSecondary,
            ),
      ),
      actions: [
        CashButton(
          label: cancelLabel,
          type: CashButtonType.outlined,
          fullWidth: false,
          height: 44,
          onPressed: () => Navigator.pop(context, false),
        ),
        const SizedBox(width: AppSpacing.sm),
        CashButton(
          label: confirmLabel,
          type: destructive ? CashButtonType.danger : CashButtonType.primary,
          fullWidth: false,
          height: 44,
          onPressed: () => Navigator.pop(context, true),
        ),
      ],
    );
  }
}

/// Abre un [CashConfirmDialog] y devuelve `true` si se confirma, `false` si se
/// cancela y `null` si se descarta tocando fuera o con el botón atrás.
///
/// Conserva exactamente la semántica de los `showDialog<bool>` que sustituye,
/// por lo que cada llamador sigue decidiendo qué hacer con el resultado.
Future<bool?> showCashConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
  IconData? icon,
  Color? iconColor,
  bool barrierDismissible = true,
}) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: barrierDismissible,
    builder: (BuildContext ctx) => CashConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
      icon: icon,
      iconColor: iconColor,
    ),
  );
}
