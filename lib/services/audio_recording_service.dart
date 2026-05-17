import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:developer';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';

class AudioRecordingService {
  static final AudioRecordingService _instance = AudioRecordingService._internal();
  factory AudioRecordingService() => _instance;
  AudioRecordingService._internal();

  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _player = AudioPlayer();
  
  String? _lastRecordingPath;
  String? _lastWavPath; // WAV copy for playback
  bool _isRecording = false;

  bool get isRecording => _isRecording;
  String? get lastRecordingPath => _lastWavPath ?? _lastRecordingPath;

  /// Start recording in WAV format (PCM 16-bit, 16kHz, mono)
  /// This is the exact format LiteRT-LM's Message.withAudio expects.
  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      final directory = await getTemporaryDirectory();
      _lastRecordingPath = '${directory.path}/benw_voice_${DateTime.now().millisecondsSinceEpoch}.wav';

      // flutter_benw requires: PCM 16-bit, 16kHz, mono
      // Adding noiseSuppress and autoGain for cleaner audio on real devices
      const config = RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
        bitRate: 256000,
        noiseSuppress: true,
        autoGain: true,
      );

      log('Starting recording: WAV 16kHz mono -> $_lastRecordingPath');
      await _recorder.start(config, path: _lastRecordingPath!);
      _isRecording = true;
      log('Recording started successfully');
    } else {
      log('Microphone permission not granted');
      throw Exception('Microphone permission not granted');
    }
  }

  /// Stop recording and return the file path and full WAV bytes.
  /// The WAV format is kept intact as LiteRT-LM's native decoder expects it.
  Future<({String? path, Uint8List? bytes})> stopRecording() async {
    if (!_isRecording) return (path: null, bytes: null);

    final path = await _recorder.stop();
    _isRecording = false;
    _lastRecordingPath = path;

    if (path != null) {
      final file = File(path);
      if (await file.exists()) {
        final fileSize = await file.length();
        log('Recording saved: $path ($fileSize bytes)');

        if (fileSize < 100) {
          log('WARNING: Recording file is too small ($fileSize bytes), audio may not have been captured.');
          return (path: null, bytes: null);
        }

        final wavBytes = await file.readAsBytes();
        
        // Keep the WAV path for playback
        _lastWavPath = path;
        
        // LiteRT-LM's native layer expects full WAV format (with header).
        // The miniaudio decoder on the native side needs the WAV container
        // to correctly identify sample rate, channels, and bit depth.
        log('Returning full WAV data: ${wavBytes.length} bytes for Benw audio processing');
        
        return (path: path, bytes: Uint8List.fromList(wavBytes));
      } else {
        log('ERROR: Recording file does not exist at $path');
      }
    } else {
      log('ERROR: recorder.stop() returned null path');
    }
    
    return (path: null, bytes: null);
  }

  /// Extract raw PCM bytes from a WAV file by stripping the header.
  /// Standard WAV files have a 44-byte header, but we find the 'data' chunk
  /// to be safe with non-standard headers.
  Uint8List _extractPcmFromWav(Uint8List wavBytes) {
    // Look for 'data' chunk marker in WAV header
    for (int i = 0; i < wavBytes.length - 8; i++) {
      // 'd' 'a' 't' 'a'
      if (wavBytes[i] == 0x64 &&
          wavBytes[i + 1] == 0x61 &&
          wavBytes[i + 2] == 0x74 &&
          wavBytes[i + 3] == 0x61) {
        // The 4 bytes after 'data' are the chunk size (little-endian)
        final dataStart = i + 8; // skip 'data' + 4 bytes size
        if (dataStart < wavBytes.length) {
          log('Found WAV data chunk at offset $i, PCM starts at $dataStart');
          return Uint8List.sublistView(wavBytes, dataStart);
        }
      }
    }
    // Fallback: assume standard 44-byte header
    log('Using default 44-byte WAV header offset');
    if (wavBytes.length > 44) {
      return Uint8List.sublistView(wavBytes, 44);
    }
    return wavBytes;
  }

  /// Play the last recording for verification
  Future<void> playLastRecording() async {
    final pathToPlay = _lastWavPath ?? _lastRecordingPath;
    if (pathToPlay != null) {
      final file = File(pathToPlay);
      if (await file.exists()) {
        final size = await file.length();
        log('Playing recording: $pathToPlay ($size bytes)');
        
        try {
          await _player.stop();
          await _player.setReleaseMode(ReleaseMode.stop);
          await _player.play(DeviceFileSource(pathToPlay));
          log('Playback started successfully');
          
          // Listen for playback completion/errors
          _player.onPlayerComplete.listen((_) {
            log('Playback completed');
          });
          _player.onLog.listen((msg) {
            log('AudioPlayer log: $msg');
          });
        } catch (e) {
          log('Playback error: $e');
        }
      } else {
        log('ERROR: Cannot play - file does not exist at $pathToPlay');
      }
    } else {
      log('ERROR: No recording path available for playback');
    }
  }

  void dispose() {
    _recorder.dispose();
    _player.dispose();
  }
}
