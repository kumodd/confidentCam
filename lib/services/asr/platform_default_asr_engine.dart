import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_recognition_error.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/utils/logger.dart';
import 'teleprompter_asr_engine.dart';

/// Default low-latency on-device / platform ASR engine.
///
/// - **Android**: Uses `NativeVoiceSyncManager` (`AudioRecord` in our own UID
///   piped via `EXTRA_AUDIO_SOURCE` + `EXTRA_SEGMENTED_SESSION` into on-device
///   `SodaSpeechRecognizer`, with Android 14+ `EXTRA_ENABLE_LANGUAGE_DETECTION`,
///   confidence scores, alternative hypotheses, partial throttling, and zero
///   system mic beep).
/// - **iOS**: Uses Apple's `SFSpeechRecognizer` via `speech_to_text`.
class PlatformDefaultAsrEngine implements TeleprompterAsrEngine {
  static const MethodChannel _androidChannel = MethodChannel(
    'com.confidentcam.confident_cam/voice_sync',
  );
  static const Duration _iosPartialThrottle = Duration(milliseconds: 240);

  final SpeechToText _speech = SpeechToText();

  final _transcriptController =
      StreamController<AsrTranscriptEvent>.broadcast();
  final _voiceLevelController = StreamController<VoiceLevelEvent>.broadcast();
  final _stateController = StreamController<VoiceTrackingState>.broadcast();
  final _languageController = StreamController<String>.broadcast();
  final _newUtteranceController = StreamController<void>.broadcast();

  bool _initialized = false;
  bool _running = false;
  bool _paused = false;
  bool _usingAndroidNative = false;
  bool _isRestartScheduled = false;
  int _consecutiveHardErrors = 0;
  String? _resolvedLocaleId;
  AsrStartConfig? _lastConfig;
  Timer? _restartTimer;
  Timer? _speechIdleTimer;
  VoiceTrackingState _state = VoiceTrackingState.stopped;
  DateTime? _lastIosPartialAt;
  String _lastIosPartialText = '';

  @override
  Stream<AsrTranscriptEvent> get transcriptStream =>
      _transcriptController.stream;

  @override
  Stream<VoiceLevelEvent> get voiceLevelStream => _voiceLevelController.stream;

  @override
  Stream<VoiceTrackingState> get stateStream => _stateController.stream;

  @override
  Stream<String> get detectedLanguageStream => _languageController.stream;

  @override
  Stream<void> get newUtteranceStream => _newUtteranceController.stream;

  bool get _isAndroid => !kIsWeb && Platform.isAndroid;

  @override
  Future<bool> start(AsrStartConfig config) async {
    _lastConfig = config;
    _running = true;
    _paused = false;
    _consecutiveHardErrors = 0;
    _lastIosPartialAt = null;
    _lastIosPartialText = '';
    _restartTimer?.cancel();
    _emitState(VoiceTrackingState.initializing);

    if (_isAndroid) {
      return _startAndroidNative(config);
    }
    return _startIosSpeechPlugin(config);
  }

  Future<bool> _startAndroidNative(AsrStartConfig config) async {
    _usingAndroidNative = true;
    _androidChannel.setMethodCallHandler(_handleAndroidMethodCall);

    try {
      await Future<void>.delayed(const Duration(milliseconds: 140));
      if (!_running) return false;

      _newUtteranceController.add(null);
      final started = await _androidChannel.invokeMethod<bool>('start', {
        'preferredLocales': config.preferredLocales,
      });

      if (started != true) {
        _running = false;
        _emitState(VoiceTrackingState.unavailableFallback);
        return false;
      }

      if (_running && _state == VoiceTrackingState.initializing) {
        _emitState(VoiceTrackingState.listening);
      }
      return true;
    } catch (e) {
      logger.w('PlatformDefaultAsrEngine Android start failed: $e');
      _running = false;
      _emitState(VoiceTrackingState.unavailableFallback);
      return false;
    }
  }

