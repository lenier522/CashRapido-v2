import '../services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../models/models.dart';
import 'info_screens.dart';
import 'licenses_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _showLockedFeature(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.t('feature_locked_title')),
        content: Text(context.t('feature_locked_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('close')),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicensesScreen()),
              );
            },
            child: Text(context.t('upgrade_btn')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.t('settings_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context.t('account_security')),
            _buildSettingsTile(
              context,
              icon: Icons.fingerprint,
              title: context.t('biometrics'),
              isLocked: !provider.canUseBiometrics,
              trailing: Switch(
                value: provider.biometricsEnabled,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) async {
                  if (!provider.canUseBiometrics) {
                    _showLockedFeature(context);
                    return;
                  }
                  if (val) {
                    final authenticated = await provider.authenticate();
                    if (authenticated) {
                      await provider.setBiometricsEnabled(true);
                      if (context.mounted) {
                        _showSnack(context, context.t('biometrics_enabled'));
                      }
                    } else {
                      if (context.mounted) {
                        _showSnack(context, context.t('auth_failed'));
                      }
                    }
                  } else {
                    await provider.setBiometricsEnabled(false);
                    if (context.mounted) {
                      _showSnack(context, context.t('biometrics_disabled'));
                    }
                  }
                },
              ),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.lock_outline,
              title: context.t('change_pin'),
              isLocked: !provider.canChangeAppPIN,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () => _showChangePinDialog(context),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.password,
              title: context.t('change_password'),
              isLocked: !provider.canChangePassword,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () => _showChangePasswordDialog(context),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.notifications_outlined,
              title: context.t('notifications'),
              trailing: Switch(
                value: provider.notificationsEnabled,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) async {
                  await provider.setNotificationsEnabled(val);
                  if (context.mounted) {
                    _showSnack(
                      context,
                      val
                          ? context.t('notif_enabled')
                          : context.t('notif_disabled'),
                    );
                  }
                },
              ),
            ),

            const SizedBox(height: 24),
            _buildSectionTitle(context.t('preferences')),
            // AI Section
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.smart_toy_outlined,
                            color: Theme.of(context).colorScheme.primary,
                            size: 20,
                          ),
                        ),
                        if (!provider.canUseAI)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).cardColor,
                                  width: 1.5,
                                ),
                              ),
                              child: const Icon(
                                Icons.lock,
                                size: 8,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                    title: Text(
                      context.t('enable_ai'),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    trailing: Switch(
                      value: provider.aiChatEnabled,
                      activeThumbColor: Theme.of(context).colorScheme.primary,
                      onChanged: (val) async {
                        if (!provider.canUseAI) {
                          _showLockedFeature(context);
                          return;
                        }
                        await provider.setAIChatEnabled(val);
                      },
                    ),
                  ),
                  if (provider.aiChatEnabled && provider.canUseAI) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Proveedor de IA",
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text("Google Gemini"),
                                  value: false,
                                  groupValue: provider.useOfflineAI,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) {
                                    provider.setUseOfflineAI(val!);
                                  },
                                ),
                              ),
                              Expanded(
                                child: RadioListTile<bool>(
                                  title: const Text("Modelo Offline"),
                                  value: true,
                                  groupValue: provider.useOfflineAI,
                                  contentPadding: EdgeInsets.zero,
                                  onChanged: (val) {
                                    provider.setUseOfflineAI(val!);
                                  },
                                ),
                              ),
                            ],
                          ),
                          if (provider.useOfflineAI) ...[
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              icon: const Icon(Icons.file_upload),
                              label: Text(
                                provider.offlineModelPath != null
                                    ? "Cambiar Modelo (LiteRT)"
                                    : "Importar Modelo",
                              ),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size(double.infinity, 45),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  final progressNotifier = ValueNotifier<int>(
                                    0,
                                  );
                                  bool dialogShown = false;

                                  await provider.importOfflineModel(
                                    onStart: () {
                                      dialogShown = true;
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (ctx) => AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          title: Text(
                                            "Importando Modelo",
                                            style: GoogleFonts.outfit(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                "Preparando el modelo para uso offline. Esto puede demorar dependiendo del tamaño del archivo.",
                                                style: GoogleFonts.outfit(),
                                              ),
                                              const SizedBox(height: 20),
                                              ValueListenableBuilder<int>(
                                                valueListenable:
                                                    progressNotifier,
                                                builder: (context, value, child) {
                                                  return Column(
                                                    children: [
                                                      ClipRRect(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              10,
                                                            ),
                                                        child: LinearProgressIndicator(
                                                          value: value / 100,
                                                          minHeight: 8,
                                                          backgroundColor:
                                                              Theme.of(context)
                                                                  .colorScheme
                                                                  .primary
                                                                  .withOpacity(
                                                                    0.2,
                                                                  ),
                                                          valueColor:
                                                              AlwaysStoppedAnimation<
                                                                Color
                                                              >(
                                                                Theme.of(
                                                                      context,
                                                                    )
                                                                    .colorScheme
                                                                    .primary,
                                                              ),
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 10,
                                                      ),
                                                      Text(
                                                        "$value% Completado",
                                                        style: GoogleFonts.outfit(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Theme.of(
                                                            context,
                                                          ).colorScheme.primary,
                                                        ),
                                                      ),
                                                    ],
                                                  );
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                    onProgress: (p) {
                                      progressNotifier.value = p;
                                    },
                                  );

                                  if (dialogShown && context.mounted) {
                                    Navigator.of(context).pop();
                                    dialogShown = false;
                                    if (provider.offlineModelPath != null) {
                                      _showSnack(
                                        context,
                                        "Modelo importado con éxito",
                                      );
                                    }
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                    ).pop(); // pop the dialog
                                    _showSnack(
                                      context,
                                      e.toString(),
                                      isError: true,
                                    );
                                  }
                                }
                              },
                            ),
                            if (provider.offlineModelPath != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  "Modelo cargado correctamente",
                                  style: GoogleFonts.outfit(
                                    fontSize: 12,
                                    color: Colors.green,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.language,
              title: context.t('language'),
              subtitle: _getLanguageName(provider.currentLocale?.languageCode),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () => _showLanguageDialog(context),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.attach_money_rounded,
              title: context.t('main_currency'),
              subtitle: provider.mainCurrency,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () => _showCurrencyDialog(context),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.account_balance_rounded,
              title: context.t('manage_banks'),
              isLocked: !provider.canManageBanks,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () => _showBankDialog(context),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.dark_mode_outlined,
              title: context.t('dark_mode'),
              trailing: Switch(
                value: provider.themeMode == ThemeMode.dark,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChanged: (val) {
                  provider.setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ),
            _buildSettingsTile(
              context,
              icon: Icons.pie_chart_outline_rounded,
              title: context.t('chart_type'),
              subtitle: provider.chartType,
              isLocked: !provider.canCustomizeCharts,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () => _showChartTypeDialog(context),
            ),
            if (provider.isCuba)
              _buildSettingsTile(
                context,
                icon: Icons.sms_outlined,
                title: "Integración Transfermóvil",
                subtitle: "Detectar pagos automáticamente (Solo Cuba)",
                isLocked: !provider.canUseTransferMovil,
                trailing: Switch(
                  value: provider.transferMovilEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChanged: (val) async {
                    if (!provider.canUseTransferMovil) {
                      _showLockedFeature(context);
                      return;
                    }
                    try {
                      await provider.setTransferMovilEnabled(val);
                    } catch (e) {
                      if (context.mounted) {
                        _showSnack(context, e.toString(), isError: true);
                      }
                    }
                  },
                ),
              ),

            const SizedBox(height: 24),
            _buildSectionTitle(context.t('backup_title')),
            _buildSettingsTile(
              context,
              icon: Icons.save_alt_rounded,
              title: context.t('backup_local'),
              subtitle: context.t('backup_local_sub'),
              onTap: () async {
                try {
                  await provider.backupToLocal();
                  if (context.mounted) {
                    _showSnack(context, context.t('backup_success'));
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showSnack(
                      context,
                      '${context.t('error')}: $e',
                      isError: true,
                    );
                  }
                }
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.restore_rounded,
              title: context.t('restore_local'),
              subtitle: context.t('restore_local_sub'),
              isLocked: !provider.canImportData, // "Import Data"
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => _buildConfirmDialog(
                    context,
                    context.t('confirm_import'),
                    context.t('import_warning'),
                  ),
                );
                if (confirm == true) {
                  try {
                    await provider.restoreFromLocal();
                    if (context.mounted) {
                      _showSnack(context, context.t('success_restore'));
                    }
                  } catch (e) {
                    if (context.mounted) {
                      _showSnack(
                        context,
                        '${context.t('error')}: $e',
                        isError: true,
                      );
                    }
                  }
                }
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.table_chart_outlined,
              title: context.t('export_excel'),
              subtitle: context.t('export_excel_sub'),
              isLocked: !provider.canExportExcel,
              onTap: () async {
                _showSnack(context, context.t('generating_excel'));
                try {
                  final path = await provider.exportToExcel();
                  if (context.mounted) {
                    _showExportSuccessDialog(context, 'Excel', path, provider);
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showSnack(
                      context,
                      '${context.t('error')}: $e',
                      isError: true,
                    );
                  }
                }
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.picture_as_pdf_outlined,
              title: context.t('export_pdf'),
              subtitle: context.t('export_pdf_sub'),
              isLocked: !provider.canExportPDF,
              onTap: () async {
                _showSnack(context, context.t('generating_pdf'));
                try {
                  final path = await provider.exportToPDF();
                  if (context.mounted) {
                    _showExportSuccessDialog(context, 'PDF', path, provider);
                  }
                } catch (e) {
                  if (context.mounted) {
                    _showSnack(
                      context,
                      '${context.t('error')}: $e',
                      isError: true,
                    );
                  }
                }
              },
            ),

            const SizedBox(height: 8),
            _buildGoogleDriveSection(context, provider),

            const SizedBox(height: 24),
            _buildSectionTitle(context.t('support_legal')),
            _buildSettingsTile(
              context,
              icon: Icons.description_outlined,
              title: context.t('terms'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TermsScreen()),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.workspace_premium_outlined,
              title: context.t('paid_licenses'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const LicensesScreen(),
                  ),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.code,
              title: context.t('open_source'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: context.t('app_name'),
                  applicationVersion: '1.12.2',
                  applicationIcon: Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.help_outline_rounded,
              title: context.t('help_center'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const HelpCenterScreen(),
                  ),
                );
              },
            ),
            _buildSettingsTile(
              context,
              icon: Icons.info_outline_rounded,
              title: context.t('about'),
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).disabledColor,
              ),
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName: context.t('app_name'),
                  applicationVersion: '1.12.2',
                  applicationIcon: Icon(
                    Icons.account_balance_wallet,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  children: [Text(context.t('app_desc'))],
                );
              },
            ),

            const SizedBox(height: 40),
            _buildFooter(context),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // -- Components --

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 8.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool isLocked = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        onTap: () {
          if (isLocked) {
            _showLockedFeature(context);
          } else {
            onTap?.call();
          }
        },
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
            ),
            if (isLocked)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.amber,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).cardColor,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 2,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.lock, size: 8, color: Colors.white),
                ),
              ),
          ],
        ),
        title: Text(
          title,
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.w600,
            color: Theme.of(context).textTheme.bodyLarge?.color,
          ),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle,
                style: GoogleFonts.outfit(
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
              )
            : null,
        trailing: trailing,
      ),
    );
  }

  Widget _buildGoogleDriveSection(BuildContext context, AppProvider provider) {
    final user = provider.currentUser;
    if (user == null) {
      return _buildSettingsTile(
        context,
        icon: Icons.cloud_upload_outlined,
        title: context.t('sync_drive_title'),
        subtitle: context.t('sync_drive_desc'),
        isLocked: !provider.canSyncDrive,
        trailing: Icon(
          Icons.login,
          color: Theme.of(context).colorScheme.primary,
        ),
        onTap: () async {
          if (!provider.canSyncDrive) {
            // Already handled by _buildSettingsTile isLocked logic,
            // but since calling onTap manually disables the tile's internal check?
            // No, _buildSettingsTile with isLocked=true intercepts onTap.
            // So I just need to return.
            // Wait, passing isLocked=true is enough.
            // But let's be explicit if needed.
            // The widget handles it.
          }
          try {
            await provider.signInToGoogle();
          } catch (e) {
            if (context.mounted) {
              _showSnack(
                context,
                '${context.t('error_connecting')}: $e',
                isError: true,
              );
            }
          }
        },
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.primary.withValues(alpha: 0.1),
                backgroundImage: user.photoUrl != null
                    ? NetworkImage(user.photoUrl!)
                    : null,
                child: user.photoUrl == null
                    ? Text(
                        user.displayName?[0] ?? 'U',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? context.t('user_default'),
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).textTheme.bodyLarge?.color,
                      ),
                    ),
                    Text(
                      user.email,
                      style: GoogleFonts.outfit(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.color?.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(
                  Icons.logout,
                  color: Theme.of(context).colorScheme.error,
                ),
                onPressed: () => provider.signOutFromGoogle(),
              ),
            ],
          ),
          const Divider(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.t('last_copy'),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).disabledColor,
                    ),
                  ),
                  Text(
                    provider.lastBackupDate != null
                        ? '${provider.lastBackupDate!.day}/${provider.lastBackupDate!.month} • ${provider.lastBackupDate!.hour}:${provider.lastBackupDate!.minute.toString().padLeft(2, '0')}'
                        : context.t('never'),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ],
              ),
              if (provider.isSyncing)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: provider.isSyncing
                      ? null
                      : () async {
                          if (!provider.canSyncDrive) {
                            _showLockedFeature(context);
                            return;
                          }
                          try {
                            await provider.backupToCloud();
                            if (context.mounted) {
                              _showSnack(
                                context,
                                context.t('backup_success_msg'),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              _showSnack(
                                context,
                                '${context.t('error')}: $e',
                                isError: true,
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.cloud_upload_rounded),
                  label: Text(context.t('backup_action')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: provider.isSyncing
                      ? null
                      : () async {
                          if (!provider.canSyncDrive) {
                            _showLockedFeature(context);
                            return;
                          }
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => _buildConfirmDialog(
                              context,
                              context.t('restore_dialog_title'),
                              context.t('restore_dialog_desc'),
                            ),
                          );
                          if (confirm == true) {
                            try {
                              await provider.restoreFromCloud();
                              if (context.mounted) {
                                _showSnack(
                                  context,
                                  context.t('success_restore'),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                _showSnack(
                                  context,
                                  '${context.t('error')}: $e',
                                  isError: true,
                                );
                              }
                            }
                          }
                        },
                  icon: const Icon(Icons.cloud_download_rounded),
                  label: Text(context.t('restore_action')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.5),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Center(
      child: Column(
        children: [
          Text(
            'CashRapido v1.12.2',
            style: GoogleFonts.outfit(
              color: Theme.of(context).disabledColor,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            context.t('developed_by'),
            style: GoogleFonts.outfit(
              color: Theme.of(context).disabledColor,
              fontSize: 12,
            ),
          ),
          Text(
            context.t('developer_name'),
            style: GoogleFonts.outfit(
              color: Theme.of(context).textTheme.bodyLarge?.color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSocialIcon(Icons.facebook, Colors.blue, null),
              const SizedBox(width: 16),
              _buildSocialIcon(
                Icons.camera_alt,
                Colors.pink,
                () => launchUrl(
                  Uri.parse('https://instagram.com/cashrapido23'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
              const SizedBox(width: 16),
              _buildSocialIcon(
                Icons.alternate_email,
                Colors.lightBlue,
                () => launchUrl(Uri.parse('mailto:leniercruz02@gmail.com')),
              ),
              const SizedBox(width: 16),
              _buildSocialIcon(
                Icons.telegram,
                Colors.blueAccent,
                () => launchUrl(
                  Uri.parse('https://t.me/+De8fwjWq94xjMzBh'),
                  mode: LaunchMode.externalApplication,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(IconData icon, Color color, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(50),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 20),
      ),
    );
  }

  // -- Dialogs & Helpers --

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError
            ? Theme.of(context).colorScheme.error
            : Theme.of(context).colorScheme.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildConfirmDialog(
    BuildContext context,
    String title,
    String content,
  ) {
    return AlertDialog(
      backgroundColor: Theme.of(context).cardColor,
      title: Text(
        title,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
      ),
      content: Text(
        content,
        style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(context.t('cancel')),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(
            context.t('confirm'),
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          context.t('language'),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildLanguageOption(ctx, 'Español', 'es'),
            _buildLanguageOption(ctx, 'English', 'en'),
            _buildLanguageOption(ctx, 'Français', 'fr'),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageOption(BuildContext ctx, String label, String code) {
    final isSelected =
        Provider.of<AppProvider>(context).currentLocale?.languageCode == code;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () {
        Provider.of<AppProvider>(context, listen: false).setLanguage(code);
        Navigator.pop(ctx);
      },
    );
  }

  void _showChartTypeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          context.t('chart_type'),
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildChartTypeOption(ctx, 'Pie', context.t('chart_type_pie')),
            _buildChartTypeOption(ctx, 'Bar', context.t('chart_type_bar')),
            _buildChartTypeOption(ctx, 'Line', context.t('chart_type_line')),
          ],
        ),
      ),
    );
  }

  Widget _buildChartTypeOption(BuildContext ctx, String type, String label) {
    final isSelected = Provider.of<AppProvider>(context).chartType == type;
    return ListTile(
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).textTheme.bodyLarge?.color,
        ),
      ),
      trailing: isSelected
          ? Icon(
              Icons.check_circle,
              color: Theme.of(context).colorScheme.primary,
            )
          : null,
      onTap: () {
        Provider.of<AppProvider>(context, listen: false).setChartType(type);
        Navigator.pop(ctx);
      },
    );
  }

  void _showExportSuccessDialog(
    BuildContext context,
    String type,
    String path,
    AppProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        title: Text(
          '$type ${context.t('success')}',
          style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.t('file_saved'),
              style: TextStyle(
                color: Theme.of(context).textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              path.split('/').last,
              style: GoogleFonts.sourceCodePro(
                fontSize: 12,
                color: Theme.of(context).disabledColor,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('close')),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await provider.shareFile(path);
              if (!context.mounted) {
                return;
              }
              Navigator.pop(ctx);
            },
            icon: const Icon(Icons.share, size: 18),
            label: Text(context.t('share_save')),
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // --- PIN Dialog ---
  void _showChangePinDialog(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          provider.hasPinSet
              ? context.t('change_pin')
              : context.t('set_pin_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (provider.hasPinSet)
              TextField(
                controller: currentPinController,
                decoration: InputDecoration(
                  labelText: context.t('current_pin_label'),
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
              ),
            if (provider.hasPinSet) const SizedBox(height: 16),
            TextField(
              controller: newPinController,
              decoration: InputDecoration(
                labelText: context.t('new_pin_label'),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmPinController,
              decoration: InputDecoration(
                labelText: context.t('confirm_pin_label'),
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 6,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          if (provider.hasPinSet)
            TextButton(
              onPressed: () async {
                await provider.clearAppPin();
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('pin_deleted'))),
                );
              },
              child: Text(
                context.t('delete_pin_action'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              // Validate current PIN if set
              if (provider.hasPinSet) {
                if (!provider.validatePin(currentPinController.text)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(context.t('current_pin_incorrect'))),
                  );
                  return;
                }
              }

              // Validate new PIN
              final newPin = newPinController.text;
              if (newPin.length < 4 || newPin.length > 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('pin_length_error'))),
                );
                return;
              }

              if (newPin != confirmPinController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('pin_mismatch'))),
                );
                return;
              }

              // Save PIN
              await provider.setAppPin(newPin);
              if (!context.mounted) {
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(context.t('pin_saved'))));
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }

  // --- Password Dialog ---
  void _showChangePasswordDialog(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          provider.hasPasswordSet
              ? context.t('change_password')
              : context.t('set_password_title'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.hasPasswordSet)
                TextField(
                  controller: currentPasswordController,
                  decoration: InputDecoration(
                    labelText: context.t('current_password_label'),
                    border: const OutlineInputBorder(),
                  ),
                  obscureText: true,
                ),
              if (provider.hasPasswordSet) const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                decoration: InputDecoration(
                  labelText: context.t('new_password_label'),
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                decoration: InputDecoration(
                  labelText: context.t('confirm_password_label'),
                  border: const OutlineInputBorder(),
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          if (provider.hasPasswordSet)
            TextButton(
              onPressed: () async {
                await provider.clearAppPassword();
                if (!context.mounted) {
                  return;
                }
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('password_deleted'))),
                );
              },
              child: Text(
                context.t('delete_password_action'),
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ElevatedButton(
            onPressed: () async {
              // Validate current password if set
              if (provider.hasPasswordSet) {
                if (!provider.validatePassword(
                  currentPasswordController.text,
                )) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(context.t('current_password_incorrect')),
                    ),
                  );
                  return;
                }
              }

              // Validate new password
              final newPassword = newPasswordController.text;
              if (newPassword.length < 6) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('password_length_error'))),
                );
                return;
              }

              if (newPassword != confirmPasswordController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('password_mismatch'))),
                );
                return;
              }

              // Save password
              await provider.setAppPassword(newPassword);
              if (!context.mounted) {
                return;
              }
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(context.t('password_saved'))),
              );
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String? code) {
    if (code == 'en') return 'English';
    if (code == 'fr') return 'Français';
    return 'Español';
  }

  void _showCurrencyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<AppProvider>(
          builder: (context, provider, _) {
            final currencies = provider.availableCurrencies;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t('select_currency'),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: currencies.length + 1,
                      itemBuilder: (context, index) {
                        if (index == currencies.length) {
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              context.t('add_currency'),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              final provider = Provider.of<AppProvider>(
                                context,
                                listen: false,
                              );
                              if (!provider.isPremium) {
                                _showLockedFeature(context);
                                return;
                              }
                              _showAddCurrencyDialog(context);
                            },
                          );
                        }

                        final currency = currencies[index];
                        final isSelected =
                            provider.mainCurrency == currency.code;
                        final isDefault = [
                          'CUP',
                          'USD',
                          'EUR',
                          'MLC',
                        ].contains(currency.code);

                        return ListTile(
                          leading: Text(
                            currency.symbol,
                            style: GoogleFonts.outfit(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : Theme.of(context).disabledColor,
                            ),
                          ),
                          title: Text(
                            currency.code,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              color: isSelected
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                            ),
                          ),
                          subtitle: Text(currency.name),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              if (!isDefault) ...[
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 20),
                                  onPressed: () {
                                    _showEditCurrencyDialog(context, currency);
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    size: 20,
                                    color: Colors.red,
                                  ),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => _buildConfirmDialog(
                                        context,
                                        context.t('delete_currency'),
                                        context.t('confirm_delete_currency'),
                                      ),
                                    );
                                    if (confirm == true) {
                                      try {
                                        await provider.deleteCustomCurrency(
                                          currency.code,
                                        );
                                        // Reopen or just toast? To toast.
                                        // Navigator.pop(context); // Already popped? No, dialog popped.
                                        // Need to close bottom sheet? No.
                                        // But if we deleted it, the list updates.
                                      } catch (e) {
                                        if (e.toString().contains('In Use')) {
                                          if (context.mounted) {
                                            _showSnack(
                                              context,
                                              context.t(
                                                'currency_in_use_error',
                                              ),
                                              isError: true,
                                            );
                                          }
                                        }
                                      }
                                    }
                                  },
                                ),
                              ],
                            ],
                          ),
                          onTap: () {
                            provider.setMainCurrency(currency.code);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showEditCurrencyDialog(BuildContext context, Currency currency) {
    final codeController = TextEditingController(text: currency.code);
    final symbolController = TextEditingController(text: currency.symbol);
    final nameController = TextEditingController(text: currency.name);
    final oldCode = currency.code;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('edit_currency'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: context.t('currency_code'),
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              decoration: InputDecoration(
                labelText: context.t('currency_symbol'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: context.t('description_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isEmpty ||
                  symbolController.text.isEmpty) {
                return;
              }

              try {
                final provider = Provider.of<AppProvider>(
                  context,
                  listen: false,
                );
                await provider.editCustomCurrency(
                  oldCode,
                  Currency(
                    code: codeController.text.toUpperCase(),
                    symbol: symbolController.text,
                    name: nameController.text.isEmpty
                        ? context.t('custom_currency')
                        : nameController.text,
                  ),
                );

                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.t('success')),
                  ), // Generic success
                );
              } catch (e) {
                if (!context.mounted) return;
                String errorMsg = context.t('error');
                if (e.toString().contains('In Use')) {
                  errorMsg = context.t('currency_in_use_error');
                } else if (e.toString().contains('Exists')) {
                  errorMsg = context.t('currency_exists');
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(errorMsg)));
              }
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }

  void _showAddCurrencyDialog(BuildContext context) {
    final codeController = TextEditingController();
    final symbolController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('add_currency'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: codeController,
              decoration: InputDecoration(
                labelText: context.t('currency_code'),
                hintText: 'USD',
                border: const OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: symbolController,
              decoration: InputDecoration(
                labelText: context.t('currency_symbol'),
                hintText: '\$',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: context.t('description_hint'),
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codeController.text.isEmpty ||
                  symbolController.text.isEmpty) {
                return;
              }

              try {
                final provider = Provider.of<AppProvider>(
                  context,
                  listen: false,
                );
                await provider.addCustomCurrency(
                  Currency(
                    code: codeController.text.toUpperCase(),
                    symbol: symbolController.text,
                    name: nameController.text.isEmpty
                        ? context.t('custom_currency')
                        : nameController.text,
                  ),
                );

                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('currency_added'))),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('currency_exists'))),
                );
              }
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }

  void _showBankDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Consumer<AppProvider>(
          builder: (context, provider, _) {
            final banks = provider.availableBanks;
            // Defaults hardcoded in provider: VISA, MasterCard, etc.
            final defaults = [
              'VISA',
              'MasterCard',
              'Metropolitano',
              'BPA',
              'BANDEC',
              'American Express',
            ];

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.t('manage_banks'),
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: banks.length + 1,
                      itemBuilder: (context, index) {
                        if (index == banks.length) {
                          return ListTile(
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.add,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                            title: Text(
                              context.t('add_bank'),
                              style: GoogleFonts.outfit(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            onTap: () {
                              final provider = Provider.of<AppProvider>(
                                context,
                                listen: false,
                              );
                              if (!provider.isPremium) {
                                _showLockedFeature(context);
                                return;
                              }
                              _showAddBankDialog(context);
                            },
                          );
                        }

                        final bankName = banks[index];
                        final isDefault = defaults.contains(bankName);

                        return ListTile(
                          leading: Icon(
                            Icons.account_balance,
                            color: Theme.of(context).disabledColor,
                          ),
                          title: Text(
                            bankName,
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          trailing: isDefault
                              ? null
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed: () {
                                        _showEditBankDialog(context, bankName);
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) =>
                                              _buildConfirmDialog(
                                                context,
                                                context.t('delete_bank'),
                                                context.t(
                                                  'confirm_delete_bank',
                                                ),
                                              ),
                                        );
                                        if (confirm == true) {
                                          try {
                                            await provider.deleteCustomBank(
                                              bankName,
                                            );
                                          } catch (e) {
                                            if (e.toString().contains(
                                              'In Use',
                                            )) {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      context.t(
                                                        'bank_in_use_error',
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              }
                                            }
                                          }
                                        }
                                      },
                                    ),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showAddBankDialog(BuildContext context) {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('add_bank'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.t('bank_name'),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              try {
                final provider = Provider.of<AppProvider>(
                  context,
                  listen: false,
                );
                await provider.addCustomBank(nameController.text);

                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('bank_added'))),
                );
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(context.t('bank_exists'))),
                );
              }
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }

  void _showEditBankDialog(BuildContext context, String oldName) {
    final nameController = TextEditingController(text: oldName);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          context.t('edit_bank'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(
            labelText: context.t('bank_name'),
            border: const OutlineInputBorder(),
          ),
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;

              try {
                final provider = Provider.of<AppProvider>(
                  context,
                  listen: false,
                );
                await provider.editCustomBank(oldName, nameController.text);

                if (!context.mounted) return;
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(context.t('success'))));
              } catch (e) {
                if (!context.mounted) return;
                String errorMsg = context.t('error');
                if (e.toString().contains('In Use')) {
                  errorMsg = context.t('bank_in_use_error');
                } else if (e.toString().contains('Exists')) {
                  errorMsg = context.t('bank_exists');
                }
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(errorMsg)));
              }
            },
            child: Text(context.t('save')),
          ),
        ],
      ),
    );
  }
}
