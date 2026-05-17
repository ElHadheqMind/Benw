import 'package:flutter/material.dart';
import 'package:benw_edu/theme/app_theme.dart';

enum EventType { study, sport, revision, relax, personal, deepSleep }

class CalendarEvent {
  final String id;
  final String title;
  final DateTime date;
  final TimeOfDay? time;
  final String description;
  final Color color;
  final EventType type;
  final String? subjectId; // Links event to a specific subject
  final bool isCompleted;
  final bool wasMissed;
  final String? subject;
  
  final IconData icon;

  CalendarEvent({
    required this.id,
    required this.title,
    required this.date,
    this.time,
    this.description = '',
    Color? color,
    this.type = EventType.personal,
    this.subjectId,
    this.isCompleted = false,
    this.wasMissed = false,
    this.subject,
  }) : color = color ?? AppColors.eventColors[title.hashCode.abs() % AppColors.eventColors.length],
       icon = _getIconForType(type);

  bool get isStudyBlock => type == EventType.study || type == EventType.revision;

  bool get isMissedStudyBlock {
    if (!isStudyBlock || isCompleted || wasMissed) return false;
    final end = endTime;
    if (end == null) return false;
    return DateTime.now().isAfter(end);
  }

  static IconData _getIconForType(EventType type) {
    switch (type) {
      case EventType.study: return Icons.menu_book_rounded;
      case EventType.sport: return Icons.directions_run_rounded;
      case EventType.revision: return Icons.history_edu_rounded;
      case EventType.relax: return Icons.self_improvement_rounded;
      case EventType.deepSleep: return Icons.bedtime_rounded;
      case EventType.personal: return Icons.person_rounded;
    }
  }

  String get formattedTime {
    if (time == null) return 'All day';
    final hour = time!.hour.toString().padLeft(2, '0');
    final minute = time!.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get formattedDate {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  DateTime? get endTime {
    if (time == null) return null;
    final start = DateTime(date.year, date.month, date.day, time!.hour, time!.minute);
    return start.add(const Duration(minutes: 60)); // Default 1 hour duration
  }

  CalendarEvent copyWith({
    String? title,
    DateTime? date,
    TimeOfDay? time,
    String? description,
    Color? color,
    EventType? type,
    String? subjectId,
    bool? isCompleted,
    bool? wasMissed,
    String? subject,
  }) {
    return CalendarEvent(
      id: id,
      title: title ?? this.title,
      date: date ?? this.date,
      time: time ?? this.time,
      description: description ?? this.description,
      color: color ?? this.color,
      type: type ?? this.type,
      subjectId: subjectId ?? this.subjectId,
      isCompleted: isCompleted ?? this.isCompleted,
      wasMissed: wasMissed ?? this.wasMissed,
      subject: subject ?? this.subject,
    );
  }
}