  Future<dynamic> _handleAndroidMethodCall(MethodCall call) async {
    if (!_running) return null;

    switch (call.method) {
      case 'onWords':
        if (_paused) return null;
        final args = call.arguments as Map?;
        final text = (args?['text'] as String?)?.trim() ?? '';
        final isFinal = (args?['isFinal'] as bool?) ?? false;
        final rawAlts = args?['alternatives'];
        final alternatives =
            rawAlts is List
                ? rawAlts
                    .whereType<String>()
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList(growable: false)
                : const <String>[];
        final confidence = (args?['confidence'] as num?)?.toDouble();

        if (text.isNotEmpty) {
          _markActiveSpeech();
          _transcriptController.add(
            AsrTranscriptEvent(
              text: text,
              alternatives: alternatives,
              confidence: confidence,
              isFinal: isFinal,
            ),
          );
          if (isFinal) {
            _newUtteranceController.add(null);
          }
        }
        break;
      case 'onLanguageDetected':
        final args = call.arguments as Map?;
        final lang = (args?['language'] as String?)?.trim() ?? '';
        if (lang.isNotEmpty) {
          _languageController.add(lang);
        }
        break;
      case 'onVoiceLevel':
        if (_paused) return null;
        final args = call.arguments as Map?;
        final rmsDb = (args?['rmsDb'] as num?)?.toDouble() ?? -60.0;
        final isSpeaking = (args?['isSpeaking'] as bool?) ?? false;
        final silenced = (args?['silenced'] as bool?) ?? false;
        _voiceLevelController.add(
          VoiceLevelEvent(
            rmsDb: rmsDb,
            isSpeaking: isSpeaking,
            silenced: silenced,
          ),
        );
        if (silenced) {
          _running = false;
          _emitState(VoiceTrackingState.unavailableFallback);
          return null;
        }
        if (isSpeaking) {
          _markActiveSpeech();
        }
        break;
      case 'onStatus':
        final args = call.arguments as Map?;
        final statusName = args?['status'] as String? ?? 'stopped';
        final locale = args?['locale'] as String?;
        if (locale != null && locale.isNotEmpty && locale != 'auto') {
          _languageController.add(locale);
        }
        if (statusName == 'unavailableFallback') {
          _running = false;
          _emitState(VoiceTrackingState.unavailableFallback);
        } else if (statusName == 'paused') {
          _emitState(VoiceTrackingState.paused);
        } else if (statusName == 'listening' &&
            !_paused &&
            _state != VoiceTrackingState.activeSpeech) {
          _emitState(VoiceTrackingState.listening);
        }
        break;
    }
    return null;
  }

  Future<bool> _startIosSpeechPlugin(AsrStartConfig config) async {
    _usingAndroidNative = false;
    try {
      if (!_initialized) {
        _initialized = await _speech.initialize(
          onError: _handleIosError,
          onStatus: _handleIosStatus,
          finalTimeout: const Duration(milliseconds: 500),
        );
      }
      if (!_initialized) {
        _running = false;
        _emitState(VoiceTrackingState.unavailableFallback);
        return false;
      }

      _resolvedLocaleId = await _resolveBestIosLocale(config.preferredLocales);
      if (_resolvedLocaleId != null) {
        _languageController.add(_resolvedLocaleId!);
      }
      await _beginIosListenCycle();
      return _running && _state != VoiceTrackingState.unavailableFallback;
    } catch (e) {
      logger.w('PlatformDefaultAsrEngine iOS start failed: $e');
      _running = false;
      _emitState(VoiceTrackingState.unavailableFallback);
      return false;
    }
  }

  Future<String?> _resolveBestIosLocale(List<String> preferred) async {
    try {
      final locales = await _speech.locales();
      for (final pref in preferred) {
        final normPref = pref.replaceAll('-', '_').toLowerCase();
        for (final locale in locales) {
          if (locale.localeId.replaceAll('-', '_').toLowerCase() == normPref) {
            return locale.localeId;
          }
        }
      }
      final sys = await _speech.systemLocale();
      return sys?.localeId;
    } catch (_) {
      return null;
    }
  }

