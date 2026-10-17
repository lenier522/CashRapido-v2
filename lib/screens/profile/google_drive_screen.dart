import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_account_avatar.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_dialog.dart';
import '../../widgets/design/cash_empty_state.dart';
import '../../widgets/design/cash_snack.dart';

/// Gestión de Google Drive: copiar, restaurar y desconectar la cuenta.
///
/// Reutiliza exactamente los métodos de sincronización de `AppProvider`
/// (`backupToCloud`, `restoreFromCloud`, `signOutFromGoogle`): no implementa
/// una segunda autenticación ni un segundo sistema de copias.
class GoogleDriveScreen extends StatefulWidget {
  const GoogleDriveScreen({super.key});

  @override
  State<GoogleDriveScreen> createState() => _GoogleDriveScreenState();
}

class _GoogleDriveScreenState extends State<GoogleDriveScreen> {
  Future<void> _backup() async {
    final AppProvider provider = context.read<AppProvider>();
    try {
      await provider.backupToCloud();
      if (mounted) CashSnack.success(context, context.t('drive_backup_success'));
    } catch (_) {
      if (mounted) {
        CashSnack.error(context, context.t('drive_backup_error'));
      }
    }
  }

  Future<void> _restore() async {
    final bool? confirm = await showCashConfirmDialog(
      context,
      title: context.t('drive_restore_confirm_title'),
      message: context.t('drive_restore_warning'),
      confirmLabel: context.t('confirm'),
      cancelLabel: context.t('cancel'),
      icon: Icons.cloud_download_outlined,
    );
    if (confirm != true || !mounted) return;

    final AppProvider provider = context.read<AppProvider>();
    try {
      await provider.restoreFromCloud();
      if (mounted) {
        CashSnack.success(context, context.t('drive_restore_success'));
      }
    } catch (_) {
      if (mounted) {
        CashSnack.error(context, context.t('drive_restore_error'));
      }
    }
  }

  Future<void> _disconnect() async {
    final bool? confirm = await showCashConfirmDialog(
      context,
      title: context.t('drive_disconnect_confirm'),
      message: context.t('drive_disconnect_desc'),
      confirmLabel: context.t('drive_disconnect'),
      cancelLabel: context.t('cancel'),
      icon: Icons.logout_rounded,
    );
    if (confirm != true || !mounted) return;

    final AppProvider provider = context.read<AppProvider>();
    await provider.signOutFromGoogle();
    if (mounted) CashSnack.info(context, context.t('drive_disconnected'));
  }

  @override
  Widget build(BuildContext context) {
    final AppProvider provider = context.watch<AppProvider>();
    final bool connected = provider.currentUser != null;
    final bool busy = provider.isSyncing;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('drive_title')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: connected
          ? _buildConnected(context, provider, busy)
          : CashEmptyState(
              icon: Icons.cloud_off_rounded,
              title: context.t('profile_drive_disconnected'),
              message: context.t('drive_disconnected_message'),
              buttonLabel: context.t('profile_drive_connect'),
              onButtonPressed: () async {
                try {
                  await provider.signInToGoogle();
                } catch (_) {
                  if (context.mounted) {
                    CashSnack.error(context, context.t('profile_drive_error'));
                  }
                }
              },
            ),
    );
  }

  Widget _buildConnected(
    BuildContext context,
    AppProvider provider,
    bool busy,
  ) {
    final DateTime? lastBackup = provider.lastBackupDate;
    final String? email = provider.currentUser?.email;

    return ListView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.screenHorizontal,
        vertical: AppSpacing.screenVertical,
      ),
      children: [
        CashCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              CashAccountAvatar(
                imageUrl: provider.currentUser?.photoUrl,
                name:
                    provider.currentUser?.displayName ??
                    provider.currentUser?.email,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      email ?? context.t('profile_drive_connected'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      lastBackup != null
                          ? context
                                .t('profile_drive_last_backup')
                                .replaceAll(
                                  '{date}',
                                  DateFormat(
                                    'dd/MM/yyyy HH:mm',
                                  ).format(lastBackup),
                                )
                          : context.t('profile_drive_no_backup'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        CashButton(
          label: context.t('drive_backup_now'),
          icon: const Icon(Icons.cloud_upload_outlined, size: 20),
          loading: busy,
          onPressed: busy ? null : _backup,
        ),
        const SizedBox(height: AppSpacing.md),
        CashButton(
          label: context.t('drive_restore'),
          type: CashButtonType.secondary,
          icon: const Icon(Icons.cloud_download_outlined, size: 20),
          onPressed: busy ? null : _restore,
        ),
        const SizedBox(height: AppSpacing.md),
        CashButton(
          label: context.t('drive_disconnect'),
          type: CashButtonType.outlined,
          icon: const Icon(Icons.logout_rounded, size: 20),
          onPressed: busy ? null : _disconnect,
        ),
        const SizedBox(height: AppSpacing.xl),
        Text(
          context.t('drive_privacy_note'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}
