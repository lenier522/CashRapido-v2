import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Tipo semántico de un mensaje efímero.
enum CashSnackType { success, error, warning, info }

/// Mensajes efímeros (`SnackBar`) coherentes para toda la aplicación.
///
/// Antes de este componente cada pantalla construía su propio `SnackBar`: unas
/// veces con el estilo del tema, otras forzando `backgroundColor` a mano y casi
/// siempre sin ninguna señal más que el color. Aquí el resultado se comunica
/// con **icono + color + texto**, de modo que la información no depende sólo
/// del color (requisito de accesibilidad) y el estilo es el mismo en todas las
/// pantallas.
///
/// Los colores salen de `AppColors` y el `SnackBar` respeta el
/// `snackBarTheme` de `AppTheme` (forma, elevación, comportamiento flotante e
/// `insetPadding`), por lo que funciona igual en modo claro y oscuro. El tipo
/// [CashSnackType.info] no fija color de fondo: usa el del tema.
abstract final class CashSnack {
  const CashSnack._();

  /// Mensaje de operación completada correctamente.
  static void success(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    show(context, message, type: CashSnackType.success, action: action);
  }

  /// Mensaje de error. [message] debe describir la operación real que falló.
  static void error(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    show(context, message, type: CashSnackType.error, action: action);
  }

  /// Mensaje de advertencia: la operación terminó, pero conviene revisarla.
  static void warning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    show(context, message, type: CashSnackType.warning, action: action);
  }

  /// Mensaje informativo neutro. Conserva la superficie del tema.
  static void info(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) {
    show(context, message, type: CashSnackType.info, action: action);
  }

  /// Muestra [message] con la presentación del [type] indicado.
  static void show(
    BuildContext context,
    String message, {
    CashSnackType type = CashSnackType.info,
    SnackBarAction? action,
  }) {
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color foreground = switch (type) {
      CashSnackType.success || CashSnackType.error => Colors.white,
      // El ámbar del tema necesita texto oscuro para mantener el contraste.
      CashSnackType.warning => AppColors.textPrimary,
      CashSnackType.info =>
        isDark ? AppColors.textPrimaryDark : Colors.white,
    };
    final Color? background = switch (type) {
      CashSnackType.success => AppColors.income,
      CashSnackType.error => AppColors.error,
      CashSnackType.warning => AppColors.warning,
      CashSnackType.info => null,
    };
    final IconData icon = switch (type) {
      CashSnackType.success => Icons.check_circle_rounded,
      CashSnackType.error => Icons.error_rounded,
      CashSnackType.warning => Icons.warning_amber_rounded,
      CashSnackType.info => Icons.info_rounded,
    };

    messenger.showSnackBar(
      SnackBar(
        // `null` deja que el tema decida el fondo (mensajes informativos).
        backgroundColor: background,
        content: Row(
          children: [
            Icon(icon, size: 20, color: foreground),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
        action: action,
      ),
    );
  }
}
