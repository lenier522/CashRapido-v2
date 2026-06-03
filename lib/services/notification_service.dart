import 'package:flutter/foundation.dart';
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
    debugPrint('Notification tapped: ${response.payload}');
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
  Future<void> scheduleAllNotifications(
    String langCode, {
    bool dailyReminderEnabled = true,
    int dailyReminderHour = 9,
    int dailyReminderMinute = 0,
    bool tipsEnabled = true,
  }) async {
    if (dailyReminderEnabled) {
      await scheduleDailyReminder(langCode, dailyReminderHour, dailyReminderMinute);
    } else {
      await cancelDailyReminder();
    }
    await scheduleWeeklySummary(langCode);
    if (tipsEnabled) {
      await scheduleMotivationalTips(langCode);
    } else {
      await cancelMotivationalTips();
    }
  }

  Future<void> cancelDailyReminder() async {
    await _notifications.cancel(0);
  }

  Future<void> cancelMotivationalTips() async {
    await _notifications.cancel(10);
    await _notifications.cancel(11);
    await _notifications.cancel(12);
  }

  // Daily reminder at custom time
  Future<void> scheduleDailyReminder(String langCode, int hour, int minute) async {
    final title = AppLocalizations.getString(langCode, 'notif_daily_title');
    final body = AppLocalizations.getString(langCode, 'notif_daily_body');

    await _notifications.zonedSchedule(
      0, // Notification ID
      title,
      body,
      _nextInstanceOfTime(hour, minute),
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

  // Schedule notification for loan installment due date
  Future<void> scheduleInstallmentReminder({
    required String langCode,
    required String loanId,
    required int installmentNumber,
    required String borrowerName,
    required double amount,
    required String currency,
    required DateTime dueDate,
  }) async {
    // Generate a unique positive 32-bit int notification ID
    final notificationId = (loanId.hashCode + installmentNumber) & 0x7FFFFFFF;

    final title = langCode == 'es' ? 'Vencimiento de Cuota' : 'Installment Due';
    final body = langCode == 'es'
        ? 'La cuota #$installmentNumber de $borrowerName por \$${amount.toStringAsFixed(2)} $currency vence hoy.'
        : 'Installment #$installmentNumber for $borrowerName of \$${amount.toStringAsFixed(2)} $currency is due today.';

    // Schedule for 9:00 AM on the due date in Cuba/Local time
    final scheduledDate = tz.TZDateTime(
      tz.local,
      dueDate.year,
      dueDate.month,
      dueDate.day,
      9, // Hour
      0, // Minute
    );

    // If scheduled time is in the past, don't schedule it
    if (scheduledDate.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notifications.zonedSchedule(
      notificationId,
      title,
      body,
      scheduledDate,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'loan_reminders',
          'Recordatorios de Préstamos',
          channelDescription: 'Notificaciones sobre cuotas por cobrar hoy',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  Future<void> cancelInstallmentReminder(String loanId, int installmentNumber) async {
    final notificationId = (loanId.hashCode + installmentNumber) & 0x7FFFFFFF;
    await _notifications.cancel(notificationId);
  }
}
