import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

// NOTE: flutter_overlay_window calls have been REMOVED from this file.
// The system overlay was causing Impeller SIGSEGV crashes because it
// created a transparent Flutter render surface with unbounded GPU texture
// allocation. The companion now lives only inside the app.

class BackgroundServiceManager {
  static final BackgroundServiceManager _instance =
      BackgroundServiceManager._internal();
  factory BackgroundServiceManager() => _instance;
  BackgroundServiceManager._internal();

  final service = FlutterBackgroundService();
  bool _isConfigured = false;

  Future<void> init() async {
    if (_isConfigured) return;

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
        onBackground: onIosBackground,
      ),
    );
    _isConfigured = true;
  }

  Future<void> startService() async {
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  Future<void> stopService() async {
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }

  static void persistEventsForBackground(
      List<Map<String, dynamic>> events) async {
    final prefs = await SharedPreferences.getInstance();
    final stringList = events.map((e) {
      return "${e['id']}|${e['title']}|${e['eventType']}|${e['endHour']}|${e['endMinute']}";
    }).toList();
    await prefs.setStringList('background_events_today', stringList);
  }
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Initialize notifications in the background isolate
  await flutterLocalNotificationsPlugin.initialize(
    const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      // Notification tapped — set flag so app opens companion chat on resume
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('pending_open_chat', true);
      } catch (_) {}
    },
  );

  final androidPlugin = flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  if (androidPlugin != null) {
    await androidPlugin.createNotificationChannel(
        const AndroidNotificationChannel(
      'dopamine_companion_channel',
      'Companion Alerts',
      importance: Importance.high,
    ));

    if (service is AndroidServiceInstance) {
      service.setAsForegroundService();
      service.setForegroundNotificationInfo(
        title: "Benw is watching your schedule",
        content: "Running in the background",
      );
    }
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // ── Block-end check every minute ──────────────────────────────────────────
  Timer.periodic(const Duration(minutes: 1), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    
    final now = DateTime.now();

    // ── 1. Recurring Reminders Check ────────────────────────────────────────
    final reminderJson = prefs.getString('active_recurring_reminder');
    if (reminderJson != null) {
      try {
        final reminder = jsonDecode(reminderJson) as Map<String, dynamic>;
        final message = reminder['message'] as String;
        final interval = reminder['interval_minutes'] as int;
        final lastFire = reminder['last_fire_time'] as int;

        final nowMs = now.millisecondsSinceEpoch;
        if (nowMs - lastFire >= (interval * 60 * 1000) - 5000) { // 5s buffer
          await flutterLocalNotificationsPlugin.show(
            88888,
            'Benw Nudge',
            message,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'dopamine_companion_channel',
                'Companion Alerts',
                importance: Importance.high,
                priority: Priority.high,
                styleInformation: MessagingStyleInformation(
                  const Person(name: 'You'),
                  conversationTitle: 'Benw Companion',
                  messages: [
                    Message(
                      message,
                      now,
                      const Person(
                        name: 'Benw',
                        icon: DrawableResourceAndroidIcon('@mipmap/ic_launcher'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          reminder['last_fire_time'] = nowMs;
          await prefs.setString('active_recurring_reminder', jsonEncode(reminder));
          // Set flag to open chat on resume
          await prefs.setBool('pending_open_chat', true);
        }
      } catch (e) {
        debugPrint("Background reminder error: $e");
      }
    }

    // ── 2. Block-end events check ───────────────────────────────────────────
    final eventsJson = prefs.getStringList('background_events_today') ?? [];
    final firedEventIds =
        prefs.getStringList('fired_background_events') ?? [];


    for (final eventStr in eventsJson) {
      try {
        final parts = eventStr.split('|');
        if (parts.length < 5) continue;

        final id = parts[0];
        final title = parts[1];
        final type = parts[2];
        final endHour = int.tryParse(parts[3]) ?? -1;
        final endMinute = int.tryParse(parts[4]) ?? -1;

        if (endHour < 0 || firedEventIds.contains(id)) continue;

        final endTime =
            DateTime(now.year, now.month, now.day, endHour, endMinute);

        if (now.isAfter(endTime) &&
            now.difference(endTime).inMinutes < 60) {
          final String notifTitle;
          final String msgText;
          if (type == 'study' || type == 'revision') {
            notifTitle = '📚 Study block done! How did it go?';
            msgText = '📚 Just wrapped up your $title block! How did it go?';
          } else if (type == 'personal') {
            notifTitle = '🥗 Meal check-in from Benw';
            msgText = '🥗 Meal time done! What did you eat?';
          } else if (type == 'sport') {
            notifTitle = '🏃 Activity done! Great work!';
            msgText = '🏃 Exercise block done! Endorphins activated!';
          } else {
            firedEventIds.add(id);
            await prefs.setStringList('fired_background_events', firedEventIds);
            continue;
          }

          // Show notification — tapping it opens the app via pending_open_chat flag
          await flutterLocalNotificationsPlugin.show(
            id.hashCode,
            notifTitle,
            msgText,
            NotificationDetails(
              android: AndroidNotificationDetails(
                'dopamine_companion_channel',
                'Companion Alerts',
                importance: Importance.high,
                priority: Priority.high,
                styleInformation: MessagingStyleInformation(
                  const Person(name: 'You'),
                  conversationTitle: 'Benw Companion',
                  messages: [
                    Message(
                      msgText,
                      now,
                      const Person(
                        name: 'Benw',
                        icon: DrawableResourceAndroidIcon('@mipmap/ic_launcher'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );

          // Set flag so HomeScreen opens the companion chat on resume
          await prefs.setBool('pending_open_chat', true);

          firedEventIds.add(id);
          await prefs.setStringList('fired_background_events', firedEventIds);
        }
      } catch (e) {
        debugPrint("Background parse error: $e");
      }
    }
  });
}
