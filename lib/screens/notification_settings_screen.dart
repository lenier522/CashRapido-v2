import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_spacing.dart';
import '../widgets/design/cash_button.dart';
import '../widgets/design/cash_card.dart';
import '../widgets/design/cash_chip.dart';
import '../widgets/design/cash_section.dart';
import '../widgets/smooth_switch.dart';

/// Configuración de notificaciones y recordatorios.
///
/// Conserva exactamente las preferencias y métodos del provider:
/// - [AppProvider.notificationsEnabled] / [AppProvider.setNotificationsEnabled]
/// - [AppProvider.dailyReminderEnabled] / [AppProvider.setDailyReminderEnabled]
/// - [AppProvider.dailyReminderHour] + [AppProvider.dailyReminderMinute]
/// - [AppProvider.tipsEnabled] / [AppProvider.setTipsEnabled]
///
/// La programación real (identificadores, canales, horarios y periodicidad)
/// permanece en [NotificationService] y no se altera desde esta pantalla.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _notifController;
  late final Animation<double> _notifAnimation;

  late final AnimationController _reminderController;
  late final Animation<double> _reminderAnimation;

  /// Estado real del permiso de notificaciones del sistema.
  /// `true` concedido, `false` bloqueado, `null` desconocido.
  bool? _systemAllowed;

  /// Fuerza la resincronización visual del interruptor maestro cuando el
  /// sistema deniega la activación, evitando mostrar un estado ficticio.
  int _masterRevision = 0;

  @override
  void initState() {
    super.initState();

    _notifController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _notifAnimation = CurvedAnimation(
      parent: _notifController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    _reminderController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _reminderAnimation = CurvedAnimation(
      parent: _reminderController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Sync initial state with provider after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (provider.notificationsEnabled) {
        _notifController.value = 1.0;
      }
      if (provider.dailyReminderEnabled) {
        _reminderController.value = 1.0;
      }
      _refreshSystemStatus();
    });
  }

  @override
  void dispose() {
    _notifController.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  Future<void> _refreshSystemStatus() async {
    if (!mounted) return;
    final provider = Provider.of<AppProvider>(context, listen: false);
    final allowed = await provider.systemNotificationsEnabled();
    if (!mounted) return;
    setState(() => _systemAllowed = allowed);
  }

  Future<void> _toggleNotifications(AppProvider provider, bool val) async {
    final applied = await provider.setNotificationsEnabled(val);
    if (!mounted) return;

    if (val && !applied) {
      // El permiso del sistema estaba denegado: revertir y explicar.
      setState(() => _masterRevision++);
      await _refreshSystemStatus();
      if (mounted) _showPermissionDialog();
      return;
    }

    if (applied) {
      _notifController.forward();
    } else {
      _notifController.reverse();
      _reminderController.reverse();
    }
    setState(() {});
    await _refreshSystemStatus();
  }

  Future<void> _toggleDailyReminder(AppProvider provider, bool val) async {
    await provider.setDailyReminderEnabled(val);
    if (!mounted) return;
    if (provider.dailyReminderEnabled) {
      _reminderController.forward();
    } else {
      _reminderController.reverse();
    }
    setState(() {});
  }

  Future<void> _toggleTips(AppProvider provider, bool val) async {
    await provider.setTipsEnabled(val);
    if (!mounted) return;
    setState(() {});
  }

  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.radiusXl),
        icon: const Icon(
          Icons.notifications_off_outlined,
          color: AppColors.warning,
        ),
        title: Text(
          context.t('notif_permission_denied_title'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        content: Text(
          context.t('notif_permission_dialog_desc'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.t('close')),
          ),
          CashButton(
            label: context.t('open_system_settings'),
            fullWidth: false,
            height: 44,
            icon: const Icon(Icons.settings_outlined, size: 18),
            onPressed: () {
              Navigator.pop(dialogContext);
              openAppSettings();
            },
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
        title: Text(context.t('notifications')),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
          vertical: AppSpacing.screenVertical,
        ),
        children: [
          // ─── General ────────────────────────────────────────────────
          CashSection(
            title: context.t('notif_general'),
            child: _group(context, [
              _tile(
                context,
                icon: Icons.notifications_active_rounded,
                title: context.t('notifications'),
                subtitle: context.t('notif_general_desc'),
                trailing: SmoothSwitch(
                  key: ValueKey('notif_master_$_masterRevision'),
                  value: provider.notificationsEnabled,
                  activeThumbColor: Theme.of(context).colorScheme.primary,
                  onChangedAsync: (val) => _toggleNotifications(provider, val),
                ),
              ),
            ]),
          ),

          const SizedBox(height: AppSpacing.lg),
          _buildSystemStatus(context),

          // ─── Recordatorios + Tips (solo si las notificaciones están activas)
          SizeTransition(
            sizeFactor: _notifAnimation,
            alignment: const AlignmentDirectional(-1.0, -1.0),
            child: FadeTransition(
              opacity: _notifAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xl),
                  CashSection(
                    title: context.t('notif_reminders'),
                    child: CashCard(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.xs,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _tile(
                            context,
                            icon: Icons.edit_calendar_rounded,
                            title: context.t('notif_daily'),
                            subtitle: context.t('notif_daily_desc'),
                            trailing: SmoothSwitch(
                              value: provider.dailyReminderEnabled,
                              activeThumbColor:
                                  Theme.of(context).colorScheme.primary,
                              onChangedAsync: (val) =>
                                  _toggleDailyReminder(provider, val),
                            ),
                          ),
                          SizeTransition(
                            sizeFactor: _reminderAnimation,
                            alignment: const AlignmentDirectional(-1.0, -1.0),
                            child: FadeTransition(
                              opacity: _reminderAnimation,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _divider(context),
                                  _tile(
                                    context,
                                    icon: Icons.access_time_rounded,
                                    title: context.t('notif_time'),
                                    subtitle: TimeOfDay(
                                      hour: provider.dailyReminderHour,
                                      minute: provider.dailyReminderMinute,
                                    ).format(context),
                                    onTap: () => _pickReminderTime(provider),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          _divider(context),
                          _tile(
                            context,
                            icon: Icons.calendar_month_outlined,
                            title: context.t('notif_weekly_label'),
                            subtitle: context.t('notif_weekly_label_desc'),
                            trailing: CashChip(
                              label: context.t('notif_auto'),
                              icon: Icons.autorenew_rounded,
                              selected: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  CashSection(
                    title: context.t('notif_tips_section'),
                    child: _group(context, [
                      _tile(
                        context,
                        icon: Icons.lightbulb_outline_rounded,
                        title: context.t('notif_tips'),
                        subtitle: context.t('notif_tips_desc'),
                        trailing: SmoothSwitch(
                          value: provider.tipsEnabled,
                          activeThumbColor: Theme.of(context).colorScheme.primary,
                          onChangedAsync: (val) => _toggleTips(provider, val),
                        ),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.xxl),
        ],
      ),
    );
  }

  Future<void> _pickReminderTime(AppProvider provider) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: provider.dailyReminderHour,
        minute: provider.dailyReminderMinute,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
            primary: Theme.of(context).colorScheme.primary,
          ),
        ),
        child: child!,
      ),
    );
    if (time != null) {
      await provider.setDailyReminderTime(time.hour, time.minute);
    }
  }

  /// Estado real del permiso del sistema (concedido / bloqueado).
  Widget _buildSystemStatus(BuildContext context) {
    final theme = Theme.of(context);

    if (_systemAllowed == null) {
      return const SizedBox.shrink();
    }

    final isDark = theme.brightness == Brightness.dark;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;

    if (_systemAllowed == true) {
      return Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              context.t('notif_permission_granted'),
              style: theme.textTheme.bodySmall?.copyWith(color: secondaryText),
            ),
          ),
        ],
      );
    }

    return CashCard(
      border: Border.all(
        color: AppColors.warning.withValues(alpha: isDark ? 0.45 : 0.35),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.notifications_off_outlined,
                color: AppColors.warning,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t('notif_permission_denied_title'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      context.t('notif_permission_denied_desc'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          CashButton(
            label: context.t('open_system_settings'),
            type: CashButtonType.outlined,
            height: 44,
            icon: const Icon(Icons.settings_outlined, size: 18),
            onPressed: openAppSettings,
          ),
        ],
      ),
    );
  }

  Widget _divider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 1,
      indent: 72,
      endIndent: AppSpacing.lg,
      color: isDark ? AppColors.dividerDark : AppColors.dividerLight,
    );
  }

  Widget _group(BuildContext context, List<Widget> children) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      rows.add(children[i]);
      if (i != children.length - 1) {
        rows.add(_divider(context));
      }
    }
    return CashCard(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _tile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primaryText = isDark
        ? AppColors.textPrimaryDark
        : AppColors.textPrimary;
    final secondaryText = isDark
        ? AppColors.textSecondaryDark
        : AppColors.textSecondary;
    final chevronColor = isDark
        ? AppColors.textTertiaryDark
        : AppColors.textTertiary;

    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: isDark ? 0.18 : 0.10),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: AppColors.primary, size: 20),
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
        trailing:
            trailing ??
            (onTap != null
                ? Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: chevronColor,
                  )
                : null),
      ),
    );
  }
}
