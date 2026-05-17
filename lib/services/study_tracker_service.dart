import 'dart:async';
import 'dart:developer';
import 'package:benw_edu/models/calendar_event.dart';
import 'package:benw_edu/services/benw_edu_service.dart';
import 'package:benw_edu/services/notification_service.dart';
import 'package:benw_edu/services/companion_service.dart';

/// Background service that checks for missed study blocks
/// and triggers AI-generated roast notifications.
/// Also resets the CompanionService walk-timer when study is interrupted.
class StudyTrackerService {
  static final StudyTrackerService _instance = StudyTrackerService._internal();
  factory StudyTrackerService() => _instance;
  StudyTrackerService._internal();

  Timer? _checkTimer;
  final _benw = BenwEduService();
  final _notifications = NotificationService();
  final _companion = CompanionService();

  /// List of event IDs that have already been roasted (avoid duplicates)
  final Set<String> _roastedIds = {};

  /// Callback to get current events from the provider
  List<CalendarEvent> Function()? getEventsCallback;

  /// Callback to mark an event as missed in the provider
  void Function(String id)? markMissedCallback;

  void start() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _checkForMissedBlocks(),
    );
    log('StudyTracker: Started checking for missed blocks every 5 minutes.');
  }

  void stop() {
    _checkTimer?.cancel();
    _checkTimer = null;
    log('StudyTracker: Stopped.');
  }

  Future<void> _checkForMissedBlocks() async {
    if (getEventsCallback == null) return;

    final events = getEventsCallback!();
    final missedBlocks = events.where((e) =>
      e.isStudyBlock &&
      !e.isCompleted &&
      !e.wasMissed &&
      !_roastedIds.contains(e.id) &&
      e.isMissedStudyBlock
    ).toList();

    for (final block in missedBlocks) {
      try {
        log('StudyTracker: Missed block detected: ${block.title} (${block.subject})');

        final roast = await _benw.generateRoastReminder(
          block.subject ?? block.title,
          block.formattedTime,
        );

        await _notifications.showImmediateRoast(
          title: '😤 ${block.subject ?? block.title} is crying!',
          body: roast,
        );

        _roastedIds.add(block.id);
        markMissedCallback?.call(block.id);
      } catch (e) {
        log('StudyTracker: Roast generation failed for ${block.id}: $e');
      }
    }
  }

  /// Manual trigger for testing — roast a specific block immediately
  Future<String> triggerRoast(CalendarEvent block) async {
    final roast = await _benw.generateRoastReminder(
      block.subject ?? block.title,
      block.formattedTime,
    );

    await _notifications.showImmediateRoast(
      title: '😤 ${block.subject ?? block.title} misses you!',
      body: roast,
    );

    return roast;
  }

  /// Trigger companion check-in for a completed block
  void triggerCompanionCheckIn(CalendarEvent event) {
    _companion.triggerStudyCheckIn(event);
  }
}

