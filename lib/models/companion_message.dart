import 'package:flutter/foundation.dart';

enum CompanionMessageType {
  greeting,
  studyCheckIn,     // after study block ends
  nutritionCheck,   // after meal block ends
  walkReminder,     // after 60 min continuous study
  exerciseCheckIn,  // after exercise block ends
  calendarAdjust,   // Benw proposes schedule change
  userReply,        // sent by the user
  BenwResponse,    // Benw's reply to a user message
  clearHistory,     // Demo trigger: clear all chat history
  recurringReminder, // Persistent nudge (e.g. nutrition)
}

@immutable
class CompanionMessage {
  final String id;
  final String text;
  final CompanionMessageType type;
  final DateTime timestamp;
  final bool isUser;

  /// ID of the CalendarEvent that triggered this message (if any)
  final String? linkedEventId;

  /// If Benw proposes calendar adjustments, this holds the raw suggestions
  final List<Map<String, dynamic>> calendarSuggestions;

  /// Quick reply chips presented below this message (Benw messages only)
  final List<String> quickReplies;

  const CompanionMessage({
    required this.id,
    required this.text,
    required this.type,
    required this.timestamp,
    required this.isUser,
    this.linkedEventId,
    this.calendarSuggestions = const [],
    this.quickReplies = const [],
  });

  CompanionMessage copyWith({
    String? text,
    List<String>? quickReplies,
    List<Map<String, dynamic>>? calendarSuggestions,
  }) {
    return CompanionMessage(
      id: id,
      text: text ?? this.text,
      type: type,
      timestamp: timestamp,
      isUser: isUser,
      linkedEventId: linkedEventId,
      calendarSuggestions: calendarSuggestions ?? this.calendarSuggestions,
      quickReplies: quickReplies ?? this.quickReplies,
    );
  }

  static CompanionMessage Benw({
    required String text,
    required CompanionMessageType type,
    String? linkedEventId,
    List<String> quickReplies = const [],
    List<Map<String, dynamic>> calendarSuggestions = const [],
  }) {
    return CompanionMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_benw',
      text: text,
      type: type,
      timestamp: DateTime.now(),
      isUser: false,
      linkedEventId: linkedEventId,
      quickReplies: quickReplies,
      calendarSuggestions: calendarSuggestions,
    );
  }

  static CompanionMessage user({required String text, String? linkedEventId}) {
    return CompanionMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_user',
      text: text,
      type: CompanionMessageType.userReply,
      timestamp: DateTime.now(),
      isUser: true,
      linkedEventId: linkedEventId,
    );
  }
}
