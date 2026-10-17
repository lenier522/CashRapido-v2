import 'package:flutter/material.dart';

import '../../services/localization_service.dart';
import '../../services/official_links.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_nav_group.dart';
import '../../widgets/design/cash_section.dart';
import 'news_screen.dart';
import 'profile_helpers.dart';

/// Apartado «Comunidad» de Perfil.
///
/// Dos grupos: «Contribuye y valora» (comunidad, novedades y valoración) y
/// «Redes Sociales». Sólo abre enlaces reales configurados en el proyecto; las
/// redes que aún no tienen URL muestran su estado de «pendiente».
class CommunityScreen extends StatelessWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('community_title')),
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
          // ── Contribuye y valora ──────────────────────────────────────────
          CashSection(
            title: context.t('community_contribute'),
            child: CashNavGroup(
              children: [
                CashNavRow(
                  icon: Icons.forum_outlined,
                  title: context.t('community_group'),
                  subtitle: context.t('community_group_desc'),
                  onTap: () => openOfficialLink(
                    context,
                    OfficialLinks.community,
                  ),
                ),
                CashNavRow(
                  icon: Icons.new_releases_outlined,
                  title: context.t('community_news'),
                  subtitle: context.t('community_news_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const NewsScreen()),
                ),
                CashNavRow(
                  icon: Icons.star_outline_rounded,
                  title: context.t('community_rate'),
                  subtitle: context.t('community_rate_desc'),
                  onTap: () =>
                      openOfficialLink(context, OfficialLinks.playStore),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Redes Sociales ───────────────────────────────────────────────
          CashSection(
            title: context.t('community_social'),
            child: CashNavGroup(
              children: [
                _socialRow(
                  context,
                  icon: Icons.discord,
                  label: context.t('social_discord'),
                  url: OfficialLinks.discord,
                ),
                _socialRow(
                  context,
                  icon: Icons.camera_alt_outlined,
                  label: context.t('social_instagram'),
                  url: OfficialLinks.instagram,
                ),
                _socialRow(
                  context,
                  icon: Icons.facebook,
                  label: context.t('social_facebook'),
                  url: OfficialLinks.facebook,
                ),
                _socialRow(
                  context,
                  icon: Icons.ondemand_video_rounded,
                  label: context.t('social_youtube'),
                  url: OfficialLinks.youtube,
                ),
                _socialRow(
                  context,
                  icon: Icons.tiktok,
                  label: context.t('social_tiktok'),
                  url: OfficialLinks.tiktok,
                ),
                CashNavRow(
                  icon: Icons.mail_outline_rounded,
                  title: context.t('social_contact'),
                  subtitle: context.t('social_contact_desc'),
                  onTap: () => openOfficialEmail(
                    context,
                    to: OfficialLinks.supportEmail,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Fila de red social: enlace real cuando existe, estado pendiente si no.
  Widget _socialRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String? url,
  }) {
    final bool configured = url != null;
    return CashNavRow(
      icon: icon,
      title: label,
      subtitle: configured
          ? null
          : context.t('link_pending_short'),
      muted: !configured,
      onTap: configured
          ? () => openOfficialLink(context, url)
          : () => showPendingLinkDialog(context),
    );
  }
}