  Future<void> _beginIosListenCycle() async {
    if (!_running || _paused || !_initialized) return;
    try {
      _newUtteranceController.add(null);
      await _speech.listen(
        onResult: _handleIosResult,
        onSoundLevelChange: (level) {
          if (!_running || _paused) return;
          final speaking = level > -35.0;
          _voiceLevelController.add(
            VoiceLevelEvent(rmsDb: level, isSpeaking: speaking),
          );
          if (speaking) _markActiveSpeech();
        },
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          listenFor: const Duration(seconds: 60),
          pauseFor: const Duration(seconds: 5),
          localeId: _resolvedLocaleId,
        ),
      );
      if (_running && !_paused) {
        _emitState(VoiceTrackingState.listening);
      }
    } catch (e) {
      logger.w('PlatformDefaultAsrEngine iOS listen error: $e');
      _handleIosHardError();
    }
  }

  void _handleIosResult(SpeechRecognitionResult result) {
    if (!_running || _paused) return;
    _consecutiveHardErrors = 0;
    final words = result.recognizedWords.trim();
    if (words.isNotEmpty) {
      final now = DateTime.now();
      if (!result.finalResult) {
        if (words == _lastIosPartialText) return;
        if (_lastIosPartialAt != null &&
            now.difference(_lastIosPartialAt!) < _iosPartialThrottle) {
          return;
        }
        _lastIosPartialText = words;
        _lastIosPartialAt = now;
      } else {
        _lastIosPartialText = '';
      }

      final alts = result.alternates
          .skip(1)
          .take(2)
          .map((a) => a.recognizedWords.trim())
          .where((s) => s.isNotEmpty && s != words)
          .toList(growable: false);
      final conf = result.hasConfidenceRating && result.confidence > 0
          ? result.confidence
          : null;

      _markActiveSpeech();
      _transcriptController.add(
        AsrTranscriptEvent(
          text: words,
          alternatives: alts,
          confidence: conf,
          isFinal: result.finalResult,
          detectedLanguageCode: _resolvedLocaleId,
        ),
      );
    }
    if (result.finalResult && _running && !_paused) {
      _scheduleIosRestart(delayMs: 220);
    }
  }

  void _handleIosStatus(String status) {
    if (!_running || _paused) return;
    if (status == 'done' || status == 'notListening') {
      _scheduleIosRestart(delayMs: 280);
    }
  }

  void _handleIosError(SpeechRecognitionError error) {
    if (!_running || _paused) return;
    final msg = error.errorMsg.toLowerCase();
    if (msg.contains('no_match') || msg.contains('speech_timeout')) {
      _consecutiveHardErrors = 0;
      _scheduleIosRestart(delayMs: 300);
      return;
    }
    if (msg.contains('audio') ||
        msg.contains('busy') ||
        msg.contains('permission') ||
        msg.contains('not_available') ||
        msg.contains('client')) {
      _handleIosHardError();
      return;
    }
    _scheduleIosRestart(delayMs: 550);
  }

  void _handleIosHardError() {
    _consecutiveHardErrors++;
    if (_consecutiveHardErrors >= 2) {
      _running = false;
      _restartTimer?.cancel();
      _emitState(VoiceTrackingState.unavailableFallback);
    } else {
      _scheduleIosRestart(delayMs: 650);
    }
  }

  void _scheduleIosRestart({required int delayMs}) {
    if (!_running || _paused || _isRestartScheduled) return;
    _isRestartScheduled = true;
    _restartTimer?.cancel();
    _restartTimer = Timer(Duration(milliseconds: delayMs), () async {
      _isRestartScheduled = false;
      if (!_running || _paused || _speech.isListening) return;
      await _beginIosListenCycle();
    });
  }

  @override
  Future<void> pause() async {
    if (!_running || _paused) return;
    _paused = true;
    _speechIdleTimer?.cancel();
    if (_usingAndroidNative) {
      try {
        await _androidChannel.invokeMethod<bool>('pause');
      } catch (_) {}
    } else {
      _restartTimer?.cancel();
      try {
        if (_speech.isListening) await _speech.stop();
      } catch (_) {}
    }
    _emitState(VoiceTrackingState.paused);
  }

  @override
  Future<void> resume() async {
    if (!_running) {
      if (_lastConfig != null) {
        await start(_lastConfig!);
      }
      return;
    }
    if (!_paused) return;
    _paused = false;
    if (_usingAndroidNative) {
      try {
        await _androidChannel.invokeMethod<bool>('resume');
      } catch (_) {}
      _emitState(VoiceTrackingState.listening);
    } else {
      await _beginIosListenCycle();
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    _paused = false;
    _isRestartScheduled = false;
    _restartTimer?.cancel();
    _speechIdleTimer?.cancel();

    if (_usingAndroidNative) {
      try {
        await _androidChannel.invokeMethod<bool>('stop');
      } catch (_) {}
      _androidChannel.setMethodCallHandler(null);
      _usingAndroidNative = false;
    } else {
      try {
        if (_speech.isListening) await _speech.stop();
      } catch (_) {}
    }
    _emitState(VoiceTrackingState.stopped);
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (!_isAndroid) {
      try {
        await _speech.cancel();
      } catch (_) {}
    }
    await _transcriptController.close();
    await _voiceLevelController.close();
    await _stateController.close();
    await _languageController.close();
    await _newUtteranceController.close();
  }

  void _markActiveSpeech() {
    if (_paused || !_running) return;
    if (_state != VoiceTrackingState.activeSpeech) {
      _emitState(VoiceTrackingState.activeSpeech);
    }
    _speechIdleTimer?.cancel();
    _speechIdleTimer = Timer(const Duration(milliseconds: 1100), () {
      if (_running && !_paused && _state == VoiceTrackingState.activeSpeech) {
        _emitState(VoiceTrackingState.listening);
      }
    });
  }

  void _emitState(VoiceTrackingState next) {
    if (_state == next) return;
    _state = next;
    if (!_stateController.isClosed) {
      _stateController.add(next);
    }
  }
}
