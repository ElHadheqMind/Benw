import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:benw_edu/models/calendar_event.dart';
import 'package:benw_edu/theme/app_theme.dart';
import 'package:benw_edu/services/rag_service.dart';
import 'package:benw_edu/services/notification_service.dart';

class CalendarProvider extends ChangeNotifier {
  final List<CalendarEvent> _events = [];
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();
  final _uuid = const Uuid();
  final _ragService = RagService();
  final _notificationService = NotificationService();
  final Set<String> _populatedDays = {}; // YYYY-MM-DD

  List<CalendarEvent> get events => List.unmodifiable(_events);
  DateTime get selectedDay => _selectedDay;
  DateTime get focusedDay => _focusedDay;

  CalendarProvider() {
    _ensureRangePopulated(DateTime.now());
  }

  void _ensureRangePopulated(DateTime day) {
    for (int i = -14; i <= 31; i++) {
      final target = day.add(Duration(days: i));
      final key = "${target.year}-${target.month}-${target.day}";
      if (!_populatedDays.contains(key)) {
        _applyHealthyDailyTemplate(target);
      }
    }
  }

  void _applyHealthyDailyTemplate(DateTime day) {
    final dateKey = "${day.year}-${day.month}-${day.day}";
    if (_populatedDays.contains(dateKey)) return;
    _populatedDays.add(dateKey);

    final List<Map<String, dynamic>> template = [];
    final w = day.weekday; // 1 = Monday, 7 = Sunday
    
    if (w == DateTime.saturday || w == DateTime.sunday) {
      // Weekend Template
      template.addAll([
        {'title': '😴 Sleep In', 'hour': 6, 'minute': 0, 'desc': 'Extra rest for the weekend.', 'type': EventType.deepSleep},
        {'title': '😴 Sleep In', 'hour': 7, 'minute': 0, 'desc': 'Catching up on Zs.', 'type': EventType.deepSleep},
        {'title': '🌅 Wake Up & Brunch', 'hour': 8, 'minute': 0, 'desc': 'Slow morning.', 'type': EventType.relax},
        {'title': '☕ Morning Coffee', 'hour': 9, 'minute': 0, 'desc': 'Relaxed start.', 'type': EventType.relax},
        {'title': '🧹 Chores & Errands', 'hour': 10, 'minute': 0, 'desc': 'Get life organized.', 'type': EventType.personal},
        {'title': '🧹 Chores & Errands', 'hour': 11, 'minute': 0, 'desc': 'Keep it going.', 'type': EventType.personal},
        {'title': '🥗 Lunch', 'hour': 12, 'minute': 0, 'desc': 'Weekend lunch.', 'type': EventType.relax},
        {'title': '🌳 Outdoor Activity', 'hour': 13, 'minute': 0, 'desc': 'Hike or park walk.', 'type': EventType.sport},
        {'title': '🌳 Outdoor Activity', 'hour': 14, 'minute': 0, 'desc': 'Enjoy the sun.', 'type': EventType.sport},
        {'title': '📖 Light Reading', 'hour': 15, 'minute': 0, 'desc': 'No heavy studying today.', 'type': EventType.relax},
        {'title': '🎨 Hobbies', 'hour': 16, 'minute': 0, 'desc': 'Do what you love.', 'type': EventType.relax},
        {'title': '🎨 Hobbies', 'hour': 17, 'minute': 0, 'desc': 'Creative time.', 'type': EventType.relax},
        {'title': '🍿 Movie / Social', 'hour': 18, 'minute': 0, 'desc': 'Hang out with friends.', 'type': EventType.relax},
        {'title': '🍿 Movie / Social', 'hour': 19, 'minute': 0, 'desc': 'Fun evening.', 'type': EventType.relax},
        {'title': '🍿 Movie / Social', 'hour': 20, 'minute': 0, 'desc': 'Relax.', 'type': EventType.relax},
        {'title': '🎮 Gaming / Chill', 'hour': 21, 'minute': 0, 'desc': 'Wind down.', 'type': EventType.relax},
        {'title': w == DateTime.sunday ? '📅 Week Planning' : '🎮 Gaming / Chill', 'hour': 22, 'minute': 0, 'desc': w == DateTime.sunday ? 'Plan the week ahead.' : 'Weekend night.', 'type': EventType.personal},
        {'title': '😴 Sleep Time', 'hour': 23, 'minute': 0, 'desc': 'Restorative sleep.', 'type': EventType.deepSleep},
      ]);
    } else if (w == DateTime.wednesday) {
      // Mid-week Neuro-Recovery (Prevents Burnout)
      template.addAll([
        {'title': '🌅 Cortisol Alignment', 'hour': 6, 'minute': 0, 'desc': 'Morning sunlight and light movement.', 'type': EventType.sport},
        {'title': '🚿 Sensory Refresh', 'hour': 7, 'minute': 0, 'desc': 'Shower and high-protein breakfast.', 'type': EventType.relax},
        {'title': '🧠 Neuro-Peak: Logic', 'hour': 8, 'minute': 0, 'desc': 'Tackle the most cognitively demanding topic.', 'type': EventType.study},
        {'title': '🧠 Neuro-Peak: Logic', 'hour': 9, 'minute': 0, 'desc': 'Sustained deep work session.', 'type': EventType.study},
        {'title': '☕ Dopamine Reset', 'hour': 10, 'minute': 0, 'desc': 'Step away from screens. Hydrate.', 'type': EventType.relax},
        {'title': '📝 Synaptic Review', 'hour': 11, 'minute': 0, 'desc': 'Review notes using Active Recall.', 'type': EventType.revision},
        {'title': '🥗 Nutrient Refuel', 'hour': 12, 'minute': 0, 'desc': 'Low-glycemic lunch for sustained energy.', 'type': EventType.relax},
        {'title': '🌿 Vagus Nerve Walk', 'hour': 13, 'minute': 0, 'desc': 'Short walk in nature to reset stress.', 'type': EventType.sport},
        {'title': '🤝 Collaborative Intel', 'hour': 14, 'minute': 0, 'desc': 'Social learning and peer discussion.', 'type': EventType.study},
        {'title': '🤝 Collaborative Intel', 'hour': 15, 'minute': 0, 'desc': 'Knowledge sharing session.', 'type': EventType.study},
        {'title': '🚶 Kinetic Break', 'hour': 16, 'minute': 0, 'desc': 'Physical stretching to improve blood flow.', 'type': EventType.relax},
        {'title': '🍎 Brain Snack', 'hour': 17, 'minute': 0, 'desc': 'Omega-3 rich snack.', 'type': EventType.relax},
        {'title': '💪 Endorphin Boost', 'hour': 18, 'minute': 0, 'desc': 'High-intensity exercise.', 'type': EventType.sport},
        {'title': '🍲 Social Connection', 'hour': 19, 'minute': 0, 'desc': 'Dinner with meaningful conversation.', 'type': EventType.relax},
        {'title': '🎮 Cognitive Unwind', 'hour': 20, 'minute': 0, 'desc': 'Light gaming or hobby.', 'type': EventType.relax},
        {'title': '🎨 Creative Flow', 'hour': 21, 'minute': 0, 'desc': 'Free expression block.', 'type': EventType.relax},
        {'title': '📵 Blue Light Cutoff', 'hour': 22, 'minute': 0, 'desc': 'Reading and sleep preparation.', 'type': EventType.relax},
        {'title': '😴 REM Recovery', 'hour': 23, 'minute': 0, 'desc': 'Restorative deep sleep.', 'type': EventType.deepSleep},
      ]);
    } else if (w == DateTime.friday) {
      // Friday - Early Weekend / Lighter afternoon
      template.addAll([
        {'title': '🌅 Wake Up & Run', 'hour': 6, 'minute': 0, 'desc': 'Morning cardio.', 'type': EventType.sport},
        {'title': '🚿 Shower & Breakfast', 'hour': 7, 'minute': 0, 'desc': 'Fuel up.', 'type': EventType.relax},
        {'title': '🧠 Deep Study', 'hour': 8, 'minute': 0, 'desc': 'Last push for the week.', 'type': EventType.study},
        {'title': '📚 Deep Study', 'hour': 9, 'minute': 0, 'desc': 'Keep momentum.', 'type': EventType.study},
        {'title': '☕ Active Pause', 'hour': 10, 'minute': 0, 'desc': 'Stand up!', 'type': EventType.relax},
        {'title': '📝 Wrap up tasks', 'hour': 11, 'minute': 0, 'desc': 'Finish week assignments.', 'type': EventType.revision},
        {'title': '🥗 Lunch Break', 'hour': 12, 'minute': 0, 'desc': 'Healthy lunch.', 'type': EventType.relax},
        {'title': '🌿 Digestion Walk', 'hour': 13, 'minute': 0, 'desc': 'Short walk.', 'type': EventType.sport},
        {'title': '🧹 Organize Desk', 'hour': 14, 'minute': 0, 'desc': 'Clean space for next week.', 'type': EventType.personal},
        {'title': '🎉 Early Weekend', 'hour': 15, 'minute': 0, 'desc': 'Done with studies!', 'type': EventType.relax},
        {'title': '🚶 Hangout', 'hour': 16, 'minute': 0, 'desc': 'Meet friends.', 'type': EventType.relax},
        {'title': '🍎 Snack & Chill', 'hour': 17, 'minute': 0, 'desc': 'Relax.', 'type': EventType.relax},
        {'title': '💪 Light Workout', 'hour': 18, 'minute': 0, 'desc': 'Keep active.', 'type': EventType.sport},
        {'title': '🍲 Dinner Out', 'hour': 19, 'minute': 0, 'desc': 'Treat yourself.', 'color': AppColors.eventColors[2], 'type': EventType.relax},
        {'title': '🍿 Movie Night', 'hour': 20, 'minute': 0, 'desc': 'Relax.', 'type': EventType.relax},
        {'title': '🍿 Movie Night', 'hour': 21, 'minute': 0, 'desc': 'Enjoy.', 'type': EventType.relax},
        {'title': '📵 Wind Down', 'hour': 22, 'minute': 0, 'desc': 'Almost sleep.', 'type': EventType.relax},
        {'title': '😴 Sleep Time', 'hour': 23, 'minute': 0, 'desc': 'Good night.', 'type': EventType.deepSleep},
      ]);
    } else {
      // Standard Hackathon Peak Productivity Days
      String focusSubject = w == DateTime.monday ? 'Structural Logic' : (w == DateTime.tuesday ? 'Experimental Theory' : 'Synthesis & Rhetoric');
      
      template.addAll([
        {'title': '🌅 Metabolic Ignition', 'hour': 6, 'minute': 0, 'desc': 'Hydrate and light movement to signal wakefulness.', 'type': EventType.sport},
        {'title': '🚿 System Reboot', 'hour': 7, 'minute': 0, 'desc': 'Cold-warm shower contrast and fueling.', 'type': EventType.relax},
        {'title': '🧠 Neuro-Peak: $focusSubject', 'hour': 8, 'minute': 0, 'desc': 'Tackle the most demanding academic architecture.', 'type': EventType.study},
        {'title': '📚 Deep Flow State', 'hour': 9, 'minute': 0, 'desc': 'Maintain momentum and eliminate distractions.', 'type': EventType.study},
        {'title': '☕ Synaptic Pause', 'hour': 10, 'minute': 0, 'desc': 'Active stretch. Oxygenate the brain.', 'type': EventType.relax},
        {'title': '📖 Cognitive Expansion', 'hour': 11, 'minute': 0, 'desc': 'Secondary focus block for broad understanding.', 'type': EventType.study},
        {'title': '🥗 Glycemic Balance', 'hour': 12, 'minute': 0, 'desc': 'Lunch optimized for cognitive sustained release.', 'type': EventType.relax},
        {'title': '🌿 Parasympathetic Reset', 'hour': 13, 'minute': 0, 'desc': 'Nature walk to lower cortisol levels.', 'type': EventType.sport},
        {'title': '📝 Active Recall: Review', 'hour': 14, 'minute': 0, 'desc': 'Challenge the memory on morning concepts.', 'type': EventType.revision},
        {'title': '✍️ Application Lab', 'hour': 15, 'minute': 0, 'desc': 'Hands-on practice and problem solving.', 'type': EventType.study},
        {'title': '🚶 Micro-Recovery', 'hour': 16, 'minute': 0, 'desc': 'Brief disconnect. Mindful breathing.', 'type': EventType.relax},
        {'title': '🍎 Glucose Boost', 'hour': 17, 'minute': 0, 'desc': 'Healthy snack to bridge to evening workout.', 'type': EventType.relax},
        {'title': '💪 Physical Excellence', 'hour': 18, 'minute': 0, 'desc': 'Resistance or cardio training.', 'type': EventType.sport},
        {'title': '🍲 Communal Connect', 'hour': 19, 'minute': 0, 'desc': 'Dinner and meaningful social interaction.', 'type': EventType.relax},
        {'title': '🎮 Serotonin Block', 'hour': 20, 'minute': 0, 'desc': 'Joy-focused hobbies and relaxation.', 'type': EventType.relax},
        {'title': '🎨 Creative Synthesis', 'hour': 21, 'minute': 0, 'desc': 'Exploration of personal interests.', 'type': EventType.relax},
        {'title': '📵 Melatonin Guard', 'hour': 22, 'minute': 0, 'desc': 'Screen cutoff. Book reading and low light.', 'type': EventType.relax},
        {'title': '😴 Cellular Repair', 'hour': 23, 'minute': 0, 'desc': 'Deep, restorative sleep cycle.', 'type': EventType.deepSleep},
      ]);
    }

    for (var item in template) {
      _events.add(CalendarEvent(
        id: _uuid.v4(),
        title: item['title'] as String,
        date: day,
        time: TimeOfDay(hour: item['hour'] as int, minute: item['minute'] as int),
        description: item['desc'] as String,
        type: item['type'] as EventType,
        color: item['color'] as Color?,
      ));
    }
    
    
    _initNotifications();
  }


