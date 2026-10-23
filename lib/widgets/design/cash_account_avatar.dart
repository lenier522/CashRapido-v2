import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';

/// Avatar circular reutilizable para la cuenta de Google.
///
/// Muestra la foto real de la cuenta (`photoUrl`) cuando existe. Si no hay
/// foto, el recurso no carga (por ejemplo sin conexión) o se está descargando,
/// cae a la inicial del nombre y, en su defecto, a un icono. Nunca inventa una
/// imagen.
class CashAccountAvatar extends StatelessWidget {
  const CashAccountAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.fallbackIcon,
    this.size = 40,
    this.showRing = true,
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
  });

  /// URL de la foto de perfil de Google (`null` cuando no hay sesión).
  final String? imageUrl;

  /// Nombre para construir la inicial de respaldo.
  final String? name;

  /// Icono de respaldo cuando no hay foto ni nombre.
  final IconData? fallbackIcon;

  /// Diámetro del avatar.
  final double size;

  /// Dibuja un borde que separa el avatar del fondo.
  final bool showRing;

  /// Fondo del avatar. Por defecto usa la superficie del tema.
  final Color? backgroundColor;

  /// Color de la inicial o del icono de respaldo.
  final Color? foregroundColor;

  /// Color del borde cuando [showRing] es `true`.
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    final Color background =
        backgroundColor ??
        (isDark ? AppColors.surfaceDark2 : AppColors.surfaceVariantLight);
    final Color foreground = foregroundColor ?? theme.colorScheme.primary;
    final Color ring =
        borderColor ?? (isDark ? AppColors.borderDark : AppColors.borderLight);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: showRing ? Border.all(color: ring) : null,
      ),
      child: imageUrl != null && imageUrl!.isNotEmpty
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => _fallback(foreground),
              loadingBuilder: (context, child, progress) =>
                  progress == null ? child : _fallback(foreground),
            )
          : _fallback(foreground),
    );
  }

  Widget _fallback(Color foreground) {
    final String trimmed = name?.trim() ?? '';
    if (trimmed.isNotEmpty) {
      return Center(
        child: Text(
          trimmed[0].toUpperCase(),
          style: TextStyle(
            color: foreground,
            fontWeight: FontWeight.w700,
            fontSize: size * 0.42,
          ),
        ),
      );
    }
    return Center(
      child: Icon(
        fallbackIcon ?? Icons.person_rounded,
        color: foreground,
        size: size * 0.5,
      ),
    );
  }
}
