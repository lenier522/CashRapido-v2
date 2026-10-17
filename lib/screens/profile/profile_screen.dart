import 'package:flutter/material.dart';

import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_nav_group.dart';
import '../settings_screen.dart';
import 'community_screen.dart';
import 'google_drive_card.dart';
import 'help_privacy_screen.dart';
import 'invite_friends_screen.dart';
import 'main_features_screen.dart';
import 'my_account_screen.dart';
import 'profile_helpers.dart';

/// Pantalla «Perfil»: sustituye al antiguo hub «Más».
///
/// Estructura de la referencia:
/// 1. Tarjeta destacada de Google Drive (verde lima).
/// 2. Una única tarjeta con las seis secciones principales.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenHorizontal,
            AppSpacing.md,
            AppSpacing.screenHorizontal,
            AppSpacing.xxxl,
          ),
          children: [
            Text(
              context.t('nav_profile'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            const GoogleDriveCard(),
            const SizedBox(height: AppSpacing.lg),
            _buildOptions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildOptions(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;

    return CashNavGroup(
      color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight,
      children: [
        CashNavRow(
          icon: Icons.person_outline_rounded,
          title: context.t('profile_my_account'),
          subtitle: context.t('profile_my_account_desc'),
          onTap: () => pushProfileScreen(context, const MyAccountScreen()),
        ),
        CashNavRow(
          icon: Icons.groups_outlined,
          title: context.t('profile_community'),
          subtitle: context.t('profile_community_desc'),
          onTap: () => pushProfileScreen(context, const CommunityScreen()),
        ),
        CashNavRow(
          icon: Icons.widgets_outlined,
          title: context.t('profile_features'),
          subtitle: context.t('profile_features_desc'),
          onTap: () => pushProfileScreen(context, const MainFeaturesScreen()),
        ),
        CashNavRow(
          icon: Icons.settings_outlined,
          title: context.t('profile_settings'),
          subtitle: context.t('profile_settings_desc'),
          onTap: () => pushProfileScreen(context, const SettingsScreen()),
        ),
        CashNavRow(
          icon: Icons.card_giftcard_rounded,
          title: context.t('profile_invite'),
          subtitle: context.t('profile_invite_desc'),
          onTap: () => pushProfileScreen(context, const InviteFriendsScreen()),
        ),
        CashNavRow(
          icon: Icons.help_outline_rounded,
          title: context.t('profile_help_privacy'),
          subtitle: context.t('profile_help_privacy_desc'),
          onTap: () => pushProfileScreen(context, const HelpPrivacyScreen()),
        ),
      ],
    );
  }
}
