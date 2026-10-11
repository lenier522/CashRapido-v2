import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../theme/app_shadows.dart';

enum CashButtonType { primary, secondary, outlined, danger }

class CashButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final Widget? icon;
  final CashButtonType type;
  final bool fullWidth;
  final bool loading;
  final double height;

  const CashButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.type = CashButtonType.primary,
    this.fullWidth = true,
    this.loading = false,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color backgroundColor;
    final Color foregroundColor;
    final Color? borderColor;

    switch (type) {
      case CashButtonType.primary:
        backgroundColor = AppColors.primary;
        foregroundColor = isDark ? AppColors.backgroundDark : Colors.white;
        borderColor = null;

      case CashButtonType.secondary:
        backgroundColor = isDark
            ? AppColors.surfaceDark2
            : AppColors.primaryLight;
        foregroundColor = isDark ? AppColors.primary : AppColors.primaryDark;
        borderColor = null;

      case CashButtonType.outlined:
        backgroundColor = Colors.transparent;
        foregroundColor = isDark ? AppColors.primary : AppColors.primaryDark;
        borderColor = AppColors.primary;

      case CashButtonType.danger:
        backgroundColor = AppColors.error;
        foregroundColor = Colors.white;
        borderColor = null;
    }

    Widget buttonContent;

    if (loading) {
      buttonContent = SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(
          strokeWidth: 2.4,
          valueColor: AlwaysStoppedAnimation<Color>(foregroundColor),
        ),
      );
    } else if (icon != null) {
      buttonContent = Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon!,
          const SizedBox(width: AppSpacing.sm),
          // Flexible para que una etiqueta larga con fuente alternativa o con
          // escala de texto grande se recorte en vez de desbordar el botón.
          Flexible(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      );
    } else {
      buttonContent = Text(label, maxLines: 1, overflow: TextOverflow.ellipsis);
    }

    final ButtonStyle style = FilledButton.styleFrom(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.md,
      ),
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
      side: borderColor == null
          ? BorderSide.none
          : BorderSide(color: borderColor, width: 1.2),
      textStyle: Theme.of(
        context,
      ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      elevation: 0,
    );

    Widget button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: style,
      child: buttonContent,
    );

    if (type == CashButtonType.primary && onPressed != null && !loading) {
      button = DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: AppRadius.radiusLg,
          boxShadow: AppShadows.primaryButton,
        ),
        child: button,
      );
    }

    if (!fullWidth) {
      return IntrinsicWidth(child: button);
    }

    // El ancho completo solo se aplica si el padre impone un ancho limitado.
    // Dentro de un Row el ancho es infinito y stretching provocaria el error
    // "BoxConstraints forces an infinite width"; en ese caso el boton se
    // ajusta a su contenido (mismo resultado que fullWidth: false).
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (!constraints.hasBoundedWidth) {
          return IntrinsicWidth(child: button);
        }
        return SizedBox(width: double.infinity, child: button);
      },
    );
  }
}
