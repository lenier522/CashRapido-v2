import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Acción rápida de las pantallas de resumen (Home, Billetero, Análisis).
///
/// Antes cada pantalla construía su propio bloque "icono + texto" con colores,
/// radios y sombras distintos. Este componente centraliza esa pieza dentro del
/// Design System: superficie con borde sutil, radio consistente, acento
/// configurable y estado bloqueado opcional.
class CashQuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool isLocked;

  const CashQuickAction({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.color,
    this.isLocked = false,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color accent = color ?? theme.colorScheme.primary;
    final Color surface = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final Color border = isDark ? AppColors.borderDark : AppColors.borderLight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: Ink(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: border),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.md,
              horizontal: AppSpacing.sm,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  // El candado sobresale sin afectar el layout de la celda.
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 44,
                      width: 44,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.11),
                        borderRadius: AppRadius.radiusMd,
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    if (isLocked)
                      Positioned(
                        right: -5,
                        top: -5,
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: AppColors.warning,
                            shape: BoxShape.circle,
                            border: Border.all(color: surface, width: 2),
                          ),
                          child: const Icon(
                            Icons.lock_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
