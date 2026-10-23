import 'package:material_ui/material_ui.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';

/// Campo de moneda del sistema de diseño.
///
/// Presenta la moneda como una fila rica: avatar circular con el **símbolo**,
/// código como título y nombre localizado como subtítulo. Puramente
/// presentacional: informa de la selección actual y delega el gesto en
/// [onTap] (la pantalla abre su hoja de selección).
///
/// El nombre se localiza con las claves `currency_name_<codigo>` y cae al
/// nombre del modelo (o al propio código) para monedas personalizadas.
class CashCurrencyField extends StatelessWidget {
  /// Código de la moneda (ej. `USD`).
  final String code;

  /// Símbolo mostrado en el avatar (ej. `$`, `₱`, `€`).
  final String symbol;

  /// Nombre del modelo usado como respaldo cuando no hay clave localizada.
  final String name;

  final VoidCallback? onTap;

  const CashCurrencyField({
    super.key,
    required this.code,
    required this.symbol,
    required this.name,
    this.onTap,
  });

  String _displayName(BuildContext context) {
    final String key = 'currency_name_${code.toLowerCase()}';
    final String resolved = context.t(key);
    if (resolved != key) return resolved;
    return name.isEmpty ? code : name;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    final Color fill = isDark
        ? AppColors.surfaceDark2
        : AppColors.surfaceVariantLight;
    final Color border = isDark ? AppColors.borderDark : AppColors.borderLight;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: AppRadius.radiusLg,
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: isDark ? 0.18 : 0.10,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    symbol,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primaryDark,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      code,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _displayName(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Icon(Icons.chevron_right_rounded, size: 22, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}
