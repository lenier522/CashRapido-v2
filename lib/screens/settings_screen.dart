import '../services/localization_service.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../providers/business_provider.dart';
import '../models/models.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_dialog.dart';
import '../widgets/design/cash_icon_button.dart';
import '../widgets/design/cash_input.dart';
import '../widgets/design/cash_section.dart';
import '../widgets/design/cash_snack.dart';
import 'licenses_screen.dart';

import 'notification_settings_screen.dart';
import '../widgets/smooth_switch.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// Limpia el mensaje de una excepción antes de mostrarlo al usuario,
  /// evitando exponer trazas, rutas o nombres técnicos.
  String _friendlyError(BuildContext context, Object error) {
    var message = error.toString().trim();
    message = message.replaceFirst(RegExp(r'^(Exception|Error):\s*'), '');
    final lower = message.toLowerCase();
    final looksTechnical =
        message.isEmpty ||
        message.contains('#') ||
        lower.contains('package:') ||
        lower.contains('.dart:') ||
        lower.contains('socketexception') ||
        lower.contains('platformexception') ||
        lower.contains('sign_in_failed') ||
        lower.contains('apiexception') ||
        lower.contains('clientexception') ||
        lower.contains('dioerror') ||
        lower.contains('googleapis') ||
        lower.contains('failed host lookup') ||
        lower.contains('connection closed') ||
        lower.contains('os error') ||
        lower.contains('errno') ||
        lower.contains('handshake') ||
        lower.contains('stack trace');
    if (looksTechnical) {
      return context.t('operation_failed');
    }
    if (message.length > 200) {
      message = '${message.substring(0, 200)}…';
    }
    return message;
  }

  void _showLockedFeature(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
        icon: const Icon(
          Icons.workspace_premium_outlined,
          color: AppColors.warning,
        ),
        title: Text(context.t('feature_locked_title')),
        content: Text(context.t('feature_locked_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('close')),
          ),
          CashButton(
            label: context.t('upgrade_btn'),
            fullWidth: false,
            height: 44,
            icon: const Icon(Icons.workspace_premium_outlined, size: 18),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const LicensesScreen()),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(context.t('settings_title')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.screenVertical,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ─────────────────────────────────────────────────────────────
            //  Cuenta y Seguridad
            // ─────────────────────────────────────────────────────────────
            CashSection(
              title: context.t('account_security'),
              child: _group(context, [
                if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
                  _row(
                    context,
                    icon: Icons.fingerprint,
                    title: context.t('biometrics'),
                    locked: !provider.canUseBiometrics,
                    trailing: SmoothSwitch(
                      value: provider.biometricsEnabled,
                      activeThumbColor: theme.colorScheme.primary,
                      onChangedAsync: (val) async {
                        if (!provider.canUseBiometrics) {
                          _showLockedFeature(context);
                          return;
                        }
                        if (val) {
                          final authenticated = await provider.authenticate();
                          if (authenticated) {
                            await provider.setBiometricsEnabled(true);
                            if (context.mounted) {
                              _showSnack(
                                context,
                                context.t('biometrics_enabled'),
                              );
                            }
                          } else {
                            if (context.mounted) {
                              _showSnack(context, context.t('auth_failed'));
                            }
                          }
                        } else {
                          await provider.setBiometricsEnabled(false);
                          if (context.mounted) {
                            _showSnack(
                              context,
                              context.t('biometrics_disabled'),
                            );
                          }
                        }
                      },
                    ),
                  ),
                _row(
                  context,
                  icon: Icons.lock_outline,
                  title: context.t('change_pin'),
                  locked: !provider.canChangeAppPIN,
                  onTap: () => _showChangePinDialog(context),
                ),
                _row(
                  context,
                  icon: Icons.password,
                  title: context.t('change_password'),
                  locked: !provider.canChangePassword,
                  onTap: () => _showChangePasswordDialog(context),
                ),
              ]),
            ),

            const SizedBox(height: AppSpacing.xxl),

            // ─────────────────────────────────────────────────────────────
            //  Preferencias
            // ─────────────────────────────────────────────────────────────
            CashSection(
              title: context.t('preferences'),
              child: _group(context, [
                _row(
                  context,
                  icon: Icons.notifications_outlined,
                  title: context.t('notifications'),
                  subtitle: context.t('notif_settings_subtitle'),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen(),
                      ),
                    );
                  },
                ),
                _row(
                  context,
                  icon: Icons.smart_toy_outlined,
                  title: context.t('enable_ai'),
                  locked: !provider.canUseAI,
                  trailing: SmoothSwitch(
                    value: provider.aiChatEnabled,
                    activeThumbColor: theme.colorScheme.primary,
                    onChangedAsync: (val) async {
                      if (!provider.canUseAI) {
                        _showLockedFeature(context);
                        return;
                      }
                      await provider.setAIChatEnabled(val);
                    },
                  ),
                ),
                _row(
                  context,
                  icon: Icons.language,
                  title: context.t('language'),
                  subtitle: _getLanguageName(
                    provider.currentLocale?.languageCode,
                  ),
                  onTap: () => _showLanguageDialog(context),
                ),
                _row(
                  context,
                  icon: Icons.attach_money_rounded,
                  title: context.t('main_currency'),
                  subtitle: provider.mainCurrency,
                  onTap: () => _showCurrencyDialog(context),
                ),
                _row(
                  context,
                  icon: Icons.currency_exchange_rounded,
                  title: context.t('exchange_rates_title'),
                  subtitle: context.t('exchange_rates_sub'),
                  onTap: () => _showExchangeRatesDialog(context),
                ),
                _row(
                  context,
                  icon: Icons.numbers_rounded,
                  title: context.t('numeric_format'),
                  subtitle:
                      "${context.t('decimal_separator')} ${provider.currentDecimalSeparator == ',' ? context.t('comma') : context.t('point')}",
                  onTap: () => _showDecimalSeparatorDialog(context),
                ),
                _row(
                  context,
                  icon: Icons.account_balance_rounded,
                  title: context.t('manage_banks'),
                  locked: !provider.canManageBanks,
                  onTap: () => _showBankDialog(context),
                ),
                _row(
                  context,
                  icon: Icons.dark_mode_outlined,
                  title: context.t('dark_mode'),
                  trailing: SmoothSwitch(
                    value:
                        provider.themeMode == ThemeMode.dark ||
                        (provider.themeMode == ThemeMode.system &&
                            MediaQuery.platformBrightnessOf(context) ==
                                Brightness.dark),
                    activeThumbColor: theme.colorScheme.primary,
                    onChanged: (val) {
                      provider.setThemeMode(
                        val ? ThemeMode.dark : ThemeMode.light,
                      );
                    },
                  ),
                ),
                _row(
                  context,
                  icon: Icons.pie_chart_outline_rounded,
                  title: context.t('chart_type'),
                  subtitle: provider.chartType,
                  locked: !provider.canCustomizeCharts,
                  onTap: () => _showChartTypeDialog(context),
                ),
                if (provider.isCuba && (!kIsWeb && !Platform.isWindows))
                  _row(
                    context,
                    icon: Icons.sms_outlined,
                    title: context.t('transfermovil_title'),
                    subtitle: context.t('transfermovil_sub'),
                    locked: !provider.canUseTransferMovil,
                    trailing: SmoothSwitch(
                      value: provider.transferMovilEnabled,
                      activeThumbColor: theme.colorScheme.primary,
                      onChangedAsync: (val) async {
                        if (!provider.canUseTransferMovil) {
                          _showLockedFeature(context);
                          return;
                        }
                        try {
                          await provider.setTransferMovilEnabled(val);
                        } catch (e) {
                          if (context.mounted) {
                            _showSnack(
                              context,
                              _friendlyError(context, e),
                              isError: true,
                            );
                          }
                        }
                      },
                    ),
                  ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  void _showExchangeRatesDialog(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final businessProvider = Provider.of<BusinessProvider>(
      context,
      listen: false,
    );

    final currencies = provider.availableCurrencies
        .where((c) => c.code != provider.mainCurrency)
        .toList();
    final controllers = <String, TextEditingController>{};
    for (var c in currencies) {
      controllers[c.code] = TextEditingController(
        text: provider.getExchangeRate(c.code).toString(),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
        title: Text(context.t('exchange_rates_title')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: currencies.length,
            itemBuilder: (context, index) {
              final code = currencies[index].code;
              return Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: CashInput(
                  controller: controllers[code],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  prefix: const Icon(Icons.currency_exchange),
                  label: context
                      .t('exchange_rate_for')
                      .replaceAll('{currency}', code)
                      .replaceAll('{main}', provider.mainCurrency),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
          CashButton(
            label: context.t('save'),
            fullWidth: false,
            height: 44,
            onPressed: () {
              // Se conserva exactamente la lógica original: solo se guardan
              // tasas parseables y mayores que cero.
              for (var entry in controllers.entries) {
                final rate = double.tryParse(entry.value.text);
                if (rate != null && rate > 0) {
                  provider.setExchangeRate(entry.key, rate);
                }
              }
              businessProvider.updateCurrencyConfig(
                provider.mainCurrency,
                provider.exchangeRates,
              );
              Navigator.pop(ctx);
              _showSnack(context, context.t('rates_updated'));
            },
          ),
        ],
      ),
    );
  }

  void _showDecimalSeparatorDialog(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final String exampleLabel = context.t('example_label');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
        title: Text(context.t('numeric_format')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDecimalSeparatorOption(
              context,
              title: context.t('point'),
              example: '$exampleLabel: 1000.00',
              selected: provider.currentDecimalSeparator == '.',
              secondaryText: secondaryText,
              onSelected: () {
                provider.setDecimalSeparator('.');
                Navigator.pop(ctx);
              },
            ),
            _buildDecimalSeparatorOption(
              context,
              title: context.t('comma'),
              example: '$exampleLabel: 1000,00',
              selected: provider.currentDecimalSeparator == ',',
              secondaryText: secondaryText,
              onSelected: () {
                provider.setDecimalSeparator(',');
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.t('cancel')),
          ),
        ],
      ),
    );
  }

  /// Opción de formato decimal con indicador de selección no dependiente solo
  /// del color (icono distinto para seleccionado / no seleccionado).
  Widget _buildDecimalSeparatorOption(
    BuildContext context, {
    required String title,
    required String example,
    required bool selected,
    required Color secondaryText,
    required VoidCallback onSelected,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color unselectedIcon = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        example,
        style: theme.textTheme.bodySmall?.copyWith(color: secondaryText),
      ),
      trailing: Icon(
        selected
            ? Icons.check_circle_rounded
            : Icons.radio_button_unchecked_rounded,
        color: selected ? AppColors.primary : unselectedIcon,
        size: 22,
      ),
      onTap: onSelected,
    );
  }

  // -- Components --

  /// Agrupa varias filas dentro de una única tarjeta con separadores.
  ///
  /// Sustituye al antiguo patrón de "una tarjeta por opción" para lograr una
  /// lista agrupada, más ligera y fácil de recorrer con el pulgar.
  Widget _group(BuildContext context, List<Widget> children) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final List<Widget> rows = <Widget>[];
    for (int i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Divider(
            height: 1,
            thickness: 1,
            indent: 72,
            endIndent: AppSpacing.lg,
            color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
          ),
        );
      }
      rows.add(children[i]);
    }
    return CashCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      // Material transparente local: las filas usan ListTile y necesitan un
      // Material propio por encima del color de la tarjeta; sin él, el
      // framework avisa de que el fondo/ondas de tinta de cada ListTile quedan
      // ocultos por el DecoratedBox del CashCard (sin feedback al pulsar).
      child: Material(
        type: MaterialType.transparency,
        child: Column(mainAxisSize: MainAxisSize.min, children: rows),
      ),
    );
  }

  /// Fila de configuración reutilizable.
  ///
  /// Muestra icono, título, estado actual (subtítulo) y la acción disponible
  /// (trailing). Cuando [onTap] se proporciona y no hay [trailing], añade un
  /// chevron; si [locked] es verdadero, muestra un candado y muestra el aviso
  /// de función bloqueada respetando el flujo existente.
  Widget _row(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
    bool locked = false,
    bool busy = false,
  }) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primaryText = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final Color chevronColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiary;

    return ListTile(
      onTap: busy
          ? null
          : () {
              if (locked) {
                _showLockedFeature(context);
              } else {
                onTap?.call();
              }
            },
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xs,
      ),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          if (locked)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    width: 1.5,
                  ),
                ),
                child: const Icon(Icons.lock, size: 8, color: AppColors.white),
              ),
            ),
        ],
      ),
      title: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(color: secondaryText),
            )
          : null,
      trailing: busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : (trailing ??
                (onTap != null
                    ? Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 16,
                        color: chevronColor,
                      )
                    : null)),
    );
  }

  void _showSnack(BuildContext context, String msg, {bool isError = false}) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.hideCurrentSnackBar();
    CashSnack.show(
      context,
      msg,
      type: isError ? CashSnackType.error : CashSnackType.success,
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


  // --- PIN Dialog ---
  void _showChangePinDialog(BuildContext context) {
    final provider = Provider.of<AppProvider>(context, listen: false);
    final currentPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
        icon: const Icon(Icons.dialpad_rounded, color: AppColors.primary),
        title: Text(
          provider.hasPinSet
              ? context.t('change_pin')
              : context.t('set_pin_title'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.hasPinSet) ...[
                CashInput(
                  controller: currentPinController,
                  label: context.t('current_pin_label'),
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  maxLength: 6,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              CashInput(
                controller: newPinController,
                label: context.t('new_pin_label'),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: confirmPinController,
                label: context.t('confirm_pin_label'),
                keyboardType: TextInputType.number,
                obscureText: true,
                maxLength: 6,
              ),
            ],
          ),
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
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          CashButton(
            label: context.t('save'),
            fullWidth: false,
            height: 44,
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
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXxl),
        icon: const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
        title: Text(
          provider.hasPasswordSet
              ? context.t('change_password')
              : context.t('set_password_title'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (provider.hasPasswordSet) ...[
                CashInput(
                  controller: currentPasswordController,
                  label: context.t('current_password_label'),
                  obscureText: true,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              CashInput(
                controller: newPasswordController,
                label: context.t('new_password_label'),
                obscureText: true,
              ),
              const SizedBox(height: AppSpacing.md),
              CashInput(
                controller: confirmPasswordController,
                label: context.t('confirm_password_label'),
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
                style: const TextStyle(color: AppColors.error),
              ),
            ),
          CashButton(
            label: context.t('save'),
            fullWidth: false,
            height: 44,
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

  /// Sincroniza la configuración monetaria del módulo Business con la
  /// preferencia global de [AppProvider].
  ///
  /// `BusinessProvider` conserva su propia copia de la moneda principal y las
  /// tasas de cambio (se cargan en su `init()` desde las mismas claves de
  /// preferencias) y las usa para convertir importes en sus reportes. El
  /// diálogo de tasas de cambio ya lo actualizaba, pero cambiar la moneda
  /// principal no: el módulo Business seguía usando la moneda anterior hasta
  /// reiniciar la aplicación. Esta llamada mantiene ambos providers coherentes
  /// usando el mismo mecanismo existente; no modifica ningún importe guardado.
  void _syncBusinessCurrency(BuildContext context, AppProvider provider) {
    Provider.of<BusinessProvider>(
      context,
      listen: false,
    ).updateCurrencyConfig(provider.mainCurrency, provider.exchangeRates);
  }

  void _showCurrencyDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        final ThemeData theme = Theme.of(context);
        return Consumer<AppProvider>(
          builder: (context, provider, _) {
            final currencies = provider.availableCurrencies;
            return SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(
                  top: AppSpacing.md,
                  bottom: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Asa para indicar que la hoja es deslizable.
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.brightness == Brightness.dark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      context.t('select_currency'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        itemCount: currencies.length + 1,
                        itemBuilder: (context, index) {
                          if (index == currencies.length) {
                            return _currencyAddTile(context, provider);
                          }
                          return _currencyTile(
                            context,
                            provider,
                            currencies[index],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Fila de una moneda. Marca la moneda principal y permite editar o eliminar
  /// únicamente las monedas personalizadas (CUP/USD/EUR/MLC no son editables).
  Widget _currencyTile(
    BuildContext context,
    AppProvider provider,
    Currency currency,
  ) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primary = theme.colorScheme.primary;
    final Color secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final bool isSelected = provider.mainCurrency == currency.code;
    final bool isDefault = ['CUP', 'USD', 'EUR', 'MLC'].contains(currency.code);

    return ListTile(
      onTap: () {
        provider.setMainCurrency(currency.code);
        _syncBusinessCurrency(context, provider);
        Navigator.pop(context);
      },
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected
              ? primary.withValues(alpha: isDark ? 0.24 : 0.12)
              : (isDark
                    ? AppColors.surfaceDark2
                    : AppColors.surfaceVariantLight),
          shape: BoxShape.circle,
        ),
        child: Text(
          currency.symbol,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: isSelected ? primary : secondaryText,
          ),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              currency.code,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: isSelected ? primary : null,
              ),
            ),
          ),
          if (isSelected) ...[
            const SizedBox(width: AppSpacing.sm),
            Icon(Icons.check_circle_rounded, size: 18, color: primary),
          ],
        ],
      ),
      subtitle: Text(
        currency.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodySmall?.copyWith(color: secondaryText),
      ),
      trailing: isDefault
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CashIconButton(
                  icon: Icons.edit_outlined,
                  size: 40,
                  iconSize: 18,
                  tooltip: context.t('edit_currency'),
                  onPressed: () => _showEditCurrencyDialog(context, currency),
                ),
                const SizedBox(width: AppSpacing.xs),
                CashIconButton(
                  icon: Icons.delete_outline,
                  size: 40,
                  iconSize: 18,
                  iconColor: AppColors.error,
                  tooltip: context.t('delete_currency'),
                  onPressed: () =>
                      _confirmDeleteCurrency(context, provider, currency),
                ),
              ],
            ),
    );
  }

  /// Fila para agregar una moneda personalizada. Se muestra bloqueada cuando
  /// la licencia activa no incluye monedas personalizadas.
  Widget _currencyAddTile(BuildContext context, AppProvider provider) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color primary = theme.colorScheme.primary;
    final bool locked = !provider.isPremium;

    return ListTile(
      onTap: () {
        if (locked) {
          _showLockedFeature(context);
          return;
        }
        _showAddCurrencyDialog(context);
      },
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: isDark ? 0.20 : 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.add, color: primary),
          ),
          if (locked)
            Positioned(
              right: -2,
              top: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: AppColors.warning,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDark
                        ? AppColors.surfaceDark
                        : AppColors.surfaceLight,
                    width: 1.5,
                  ),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 10,
                  color: AppColors.white,
                ),
              ),
            ),
        ],
      ),
      title: Text(
        context.t('add_currency'),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: primary,
        ),
      ),
    );
  }

  /// Confirma y elimina una moneda personalizada conservando la validación
  /// original: una moneda en uso por una tarjeta no puede eliminarse.
  Future<void> _confirmDeleteCurrency(
    BuildContext context,
    AppProvider provider,
    Currency currency,
  ) async {
    final bool? confirm = await showCashConfirmDialog(
      context,
      title: context.t('delete_currency'),
      message: context.t('confirm_delete_currency'),
      confirmLabel: context.t('delete'),
      cancelLabel: context.t('cancel'),
      icon: Icons.delete_outline_rounded,
    );
    if (confirm != true) {
      return;
    }
    try {
      await provider.deleteCustomCurrency(currency.code);
      if (context.mounted) {
        // Si la moneda eliminada era la principal, AppProvider revierte a CUP;
        // hay que reflejarlo también en el módulo Business.
        _syncBusinessCurrency(context, provider);
      }
    } catch (e) {
      if (!context.mounted) {
        return;
      }
      final String message = e.toString().contains('In Use')
          ? context.t('currency_in_use_error')
          : context.t('error');
      _showSnack(context, message, isError: true);
    }
  }

  void _showEditCurrencyDialog(BuildContext context, Currency currency) {
    final codeController = TextEditingController(text: currency.code);
    final symbolController = TextEditingController(text: currency.symbol);
    final nameController = TextEditingController(text: currency.name);
    final oldCode = currency.code;
    final provider = Provider.of<AppProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final bool canSave =
              codeController.text.trim().isNotEmpty &&
              symbolController.text.trim().isNotEmpty;
          return AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusXxl,
            ),
            title: Text(context.t('edit_currency')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CashInput(
                    controller: codeController,
                    label: context.t('currency_code'),
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CashInput(
                    controller: symbolController,
                    label: context.t('currency_symbol'),
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CashInput(
                    controller: nameController,
                    label: context.t('description_hint'),
                    onChanged: (_) => setLocalState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.t('cancel')),
              ),
              CashButton(
                label: context.t('save'),
                fullWidth: false,
                height: 44,
                onPressed: canSave
                    ? () async {
                        if (codeController.text.isEmpty ||
                            symbolController.text.isEmpty) {
                          return;
                        }

                        try {
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
                          _showSnack(context, context.t('success'));
                        } catch (e) {
                          if (!context.mounted) return;
                          String errorMsg = context.t('error');
                          if (e.toString().contains('In Use')) {
                            errorMsg = context.t('currency_in_use_error');
                          } else if (e.toString().contains('Exists')) {
                            errorMsg = context.t('currency_exists');
                          }
                          _showSnack(context, errorMsg, isError: true);
                        }
                      }
                    : null,
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAddCurrencyDialog(BuildContext context) {
    final codeController = TextEditingController();
    final symbolController = TextEditingController();
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocalState) {
          final bool canSave =
              codeController.text.trim().isNotEmpty &&
              symbolController.text.trim().isNotEmpty;
          return AlertDialog(
            shape: const RoundedRectangleBorder(
              borderRadius: AppRadius.radiusXxl,
            ),
            title: Text(context.t('add_currency')),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CashInput(
                    controller: codeController,
                    label: context.t('currency_code'),
                    hint: 'USD',
                    textCapitalization: TextCapitalization.characters,
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CashInput(
                    controller: symbolController,
                    label: context.t('currency_symbol'),
                    hint: '\$',
                    onChanged: (_) => setLocalState(() {}),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CashInput(
                    controller: nameController,
                    label: context.t('description_hint'),
                    onChanged: (_) => setLocalState(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(context.t('cancel')),
              ),
              CashButton(
                label: context.t('save'),
                fullWidth: false,
                height: 44,
                onPressed: canSave
                    ? () async {
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
                          _showSnack(context, context.t('currency_added'));
                        } catch (e) {
                          if (!context.mounted) return;
                          _showSnack(
                            context,
                            context.t('currency_exists'),
                            isError: true,
                          );
                        }
                      }
                    : null,
              ),
            ],
          );
        },
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
                                        color: AppColors.error,
                                      ),
                                      onPressed: () async {
                                        final confirm =
                                            await showCashConfirmDialog(
                                              context,
                                              title: context.t('delete_bank'),
                                              message: context.t(
                                                'confirm_delete_bank',
                                              ),
                                              confirmLabel: context.t('delete'),
                                              cancelLabel: context.t('cancel'),
                                              icon:
                                                  Icons.delete_outline_rounded,
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
