import 'dart:async';
import 'dart:developer';

/// A global mutex lock to ensure only one LiteRT operation runs at a time.
/// This prevents native crashes in liblitertlm_jni.so caused by concurrent
/// access or premature session closure during active inference.
class AiLock {
  static final AiLock _instance = AiLock._internal();
  factory AiLock() => _instance;
  AiLock._internal();

  Completer<void>? _currentTask;

  /// Executes [task] when the AI engine is free.
  Future<T> run<T>(Future<T> Function() task, {String? debugLabel}) async {
    final label = debugLabel ?? 'Unnamed Task';
    
    // Wait for the current task to finish
    while (_currentTask != null) {
      log('AiLock: Waiting for engine... (Queuing: $label)');
      await _currentTask!.future;
    }

    // Set the new current task
    final completer = Completer<void>();
    _currentTask = completer;

    log('AiLock: 🔒 Lock acquired by: $label');
    try {
      final result = await task();
      return result;
    } finally {
      log('AiLock: 🔓 Lock released by: $label');
      _currentTask = null;
      completer.complete();
    }
  }
}
