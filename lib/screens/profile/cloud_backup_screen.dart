import 'package:material_ui/material_ui.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/cloud_sync_service.dart';
import '../../services/localization_service.dart';
import '../../services/supabase_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_card.dart';
import '../../widgets/design/cash_dialog.dart';
import '../../widgets/design/cash_snack.dart';
import 'profile_helpers.dart';

/// Copia de seguridad en la nube (Supabase).
///
/// Muestra el estado de la cuenta, permite guardar y recuperar el paquete
/// completo y controlar el guardado automático. La recuperación reemplaza los
/// datos locales, por eso siempre pide confirmación.
class CloudBackupScreen extends StatefulWidget {
  const CloudBackupScreen({super.key});

  @override
  State<CloudBackupScreen> createState() => _CloudBackupScreenState();
}

class _CloudBackupScreenState extends State<CloudBackupScreen> {
  bool _busy = false;

  Future<void> _connect() async {
    final AppProvider provider = context.read<AppProvider>();
    final bool connected = await connectGoogleAccount(context);
    if (!connected || !mounted) return;
    await provider.syncGoogleProfile();
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final bool ok = await CloudSyncService.pushNow();
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      CashSnack.success(context, context.t('cloud_save_success'));
    } else {
      CashSnack.error(context, context.t('cloud_save_error'));
    }
  }

  Future<void> _restore() async {
    final bool? confirm = await showCashConfirmDialog(
      context,
      title: context.t('cloud_restore_confirm_title'),
      message: context.t('cloud_restore_confirm_desc'),
      confirmLabel: context.t('cloud_restore'),
      cancelLabel: context.t('cancel'),
      icon: Icons.cloud_download_outlined,
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    final AppProvider app = context.read<AppProvider>();
    final BusinessProvider business = context.read<BusinessProvider>();
    final LoanProvider loans = context.read<LoanProvider>();

    final bool ok = await CloudSyncService.pullNow();
    if (ok) {
      app.refreshFromBoxes();
      business.refreshFromBoxes();
      loans.refreshFromBoxes();
    }
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      CashSnack.success(context, context.t('cloud_restore_success'));
    } else {
      CashSnack.error(context, context.t('cloud_restore_error'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondary = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final bool hasSession = SupabaseService.currentUser != null;
    final DateTime? lastSync = CloudSyncService.lastSync;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('cloud_title')),
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
            child: Row(
              children: [
                Icon(
                  hasSession
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_off_outlined,
                  size: 32,
                  color: hasSession ? theme.colorScheme.primary : secondary,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        SupabaseService.currentUser?.email ??
                            context.t('cloud_not_connected'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        lastSync == null
                            ? context.t('cloud_never_synced')
                            : context
                                  .t('cloud_last_sync')
                                  .replaceAll(
                                    '{date}',
                                    DateFormat('dd/MM/yyyy HH:mm')
                                        .format(lastSync),
                                  ),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            context.t('cloud_subtitle'),
            style: theme.textTheme.bodyMedium?.copyWith(color: secondary),
          ),
          const SizedBox(height: AppSpacing.xl),
          if (!hasSession)
            CashButton(
              label: context.t('cloud_connect'),
              icon: const Icon(Icons.login_rounded, size: 20),
              onPressed: _busy ? null : _connect,
            )
          else ...[
            CashButton(
              label: context.t('cloud_save_now'),
              icon: const Icon(Icons.cloud_upload_outlined, size: 20),
              loading: _busy,
              onPressed: _busy ? null : _save,
            ),
            const SizedBox(height: AppSpacing.md),
            CashButton(
              label: context.t('cloud_restore'),
              type: CashButtonType.secondary,
              icon: const Icon(Icons.cloud_download_outlined, size: 20),
              onPressed: _busy ? null : _restore,
            ),
            const SizedBox(height: AppSpacing.xl),
            CashCard(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.xs,
              ),
              child: SwitchListTile.adaptive(
                value: CloudSyncService.autoSyncEnabled,
                onChanged: _busy
                    ? null
                    : (bool value) async {
                        await CloudSyncService.setAutoSync(value);
                        if (mounted) setState(() {});
                      },
                contentPadding: EdgeInsets.zero,
                title: Text(
                  context.t('cloud_auto_sync'),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: Text(
                  context.t('cloud_auto_sync_desc'),
                  style: theme.textTheme.bodySmall?.copyWith(color: secondary),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              context.t('cloud_restore_warning'),
              style: theme.textTheme.bodySmall?.copyWith(color: secondary),
            ),
          ],
        ],
      ),
    );
  }
}
