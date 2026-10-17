import 'package:flutter/material.dart';

import '../../services/app_info.dart';
import '../../services/localization_service.dart';
import '../../services/official_links.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_section.dart';
import 'profile_helpers.dart';

/// Pantalla «Cómo tratamos tus datos».
///
/// Describe el comportamiento real de la aplicación, verificado en el código:
/// no existe una política de privacidad oficial publicada, así que no se
/// presenta como tal ni se enlaza a una URL inexistente.
class PrivacyInfoScreen extends StatelessWidget {
  const PrivacyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('privacy_title')),
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
          _section(
            context,
            icon: Icons.storage_rounded,
            title: context.t('privacy_local_title'),
            body: context.t('privacy_local_body'),
          ),
          _section(
            context,
            icon: Icons.lock_outline_rounded,
            title: context.t('privacy_security_title'),
            body: context.t('privacy_security_body'),
          ),
          _section(
            context,
            icon: Icons.cloud_outlined,
            title: context.t('privacy_drive_title'),
            body: context.t('privacy_drive_body'),
          ),
          _section(
            context,
            icon: Icons.smart_toy_outlined,
            title: context.t('privacy_ai_title'),
            body: context.t('privacy_ai_body'),
          ),
          _section(
            context,
            icon: Icons.file_present_outlined,
            title: context.t('privacy_export_title'),
            body: context.t('privacy_export_body'),
          ),
          _section(
            context,
            icon: Icons.delete_outline_rounded,
            title: context.t('privacy_delete_title'),
            body: context.t('privacy_delete_body'),
          ),
          _section(
            context,
            icon: Icons.mail_outline_rounded,
            title: context.t('privacy_contact_title'),
            body: context
                .t('privacy_contact_body')
                .replaceAll('{email}', OfficialLinks.supportEmail),
            onTap: () => openOfficialEmail(
              context,
              to: OfficialLinks.supportEmail,
              subject: context.t('privacy_contact_subject'),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            '${AppInfo.name} ${AppInfo.fullVersion}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.textTertiaryDark
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String body,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: CashSection(
        title: title,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
