import 'dart:async';

import '../core/utils/logger.dart';
import '../core/utils/spoken_language_detector.dart';
import 'asr/platform_default_asr_engine.dart';
import 'asr/teleprompter_asr_engine.dart';

export 'asr/teleprompter_asr_engine.dart'
    show AsrTranscriptEvent, VoiceTrackingState;

/// Backward-compatible alias used across existing widgets/tests.
typedef VoiceSyncStatus = VoiceTrackingState;

/// High-level voice-tracking orchestrator bridging the default platform ASR
/// engine, automatic [SpokenLanguageDetector] (English / Hindi / Hinglish),
/// and `start / pause / resume / stop` controls.
class VoiceTeleprompterService {
  final TeleprompterAsrEngine Function()? _engineFactory;
  final SpokenLanguageDetector _languageDetector = SpokenLanguageDetector();

  TeleprompterAsrEngine? _activeEngine;
  VoiceTrackingState _status = VoiceTrackingState.stopped;
  SpokenLanguage _detectedLanguage = SpokenLanguage.unknown;

  final List<StreamSubscription<dynamic>> _subs = [];

  void Function(AsrTranscriptEvent event)? _onTranscript;
  void Function(double soundLevel, bool isSpeaking)? _onVoiceActivity;
  void Function(VoiceTrackingState status)? _onStatusChanged;
  void Function(SpokenLanguage language)? _onLanguageDetected;
  void Function()? _onNewUtteranceStarted;

  VoiceTeleprompterService({
    TeleprompterAsrEngine Function()? engineFactory,
  }) : _engineFactory = engineFactory;

  VoiceTrackingState get status => _status;
  SpokenLanguage get detectedLanguage => _detectedLanguage;

  TeleprompterAsrEngine _createEngine() {
    if (_engineFactory != null) return _engineFactory();
    return PlatformDefaultAsrEngine();
  }

  /// Starts real-time voice tracking using the default platform ASR engine.
  ///
  /// Automatically infers preferred locales from [scriptText] and
  /// [languagePreference], and continuously updates [detectedLanguage] from
  /// live ASR language metadata + recognized tokens.
  Future<bool> start({
    required String languagePreference,
    String scriptText = '',
    void Function(AsrTranscriptEvent event)? onTranscript,
    void Function(double soundLevel, bool isSpeaking)? onVoiceActivity,
    void Function(VoiceTrackingState status)? onStatusChanged,
    void Function(SpokenLanguage language)? onLanguageDetected,
    void Function()? onNewUtteranceStarted,
  }) async {
    await stop();

    _onTranscript = onTranscript;
    _onVoiceActivity = onVoiceActivity;
    _onStatusChanged = onStatusChanged;
    _onLanguageDetected = onLanguageDetected;
    _onNewUtteranceStarted = onNewUtteranceStarted;

    _languageDetector.reset();
    final initialLang = _languageDetector.observe(text: scriptText);
    _updateDetectedLanguage(initialLang);

    final preferredLocales = SpokenLanguageDetector.inferPreferredLocales(
      scriptText: scriptText,
      languagePreference: languagePreference,
    );

    final config = AsrStartConfig(
      preferredLocales: preferredLocales,
      scriptContextHint: scriptText,
    );

    final engine = _createEngine();
    _activeEngine = engine;

    _subs.add(
      engine.transcriptStream.listen((event) {
        final lang = _languageDetector.observe(
          languageCode: event.detectedLanguageCode,
          text: event.text,
        );
        _updateDetectedLanguage(lang);
        _onTranscript?.call(event);
      }),
    );

    _subs.add(
      engine.voiceLevelStream.listen((event) {
        _onVoiceActivity?.call(event.rmsDb, event.isSpeaking);
      }),
    );

    _subs.add(
      engine.stateStream.listen((nextState) {
        _setStatus(nextState);
      }),
    );

    _subs.add(
      engine.detectedLanguageStream.listen((code) {
        final lang = _languageDetector.observe(languageCode: code);
        _updateDetectedLanguage(lang);
      }),
    );

    _subs.add(
      engine.newUtteranceStream.listen((_) {
        _onNewUtteranceStarted?.call();
      }),
    );

    return engine.start(config);
  }

  Future<void> pause() async {
    await _activeEngine?.pause();
    _setStatus(VoiceTrackingState.paused);
  }

  Future<void> resume() async {
    await _activeEngine?.resume();
    if (_status == VoiceTrackingState.paused) {
      _setStatus(VoiceTrackingState.listening);
    }
  }

  Future<void> stop() async {
    await _disposeActiveEngine();
    _setStatus(VoiceTrackingState.stopped);
  }

  Future<void> dispose() async {
    await _disposeActiveEngine();
    _status = VoiceTrackingState.stopped;
  }

  Future<void> _disposeActiveEngine() async {
    final engine = _activeEngine;
    _activeEngine = null;

    // Cancel listeners FIRST so teardown events never re-enter disposed widgets
    // or leave un-drained broadcast deliveries hanging on controller.close().
    final subs = List<StreamSubscription<dynamic>>.of(_subs);
    _subs.clear();
    for (final sub in subs) {
      await sub.cancel();
    }

    if (engine != null) {
      try {
        await engine.stop();
      } catch (_) {}
      try {
        await engine.dispose();
      } catch (e) {
        logger.d('VoiceTeleprompterService engine dispose ignored: $e');
      }
    }
  }

  void _updateDetectedLanguage(SpokenLanguage next) {
    if (next == _detectedLanguage) return;
    _detectedLanguage = next;
    _onLanguageDetected?.call(next);
  }

  void _setStatus(VoiceTrackingState next) {
    if (_status == next) return;
    _status = next;
    _onStatusChanged?.call(next);
  }
}