  Future<void> _initNotifications() async {
    for (var event in _events) {
      _scheduleNotification(event);
    }
  }

  void _scheduleNotification(CalendarEvent event) {
    if (event.time == null) return;

    final scheduledDate = DateTime(
      event.date.year,
      event.date.month,
      event.date.day,
      event.time!.hour,
      event.time!.minute,
    );

    _notificationService.scheduleNotification(
      id: event.id,
      title: 'Event Starting: ${event.title}',
      body: event.description.isNotEmpty ? event.description : 'Your event is starting now.',
      scheduledDate: scheduledDate,
    );
  }

  Future<void> _initRag() async {
    for (var event in _events) {
      _syncToRag(event);
    }
  }

  void _syncToRag(CalendarEvent event) {
    String timeStr = event.time != null ? "${event.time!.hour}:${event.time!.minute}" : "All day";
    final chunk = "Calendar Event on ${event.date.toIso8601String().split('T')[0]} at $timeStr:\nTitle: ${event.title}\nDescription: ${event.description}";
    _ragService.upsertDocument(event.id, chunk);
  }

  List<CalendarEvent> getEventsForDay(DateTime day) {
    return _events.where((event) {
      return event.date.year == day.year &&
          event.date.month == day.month &&
          event.date.day == day.day;
    }).toList()
      ..sort((a, b) {
        if (a.time == null && b.time == null) return 0;
        if (a.time == null) return 1;
        if (b.time == null) return -1;
        return (a.time!.hour * 60 + a.time!.minute)
            .compareTo(b.time!.hour * 60 + b.time!.minute);
      });
  }

