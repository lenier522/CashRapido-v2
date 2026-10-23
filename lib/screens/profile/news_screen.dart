import 'package:material_ui/material_ui.dart';

import '../../services/app_info.dart';
import '../../services/localization_service.dart';
import '../../services/official_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import 'profile_helpers.dart';

/// Apartado «Novedades».
///
/// CashRapido no mantiene un registro de cambios interno, así que esta pantalla
/// no inventa una lista de versiones: muestra la versión realmente instalada y
/// enlaza a la ficha de la tienda, donde se publica la información más
/// reciente.
class NewsScreen extends StatelessWidget {
  const NewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('community_news')),
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
          CashCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              children: [
                Icon(
                  Icons.new_releases_rounded,
                  size: 44,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  AppInfo.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${context.t('news_version_label')}: ${AppInfo.fullVersion}',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t('news_no_changelog'),
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          CashButton(
            label: context.t('news_open_store'),
            icon: const Icon(Icons.storefront_outlined, size: 20),
            onPressed: () => openOfficialLink(context, OfficialLinks.playStore),
          ),
        ],
      ),
    );
  }
}
