import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:benw_edu/models/calendar_event.dart';
import 'package:benw_edu/models/companion_message.dart';
import 'package:benw_edu/services/benw_edu_service.dart';
import 'package:benw_edu/services/notification_service.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The brain of the Benw Companion feature.
///
/// Runs two background routines:
///  1. **Block-end detector** (every 2 min) — fires check-in messages when
///     calendar events end.
///  2. **Walk timer** — tracks continuous study time and fires a walk reminder
///     after [walkReminderMinutes] of unbroken study.
///
/// Feature additions:
///  - Passes weekly calendar context to Benw for calendar-aware responses.
///  - Parses `Benw_CALENDAR_ACTION:{...}` tags from Benw's responses and
///    applies them to the calendar via [addEventCallback] / [updateEventCallback].
class CompanionService {
  static final CompanionService _instance = CompanionService._internal();
  factory CompanionService() => _instance;
  CompanionService._internal();

  static const int walkReminderMinutes = 60;

  final _benw = BenwEduService();
  final _notifications = NotificationService();

  // ── Settings flags (updated from SettingsProvider) ────────────────────────
  bool notificationsEnabled = true;
  bool walkRemindersEnabled = true;

  // ── Callbacks wired from HomeScreen ──────────────────────────────────────
  /// Returns today's calendar events for block-end detection.
  List<CalendarEvent> Function()? getEventsCallback;

  /// Returns a plain-text summary of the next 7 days for Benw's context.
  String Function()? getWeekCalendarCallback;

  /// Adds a new event (used when Benw suggests a revision block).
  void Function(CalendarEvent)? addEventCallback;

  /// Updates an existing event (used when Benw reschedules).
  void Function(String id, int newHour, int newMinute)? rescheduleEventCallback;

  /// Convenience: adds an event on a relative day offset (0=today, 1=tomorrow…)
  CalendarEvent Function({
    required int dayOffset,
    required String title,
    required EventType type,
    required int hour,
    int minute,
    String description,
  })? addEventOnDayCallback;

  // ── Message stream ────────────────────────────────────────────────────────
  final StreamController<CompanionMessage> _messageStream =
      StreamController<CompanionMessage>.broadcast();

  Stream<CompanionMessage> get messageStream => _messageStream.stream;

  // ── Internal state ────────────────────────────────────────────────────────
  Timer? _blockCheckTimer;
  Timer? _walkTimer;

  final Set<String> _firedBlockIds = {};
  bool _walkReminderFired = false;
  DateTime? _continuousStudyStart;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void start() {
    _blockCheckTimer?.cancel();
    _blockCheckTimer = Timer.periodic(
      const Duration(minutes: 2),
      (_) => _checkBlockEnds(),
    );

    _walkTimer?.cancel();
    _walkTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkWalkReminder(),
    );

