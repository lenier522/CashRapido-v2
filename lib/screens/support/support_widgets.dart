import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Estado vacío / de error de las pantallas de soporte.
///
/// Mantiene el mismo lenguaje visual en el chat y en la bandeja: icono en un
/// círculo suave, título, explicación y, opcionalmente, una acción.
class SupportStateView extends StatelessWidget {
  const SupportStateView({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.surfaceDark2
                    : AppColors.primaryLight,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: isDark ? AppColors.primary : AppColors.primaryDeep,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: secondary,
                  height: 1.4,
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Avatar circular con las iniciales del cliente.
class SupportAvatar extends StatelessWidget {
  const SupportAvatar({super.key, required this.initials, this.size = 46});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark3 : AppColors.primaryLight,
        shape: BoxShape.circle,
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.primary : AppColors.primaryDeep,
        ),
      ),
    );
  }
}

/// Etiqueta de hora para el chat: solo la hora si es de hoy, si no la fecha.
String formatSupportTime(DateTime date) {
  final DateTime now = DateTime.now();
  final bool isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return DateFormat(isToday ? 'HH:mm' : 'dd/MM HH:mm').format(date);
}

/// Etiqueta compacta para la bandeja: hora hoy, día/mes el resto.
String formatSupportListDate(DateTime date) {
  final DateTime now = DateTime.now();
  final bool isToday =
      date.year == now.year && date.month == now.month && date.day == now.day;
  return DateFormat(isToday ? 'HH:mm' : 'dd/MM').format(date);
}

/// Contador de mensajes sin leer.
class SupportUnreadBadge extends StatelessWidget {
  const SupportUnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: AppRadius.radiusFull,
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
