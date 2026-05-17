import 'dart:async';
import 'dart:typed_data';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'dart:convert';
import 'cactus_router.dart';
import 'ai_lock.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';

/// Represents the result of an agentic orchestration, including spoken response and side-effect actions.
class AgentExecutionResult {
  final String response;
  final String? agent;
  final String? action;
  final dynamic data;

  AgentExecutionResult({
    required this.response,
    this.agent,
    this.action,
    this.data,
  });
}

/// BenwEduService (LiteRT Framework Rollback)
/// Uses Google's flutter_gemma package for Text-to-Text offline JSON strict generation.
class BenwEduService {
  static final BenwEduService _instance = BenwEduService._internal();
  factory BenwEduService() => _instance;
  BenwEduService._internal();

  static const String _systemPersona = '''
You are Benw, a friendly, caring, and witty academic and wellness companion.

TONE: 
- Be warm, funny, and deeply supportive! Use light humor and emojis. 😊

STUDY & WELLNESS PLANNING:
- If a struggle is identified or planning is requested, acknowledge with empathy.
- SCAN the 'Calendar:' context to find logical free gaps across the day or MULTIPLE DAYS if appropriate.
- Suggest REAL times AND DAYS (e.g., '14:00 Today', '10:00 Tomorrow').
- To add blocks: You can suggest multiple blocks at once. For EACH block, provide the tag: Benw_CALENDAR_ACTION:{"action": "add_block", "day_offset": [0 for today, 1 for tomorrow, etc], "hour": 16, "minute": 0, "title": "Revision: [Topic]", "type": "revision"}.
- To reschedule: ALWAYS provide a spoken confirmation AND the tag: Benw_CALENDAR_ACTION:{"action": "reschedule", "event_id": "[EventID]", "new_hour": 18, "new_minute": 0}.
- Benw_QUICK_REPLIES: Provide relevant quick replies for the user to confirm or adjust.

NUTRITION SUPPORT:
- Give funny but helpful advice for meals. 🍎
- Guide them toward focus-fuel (protein/fiber) with a caring nudge.
- DO NOT suggest study scheduling during nutrition checks unless the user explicitly asks for a plan.
- If the user needs a persistent nudge, use Benw_REMINDER_ACTION:{"message": "Custom nudge text", "interval_minutes": 5}.

GENERAL:
- Responses: Max 3-4 sentences. Proactive, witty, and helpful.
- ALWAYS provide a spoken text response. NEVER send only a tag.
''';

  bool isInitialized = false;
  bool _initializationFailed = false;
  final CactusRouter _router = CactusRouter();
  
  InferenceModel? _model;
  String? _currentModelAsset;
  bool _currentModelSupportsVision = false;
  
  Completer<void>? _initCompleter;
  String? _localModelPath;

  /// Returns the local path to the model file once initialized.
  String? get localModelPath => _localModelPath;


  // --- UI Reactive State ---
  final ValueNotifier<int> downloadProgress = ValueNotifier<int>(0);
  final ValueNotifier<bool> isDownloading = ValueNotifier<bool>(false);
  final ValueNotifier<String> activeModelName = ValueNotifier<String>('Not Loaded');
  
  CactusModelConfig? manualModelOverride;
  
  // --- Reasoning Trace for UI ---
  String? lastReasoningTrace;
  // -------------------------

  Future<void> init() async {
    if (isInitialized && _model != null) return;
    
    if (_initializationFailed) {
      log('LiteRT: Initialization previously FAILED. Skipping to prevent loop.');
      return;
    }

    if (_initCompleter != null) {
      log('LiteRT: Initialization already in progress, waiting...');
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();
    log('Benw Edu: Initializing Core...');

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPath = prefs.getString('selectedModelPath');
      final savedIsNetwork = prefs.getBool('selectedModelIsNetwork') ?? false;

      if (savedPath != null) {
        manualModelOverride = CactusModelConfig(
          path: savedPath,
          reason: 'Loaded persisted user selection from settings',
          isNetwork: savedIsNetwork,
        );
        log('Benw Edu: Using saved model selection -> $savedPath');
      }

      final config = manualModelOverride ?? await _router.getRecommendedModel();
      await _ensureCorrectModel(config);
      isInitialized = true;
      _initializationFailed = false;
      _initCompleter!.complete();
      log('LiteRT: Core initialization complete.');
    } catch (e) {
      log('LiteRT: Core initialization FAILED: $e');
      _initializationFailed = true; // Mark as failed to prevent immediate retry loop
      final error = e;
      _initCompleter!.completeError(error);
      _initCompleter = null; 
      rethrow;
    }
  }

