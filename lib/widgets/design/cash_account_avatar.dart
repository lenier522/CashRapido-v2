import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';

/// Avatar circular reutilizable para la cuenta de Google.
///
/// Muestra la foto de perfil cacheada localmente cuando existe, para que esté
/// disponible sin conexión y sin parpadeos al reabrir la app. Si no hay copia
/// local, intenta cargar la URL remota; si falla o no hay imagen, muestra la
/// inicial del nombre o un icono. Nunca inventa una imagen.
class CashAccountAvatar extends StatelessWidget {
  const CashAccountAvatar({
    super.key,
    this.imageUrl,
    this.imageBytes,
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

  /// Bytes de la foto cacheada localmente (disponible sin conexión).
  final Uint8List? imageBytes;

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

    final bool hasCached = imageBytes != null && imageBytes!.isNotEmpty;
    final bool hasRemote = imageUrl != null && imageUrl!.isNotEmpty;

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: showRing ? Border.all(color: ring) : null,
      ),
      child: hasCached
          ? Image.memory(
              imageBytes!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) =>
                  hasRemote ? _network(foreground) : _fallback(foreground),
            )
          : hasRemote
          ? _network(foreground)
          : _fallback(foreground),
    );
  }

  Widget _network(Color foreground) {
    return Image.network(
      imageUrl!,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => _fallback(foreground),
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return _fallback(foreground);
      },
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
