import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Campo de formulario con la misma piel que [CashInput] pero que actúa como
/// botón: al pulsarlo la pantalla abre el selector que corresponda (bottom
/// sheet, diálogo o ruta).
///
/// Sustituye a los `DropdownButton` antiguos sin alterar la lógica del
/// formulario: este componente no guarda estado ni toma decisiones, sólo
/// presenta la selección y delega el gesto en [onTap].
class CashSelectorField extends StatelessWidget {
  /// Etiqueta pequeña situada sobre el valor dentro del propio campo.
  final String label;

  /// Valor seleccionado. Si es `null` o vacío se muestra [placeholder].
  final String? value;

  /// Texto mostrado cuando todavía no hay valor.
  final String? placeholder;

  /// Icono a la izquierda. Se ignora si se pasa [leading].
  final IconData? icon;

  /// Elemento a la izquierda con prioridad sobre [icon] (avatar de categoría,
  /// insignia de cuenta, etc.).
  final Widget? leading;

  /// Texto corto a la derecha (código de moneda, saldo, tipo de cuenta).
  final String? trailing;

  /// Texto de ayuda debajo del campo.
  final String? helperText;

  /// Error contextual. Cuando no es `null` el borde se pinta de error.
  final String? errorText;

  final VoidCallback? onTap;

  /// Color de acento del valor (por ejemplo, el color de la categoría).
  final Color? accent;

  /// Muestra el chevron. Se oculta cuando el campo es sólo informativo.
  final bool showChevron;

  /// Versión compacta (altura ~44 px) para filas de formulario con poco
  /// espacio vertical. Mantiene la misma lógica y jerarquía visual.
  final bool dense;

  const CashSelectorField({
    super.key,
    required this.label,
    this.value,
    this.placeholder,
    this.icon,
    this.leading,
    this.trailing,
    this.helperText,
    this.errorText,
    this.onTap,
    this.accent,
    this.showChevron = true,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color textColor = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color secondaryColor = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final Color fill = isDark
        ? AppColors.surfaceDark2
        : AppColors.surfaceVariantLight;
    final Color border = isDark ? AppColors.borderDark : AppColors.borderLight;

    final bool hasError = errorText != null && errorText!.isNotEmpty;
    final bool isEmpty = value == null || value!.trim().isEmpty;
    final String shown = isEmpty ? (placeholder ?? '') : value!;
    final Color accentColor =
        accent ?? (isDark ? AppColors.primary : AppColors.primaryDark);

    Widget field = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: BoxConstraints(minHeight: dense ? 44 : 58),
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: dense ? AppSpacing.xxs : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(
          color: hasError ? AppColors.error : border,
          width: hasError ? 1.4 : 1,
        ),
      ),
      child: Row(
        children: [
          if (leading != null)
            leading!
          else if (icon != null)
            Icon(
              icon,
              size: dense ? 18 : 21,
              color: isEmpty ? secondaryColor : accentColor,
            ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: hasError ? AppColors.error : secondaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  shown,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: isEmpty ? secondaryColor : textColor,
                    fontWeight: isEmpty ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null && trailing!.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                trailing!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: secondaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          if (showChevron) ...[
            const SizedBox(width: AppSpacing.xs),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 22,
              color: secondaryColor,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      field = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.radiusLg,
          child: field,
        ),
      );
    }

    if (helperText == null && !hasError) return field;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        field,
        const SizedBox(height: AppSpacing.xs),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            hasError ? errorText! : helperText!,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: hasError ? AppColors.error : secondaryColor,
            ),
          ),
        ),
      ],
    );
  }
}
