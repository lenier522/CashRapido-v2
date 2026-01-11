import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';
import 'localization_service.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    // Initialize timezone
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('America/Havana')); // Cuba timezone

    // Android initialization settings
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const initSettings = InitializationSettings(android: androidSettings);

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    // Handle notification tap (open app)
    print('Notification tapped: ${response.payload}');
  }

  // Request notification permissions (Android 13+)
  Future<bool> requestPermissions() async {
    final android = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }

  // Schedule all notifications
  Future<void> scheduleAllNotifications(String langCode) async {
    await scheduleDailyReminder(langCode);
    await scheduleWeeklySummary(langCode);
    await scheduleMotivationalTips(langCode);
  }

  // Daily reminder at 9:00 AM
  Future<void> scheduleDailyReminder(String langCode) async {
    final title = AppLocalizations.getString(langCode, 'notif_daily_title');
    final body = AppLocalizations.getString(langCode, 'notif_daily_body');

    await _notifications.zonedSchedule(
      0, // Notification ID
      title,
      body,
      _nextInstanceOfTime(9, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          'Recordatorios Diarios',
          channelDescription: 'Recordatorios diarios para registrar gastos',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  // Weekly summary on Sundays at 7:00 PM
  Future<void> scheduleWeeklySummary(String langCode) async {
    final title = AppLocalizations.getString(langCode, 'notif_weekly_title');
    final body = AppLocalizations.getString(langCode, 'notif_weekly_body');

    await _notifications.zonedSchedule(
      1, // Notification ID
      title,
      body,
      _nextInstanceOfWeekday(DateTime.sunday, 19, 0),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'weekly_summary',
          'Resumen Semanal',
          channelDescription: 'Resumen semanal de gastos',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  // Motivational tips (3 random times per week)
  Future<void> scheduleMotivationalTips(String langCode) async {
    // Schedule 3 tips per week (Mon, Wed, Fri at different times)
    final schedules = [
      {'day': DateTime.monday, 'hour': 14, 'minute': 0},
      {'day': DateTime.wednesday, 'hour': 16, 'minute': 30},
      {'day': DateTime.friday, 'hour': 12, 'minute': 0},
    ];

    final title = AppLocalizations.getString(langCode, 'notif_tip_title');

    for (int i = 0; i < schedules.length; i++) {
      final schedule = schedules[i];
      // Pick a random tip key from tip_1 to tip_5
      final randomTipKey = 'tip_${Random().nextInt(5) + 1}';
      final randomTip = AppLocalizations.getString(langCode, randomTipKey);

      await _notifications.zonedSchedule(
        10 + i, // Notification IDs: 10, 11, 12
        title,
        randomTip,
        _nextInstanceOfWeekday(
          schedule['day'] as int,
          schedule['hour'] as int,
          schedule['minute'] as int,
        ),
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'financial_tips',
            'Tips Financieros',
            channelDescription: 'Consejos y motivación financiera',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  // Cancel all scheduled notifications
  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }

  // Helper: Get next instance of specific time today/tomorrow
  tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  // Helper: Get next instance of specific weekday and time
  tz.TZDateTime _nextInstanceOfWeekday(int weekday, int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    while (scheduledDate.weekday != weekday || scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }
}
