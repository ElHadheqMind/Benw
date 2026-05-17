import 'package:flutter/foundation.dart';
import 'package:ai_edge_rag/ai_edge_rag.dart';
import 'dart:io';
import 'dart:async';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai_lock.dart';

/// A service that interfaces with the Google AI Edge RAG SDK
class RagService {
  static final RagService _instance = RagService._internal();
  factory RagService() => _instance;
  RagService._internal();

  bool _isInitialized = false;
  Completer<void>? _initCompleter;
  
  // In-memory fallback if the native plugin isn't ready or fails
  final List<String> _fallbackChunkStore = [];

  Future<void> initializeDatabase() async {
    if (_isInitialized) return;

    if (_initCompleter != null) {
      return _initCompleter!.future;
    }

    _initCompleter = Completer<void>();

    try {
      debugPrint('AI Edge RAG: Initializing...');
      final directory = await getApplicationSupportDirectory();
      const modelName = 'gemma-4-E2B-it.litertlm';
      final localPath = '${directory.path}/$modelName';
      final file = File(localPath);

      // Non-blocking: check once if the model is on disk.
      // If not ready yet, skip native RAG and use in-memory fallback.
      // The caller can retry later; we never block startup.
      final prefs = await SharedPreferences.getInstance();
      final modelReady = prefs.getBool('model_ready_on_disk') ?? false;
      if (!modelReady || !await file.exists()) {
        debugPrint('AI Edge RAG: Model not ready on disk yet — using in-memory fallback.');
        _isInitialized = false;
        _initCompleter!.complete();
        _initCompleter = null; // Allow retry on next call
        return;
      }

      debugPrint('AI Edge RAG: Initializing native SDK with path: $localPath');
      await AiEdgeRag.instance.initialize(
        modelPath: localPath,
      ).timeout(const Duration(minutes: 5));

      _isInitialized = true;
      _initCompleter!.complete();
      debugPrint('Google AI Edge RAG initialized successfully.');
    } catch (e) {
      debugPrint('Error initializing Google AI Edge RAG (falling back): $e');
      _isInitialized = false;
      _initCompleter!.complete();
      _initCompleter = null; // Allow retry on next call
    }
  }

  Future<void> upsertDocument(String id, String text) async {
    // Always add to fallback store
    _fallbackChunkStore.add("[$id] $text");

    try {
      // Short timeout — never block the caller for more than 10 seconds.
      await initializeDatabase().timeout(const Duration(seconds: 10));

      await AiLock().run(() async {
        if (!_isInitialized) return;
        await AiEdgeRag.instance.memorizeChunk(text);
        debugPrint('AI Edge RAG: Memorized chunk for $id');
      }, debugLabel: 'RAG Upsert: $id');
    } catch (e) {
      debugPrint('AI Edge RAG upsert skipped (fallback active): $e');
    }
  }

  Future<void> deleteDocument(String id) async {
    _fallbackChunkStore.removeWhere((chunk) => chunk.startsWith("[$id]"));
    debugPrint('AI Edge RAG: Deletion of $id requested.');
  }

  Future<String> retrieveContext(String query, {int topK = 2}) async {
    try {
      // 1. Try native RAG with a short timeout
      return await AiLock().run(() async {
        await initializeDatabase().timeout(const Duration(seconds: 5));
        if (_isInitialized) {
          final stream = AiEdgeRag.instance.generateResponseAsync(
            "Identify key facts about: $query",
          );
          
          String result = "";
          // Reduced timeout for better UI responsiveness
          await for (final event in stream.timeout(const Duration(seconds: 5))) {
            result += event.partialResult;
          }
          if (result.isNotEmpty) return result;
        }
        return "";
      }, debugLabel: 'RAG Retrieval: $query');
    } catch (e) {
      debugPrint('AI Edge RAG native retrieval failed or timed out, using fallback: $e');
    }
    
    // 2. Fallback: Naive keyword matching
    return _performFallbackRetrieval(query, topK: topK);
  }

  String _performFallbackRetrieval(String query, {int topK = 2}) {
    // Only use significant keywords
    final keywords = query.toLowerCase()
        .split(RegExp(r'\s+'))
        .where((w) => w.length > 3 && !['create', 'study', 'quiz', 'for', 'about'].contains(w))
        .toList();
    
    if (keywords.isEmpty || _fallbackChunkStore.isEmpty) return "";

    final scored = _fallbackChunkStore.map((chunk) {
      int score = 0;
      final ch = chunk.toLowerCase();
      for (var kw in keywords) {
        if (ch.contains(kw)) {
          score += 2; // Higher weight for keyword match
        }
      }
      return MapEntry(chunk, score);
    }).where((e) => e.value > 0).toList();
    
    scored.sort((a, b) => b.value.compareTo(a.value));
    final topChunks = scored.take(topK).map((e) => e.key).toList();
    
    return topChunks.join("\n");
  }
}


