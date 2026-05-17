import 'dart:async';
import 'dart:ui';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'dopamine_companion_channel',
      'Companion Alerts',
      description: 'Notifications for Benw Companion check-ins',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // User tapped a notification — set flag so HomeScreen opens the
        // companion chat when the app comes to the foreground.
        // No overlay involved — the companion lives only inside the app.
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool('pending_open_chat', true);
        } catch (_) {}
      },
    );
  }


  /// Schedule a notification for an upcoming study block
  Future<void> scheduleNotification({
    required String id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    // Prevent scheduling in the past
    if (scheduledDate.isBefore(DateTime.now())) {
      return;
    }

    await _notificationsPlugin.zonedSchedule(
      id.hashCode,
      title,
      body,
      tz.TZDateTime.from(scheduledDate, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'study_blocks',
          'Study Blocks',
          channelDescription: 'Reminders for upcoming study sessions',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: MessagingStyleInformation(
            const Person(name: 'You'),
            conversationTitle: 'Benw Companion',
            messages: [
              Message(body, DateTime.now(), const Person(name: 'Benw', icon: DrawableResourceAndroidIcon('@mipmap/ic_launcher'))),
            ],
          ),
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF7C3AED),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  /// Immediately show a "Roast" notification for missed study blocks
  Future<void> showImmediateRoast({
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'roast_reminders',
          'Roast & Remind',
          channelDescription: 'Funny AI roasts when you miss study blocks',
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: MessagingStyleInformation(
            const Person(name: 'You'),
            conversationTitle: 'Benw Companion',
            messages: [
              Message(body, DateTime.now(), const Person(name: 'Benw', icon: DrawableResourceAndroidIcon('@mipmap/ic_launcher'))),
            ],
          ),
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF7C3AED),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
    );
  }

  /// Schedule a pre-study-block reminder (5 min before)
  Future<void> scheduleStudyReminder({
    required String id,
    required String subject,
    required DateTime studyTime,
  }) async {
    final reminderTime = studyTime.subtract(const Duration(minutes: 5));
    if (reminderTime.isBefore(DateTime.now())) return;

    await scheduleNotification(
      id: 'reminder_$id',
      title: '📚 $subject in 5 minutes!',
      body: 'Time to get your brain in gear. Your $subject study block starts soon!',
      scheduledDate: reminderTime,
    );
  }

  Future<void> cancelNotification(String id) async {
    await _notificationsPlugin.cancel(id.hashCode);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  Future<void> requestPermissions() async {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        _notificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await androidImplementation?.requestNotificationsPermission();

    // Android 14+ requires explicit permission for exact alarms
    if (await Permission.scheduleExactAlarm.isDenied) {
      await Permission.scheduleExactAlarm.request();
    }
  }

  /// Show a Benw Companion check-in notification (block end, nutrition, etc.)
  Future<void> showCompanionNotification({
    required String title,
    required String body,
  }) async {
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'companion_checkins',
          'Benw Companion',
          channelDescription: 'Check-in messages from your AI study partner',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: MessagingStyleInformation(
            const Person(
              name: 'You',
            ),
            conversationTitle: 'Benw Companion',
            messages: [
              Message(
                body,
                DateTime.now(),
                const Person(
                  name: 'Benw',
                  icon: DrawableResourceAndroidIcon('@mipmap/ic_launcher'),
                ),
              ),
            ],
          ),
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF7C3AED),
          enableLights: true,
          enableVibration: true,
          playSound: true,
          autoCancel: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
    );
  }

  /// High-priority walk break reminder notification
  Future<void> showWalkReminderNotification() async {
    const String body = "You've been studying for 60+ minutes. Stand up and walk for 5 min — your brain needs it! 🧠";
    await _notificationsPlugin.show(
      99999, // Fixed ID so it replaces any previous walk reminder
      '⚡ Walk Break Time!',
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'walk_reminders',
          'Walk Reminders',
          channelDescription: 'Health reminders to take walking breaks during study',
          importance: Importance.max,
          priority: Priority.max,
          styleInformation: MessagingStyleInformation(
            const Person(name: 'You'),
            conversationTitle: 'Benw Companion',
            messages: [
              Message(body, DateTime.now(), const Person(name: 'Benw', icon: DrawableResourceAndroidIcon('@mipmap/ic_launcher'))),
            ],
          ),
          icon: '@mipmap/ic_launcher',
          color: const Color(0xFF2DD4BF),
          enableLights: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
          fullScreenIntent: false,
          autoCancel: true,
          ticker: 'Walk break reminder',
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      ),
    );
  }
}
