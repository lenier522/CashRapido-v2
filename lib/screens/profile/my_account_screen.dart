import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import '../../providers/app_provider.dart';
import '../../providers/business_provider.dart';
import '../../providers/loan_provider.dart';
import '../../services/localization_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_radius.dart';
import '../../theme/app_spacing.dart';
import '../../widgets/design/cash_button.dart';
import '../../widgets/design/cash_dialog.dart';
import '../../widgets/design/cash_nav_group.dart';
import '../../widgets/design/cash_snack.dart';
import '../licenses_screen.dart';
import 'account_details_screen.dart';
import 'app_icon_screen.dart';
import 'profile_helpers.dart';
import 'promo_code_screen.dart';

/// Apartado «Mi Cuenta» de Perfil.
///
/// Reúne cuenta, licencias, canje de códigos, exportación, importación y
/// restablecimiento. Todas las acciones reutilizan los métodos existentes de
/// los proveedores: no se duplica lógica de licencias, exportación ni copias.
class MyAccountScreen extends StatefulWidget {
  const MyAccountScreen({super.key});

  @override
  State<MyAccountScreen> createState() => _MyAccountScreenState();
}

class _MyAccountScreenState extends State<MyAccountScreen> {
  /// Identificador de la operación de datos en curso (evita reentradas).
  String? _busy;

