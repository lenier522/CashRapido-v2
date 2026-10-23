import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/app_icon_service.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_snack.dart';
import 'profile_helpers.dart';

/// Pantalla «Icono de la app».
///
/// Muestra los iconos que el usuario puede elegir ([AppIconVariant.defaultIcon],
/// [AppIconVariant.playa] y [AppIconVariant.mar]). Los iconos estacionales
/// (Halloween y Navidad) **nunca** aparecen aquí: se aplican solos en sus
/// fechas desde [AppIconService].
///
/// Reglas de acceso:
/// * Solo se puede cambiar de icono con licencia Empresarial vigente
///   ([AppProvider.isEnterpriseActive]); sin ella, cada ficha muestra un
///   candado y al tocarla se explica el requisito.
/// * La elección se persiste, pero el icono visible lo decide siempre
///   `AppIconService.applyForLicense`, que además devuelve al icono por
///   defecto cuando vence el plan y fuerza el estacional en su fecha.
class AppIconScreen extends StatefulWidget {
  const AppIconScreen({super.key});

  @override
  State<AppIconScreen> createState() => _AppIconScreenState();
}

class _AppIconScreenState extends State<AppIconScreen> {
  /// Icono elegido por el usuario (`null` = aún no cargado / por defecto).
  AppIconVariant? _selected;

  @override
  void initState() {
    super.initState();
    _loadSelection();
  }

  Future<void> _loadSelection() async {
    final String? key = await AppIconService.selectedKey();
    if (!mounted) return;
    setState(() => _selected = AppIconService.byKey(key));
  }

  Future<void> _pick(AppIconVariant variant) async {
    final AppProvider provider = context.read<AppProvider>();

    // Sin licencia Empresarial vigente no se permite cambiar el icono.
    if (!provider.isEnterpriseActive) {
      showFeatureLockedDialog(context);
      return;
    }

    await AppIconService.saveSelected(variant);
    await AppIconService.applyForLicense(
      isEnterpriseActive: provider.isEnterpriseActive,
      selectedKey: variant.key,
    );

    if (!mounted) return;
    setState(() => _selected = variant);
    CashSnack.success(context, context.t('app_icon_updated_msg'));
  }

  @override
  Widget build(BuildContext context) {
    final bool canChange = context.watch<AppProvider>().isEnterpriseActive;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('app_icon_title')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.screenVertical,
        ),
        children: [
          Text(
            canChange
                ? context.t('app_icon_pick_hint')
                : context.t('app_icon_locked_note'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 0.78,
            children: [
              for (final AppIconVariant variant in _visibleIcons)
                _IconTile(
                  variant: variant,
                  isSelected: variant == _selected,
                  locked: !canChange,
                  onTap: () => _pick(variant),
                ),
            ],
          ),
          if (!canChange) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.t('app_icon_enterprise_note'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiary,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  /// Iconos visibles en el selector (los estacionales quedan fuera).
  static const List<AppIconVariant> _visibleIcons = [
    AppIconVariant.defaultIcon,
    AppIconVariant.playa,
    AppIconVariant.mar,
  ];
}

/// Ficha de un icono: vista previa redondeada, nombre y estado
/// (seleccionado / bloqueado).
class _IconTile extends StatelessWidget {
  final AppIconVariant variant;
  final bool isSelected;
  final bool locked;
  final VoidCallback onTap;

  const _IconTile({
    required this.variant,
    required this.isSelected,
    required this.locked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color accent = AppColors.primary;

    final String name = switch (variant) {
      AppIconVariant.defaultIcon => context.t('app_icon_default'),
      AppIconVariant.playa => context.t('app_icon_playa'),
      AppIconVariant.mar => context.t('app_icon_mar'),
      _ => variant.key,
    };

    return Semantics(
      selected: isSelected,
      button: true,
      label: name,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusMd,
        child: Opacity(
          opacity: locked ? 0.6 : 1,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
              borderRadius: AppRadius.radiusMd,
              border: Border.all(
                color: isSelected
                    ? accent
                    : (isDark ? AppColors.borderDark : AppColors.borderLight),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: AppRadius.radiusSm,
                    child: Image.asset(
                      variant.previewAsset,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? accent
                              : (isDark
                                  ? AppColors.textPrimaryDark
                                  : AppColors.textPrimary),
                        ),
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(
                        Icons.lock_rounded,
                        size: 14,
                        color: isDark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiary,
                      ),
                    ] else if (isSelected) ...[
                      const SizedBox(width: AppSpacing.xs),
                      Icon(Icons.check_circle_rounded, size: 16, color: accent),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
