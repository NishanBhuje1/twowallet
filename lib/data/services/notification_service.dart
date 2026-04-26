import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Australia/Sydney'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      ),
    );

    await _plugin.initialize(settings);
    _initialized = true;
  }

  static Future<void> scheduleMoneyDate({
    required int dayOfWeek,
    required int hour,
  }) async {
    await _plugin.cancelAll();

    final now = tz.TZDateTime.now(tz.local);

    // Dart weekday: 1=Monday … 7=Sunday. Subtract directly before modulo.
    int daysUntil = (dayOfWeek - now.weekday + 7) % 7;
    if (daysUntil == 0 && now.hour >= hour) daysUntil = 7;

    final scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + daysUntil,
      hour,
    );

    await _plugin.zonedSchedule(
      0,
      'Your Money Date is ready',
      '3 things to talk about this week — takes 5 minutes.',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'money_date',
          'Money Date',
          channelDescription: 'Weekly Money Date reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
    );
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