  Future<void> _pickExportFormat() async {
    final AppProvider provider = context.read<AppProvider>();
    if (!provider.canExportExcel && !provider.canExportPDF) {
      showFeatureLockedDialog(context);
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) {
        final bool isDark = Theme.of(ctx).brightness == Brightness.dark;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Material(
              color: isDark ? AppColors.surfaceDark2 : AppColors.surfaceLight,
              borderRadius: AppRadius.radiusXl,
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Text(
                      context.t('export_choose_title'),
                      style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  CashNavRow(
                    icon: Icons.table_chart_outlined,
                    title: context.t('export_excel'),
                    subtitle: context.t('export_excel_sub'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _export('excel');
                    },
                  ),
                  CashNavRow(
                    icon: Icons.picture_as_pdf_outlined,
                    title: context.t('export_pdf'),
                    subtitle: context.t('export_pdf_sub'),
                    onTap: () {
                      Navigator.pop(ctx);
                      _export('pdf');
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _export(String format) async {
    if (_busy != null) return;
    final AppProvider provider = context.read<AppProvider>();
    final BusinessProvider business = context.read<BusinessProvider>();
    setState(() => _busy = 'export');
    try {
      final String path = format == 'excel'
          ? await provider.exportToExcel(
              businesses: business.businesses,
              products: business.products,
              sales: business.sales,
              businessExpenses: business.expenses,
            )
          : await provider.exportToPDF(
              businesses: business.businesses,
              products: business.products,
              sales: business.sales,
              businessExpenses: business.expenses,
            );
      if (!mounted) return;
      await provider.shareFile(path);
    } catch (_) {
      if (mounted) CashSnack.error(context, context.t('export_error'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _backupLocal() async {
    if (_busy != null) return;
    final AppProvider provider = context.read<AppProvider>();
    setState(() => _busy = 'backup');
    try {
      await provider.backupToLocal();
      if (!mounted) return;
      CashSnack.success(context, context.t('backup_success'));
    } catch (_) {
      if (mounted) CashSnack.error(context, context.t('backup_error'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _import() async {
    if (_busy != null) return;
    final AppProvider provider = context.read<AppProvider>();
    if (!provider.canImportData) {
      showFeatureLockedDialog(context);
      return;
    }

    final bool? confirm = await showCashConfirmDialog(
      context,
      title: context.t('confirm_import'),
      message: context.t('import_warning'),
      confirmLabel: context.t('confirm'),
      cancelLabel: context.t('cancel'),
      icon: Icons.file_upload_outlined,
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = 'import');
    try {
      final bool restored = await provider.restoreFromLocal();
      if (!mounted) return;
      if (restored) {
        CashSnack.success(context, context.t('success_restore'));
      }
    } catch (_) {
      if (mounted) CashSnack.error(context, context.t('import_error'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  /// Confirma el restablecimiento en dos pasos y ofrece una copia previa.
  Future<void> _reset() async {
    if (_busy != null) return;

    final bool? first = await showCashConfirmDialog(
      context,
      title: context.t('reset_warning_title'),
      message: context.t('reset_warning_desc'),
      confirmLabel: context.t('reset_confirm_first'),
      cancelLabel: context.t('cancel'),
      icon: Icons.delete_forever_outlined,
    );
    if (first != true || !mounted) return;

    // Paso intermedio: copia de seguridad opcional.
    final String? choice = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
        icon: const Icon(Icons.backup_outlined, color: AppColors.warning),
        title: Text(context.t('reset_backup_title')),
        content: Text(context.t('reset_backup_desc')),
        actionsOverflowButtonSpacing: AppSpacing.xs,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'backup'),
            child: Text(context.t('reset_backup_and_reset')),
          ),
          CashButton(
            label: context.t('reset_confirm_final_action'),
            type: CashButtonType.danger,
            fullWidth: false,
            height: 44,
            onPressed: () => Navigator.pop(ctx, 'reset'),
          ),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    // Captura de proveedores antes de cualquier `await` para no usar
    // `context` a través de una brecha asíncrona.
    final AppProvider appProvider = context.read<AppProvider>();
    final BusinessProvider businessProvider = context.read<BusinessProvider>();
    final LoanProvider loanProvider = context.read<LoanProvider>();

    if (choice == 'backup') {
      try {
        await appProvider.backupToLocal();
      } catch (_) {
        if (mounted) {
          CashSnack.error(context, context.t('backup_error'));
          return;
        }
      }
      if (!mounted) return;
    }

    setState(() => _busy = 'reset');
    try {
      await appProvider.resetAllData();
      await businessProvider.clearAllData();
      await loanProvider.clearAllData();
      if (!mounted) return;
      CashSnack.success(context, context.t('reset_success'));
    } catch (_) {
      if (mounted) CashSnack.error(context, context.t('reset_error'));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool busy = _busy != null;
    final bool canChangeIcon =
        context.watch<AppProvider>().isEnterpriseActive;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('account_title')),
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
          CashNavGroup(
            children: [
              CashNavRow(
                icon: Icons.badge_outlined,
                title: context.t('account_my_account'),
                subtitle: context.t('account_my_account_desc'),
                onTap: () =>
                    pushProfileScreen(context, const AccountDetailsScreen()),
              ),
              CashNavRow(
                icon: Icons.workspace_premium_outlined,
                title: context.t('account_licenses'),
                subtitle: context.t('account_licenses_desc'),
                onTap: () =>
                    pushProfileScreen(context, const LicensesScreen()),
              ),
              CashNavRow(
                icon: Icons.image_rounded,
                title: context.t('app_icon_title'),
                subtitle: context.t('app_icon_desc'),
                muted: !canChangeIcon,
                trailing: canChangeIcon
                    ? null
                    : Icon(
                        Icons.lock_rounded,
                        size: 18,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.textTertiaryDark
                            : AppColors.textTertiary,
                      ),
                onTap: () => pushProfileScreen(context, const AppIconScreen()),
              ),
              CashNavRow(
                icon: Icons.redeem_rounded,
                title: context.t('account_redeem'),
                subtitle: context.t('account_redeem_desc'),
                onTap: () =>
                    pushProfileScreen(context, const PromoCodeScreen()),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CashNavGroup(
            children: [
              CashNavRow(
                icon: Icons.ios_share_rounded,
                title: context.t('account_export'),
                subtitle: context.t('account_export_desc'),
                onTap: busy ? null : _pickExportFormat,
                trailing: _busy == 'export'
                    ? const _RowSpinner()
                    : null,
              ),
              CashNavRow(
                icon: Icons.save_alt_rounded,
                title: context.t('backup_local'),
                subtitle: context.t('backup_local_sub'),
                onTap: busy ? null : _backupLocal,
                trailing: _busy == 'backup'
                    ? const _RowSpinner()
                    : null,
              ),
              CashNavRow(
                icon: Icons.file_download_outlined,
                title: context.t('account_import'),
                subtitle: context.t('account_import_desc'),
                onTap: busy ? null : _import,
                trailing: _busy == 'import'
                    ? const _RowSpinner()
                    : null,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          CashNavGroup(
            children: [
              CashNavRow(
                icon: Icons.delete_forever_outlined,
                iconColor: AppColors.error,
                title: context.t('account_reset'),
                subtitle: context.t('account_reset_desc'),
                onTap: busy ? null : _reset,
                trailing: _busy == 'reset'
                    ? const _RowSpinner()
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Indicador de progreso compacto para una fila ocupada.
class _RowSpinner extends StatelessWidget {
  const _RowSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(strokeWidth: 2.2),
    );
  }
}
