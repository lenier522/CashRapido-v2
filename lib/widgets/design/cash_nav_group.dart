import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import 'cash_card.dart';

/// Tarjeta que agrupa varias filas de navegación con separadores finos.
///
/// Reproduce el patrón «una sola tarjeta con varias filas» que ya usaba la
/// pantalla de Ajustes, pero como componente público reutilizable por las
/// nuevas pantallas de Perfil (Mi Cuenta, Comunidad, Funciones, Ayuda…).
class CashNavGroup extends StatelessWidget {
  final List<Widget> children;

  /// Color de la tarjeta. Por defecto, el de [CashCard] según el tema.
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;

  const CashNavGroup({
    super.key,
    required this.children,
    this.color,
    this.padding,
    this.margin,
  });

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 68,
            endIndent: AppSpacing.lg,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        );
      }
      rows.add(children[i]);
    }

    return CashCard(
      color: color,
      margin: margin,
      padding: padding ?? const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      // Material transparente local: las filas usan ListTile y necesitan un
      // Material propio por encima del color de la tarjeta para no perder el
      // efecto de pulsación.
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }
}

/// Fila de navegación reutilizable: icono, título, descripción y acción.
///
/// Es la unidad que comparten todas las pantallas de Perfil. Mantiene el área
/// táctil de [ListTile] y adapta colores a los modos claro y oscuro.
class CashNavRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;

  /// Widget a la derecha. Si es `null` y hay [onTap], se dibuja un chevron.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Atenúa la fila para indicar que la función todavía no está disponible
  /// (por ejemplo, un enlace pendiente de configurar) sin dejar de ser
  /// pulsable: al tocarla se explica el estado.
  final bool muted;

  /// Tinte del icono. Por defecto, el color de marca.
  final Color? iconColor;

  /// Fuerza u oculta el chevron cuando no se pasa [trailing].
  final bool? showChevron;

  const CashNavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.muted = false,
    this.iconColor,
    this.showChevron,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primaryText = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final Color chevronColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiary;
    final Color accent = iconColor ?? AppColors.primary;

    final bool effectiveChevron =
        showChevron ?? (onTap != null && trailing == null);

    return Opacity(
      opacity: muted ? 0.55 : 1,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isDark ? 0.18 : 0.12),
            borderRadius: AppRadius.radiusMd,
          ),
          child: Icon(icon, size: 20, color: accent),
        ),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondaryText,
                ),
              ),
        trailing:
            trailing ??
            (effectiveChevron
                ? Icon(Icons.chevron_right_rounded, color: chevronColor)
                : null),
        minVerticalPadding: AppSpacing.md,
      ),
    );
  }
}