    log('CompanionService: Started.');
  }

  int _demoStep = 0;

  void triggerDemoStep() {
    _demoStep++;
    log('CompanionService: Triggering demo step $_demoStep');

    switch (_demoStep) {
      case 1:
        log('CompanionService: Step 1 - Waiting 20s for Calculus...');
        Timer(const Duration(seconds: 20), () {
          _emit(CompanionMessage.Benw(
            text: "Your Calculus session has concluded. How would you rate your understanding of the concepts?",
            type: CompanionMessageType.studyCheckIn,
            quickReplies: ["Confident", "Adequate", "Uncertain"],
          ));
        });
        break;

      case 2:
        log('CompanionService: Step 2 - Clearing previous and waiting 20s for Nutrition...');
        // First, clear the chat history in UI
        _emit(CompanionMessage.Benw(
          text: "CLEARING_HISTORY",
          type: CompanionMessageType.clearHistory,
        ));

        // Then wait 20s and launch Nutrition
        Timer(const Duration(seconds: 20), () {
          _emit(CompanionMessage.Benw(
            text: "Nutrition check. Provide details of your last meal to ensure adequate fuel for cognitive function.",
            type: CompanionMessageType.nutritionCheck,
            quickReplies: ["Meal details provided", "Balanced meal", "Light snack"],
          ));
        });
        break;

      case 3:
        log('CompanionService: Step 3 - Deleting all and restarting.');
        // Clear UI history
        _emit(CompanionMessage.Benw(
          text: "CLEARING_ALL",
          type: CompanionMessageType.clearHistory,
        ));
        // Clear all system notifications
        _notifications.cancelAll();
        // Reset demo cycle
        _demoStep = 0;
        break;

      default:
        _demoStep = 0;
    }
  }

  /// ── Demo Orchestration ────────────────────────────────────────────────────
  void startDemo() {
    log('CompanionService: Starting staggered demo sequence.');

    Timer(const Duration(minutes: 5), () {
      if (_demoStep == 0) triggerDemoStep();
    });

    Timer(const Duration(minutes: 10), () {
      if (_demoStep == 1) triggerDemoStep();
    });

    Timer(const Duration(minutes: 15), () {
      if (_demoStep == 2) triggerDemoStep();
    });
  }

  void stop() {
    _blockCheckTimer?.cancel();
    _walkTimer?.cancel();
    _blockCheckTimer = null;
    _walkTimer = null;
    log('CompanionService: Stopped.');
  }

  void dispose() {
    stop();
    _messageStream.close();
  }

  // ── Block-end detector ────────────────────────────────────────────────────

  void _checkBlockEnds() {
    if (getEventsCallback == null) return;

    final now = DateTime.now();
    final events = getEventsCallback!();

    final ended = events.where((e) {
      if (_firedBlockIds.contains(e.id)) return false;
      final end = e.endTime;
      if (end == null) return false;
      final diff = now.difference(end).inMinutes;
      return diff >= 0 && diff < 4;
    }).toList();

    for (final event in ended) {
      _firedBlockIds.add(event.id);
      _fireBlockEndMessage(event);
    }
  }

  void _fireBlockEndMessage(CalendarEvent event) {
    CompanionMessage msg;

    switch (event.type) {
      case EventType.study:
      case EventType.revision:
        msg = CompanionMessage.Benw(
          text: 'Great work finishing ${event.title}! How did it go? Did you find anything tricky?',
          type: CompanionMessageType.studyCheckIn,
          linkedEventId: event.id,
          quickReplies: [
            'Productive',
            'Neutral',
            'Challenging',
            'Incomplete',
          ],
        );
        break;

      case EventType.personal:
        msg = CompanionMessage.Benw(
          text: 'Time for a nutrition check! What did you have for your last meal?',
          type: CompanionMessageType.nutritionCheck,
          linkedEventId: event.id,
          quickReplies: [
            'Balanced meal',
            'Protein focused',
            'High carb / processed',
            'Skipped',
          ],
        );
        break;

      case EventType.sport:
        msg = CompanionMessage.Benw(
          text: 'Active session done! How are you feeling after that workout?',
          type: CompanionMessageType.exerciseCheckIn,
          linkedEventId: event.id,
          quickReplies: ['High intensity', 'Moderate', 'Low / Skipped'],
        );
        break;

      case EventType.relax:
        msg = CompanionMessage.Benw(
          text: 'Break is over! Feeling refreshed and ready for more?',
          type: CompanionMessageType.exerciseCheckIn,
          linkedEventId: event.id,
          quickReplies: ['Restored', 'Partial', 'Inadequate'],
        );
        break;

      case EventType.deepSleep:
        msg = CompanionMessage.Benw(
          text: 'Good morning! Ready to tackle your goals today?',
          type: CompanionMessageType.greeting,
          linkedEventId: event.id,
          quickReplies: ["Commence", "Delayed start"],
        );
        break;

      default:
        return;
    }

    _emit(msg);
  }

  // ── Walk reminder ─────────────────────────────────────────────────────────

  void _checkWalkReminder() {
    if (getEventsCallback == null) return;

    final now = DateTime.now();
    final events = getEventsCallback!();

    final activeStudy = events.any((e) {
      if (e.type != EventType.study && e.type != EventType.revision) return false;
      if (e.time == null) return false;
      final start = DateTime(e.date.year, e.date.month, e.date.day,
          e.time!.hour, e.time!.minute);
      final end = start.add(const Duration(minutes: 60));
      return now.isAfter(start) && now.isBefore(end);
    });

    if (activeStudy) {
      _continuousStudyStart ??= now;

      final studyMinutes = now.difference(_continuousStudyStart!).inMinutes;

      if (studyMinutes >= walkReminderMinutes && !_walkReminderFired) {
        _walkReminderFired = true;
        _emit(CompanionMessage.Benw(
          text:
              'Recommended break. You have reached $walkReminderMinutes minutes of continuous study.\n\nA 5-minute movement break is required for optimal memory consolidation.',
          type: CompanionMessageType.walkReminder,
          quickReplies: ['Completed', 'In 5 minutes', 'Already completed'],
        ));
      }
    } else {
      _continuousStudyStart = null;
      _walkReminderFired = false;
    }
  }

  // ── Reply handler — called from the chat UI ───────────────────────────────

  Future<CompanionMessage> handleUserReply({
    required String text,
    required CompanionMessage replyingTo,
    List<CompanionMessage> history = const [],
  }) async {
    final weekCtx = getWeekCalendarCallback?.call() ?? '';

    final historyMap = history.take(10).map((m) => {
      'role': m.isUser ? 'user' : 'assistant',
      'content': m.text,
    }).toList();

    // ── Benw response ────────────────────────────────────────────────────────
    String BenwText;

    try {
      switch (replyingTo.type) {
        case CompanionMessageType.studyCheckIn:
          final subject = _subjectFromLinkedEvent(replyingTo.linkedEventId);
          BenwText = await _benw.generateStudyCheckIn(
            subject: subject,
            userFeedback: text,
            durationMinutes: 60,
            eventId: replyingTo.linkedEventId,
            weekCalendarContext: weekCtx,
            chatHistory: historyMap,
          );
          break;

        case CompanionMessageType.nutritionCheck:
          BenwText = await _benw.generateNutritionAdvice(
            mealDescription: text,
            weekCalendarContext: weekCtx,
            chatHistory: historyMap,
          );
          break;

        case CompanionMessageType.walkReminder:
          if (text.toLowerCase().contains('done') ||
              text.toLowerCase().contains('walk')) {
            BenwText =
                'Acknowledged. Brief activity is proven to improve focus. Resume when ready.';
          } else {
            BenwText =
                'Recorded. Ensure the break is taken at the next interval.';
          }
          break;

        default:
          final result = await _benw.generateAssistantResponse(
            text,
            chatHistory: historyMap,
            calendarContext: weekCtx,
          );
          BenwText = result.response;
      }
    } catch (e) {
      log('CompanionService: Benw response failed: $e');
      BenwText = 'Input received. Continue with your schedule.';
    }

    // ── Parse and apply calendar actions from Benw's response ───────────────
    final parsed = _benw.parseCalendarActions(BenwText);
    List<Map<String, dynamic>> calendarSuggestions = parsed.actions;
    var processedText = parsed.cleanedText;

    // ── Parse and apply reminder actions ─────────────────────────────────────
    processedText = _parseAndApplyReminderAction(processedText);

    // ── Safety check: Ensure the response is not empty after parsing tags ───
    if (processedText.isEmpty && calendarSuggestions.isNotEmpty) {
      processedText = "Great! I've added those to your calendar. Check it out in the planner! 😉";
    } else if (processedText.isEmpty) {
      processedText = "I'm processing that... sometimes I need a moment to think. Could you repeat that? 🤔";
    }

    List<String> extractedReplies = [];
    final cleanedText = _parseQuickReplies(processedText, (replies) {
      extractedReplies = replies;
    });

    return CompanionMessage.Benw(
      text: cleanedText,
      type: CompanionMessageType.BenwResponse,
      linkedEventId: replyingTo.linkedEventId,
      calendarSuggestions: calendarSuggestions,
      quickReplies: extractedReplies,
    );
  }

  // ── Calendar action parser ─────────────────────────────────────────────────


  /// Scans Benw's text for `Benw_REMINDER_ACTION:{...}` and applies it.
  String _parseAndApplyReminderAction(String text) {
    const tag = 'Benw_REMINDER_ACTION:';
    final idx = text.indexOf(tag);
    if (idx == -1) return text.trim();

    final jsonPart = text.substring(idx + tag.length).trim();
    final cleanText = text.substring(0, idx).trim();

    try {
      final start = jsonPart.indexOf('{');
      final end = jsonPart.lastIndexOf('}');
      if (start == -1 || end == -1) return cleanText;

      final raw = jsonPart.substring(start, end + 1);
      final reminder = jsonDecode(raw) as Map<String, dynamic>;

      _applyReminderAction(reminder);
    } catch (e) {
      log('CompanionService: Reminder action parse error: $e');
    }

    return cleanText;
  }

  void _applyReminderAction(Map<String, dynamic> reminder) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (reminder['action'] == 'stop') {
        await prefs.remove('active_recurring_reminder');
        log('CompanionService: Recurring reminder STOPPED.');
        return;
      }

      final message = reminder['message'] as String? ?? 'Reminder!';
      final interval = (reminder['interval_minutes'] as num?)?.toInt() ?? 5;

      final reminderData = {
        'message': message,
        'interval_minutes': interval,
        'last_fire_time': DateTime.now().millisecondsSinceEpoch,
      };

      await prefs.setString('active_recurring_reminder', jsonEncode(reminderData));
      log('CompanionService: Recurring reminder set: $message every $interval min');
    } catch (e) {
      log('CompanionService: Failed to apply reminder action: $e');
    }
  }

  /// Scans Benw's text for `Benw_QUICK_REPLIES:[...]` and extracts them.
  /// Returns the cleaned text without the replies tag.
  String _parseQuickReplies(
    String text,
    void Function(List<String>) onReplies,
  ) {
    const tag = 'Benw_QUICK_REPLIES:';
    final idx = text.indexOf(tag);
    if (idx == -1) return text.trim();

    final listPart = text.substring(idx + tag.length).trim();
    final cleanText = text.substring(0, idx).trim();

    try {
      final start = listPart.indexOf('[');
      final end = listPart.indexOf(']');
      if (start == -1 || end == -1) return cleanText;

      final raw = listPart.substring(start, end + 1);
      final list = jsonDecode(raw) as List<dynamic>;
      onReplies(list.map((e) => e.toString()).toList());
    } catch (e) {
      log('CompanionService: Quick replies parse error: $e');
    }

    return cleanText;
  }

  void applyCalendarAction(Map<String, dynamic> action) {
    try {
      final actionType = action['action'] as String? ?? '';

      if (actionType == 'add_block' && addEventOnDayCallback != null) {
        final dayOffset = (action['day_offset'] as num?)?.toInt() ?? 1;
        final title = action['title'] as String? ?? '📚 Revision';
        final hour = (action['hour'] as num?)?.toInt() ?? 16;
        final minute = (action['minute'] as num?)?.toInt() ?? 0;
        final description =
            action['description'] as String? ?? 'Benw-recommended block.';
        final typeStr = action['type'] as String? ?? 'revision';
        final type = _eventTypeFromString(typeStr);

        addEventOnDayCallback!(
          dayOffset: dayOffset,
          title: title,
          type: type,
          hour: hour,
          minute: minute,
          description: description,
        );
        log('CompanionService: Calendar action applied — added "$title" at $hour:00 (day+$dayOffset)');
      } else if (actionType == 'reschedule' && rescheduleEventCallback != null) {
        final id = action['event_id'] as String?;
        final hour = (action['new_hour'] as num?)?.toInt() ?? 16;
        final minute = (action['new_minute'] as num?)?.toInt() ?? 0;
        if (id != null) {
          rescheduleEventCallback!(id, hour, minute);
          log('CompanionService: Calendar action applied — rescheduled $id to $hour:$minute');
        }
      }
    } catch (e) {
      log('CompanionService: Failed to apply calendar action: $e');
    }
  }

  EventType _eventTypeFromString(String s) {
    switch (s.toLowerCase()) {
      case 'study': return EventType.study;
      case 'revision': return EventType.revision;
      case 'sport': return EventType.sport;
      case 'relax': return EventType.relax;
      case 'personal': return EventType.personal;
      case 'deepsleep': return EventType.deepSleep;
      default: return EventType.study;
    }
  }

  /// Manually trigger a study check-in (e.g. from event card long-press)
  void triggerStudyCheckIn(CalendarEvent event) {
    if (!_firedBlockIds.contains(event.id)) {
      _firedBlockIds.add(event.id);
    }
    _fireBlockEndMessage(event);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _subjectFromLinkedEvent(String? eventId) {
    if (eventId == null || getEventsCallback == null) return 'your subject';
    final events = getEventsCallback!();
    try {
      final event = events.firstWhere((e) => e.id == eventId);
      return event.title;
    } catch (_) {
      return 'your subject';
    }
  }

  void _emit(CompanionMessage msg) {
    if (!_messageStream.isClosed) {
      _messageStream.add(msg);
    }

    // Send to system overlay isolate
    if (!msg.isUser) {
      try {
        FlutterOverlayWindow.shareData({
          'type': 'show_message',
          'text': msg.text,
          'quick_replies': msg.quickReplies,
        });
      } catch (e) {
        log('CompanionService: Overlay share error: $e');
      }
    }

    // Also fire system notification
    if (notificationsEnabled && !msg.isUser) {
      _fireNotification(msg);
    }
  }

  void _fireNotification(CompanionMessage msg) {
    try {
      // Skip notifications for history clearing
      if (msg.type == CompanionMessageType.clearHistory) return;

      // ALL Benw messages get a messenger-style companion notification
      // so they appear as chat messages in the status bar.
      if (msg.type != CompanionMessageType.greeting) {
        final title = _notifTitleFor(msg.type);
        final body = msg.text.length > 120
            ? '${msg.text.substring(0, 117)}...'
            : msg.text;
        _notifications.showCompanionNotification(title: title, body: body);

        // Walk reminders also get the extra vibration/sound notification
        if (msg.type == CompanionMessageType.walkReminder && walkRemindersEnabled) {
          _notifications.showWalkReminderNotification();
        }
      }
    } catch (e) {
      log('CompanionService: Notification failed: $e');
    }
  }


  String _notifTitleFor(CompanionMessageType type) {
    switch (type) {
      case CompanionMessageType.studyCheckIn:
        return 'Study Session Complete';
      case CompanionMessageType.nutritionCheck:
        return 'Nutrition Check-in';
      case CompanionMessageType.exerciseCheckIn:
        return 'Activity Concluded';
      case CompanionMessageType.walkReminder:
        return 'Scheduled Break Reminder';
      default:
        return 'Benw Companion';
    }
  }
}