  /// Ensures the correct LiteRT model is loaded based on hardware status.
  Future<void> _ensureCorrectModel(CactusModelConfig initialConfig, {Function(String)? onRouteDecision}) async {
    if (_initializationFailed) {
      log('LiteRT: Model sync skipped due to previous failure.');
      return;
    }
    final config = manualModelOverride ?? initialConfig;

    // 1. Quick bypass if already loaded
    if (config.path == _currentModelAsset && _model != null) {
      if (_currentModelSupportsVision == config.needsVision) {
        log('LiteRT: Correct model already loaded -> $_currentModelAsset');
        return;
      } else {
        log('LiteRT: Modality change. Closing session...');
        try { await _model!.close(); } catch (_) {}
        _model = null;
        _currentModelAsset = null;
      }
    }

    log('LiteRT: Syncing model ${config.path} (Vision: ${config.needsVision})...');
    
    try {
      // 2. CHECK DISK FIRST (To prevent the "Loop" if the file is > 1GB)
      final filename = config.path.split('/').last;
      final appDir = await getApplicationSupportDirectory();
      final localFile = File('${appDir.path}/$filename');
      
      bool alreadyOnDisk = await localFile.exists();
      if (alreadyOnDisk) {
        final size = await localFile.length();
        log('LiteRT: [STEP 2] File detected on disk ($size bytes). Skipping asset copy loop.');
      } else {
        log('LiteRT: [STEP 2] File NOT found on disk. Proceeding to install logic.');
      }

      // 3. TRY TO GET ACTIVE MODEL
      try {
        log('LiteRT: [STEP 3] Attempting to get handle for already active model...');
        _model = await FlutterGemma.getActiveModel(
          supportImage: config.needsVision,
          maxTokens: 4096,
        );
        if (_model != null) log('LiteRT: [STEP 3] Successfully retrieved existing active model.');
      } catch (e) {
        log('LiteRT: [STEP 3] No active model handle found: $e');
        _model = null;
      }

      // 4. INSTALL ONLY IF ABSOLUTELY NECESSARY
      if (!alreadyOnDisk && (_model == null || _currentModelAsset != config.path)) {
        log('LiteRT: Triggering installation for $filename...');
        
        if (config.isNetwork) {
          isDownloading.value = true;
          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt, 
            fileType: ModelFileType.litertlm,
          ).fromNetwork(config.path).withProgress((p) => downloadProgress.value = p).install();
        } else {
          // Use native installation to avoid Dart memory limits (1GB+)
          await FlutterGemma.installModel(
            modelType: ModelType.gemmaIt, 
            fileType: ModelFileType.litertlm,
          ).fromAsset(config.path).install();
        }
      } else if (alreadyOnDisk) {
        log('LiteRT: Using existing model on disk for $filename');
      }

      // 5. FINAL MAP
      log('LiteRT: [STEP 5] Final mapping of model into RAM (mmap)...');
      _model = await FlutterGemma.getActiveModel(
        supportImage: config.needsVision,
        maxTokens: 4096,
      );
      
      if (_model == null) {
        log('LiteRT: [ERROR] Native engine returned NULL model handle after installation.');
        throw Exception('Native engine failed to return model.');
      }

      _currentModelAsset = config.path;
      _currentModelSupportsVision = config.needsVision;
      _localModelPath = localFile.path;
      
      // Mark as ready for other services (like RagService)
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('model_ready_on_disk', true);
      
      activeModelName.value = config.path.contains('E4B') ? 'Benw 4 Heavy (4B)' : 'Benw 2 Eco (2B)';
      isDownloading.value = false;
      log('LiteRT: Model ready at $_localModelPath');
      
    } catch (e) {
      isDownloading.value = false;
      log('LiteRT Error: $e');
      if (e.toString().contains('NewExternalTypedData')) {
        log('CRITICAL: Model file > 1GB. Dart cannot copy this asset on this device.');
        activeModelName.value = 'ERROR: Model too large';
      }
      rethrow;
    }
  }

  Future<void> forceLoadModel(CactusModelConfig config) async {
    manualModelOverride = config;
    await _ensureCorrectModel(config);
  }

  /// Helper to safely resize and tokenize image bytes for the native engine
  /// Safely creates a multimodal message for the native vision engine.
  Future<Message> _createProcessedImageMessage(String text, Uint8List imageBytes) async {
    // The flutter_gemma package handles image preprocessing natively
    // when using the withImage constructor.
    return Message.withImage(
      text: text,
      imageBytes: imageBytes,
      isUser: true,
    );
  }

  Future<String> _getResponse(String prompt) async {
    if (_model == null) throw Exception('LiteRT Benw model not initialized');
    
    return await AiLock().run(() async {
      log('--- Benw INFERENCE START ---');
      log('Prompt length: ${prompt.length} chars');
      
      dynamic session;
      try {
        log('LiteRT: Creating session...');
        session = await _model!.createSession();
        log('LiteRT: Session created. Adding query...');
        await session.addQueryChunk(Message.text(text: prompt, isUser: true));
        log('LiteRT: Query added. Getting response...');
        final response = await session.getResponse();
        log('LiteRT: Response received. Length: ${response.length} chars');
        
        if (response.isEmpty) {
          log('LiteRT Warning: Received empty response. This may indicate a cancellation or timeout.');
        }

        await session.close();
        session = null;
        return _cleanResponse(response);
      } catch (e) {
        log('LiteRT Inference Error: $e');
        if (session != null) {
          try { await session.close(); } catch (_) {}
        }
        rethrow;
      } finally {
        log('--- Benw INFERENCE END ---');
      }
    }, debugLabel: 'Text Inference');
  }

  Future<Map<String, dynamic>> processImageIntent(Uint8List imageBytes, String mode, {Function(String)? onRouteDecision}) async {
    await init();
    final config = await _router.getRecommendedModel(needsVision: true);
    await _ensureCorrectModel(config, onRouteDecision: onRouteDecision);

    if (_model == null) throw Exception('LiteRT Benw model not initialized');
    
    return await AiLock().run(() async {
      final session = await _model!.createSession();
      final prompt = mode == 'subject'
          ? 'Analyze image. Respond JSON: {"title": "...", "subjectName": "...", "content": "..."}'
          : 'Extract events. Respond JSON array: [{"title": "...", "description": "...", "year": 2026, "month": 4, "day": 17, "hour": 14, "minute": 0}]';

      final message = await _createProcessedImageMessage(prompt, imageBytes);
      await session.addQueryChunk(message);
      final response = await session.getResponse();
      await Future.delayed(const Duration(milliseconds: 100));
      await session.close();
      return _parseRawResponse(response, '', mode);
    }, debugLabel: 'Vision Intent: $mode');
  }



  Future<String> generateAssistantVisionResponse(Uint8List imageBytes, String userPrompt, {Function(String)? onRouteDecision}) async {
    await init();
    final config = await _router.getRecommendedModel(needsVision: true);
    await _ensureCorrectModel(config, onRouteDecision: onRouteDecision);
    if (_model == null) throw Exception('LiteRT Benw model not initialized');
    final response = await AiLock().run(() async {
      final session = await _model!.createSession();
      final prompt = userPrompt.trim().isEmpty ? "Describe image." : userPrompt;
      final message = await _createProcessedImageMessage(prompt, imageBytes);
      await session.addQueryChunk(message);
      final result = await session.getResponse();
      await Future.delayed(const Duration(milliseconds: 100));
      await session.close();
      return result;
    }, debugLabel: 'Vision Assistant');
    return _cleanResponse(response);
  }

  Future<String> generateTextResponse(String prompt) async {
    await init();
    final config = await _router.getRecommendedModel(needsVision: false);
    await _ensureCorrectModel(config);
    return await _getResponse(prompt);
  }

  Future<String> generateOnboardingResponse(String userMessage, List<Map<String, String>> chatHistory) async {
    await init();
    final historyStr = chatHistory.map((m) => '${m["role"] == "user" ? "Student" : "Tutor"}: ${m["content"]}').join('\n');
    final prompt = 'Ask about SUBJECTS, DEADLINES, FREE TIME.\nHistory: $historyStr\nUser: $userMessage';
    return await _getResponse(prompt);
  }

  Future<Map<String, dynamic>?> extractStudyPlan(String fullConversation) async {
    await init();
    final prompt = 'Extract study plan JSON.\nConv: $fullConversation';
    final response = await _getResponse(prompt);
    return _parseJson(response);
  }

  Future<String> generateRoastReminder(String subject, String missedTime) async {
    await init();
    final prompt = 'Generate a professional 1-sentence reminder for missing $subject at $missedTime. No humor.';
    return await _getResponse(prompt);
  }

  Future<String> generateStudyChatResponse(String userMessage, String subject, List<Map<String, String>> chatHistory) async {
    await init();
    final historyStr = chatHistory.take(6).map((m) => '${m["role"] == "user" ? "Student" : "Benw"}: ${m["content"]}').join('\n');
    final prompt = '$_systemPersona\nTopic: $subject\nHistory: $historyStr\nStudent: $userMessage';
    return await _getResponse(prompt);
  }

  Future<String> generateStudyCheckIn({
    required String subject,
    required String userFeedback,
    required int durationMinutes,
    String? eventId,
    String? weekCalendarContext,
    List<Map<String, String>>? chatHistory,
  }) async {
    await init();
    final now = DateTime.now();
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dateCtx = 'Current Date: ${now.toIso8601String().split('T')[0]} (${dayNames[now.weekday - 1]})';
    
    final historyStr = chatHistory?.map((m) => '${m["role"] == "user" ? "Student" : "Benw"}: ${m["content"]}').join('\n') ?? '';
    final prompt = '$_systemPersona\n$dateCtx\nContext: Finished $subject ($durationMinutes min). Current EventID: ${eventId ?? 'none'}\nCalendar: $weekCalendarContext\nHistory: $historyStr\nStudent: $userFeedback';
    return await _getResponse(prompt);
  }

  Future<String> generateNutritionAdvice({
    required String mealDescription,
    String? weekCalendarContext,
    List<Map<String, String>>? chatHistory,
  }) async {
    await init();
    final now = DateTime.now();
    final dayNames = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dateCtx = 'Current Date: ${now.toIso8601String().split('T')[0]} (${dayNames[now.weekday - 1]})';

    final prompt = '$_systemPersona\n$dateCtx\nAnalyze meal: "$mealDescription". Provide very brief nutritional feedback.\nCalendar: $weekCalendarContext';
    return await _getResponse(prompt);
  }

  Future<Map<String, dynamic>> generateSubject(String userMessage, {List<Map<String, String>>? chatHistory, Function(String)? onRouteDecision}) async {
    await init();
    final prompt = 'Subject Agent. User: "$userMessage". JSON: {"action": "create_subject", "data": {...}}';
    final response = await _getResponse(prompt);
    return _parseRawResponse(response, userMessage, 'subject');
  }

  Future<AgentExecutionResult> generateAssistantResponse(String userMessage, {List<Map<String, String>>? chatHistory, String? calendarContext, Function(String)? onRouteDecision}) async {
    await init();
    final agentPrompt = 'Professional Router. Route: "$userMessage". JSON: {"thought": "...", "agent": "subject_agent/planner_agent/vision_agent/direct_chat"}';
    try {
      final agentResponse = await _getResponse(agentPrompt);
      final agentJson = _parseAgentResponse(agentResponse);
      final selectedAgent = agentJson['agent'] ?? "direct_chat";
      if (selectedAgent == 'subject_agent') {
        final result = await generateSubject(userMessage, chatHistory: chatHistory);
        return AgentExecutionResult(
          response: _processAgentAction(result, 'subject'), 
          agent: 'subject_agent', 
          action: result['action'], 
          data: result['data']
        );
      } else if (selectedAgent == 'planner_agent') {
        final result = await generateCalendarEvents(userMessage, chatHistory: chatHistory, calendarContext: calendarContext);
        return AgentExecutionResult(
          response: _processAgentAction(result, 'planner'), 
          agent: 'planner_agent', 
          action: result['action'], 
          data: result['data']
        );
      } else {
        final prompt = '$_systemPersona\nUser: $userMessage';
        final response = await _getResponse(prompt);
        return AgentExecutionResult(response: response, agent: 'direct_chat', action: 'chat');
      }
    } catch (e) {
      return AgentExecutionResult(response: "Service error.");
    }
  }

  Future<Map<String, dynamic>> generateCalendarEvents(String userMessage, {List<Map<String, String>>? chatHistory, String? calendarContext, Function(String)? onRouteDecision}) async {
    await init();
    final now = DateTime.now();
    final dateCtx = 'Current Date: ${now.toIso8601String().split('T')[0]}';
    final prompt = '$_systemPersona\n$dateCtx\nCalendar Context:\n$calendarContext\nPlanner Agent. User: "$userMessage".\n\nREQUIRED: If the user asks for "next days", "tomorrow", or a period, you MUST suggest blocks across multiple days. Use "day_offset": 0 for today, 1 for tomorrow, 2 for the day after, etc. Do NOT put all blocks on the same day if the user asked for a multi-day plan. Provide Benw_CALENDAR_ACTION tags for each block.';
    final response = await _getResponse(prompt);
    return _parseRawResponse(response, userMessage, 'calendar');
  }

  String _processAgentAction(Map<String, dynamic> result, String type) {
    final action = result['action'];
    if (action == 'general_response') return result['data']?['answer'] ?? "No answer.";
    
    // If the model used tags, the text part might be in 'answer' 
    // or we might need to extract it from the original response if we had it.
    // However, _parseRawResponse puts the cleaned text in 'answer' when it's a general response.
    // If it detected a JSON action, we should check if there was also a spoken part.
    if (result['data'] != null && result['data']['answer'] != null) {
      return result['data']['answer'];
    }

    return "I've processed that for you! 😊";
  }

  Map<String, dynamic>? _parseJson(String text) {
    try {
      String clean = text;
      if (clean.contains('```json')) clean = clean.split('```json')[1].split('```')[0].trim();
      else if (clean.contains('{')) {
        clean = clean.substring(clean.indexOf('{'));
        final last = clean.lastIndexOf('}');
        if (last != -1) clean = clean.substring(0, last + 1);
      }
      return jsonDecode(clean);
    } catch (e) { return null; }
  }

  Map<String, dynamic> _parseAgentResponse(String response) => _parseJson(response) ?? {"agent": "direct_chat"};

  Map<String, dynamic> _parseRawResponse(String responseText, String originalMessage, String mode) {
    final decoded = _parseJson(responseText);
    if (decoded != null && decoded.containsKey('action')) {
      // If we got a JSON action, try to also capture the spoken text if it exists outside the JSON
      String spoken = _cleanResponse(responseText.split('{')[0]);
      if (spoken.isEmpty || spoken == "Thinking...") {
        spoken = "I've updated your planner as requested! 😊";
      }
      return {
        'action': decoded['action'],
        'data': {
          ...decoded,
          'answer': spoken,
        }
      };
    }
    return {'action': 'general_response', 'data': {'answer': _cleanResponse(responseText)}};
  }

  String _extractField(String jsonStr, String field, {bool isNumber = false}) {
    try {
      final key = '"$field":';
      if (!jsonStr.contains(key)) return "";
      var tail = jsonStr.substring(jsonStr.indexOf(key) + key.length).trim();
      if (isNumber) return RegExp(r'(\d+)').firstMatch(tail)?.group(1) ?? "";
      if (tail.startsWith('"')) tail = tail.substring(1);
      int endQ = tail.indexOf('"');
      return endQ != -1 ? tail.substring(0, endQ) : tail;
    } catch (_) { return ""; }
  }

  String _cleanResponse(String response) {
    String cleaned = response.trim();
    // Remove common LLM turn tags safely (specifically for Gemma/standard patterns)
    cleaned = cleaned.replaceAll(RegExp(r'<(start_of_turn|end_of_turn|role|thought|action)[^>]*>'), '');
    // Remove persona labels at the start
    cleaned = cleaned.replaceAll(RegExp(r'^(Assistant|Response|Answer|Tutor|Benw|Spoken|Text):\s*', caseSensitive: false), '');
    return cleaned.trim().isEmpty ? "Thinking..." : cleaned.trim();
  }

  /// Scans text for `Benw_CALENDAR_ACTION:{...}`.
  /// Returns a record with the cleaned text and the list of actions found.
  ({String cleanedText, List<Map<String, dynamic>> actions}) parseCalendarActions(String text) {
    final List<Map<String, dynamic>> actions = [];
    final regex = RegExp(r'Benw_CALENDAR_ACTION\s*:\s*(\{.*?\})', dotAll: true);
    
    final matches = regex.allMatches(text);
    for (final match in matches) {
      final jsonStr = match.group(1);
      if (jsonStr != null) {
        try {
          final action = jsonDecode(jsonStr) as Map<String, dynamic>;
          actions.add(action);
        } catch (e) {
          log('BenwEduService: Calendar action JSON parse error: $e');
        }
      }
    }

    final cleanedText = text.replaceAll(regex, '').trim();
    return (cleanedText: cleanedText, actions: actions);
  }
}