  /// Returns a compact plain-text summary of the next 7 days for Benw's context.
  /// Format: "Mon 05/05: 08:00 Study, 12:00 Lunch, ..."
  String getWeekText() {
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final typeLabels = {
      EventType.study: 'Study',
      EventType.revision: 'Revision',
      EventType.sport: 'Sport',
      EventType.relax: 'Rest',
      EventType.personal: 'Personal',
      EventType.deepSleep: 'Sleep',
    };
    final buffer = StringBuffer();
    final today = DateTime.now();
    for (int i = 0; i < 7; i++) {
      final day = today.add(Duration(days: i));
      final events = getEventsForDay(day);
      if (events.isEmpty) continue;
      final dayLabel = dayNames[day.weekday - 1];
      final dateStr = '${day.day.toString().padLeft(2,'0')}/${day.month.toString().padLeft(2,'0')}';
      final label = i == 0 ? 'Today ($dayLabel $dateStr)' : '$dayLabel $dateStr';
      // Only include meaningful events (not every hour) — take first 6
      final meaningful = events.take(6).map((e) {
        final t = e.time != null ? '${e.time!.hour.toString().padLeft(2,'0')}:${e.time!.minute.toString().padLeft(2,'0')}' : '?';
        final typeName = typeLabels[e.type] ?? e.type.name;
        return '$t $typeName: ${e.title}';
      }).join(', ');
      buffer.writeln('$label: $meaningful');
    }
    return buffer.toString().trim();
  }

