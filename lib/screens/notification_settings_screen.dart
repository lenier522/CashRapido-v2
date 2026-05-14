import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/app_provider.dart';
import '../services/localization_service.dart';
import '../widgets/smooth_switch.dart';

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
      final provider = Provider.of<AppProvider>(context, listen: false);
      if (provider.notificationsEnabled) {
        _notifController.value = 1.0;
      }
      if (provider.dailyReminderEnabled) {
        _reminderController.value = 1.0;
      }
    });
  }

  @override
  void dispose() {
    _notifController.dispose();
    _reminderController.dispose();
    super.dispose();
  }

  void _toggleNotifications(AppProvider provider, bool val) async {
    await provider.setNotificationsEnabled(val);
    if (val) {
      _notifController.forward();
    } else {
      _notifController.reverse();
    }
  }

  void _toggleDailyReminder(AppProvider provider, bool val) async {
    await provider.setDailyReminderEnabled(val);
    if (val) {
      _reminderController.forward();
    } else {
      _reminderController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<AppProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          context.t('notifications'),
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle(context.t('notif_general')),
            _buildSettingsTile(
              icon: Icons.notifications_active_rounded,
              title: context.t('notifications'),
              subtitle: context.t('notif_general_desc'),
              trailing: SmoothSwitch(
                value: provider.notificationsEnabled,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                onChangedAsync: (val) async =>
                    _toggleNotifications(provider, val),
              ),
            ),

            // ─── Expandible Notifications Section ───────────────────────
            SizeTransition(
              sizeFactor: _notifAnimation,
              axisAlignment: -1.0,
              child: FadeTransition(
                opacity: _notifAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 24),
                    _buildSectionTitle(context.t('notif_reminders')),
                    _buildSettingsTile(
                      icon: Icons.edit_calendar_rounded,
                      title: context.t('notif_daily'),
                      subtitle: context.t('notif_daily_desc'),
                      trailing: SmoothSwitch(
                        value: provider.dailyReminderEnabled,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChangedAsync: (val) async =>
                            _toggleDailyReminder(provider, val),
                      ),
                    ),

                    // ─── Expandible Time Picker ──────────────────────
                    SizeTransition(
                      sizeFactor: _reminderAnimation,
                      axisAlignment: -1.0,
                      child: FadeTransition(
                        opacity: _reminderAnimation,
                        child: _buildSettingsTile(
                          icon: Icons.access_time_rounded,
                          title: context.t('notif_time'),
                          subtitle: TimeOfDay(
                            hour: provider.dailyReminderHour,
                            minute: provider.dailyReminderMinute,
                          ).format(context),
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: Theme.of(context).disabledColor,
                          ),
                          onTap: () async {
                            final time = await showTimePicker(
                              context: context,
                              initialTime: TimeOfDay(
                                hour: provider.dailyReminderHour,
                                minute: provider.dailyReminderMinute,
                              ),
                              builder: (context, child) => Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: Theme.of(context).colorScheme
                                      .copyWith(
                                        primary: Theme.of(
                                          context,
                                        ).colorScheme.primary,
                                      ),
                                ),
                                child: child!,
                              ),
                            );
                            if (time != null) {
                              await provider.setDailyReminderTime(
                                time.hour,
                                time.minute,
                              );
                            }
                          },
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    _buildSectionTitle(context.t('notif_tips_section')),
                    _buildSettingsTile(
                      icon: Icons.lightbulb_outline_rounded,
                      title: context.t('notif_tips'),
                      subtitle: context.t('notif_tips_desc'),
                      trailing: SmoothSwitch(
                        value: provider.tipsEnabled,
                        activeThumbColor: Theme.of(context).colorScheme.primary,
                        onChangedAsync: (val) => provider.setTipsEnabled(val),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, left: 8.0),
      child: Text(
        title,
        style: GoogleFonts.outfit(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
          letterSpacing: 1.1,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: Theme.of(context).colorScheme.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                          color: Theme.of(context).textTheme.bodyLarge?.color,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          style: GoogleFonts.outfit(
                            fontSize: 12.5,
                            color: Theme.of(context).textTheme.bodyMedium?.color
                                ?.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                ?trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
