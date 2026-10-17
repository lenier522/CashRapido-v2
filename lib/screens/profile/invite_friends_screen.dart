import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../services/localization_service.dart';
import '../../services/official_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_snack.dart';
import 'profile_helpers.dart';

/// Apartado «Invita a tus amigos».
///
/// Comparte el enlace oficial de descarga. No hay sistema de puntos ni de
/// referidos: el objetivo es difundir la aplicación, como pide el diseño.
class InviteFriendsScreen extends StatelessWidget {
  const InviteFriendsScreen({super.key});

  Future<void> _share(BuildContext context) async {
    final String text = context
        .t('invite_share_text')
        .replaceAll('{link}', OfficialLinks.invite);
    try {
      await SharePlus.instance.share(ShareParams(text: text));
    } catch (_) {
      if (context.mounted) {
        CashSnack.error(context, context.t('invite_share_error'));
      }
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: OfficialLinks.invite));
    if (context.mounted) {
      CashSnack.success(context, context.t('invite_copied'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('invite_title')),
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
          Icon(
            Icons.card_giftcard_rounded,
            size: 64,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t('invite_headline'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            context.t('invite_message'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          CashCard(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.t('invite_link_label'),
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: secondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.surfaceDark3
                        : AppColors.surfaceVariantLight,
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Text(
                    OfficialLinks.invite,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => _copy(context),
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    label: Text(context.t('invite_copy')),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          CashButton(
            label: context.t('invite_share'),
            icon: const Icon(Icons.share_rounded, size: 20),
            onPressed: () => _share(context),
          ),
          const SizedBox(height: AppSpacing.md),
          CashButton(
            label: context.t('invite_open_link'),
            type: CashButtonType.outlined,
            icon: const Icon(Icons.open_in_new_rounded, size: 20),
            onPressed: () =>
                openOfficialLink(context, OfficialLinks.invite),
          ),
        ],
      ),
    );
  }
}