  /// Reschedule an existing event to a new time on the same day.
  void rescheduleEvent(String id, int newHour, int newMinute) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index == -1) return;
    _events[index] = _events[index].copyWith(
      time: TimeOfDay(hour: newHour, minute: newMinute),
    );
    _syncToRag(_events[index]);
    notifyListeners();
  }

  /// Add a new event on a relative day offset from today.
  CalendarEvent addEventOnDay({
    required int dayOffset,
    required String title,
    required EventType type,
    required int hour,
    int minute = 0,
    String description = '',
  }) {
    final day = DateTime.now().add(Duration(days: dayOffset));
    final event = CalendarEvent(
      id: _uuid.v4(),
      title: title,
      date: day,
      time: TimeOfDay(hour: hour, minute: minute),
      description: description,
      type: type,
    );
    debugPrint('CalendarProvider: Adding event "${event.title}" on ${event.date} at ${event.time} (dayOffset: $dayOffset)');
    addEvent(event);
    return event;
  }

  void setSelectedDay(DateTime day) {
    _selectedDay = day;
    _ensureRangePopulated(day);
    notifyListeners();
  }

  void setFocusedDay(DateTime day) {
    _focusedDay = day;
    _ensureRangePopulated(day);
    notifyListeners();
  }

  void addEvent(CalendarEvent event) {
    _events.add(event);
    _scheduleNotification(event);
    notifyListeners();
  }

  void updateEvent(String id, {
    String? title,
    String? description,
    EventType? type,
    String? subjectId,
  }) {
    final index = _events.indexWhere((e) => e.id == id);
    if (index != -1) {
      _events[index] = _events[index].copyWith(
        title: title,
        description: description,
        type: type,
        subjectId: subjectId,
      );
      notifyListeners();
    }
  }

  void deleteEvent(String id) {
    _events.removeWhere((e) => e.id == id);
    _ragService.deleteDocument(id);
    _notificationService.cancelNotification(id);
    notifyListeners();
  }

  void addEventsFromBenw(List<CalendarEvent> events) {
    _events.addAll(events);
    for (var event in events) {
      _scheduleNotification(event);
    }
    notifyListeners();
  }

  CalendarEvent createEventFromBenw({
    required String title,
    required DateTime date,
    TimeOfDay? time,
    String description = '',
    Color? color,
  }) {
    final event = CalendarEvent(
      id: _uuid.v4(),
      title: title,
      date: date,
      time: time,
      description: description,
      color: color,
    );
    addEvent(event);
    return event;
  }
}
