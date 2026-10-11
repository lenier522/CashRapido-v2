import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';

class CashIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double iconSize;
  final bool bordered;

  /// Elemento superpuesto en la esquina superior derecha (contadores, punto de
  /// "nuevo", etc.). El propio componente decide dónde colocarlo.
  final Widget? badge;

  const CashIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.iconColor,
    this.backgroundColor,
    this.size = 48,
    this.iconSize = 22,
    this.bordered = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color background =
        backgroundColor ??
        (isDark ? AppColors.surfaceDark2 : AppColors.surfaceVariantLight);

    final Color foreground =
        iconColor ??
        (isDark ? AppColors.textPrimaryDark : AppColors.textPrimary);

    final button = Material(
      color: Colors.transparent,
      child: Ink(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background,
          borderRadius: AppRadius.radiusLg,
          border: bordered
              ? Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                )
              : null,
        ),
        child: Stack(
          // El badge sobresale sin alterar el tamaño ni el área táctil.
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: InkWell(
                onTap: onPressed,
                borderRadius: AppRadius.radiusLg,
                child: Center(
                  child: Icon(icon, size: iconSize, color: foreground),
                ),
              ),
            ),
            if (badge != null) Positioned(top: -6, right: -6, child: badge!),
          ],
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }

    return Tooltip(message: tooltip!, child: button);
  }
}
