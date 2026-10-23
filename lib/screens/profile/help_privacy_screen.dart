import 'package:material_ui/material_ui.dart';

import '../../services/app_info.dart';
import '../../services/localization_service.dart';
import '../../services/official_links.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_nav_group.dart';
import '../../widgets/design/cash_section.dart';
import '../info_screens.dart';
import 'google_drive_screen.dart';
import 'privacy_info_screen.dart';
import 'profile_helpers.dart';

/// Apartado «Ayuda y privacidad» de Perfil.
///
/// Reúne ayuda, soporte, privacidad y la información legal y de la aplicación.
/// Reutiliza las pantallas y diálogos existentes (`HelpCenterScreen`,
/// `TermsScreen`, `showLicensePage`, `showAboutDialog`) y centraliza las
/// direcciones en [OfficialLinks]. No inventa políticas ni URLs.
class HelpPrivacyScreen extends StatelessWidget {
  const HelpPrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('help_privacy_title')),
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
          // ── Ayuda y soporte ──────────────────────────────────────────────
          CashSection(
            title: context.t('help_support_group'),
            child: CashNavGroup(
              children: [
                CashNavRow(
                  icon: Icons.help_outline_rounded,
                  title: context.t('help_faq'),
                  subtitle: context.t('help_center_subtitle'),
                  onTap: () =>
                      pushProfileScreen(context, const HelpCenterScreen()),
                ),
                CashNavRow(
                  icon: Icons.mail_outline_rounded,
                  title: context.t('help_contact'),
                  subtitle: OfficialLinks.supportEmail,
                  onTap: () => openOfficialEmail(
                    context,
                    to: OfficialLinks.supportEmail,
                    subject: context.t('help_contact_subject'),
                  ),
                ),
                CashNavRow(
                  icon: Icons.bug_report_outlined,
                  title: context.t('help_report_bug'),
                  onTap: () => openOfficialEmail(
                    context,
                    to: OfficialLinks.supportEmail,
                    subject: context.t('help_report_bug_subject'),
                  ),
                ),
                CashNavRow(
                  icon: Icons.lightbulb_outline_rounded,
                  title: context.t('help_send_suggestion'),
                  onTap: () => openOfficialEmail(
                    context,
                    to: OfficialLinks.supportEmail,
                    subject: context.t('help_send_suggestion_subject'),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Privacidad y datos ───────────────────────────────────────────
          CashSection(
            title: context.t('privacy_group'),
            child: CashNavGroup(
              children: [
                CashNavRow(
                  icon: Icons.shield_outlined,
                  title: context.t('privacy_how_we_handle'),
                  subtitle: context.t('privacy_how_we_handle_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const PrivacyInfoScreen()),
                ),
                CashNavRow(
                  icon: Icons.cloud_outlined,
                  title: context.t('privacy_backup'),
                  subtitle: context.t('privacy_backup_desc'),
                  onTap: () =>
                      pushProfileScreen(context, const GoogleDriveScreen()),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.xl),

          // ── Información legal y de la aplicación ─────────────────────────
          CashSection(
            title: context.t('legal_group'),
            child: CashNavGroup(
              children: [
                CashNavRow(
                  icon: Icons.description_outlined,
                  title: context.t('terms'),
                  onTap: () =>
                      pushProfileScreen(context, const TermsScreen()),
                ),
                CashNavRow(
                  icon: Icons.code_rounded,
                  title: context.t('open_source'),
                  onTap: () => showLicensePage(
                    context: context,
                    applicationName: AppInfo.name,
                    applicationVersion: AppInfo.fullVersion,
                    applicationIcon: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                CashNavRow(
                  icon: Icons.info_outline_rounded,
                  title: context.t('about'),
                  subtitle: '${context.t('app_version_label')}: '
                      '${AppInfo.fullVersion}',
                  onTap: () => showAboutDialog(
                    context: context,
                    applicationName: AppInfo.name,
                    applicationVersion: AppInfo.fullVersion,
                    applicationIcon: Icon(
                      Icons.account_balance_wallet_rounded,
                      size: 48,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    children: [
                      Text(
                        '${context.t('about_developer_label')}: '
                        '${AppInfo.developer}',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(context.t('app_desc')),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
