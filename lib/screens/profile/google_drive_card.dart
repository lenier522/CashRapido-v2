import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_shadows.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_account_avatar.dart';
import '../../widgets/design/cash_snack.dart';
import 'google_drive_screen.dart';
import 'profile_helpers.dart';

/// Tarjeta destacada de Perfil con el estado real de Google Drive.
///
/// Refleja únicamente lo que la aplicación puede verificar: si hay una cuenta
/// con sesión iniciada, su correo, si está sincronizando y la fecha de la
/// última copia cuando el servicio la registra. Nunca muestra estados
/// ficticios.
class GoogleDriveCard extends StatefulWidget {
  const GoogleDriveCard({super.key});

  @override
  State<GoogleDriveCard> createState() => _GoogleDriveCardState();
}

class _GoogleDriveCardState extends State<GoogleDriveCard> {
  bool _connecting = false;

  Future<void> _connect() async {
    final AppProvider provider = context.read<AppProvider>();
    if (!provider.canSyncDrive) {
      showFeatureLockedDialog(context);
      return;
    }
    setState(() => _connecting = true);
    try {
      await provider.signInToGoogle();
      if (!mounted) return;
      if (provider.currentUser != null) {
        CashSnack.success(context, context.t('profile_drive_connected_msg'));
      }
    } catch (_) {
      if (mounted) {
        CashSnack.error(context, context.t('profile_drive_error'));
      }
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppProvider provider = context.watch<AppProvider>();
    final bool connected = provider.currentUser != null;
    final String? email = provider.currentUser?.email;
    final DateTime? lastBackup = provider.lastBackupDate;

    final String statusText = provider.isSyncing
        ? context.t('profile_drive_syncing')
        : connected
        ? context.t('profile_drive_connected')
        : context.t('profile_drive_disconnected');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.lime,
        borderRadius: AppRadius.radiusXxl,
        boxShadow: AppShadows.elevated,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CashAccountAvatar(
                imageUrl: provider.currentUser?.photoUrl,
                name: connected
                    ? (provider.currentUser?.displayName ?? email)
                    : null,
                fallbackIcon: Icons.cloud_rounded,
                size: 46,
                backgroundColor: AppColors.onLime.withValues(alpha: 0.14),
                foregroundColor: AppColors.onLime,
                borderColor: AppColors.onLime.withValues(alpha: 0.24),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('profile_drive_title'),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.onLime,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      connected
                          ? (email ?? context.t('profile_drive_connected'))
                          : context.t('profile_drive_not_connected_desc'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onLime.withValues(alpha: 0.78),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              _StatusPill(
                label: statusText,
                syncing: provider.isSyncing,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _LicensePill(label: licenseLabel(context, provider.licenseType)),
          if (connected) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(
                  Icons.history_rounded,
                  size: 16,
                  color: AppColors.onLime.withValues(alpha: 0.75),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    lastBackup != null
                        ? context.t('profile_drive_last_backup').replaceAll(
                            '{date}',
                            DateFormat('dd/MM/yyyy HH:mm').format(lastBackup),
                          )
                        : context.t('profile_drive_no_backup'),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onLime.withValues(alpha: 0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _DriveActionButton(
            label: !connected
                ? (_connecting
                      ? context.t('profile_drive_connecting')
                      : context.t('profile_drive_connect'))
                : context.t('profile_drive_manage'),
            icon: !connected ? Icons.login_rounded : Icons.tune_rounded,
            busy: _connecting,
            onPressed: !connected
                ? _connect
                : () => pushProfileScreen(context, const GoogleDriveScreen()),
          ),
        ],
      ),
    );
  }
}

/// Botón oscuro sobre la tarjeta lima.
class _DriveActionButton extends StatelessWidget {
  const _DriveActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onLime,
      borderRadius: AppRadius.radiusMd,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: busy ? null : onPressed,
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.lime),
                  ),
                )
              else
                Icon(icon, size: 18, color: AppColors.lime),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: AppColors.lime,
                    fontWeight: FontWeight.w700,
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

/// Píldora de estado sobre la tarjeta lima.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.syncing});

  final String label;
  final bool syncing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.onLime.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (syncing)
            const SizedBox(
              width: 12,
              height: 12,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.onLime),
              ),
            )
          else
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.onLime,
                shape: BoxShape.circle,
              ),
            ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.onLime,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta del tipo de licencia, dentro de la tarjeta lima.
class _LicensePill extends StatelessWidget {
  const _LicensePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: AppColors.onLime.withValues(alpha: 0.12),
        borderRadius: AppRadius.radiusFull,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.workspace_premium_rounded,
            size: 14,
            color: AppColors.onLime,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onLime,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
