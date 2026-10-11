import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Contenedor común de los bottom sheets de la aplicación.
///
/// Aplica el `BottomSheetTheme` de `AppTheme`, añade asa de arrastre, jerarquía
/// de título y, sobre todo, reserva el espacio que ocupa el teclado para que
/// el botón principal nunca quede fuera de la pantalla.
class CashBottomSheet extends StatelessWidget {
  final Widget child;
  final String? title;
  final String? subtitle;
  final Widget? trailing;

  /// Envuelve [child] en un `SingleChildScrollView`.
  final bool scrollable;

  /// Fracción máxima de la altura de pantalla que puede ocupar la hoja.
  final double maxHeightFactor;

  final EdgeInsetsGeometry? padding;

  const CashBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.trailing,
    this.scrollable = true,
    this.maxHeightFactor = 0.9,
    this.padding,
  });

  /// Abre la hoja respetando el tema de la aplicación.
  static Future<T?> show<T>(
    BuildContext context, {
    required WidgetBuilder builder,
    bool isScrollControlled = true,
    bool isDismissible = true,
  }) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: isDismissible,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: builder,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color surface = isDark
        ? AppColors.surfaceDark
        : AppColors.surfaceLight;
    final Color textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    // Con el teclado abierto el inset inferior es el que hay que respetar;
    // cerrado, manda el área segura del dispositivo.
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * maxHeightFactor,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadius.xxxl),
            ),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding:
                  padding ??
                  const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.xl,
                    AppSpacing.lg,
                  ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                  if (title != null) ...[
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                title!,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.headlineSmall
                                    ?.copyWith(color: textColor),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: AppSpacing.xxs),
                                Text(
                                  subtitle!,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(color: secondaryColor),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (trailing != null) ...[
                          const SizedBox(width: AppSpacing.sm),
                          trailing!,
                        ],
                      ],
                    ),
                  ],
                  SizedBox(
                    height: title != null ? AppSpacing.xl : AppSpacing.sm,
                  ),
                  Flexible(
                    child: scrollable
                        ? SingleChildScrollView(
                            // El teclado puede crecer durante el scroll.
                            keyboardDismissBehavior:
                                ScrollViewKeyboardDismissBehavior.onDrag,
                            child: child,
                          )
                        : child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
