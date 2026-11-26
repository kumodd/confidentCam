import 'dart:async';

/// Runtime lifecycle state for voice-following teleprompter tracking.
enum VoiceTrackingState {
  /// Tracking is stopped / inactive.
  stopped,

  /// Starting audio capture & on-device ASR.
  initializing,

  /// Listening for speech (paused between sentences or waiting for speaker).
  listening,

  /// Actively recognizing speech.
  activeSpeech,

  /// Explicitly paused by user (mic idle, scroll position preserved).
  paused,

  /// Voice tracking unavailable or audio silenced; teleprompter falls back to
  /// fixed-speed auto-scroll cleanly.
  unavailableFallback,
}

/// Streaming recognition output emitted by [TeleprompterAsrEngine].
class AsrTranscriptEvent {
  final String text;
  final List<String> alternatives;
  final double? confidence;
  final bool isFinal;
  final String? detectedLanguageCode;

  const AsrTranscriptEvent({
    required this.text,
    this.alternatives = const [],
    this.confidence,
    required this.isFinal,
    this.detectedLanguageCode,
  });
}

/// Real-time microphone energy & voice-activity telemetry.
class VoiceLevelEvent {
  final double rmsDb;
  final bool isSpeaking;
  final bool silenced;

  const VoiceLevelEvent({
    required this.rmsDb,
    required this.isSpeaking,
    this.silenced = false,
  });
}

/// Configuration passed when starting [TeleprompterAsrEngine].
class AsrStartConfig {
  final List<String> preferredLocales;
  final String scriptContextHint;

  const AsrStartConfig({
    required this.preferredLocales,
    this.scriptContextHint = '',
  });
}

/// Contract implemented by the default platform ASR engine (and test doubles).
abstract class TeleprompterAsrEngine {
  Stream<AsrTranscriptEvent> get transcriptStream;
  Stream<VoiceLevelEvent> get voiceLevelStream;
  Stream<VoiceTrackingState> get stateStream;
  Stream<String> get detectedLanguageStream;
  Stream<void> get newUtteranceStream;

  Future<bool> start(AsrStartConfig config);
  Future<void> pause();
  Future<void> resume();
  Future<void> stop();
  Future<void> dispose();
}
