import 'dart:async';
import 'benw_edu_service.dart';

/// Legacy proxy for BenwEduService to prevent breaking existing code
/// while ensuring only ONE AI model is loaded in memory.
class BenwInferenceService {
  static final BenwInferenceService _instance = BenwInferenceService._internal();
  factory BenwInferenceService() => _instance;
  BenwInferenceService._internal();

  final _eduService = BenwEduService();

  bool get isInitialized => _eduService.isInitialized;
  dynamic get activeModelName => _eduService.activeModelName;

  Future<void> init() => _eduService.init();

  Future<String> generateOnboardingResponse(String userMessage, List<Map<String, String>> chatHistory) =>
      _eduService.generateOnboardingResponse(userMessage, chatHistory);

  Future<Map<String, dynamic>?> extractStudyPlan(String fullConversation) =>
      _eduService.extractStudyPlan(fullConversation);

  Future<String> generateRoastReminder(String subject, String missedTime) =>
      _eduService.generateRoastReminder(subject, missedTime);

  Future<String> generateStudyChatResponse(String userMessage, String subject, List<Map<String, String>> chatHistory) =>
      _eduService.generateStudyChatResponse(userMessage, subject, chatHistory);

  Future<String> generateStudyCheckIn({
    required String subject,
    required String userFeedback,
    required int durationMinutes,
    String? weekCalendarContext,
    List<Map<String, String>>? chatHistory,
  }) => _eduService.generateStudyCheckIn(
        subject: subject,
        userFeedback: userFeedback,
        durationMinutes: durationMinutes,
        weekCalendarContext: weekCalendarContext,
        chatHistory: chatHistory,
      );

  Future<String> generateNutritionAdvice({
    required String mealDescription,
    String? weekCalendarContext,
    List<Map<String, String>>? chatHistory,
  }) => _eduService.generateNutritionAdvice(
        mealDescription: mealDescription,
        weekCalendarContext: weekCalendarContext,
        chatHistory: chatHistory,
      );

  Future<Map<String, dynamic>> generateCalendarEvents(String userMessage, {List<Map<String, String>>? chatHistory, String? calendarContext}) =>
      _eduService.generateCalendarEvents(userMessage, chatHistory: chatHistory, calendarContext: calendarContext);
}
