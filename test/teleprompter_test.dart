import 'dart:async';

import 'package:confident_cam/core/utils/script_sentence_matcher.dart';
import 'package:confident_cam/core/utils/spoken_language_detector.dart';
import 'package:confident_cam/core/utils/teleprompter_scroll_math.dart';
import 'package:confident_cam/domain/entities/settings.dart';
import 'package:confident_cam/presentation/widgets/camera/teleprompter_widget.dart';
import 'package:confident_cam/services/asr/teleprompter_asr_engine.dart';
import 'package:confident_cam/services/voice_teleprompter_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAsrEngine implements TeleprompterAsrEngine {
  final _transcript = StreamController<AsrTranscriptEvent>.broadcast();
  final _voiceLevel = StreamController<VoiceLevelEvent>.broadcast();
  final _state = StreamController<VoiceTrackingState>.broadcast();
  final _language = StreamController<String>.broadcast();
  final _utterance = StreamController<void>.broadcast();

  bool started = false;
  bool paused = false;
  bool stopped = false;

  _FakeAsrEngine();

  @override
  Stream<AsrTranscriptEvent> get transcriptStream => _transcript.stream;

  @override
  Stream<VoiceLevelEvent> get voiceLevelStream => _voiceLevel.stream;

  @override
  Stream<VoiceTrackingState> get stateStream => _state.stream;

  @override
  Stream<String> get detectedLanguageStream => _language.stream;

  @override
  Stream<void> get newUtteranceStream => _utterance.stream;

  @override
  Future<bool> start(AsrStartConfig config) async {
    started = true;
    paused = false;
    stopped = false;
    _state.add(VoiceTrackingState.listening);
    return true;
  }

  @override
  Future<void> pause() async {
    paused = true;
    _state.add(VoiceTrackingState.paused);
  }

  @override
  Future<void> resume() async {
    paused = false;
    _state.add(VoiceTrackingState.listening);
  }

  @override
  Future<void> stop() async {
    stopped = true;
    paused = false;
    _state.add(VoiceTrackingState.stopped);
  }

  @override
  Future<void> dispose() async {
    await _transcript.close();
    await _voiceLevel.close();
    await _state.close();
    await _language.close();
    await _utterance.close();
  }

  void emitTranscript(
    String text, {
    List<String> alternatives = const [],
    double? confidence,
    bool isFinal = false,
    String? lang,
  }) {
    _state.add(VoiceTrackingState.activeSpeech);
    _transcript.add(
      AsrTranscriptEvent(
        text: text,
        alternatives: alternatives,
        confidence: confidence,
        isFinal: isFinal,
        detectedLanguageCode: lang,
      ),
    );
  }

  void emitFallback() {
    _state.add(VoiceTrackingState.unavailableFallback);
  }
}

void main() {
  group('TeleprompterScrollMath', () {
    test(
      'scales effective font size and scroll velocity with overlay height',
      () {
        final smallOverlay = TeleprompterScrollMath.computeMetrics(
          viewportWidth: 320,
          viewportHeight: 130,
          baseFontSize: 16,
          speedMultiplier: 1.0,
        );
        final mediumOverlay = TeleprompterScrollMath.computeMetrics(
          viewportWidth: 320,
          viewportHeight: 220,
          baseFontSize: 16,
          speedMultiplier: 1.0,
        );
        final largeOverlay = TeleprompterScrollMath.computeMetrics(
          viewportWidth: 320,
          viewportHeight: 380,
          baseFontSize: 16,
          speedMultiplier: 1.0,
        );

        expect(
          smallOverlay.effectiveFontSize,
          lessThan(mediumOverlay.effectiveFontSize),
        );
        expect(
          mediumOverlay.effectiveFontSize,
          lessThan(largeOverlay.effectiveFontSize),
        );
        expect(mediumOverlay.sizeScaleFactor, closeTo(1.0, 0.001));
        expect(smallOverlay.targetWpm, equals(135.0));
        expect(largeOverlay.targetWpm, equals(135.0));
        expect(
          smallOverlay.pixelsPerSecond,
          lessThan(mediumOverlay.pixelsPerSecond),
        );
        expect(
          mediumOverlay.pixelsPerSecond,
          lessThan(largeOverlay.pixelsPerSecond),
        );
      },
    );

    test(
      'maintains proportional speed with narrower widths and speed multiplier',
      () {
        final wide = TeleprompterScrollMath.computeMetrics(
          viewportWidth: 380,
          viewportHeight: 220,
          baseFontSize: 16,
          speedMultiplier: 1.0,
        );
        final narrow = TeleprompterScrollMath.computeMetrics(
          viewportWidth: 220,
          viewportHeight: 220,
          baseFontSize: 16,
          speedMultiplier: 1.0,
        );
        final fast = TeleprompterScrollMath.computeMetrics(
          viewportWidth: 380,
          viewportHeight: 220,
          baseFontSize: 16,
          speedMultiplier: 2.0,
        );

        expect(narrow.pixelsPerSecond, greaterThan(wide.pixelsPerSecond));
        expect(fast.pixelsPerSecond, closeTo(wide.pixelsPerSecond * 2.0, 0.01));
      },
    );

    test('honors full 15%..90% display height range without 55% cap', () {
      final h15 = TeleprompterScrollMath.computeOverlayHeight(
        containerHeight: 800,
        heightFraction: 0.15,
      );
      final h55 = TeleprompterScrollMath.computeOverlayHeight(
        containerHeight: 800,
        heightFraction: 0.55,
      );
      final h90 = TeleprompterScrollMath.computeOverlayHeight(
        containerHeight: 800,
        heightFraction: 0.90,
      );

      expect(h15, closeTo(120.0, 0.1));
      expect(h55, closeTo(440.0, 0.1));
      expect(h90, closeTo(720.0, 0.1));
    });

    test('centers active sentence cleanly with smooth proportional duration', () {
      final metrics = TeleprompterScrollMath.computeMetrics(
        viewportWidth: 340,
        viewportHeight: 240,
        baseFontSize: 16,
        speedMultiplier: 1.0,
      );
      expect(metrics.focusAnchorY, closeTo(240 * 0.46, 0.5));

      final offset =
          TeleprompterScrollMath.computeTargetOffsetForSentenceCenterY(
            sentenceCenterY: 320,
            focusAnchorY: metrics.focusAnchorY,
            maxScrollExtent: 500,
          );
      expect(offset, closeTo(320 - metrics.focusAnchorY, 0.5));

      final shortDur = TeleprompterScrollMath.computeSmoothScrollDuration(40);
      final longDur = TeleprompterScrollMath.computeSmoothScrollDuration(300);
      expect(shortDur.inMilliseconds, greaterThanOrEqualTo(420));
      expect(longDur.inMilliseconds, greaterThan(shortDur.inMilliseconds));
      expect(longDur.inMilliseconds, lessThanOrEqualTo(950));
    });
  });

  group('SpokenLanguageDetector & DevanagariTransliterator', () {
    test('transliterates Devanagari Hindi into phonetic Latin', () {
      final latin = DevanagariTransliterator.toLatin(
        'क्या आपको लगता है कॉन्फिडेंस',
      );
      expect(latin.toLowerCase(), contains('kya'));
      expect(latin.toLowerCase(), contains('aapko'));
      expect(latin.toLowerCase(), contains('lagta'));
    });

    test('automatically detects English, Hindi, and mixed Hinglish', () {
      final en = SpokenLanguageDetector();
      expect(
        en.observe(text: 'This is my first step toward camera confidence'),
        SpokenLanguage.english,
      );

      final hi = SpokenLanguageDetector();
      expect(
        hi.observe(
          languageCode: 'hi-IN',
          text: 'क्या आपको लगता है बिल्कुल नहीं',
        ),
        SpokenLanguage.hindi,
      );

      final hinglish = SpokenLanguageDetector();
      expect(
        hinglish.observe(
          text: 'Kya aapko lagta hai camera confidence practice se aata hai',
        ),
        SpokenLanguage.hinglish,
      );

      // Voice-to-Script short transcript language detection
      expect(
        SpokenLanguageDetector.detectTranscriptLanguage(
          'chat GPT Kaise kam karta hai',
        ).code,
        equals('hinglish'),
      );
      expect(
        SpokenLanguageDetector.detectTranscriptLanguage(
          'कैमरे के सामने कैसे बोलें',
        ).code,
        equals('hi'),
      );
      expect(
        SpokenLanguageDetector.detectTranscriptLanguage(
          'How to record clean talking head reels',
        ).code,
        equals('en'),
      );
    });
  });

  group('ScriptSentenceMatcher sentence-level tracking & stability', () {
    const englishScript =
        'Welcome everyone to day one of your camera confidence journey. '
        'Today we practice speaking clearly and looking directly into the lens. '
        'Take a calm breath, relax your shoulders, and share your message naturally. '
        'Every repetition builds comfort and momentum over thirty days. '
        'Consistency always beats perfection when building real confidence on camera.';

    const hinglishScript =
        'Kya aapko lagta hai confidence sirf naturally milta hai? '
        'Bilkul nahi. '
        'Sabko pata hai, camera ke saamne aana tough hota hai. '
        'Aaj chaliye chhote steps mein practice shuru karein.';

    test('segments script into clean sentences and preserves markdown bold/bullets', () {
      final matcher = ScriptSentenceMatcher.fromSections(const [
        TeleprompterSection(
          badgeTitle: 'HOOK',
          body: '**Stop** scrolling right now! Listen closely.',
        ),
        TeleprompterSection(
          badgeTitle: 'CONTENT',
          body: '* Focus on systems every morning.\n* Practice daily on camera.',
        ),
      ]);

      expect(matcher.parsedSections.length, 2);
      expect(matcher.totalSentenceCount, 4);
      expect(matcher.parsedSections[0].pieces.first.isBold, isTrue);
      expect(
        matcher.parsedSections[1].plainText,
        contains('• Focus on systems every morning.'),
      );
    });

    test('does NOT jump on a single partial result or low-confidence noise', () {
      final matcher = ScriptSentenceMatcher.fromPlainText(englishScript);
      final t0 = DateTime(2026, 11, 27, 0, 0, 0);

      // Low-confidence ASR update must hold cleanly
      final lowConf = matcher.processRecognition(
        'Today we practice speaking clearly and looking directly',
        asrConfidence: 0.20,
        isFinal: true,
        timestamp: t0,
      );
      expect(lowConf.moved, isFalse);
      expect(lowConf.moveKind, SentenceMoveKind.heldLowConfidence);
      expect(matcher.confirmedSentenceIndex, 0);

      // Single partial pointing to sentence 1 holds pending confirmation
      final partial1 = matcher.processRecognition(
        'Today we practice speaking clearly',
        isFinal: false,
        timestamp: t0.add(const Duration(milliseconds: 300)),
      );
      expect(partial1.moved, isFalse);
      expect(partial1.moveKind, SentenceMoveKind.heldPendingConfirmation);
      expect(matcher.confirmedSentenceIndex, 0);

      // Second consistent partial confirms sentence 1 smoothly
      final partial2 = matcher.processRecognition(
        'Today we practice speaking clearly and looking directly into the lens',
        isFinal: false,
        timestamp: t0.add(const Duration(milliseconds: 600)),
      );
      expect(partial2.moved, isTrue);
      expect(partial2.moveKind, SentenceMoveKind.nextSentence);
      expect(matcher.confirmedSentenceIndex, 1);

      // Temporary ASR mistake / unrelated chatter must NOT move the prompter
      final noise = matcher.processRecognition(
        'banana spaceship xylophone mountain',
        isFinal: true,
        timestamp: t0.add(const Duration(milliseconds: 1400)),
      );
      expect(noise.moved, isFalse);
      expect(matcher.confirmedSentenceIndex, 1);
    });

    test('handles skipped sentences and guards backward retakes strictly to finals', () {
      final matcher = ScriptSentenceMatcher.fromPlainText(englishScript);
      final t0 = DateTime(2026, 11, 27, 0, 0, 0);

      // Skip directly to sentence 3 ("Every repetition builds comfort...")
      final skipRes = matcher.processRecognition(
        'Every repetition builds comfort and momentum over thirty days',
        isFinal: true,
        asrConfidence: 0.88,
        timestamp: t0,
      );
      expect(skipRes.moved, isTrue);
      expect(skipRes.moveKind, SentenceMoveKind.skippedForward);
      expect(matcher.confirmedSentenceIndex, 3);

      // Partial echoing sentence 2 MUST NOT jump backward!
      final backPartial = matcher.processRecognition(
        'Take a calm breath relax your shoulders and share your message',
        isFinal: false,
        timestamp: t0.add(const Duration(milliseconds: 800)),
      );
      expect(backPartial.moved, isFalse);
      expect(matcher.confirmedSentenceIndex, 3);

      // Intentional high-confidence final retake of sentence 2 smoothly re-anchors
      final backFinal = matcher.processRecognition(
        'Take a calm breath relax your shoulders and share your message naturally',
        isFinal: true,
        asrConfidence: 0.91,
        timestamp: t0.add(const Duration(milliseconds: 1600)),
      );
      expect(backFinal.moved, isTrue);
      expect(backFinal.moveKind, SentenceMoveKind.repeatedSentence);
      expect(matcher.confirmedSentenceIndex, 2);
    });

    test('matches Devanagari Hindi ASR against Romanized Hinglish sentences', () {
      final matcher = ScriptSentenceMatcher.fromPlainText(hinglishScript);
      final t0 = DateTime(2026, 11, 27, 0, 0, 0);

      // Sentence 0 stays on 0 while speaker reads opening Hinglish question
      final s0 = matcher.processRecognition(
        'क्या आपको लगता है कॉन्फिडेंस सिर्फ नेचुरली मिलता है',
        isFinal: true,
        timestamp: t0,
      );
      expect(s0.confirmedSentenceIndex, 0);

      // Speaker advances to sentence 2 ("Sabko pata hai, camera ke saamne aana tough hota hai.")
      final s2 = matcher.processRecognition(
        'सबको पता है कैमरा के सामने आना टफ होता है',
        isFinal: true,
        timestamp: t0.add(const Duration(seconds: 2)),
      );
      expect(s2.moved, isTrue);
      expect(s2.confirmedSentenceIndex, 2);

      // Speaker finishes with sentence 3 via alternative hypothesis
      final s3 = matcher.processRecognition(
        'today lets start',
        alternatives: const [
          'आज चलिए छोटे स्टेप्स में प्रैक्टिस शुरू करें',
        ],
        isFinal: true,
        timestamp: t0.add(const Duration(seconds: 4)),
      );
      expect(s3.moved, isTrue);
      expect(s3.confirmedSentenceIndex, 3);
    });
  });

  group('TeleprompterWidget sentence scrolling, controls & fallback', () {
    const longScript =
        'Welcome everyone to day one of your camera confidence journey. '
        'Today we practice speaking clearly and looking directly into the lens. '
        'Take a calm breath, relax your shoulders, and share your message naturally. '
        'Every repetition builds comfort and momentum over thirty days. '
        'Keep going line by line without rushing, letting the teleprompter guide your pace. '
        'Consistency always beats perfection when building real confidence on camera. '
        'Remember to smile, project your voice warmly, and finish strong with a clear call to action.';

    testWidgets(
      'starts mathematically scaled fixed-speed auto-scroll even when mounted already recording',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 200,
                child: TeleprompterWidget.plain(
                  script: longScript,
                  title: 'Day 1',
                  isRecording: true,
                  autoScrollEnabled: true,
                  voiceSyncEnabled: false,
                  scrollSpeed: 1.5,
                  opacity: 0.35,
                  onSpeedChange: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        final controller = scrollView.controller!;
        expect(controller.offset, equals(0.0));

        for (var i = 0; i < 40; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(controller.offset, greaterThan(15.0));
      },
    );

    testWidgets(
      'respects autoScrollEnabled=false (stays at offset 0 during recording)',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 200,
                child: TeleprompterWidget.plain(
                  script: longScript,
                  title: 'Day 1',
                  isRecording: true,
                  autoScrollEnabled: false,
                  voiceSyncEnabled: false,
                  scrollSpeed: 1.5,
                  opacity: 0.35,
                  onSpeedChange: (_) {},
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        expect(scrollView.controller!.offset, equals(0.0));
      },
    );

    testWidgets(
      'scrolls smoothly sentence-by-sentence without word highlighting, supports pause/stop & fallback',
      (tester) async {
        final fakeEngine = _FakeAsrEngine();
        final service = VoiceTeleprompterService(
          engineFactory: () => fakeEngine,
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 180,
                child: TeleprompterWidget.plain(
                  script: longScript,
                  title: 'Day 1',
                  isRecording: true,
                  autoScrollEnabled: true,
                  voiceSyncEnabled: true,
                  scrollSpeed: 1.0,
                  opacity: 0.35,
                  onSpeedChange: (_) {},
                  voiceService: service,
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(fakeEngine.started, isTrue);

        final scrollView = tester.widget<SingleChildScrollView>(
          find.byType(SingleChildScrollView),
        );
        final controller = scrollView.controller!;
        expect(controller.offset, equals(0.0));

        // Emit a confirmed final sentence deeper in the script
        fakeEngine.emitTranscript(
          'Every repetition builds comfort and momentum over thirty days',
          isFinal: true,
          confidence: 0.92,
          lang: 'en-US',
        );
        for (var i = 0; i < 24; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(controller.offset, greaterThan(40.0));

        // Verify NO individual word background highlight boxes are rendered
        final richText = tester.widget<RichText>(find.byType(RichText).first);
        final rootSpan = richText.text as TextSpan;
        for (final child in rootSpan.children ?? const <InlineSpan>[]) {
          if (child is TextSpan) {
            expect(child.style?.backgroundColor, isNull);
          }
        }

        // Pause voice tracking via header control -> holds exact offset
        final offsetBeforePause = controller.offset;
        await tester.tap(find.bySemanticsLabel('Pause Voice Tracking'));
        await tester.pump();
        expect(fakeEngine.paused, isTrue);
        expect(controller.offset, equals(offsetBeforePause));

        // Resume voice tracking
        await tester.tap(find.bySemanticsLabel('Resume Voice Tracking'));
        await tester.pump();
        expect(fakeEngine.paused, isFalse);

        // Unavailable ASR triggers automatic Fixed-Speed fallback cleanly
        fakeEngine.emitFallback();
        await tester.pump();
        final beforeFallback = controller.offset;
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }
        expect(controller.offset, greaterThan(beforeFallback));

        // Unmount widget cleanly before closing fake streams
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        await service.dispose();
      },
    );

    testWidgets(
      'mirrors teleprompter script horizontally when mirrorText=true and fires onMirrorToggle',
      (tester) async {
        bool? toggledValue;

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 340,
                height: 220,
                child: TeleprompterWidget.plain(
                  script: longScript,
                  title: 'Mirror Rig',
                  isRecording: false,
                  mirrorText: true,
                  scrollSpeed: 1.0,
                  opacity: 0.35,
                  onSpeedChange: (_) {},
                  onMirrorToggle: (v) => toggledValue = v,
                ),
              ),
            ),
          ),
        );

        await tester.pump();

        // Find the Transform wrapping the SingleChildScrollView and verify X-axis flip (-1, 1, 1)
        final transforms = tester.widgetList<Transform>(find.byType(Transform));
        final hasHorizontalMirror = transforms.any((t) {
          final m = t.transform.storage;
          return (m[0] + 1.0).abs() < 0.001 && (m[5] - 1.0).abs() < 0.001;
        });
        expect(hasHorizontalMirror, isTrue);

        // Tap mirror header control to toggle off
        await tester.tap(find.bySemanticsLabel('Disable Text Mirroring'));
        await tester.pump();
        expect(toggledValue, isFalse);

        // Verify teleprompter controls sit BELOW the script text so text sticks near camera lens
        final scriptTop = tester.getTopLeft(find.byType(SingleChildScrollView)).dy;
        final controlsTop =
            tester.getTopLeft(find.bySemanticsLabel('Disable Text Mirroring')).dy;
        expect(controlsTop, greaterThan(scriptTop));
      },
    );
  });

  group('Recording layout templates & enhanced recording Settings', () {
    test('RecordingLayoutTemplate exposes 40/60, 50/50, 60/40 split ratios & fallbacks cleanly', () {
      final split40 = RecordingLayoutTemplate.fromKey('split_top_40');
      expect(split40.isSplit, isTrue);
      expect(split40.scriptFlex, equals(40));
      expect(split40.cameraFlex, equals(60));

      final split50 = RecordingLayoutTemplate.fromKey('split_even_50');
      expect(split50.scriptFlex, equals(50));
      expect(split50.cameraFlex, equals(50));

      final focus60 = RecordingLayoutTemplate.fromKey('script_focus_60');
      expect(focus60.scriptFlex, equals(60));
      expect(focus60.cameraFlex, equals(40));

      expect(
        RecordingLayoutTemplate.fromKey('unknown_key'),
        equals(RecordingLayoutTemplate.classicOverlay),
      );
    });

    test('Settings preserves mirror, template, countdown, silence alerts, and preferred mic', () {
      final defaults = Settings.defaults();
      expect(defaults.teleprompterMirrorText, isFalse);
      expect(defaults.layoutTemplate, equals(RecordingLayoutTemplate.classicOverlay));
      expect(defaults.recordingCountdownSeconds, equals(3));
      expect(defaults.silenceNotificationsDuringRecording, isTrue);
      expect(defaults.preferredMicDeviceId, isNull);

      final updated = defaults.copyWith(
        teleprompterMirrorText: true,
        recordingLayoutTemplate: 'split_top_40',
        recordingCountdownSeconds: 0,
        silenceNotificationsDuringRecording: false,
        preferredMicDeviceId: 42,
      );
      expect(updated.teleprompterMirrorText, isTrue);
      expect(updated.layoutTemplate, equals(RecordingLayoutTemplate.splitTop40));
      expect(updated.recordingCountdownSeconds, equals(0));
      expect(updated.silenceNotificationsDuringRecording, isFalse);
      expect(updated.preferredMicDeviceId, equals(42));

      final clearedMic = updated.copyWith(clearPreferredMicDevice: true);
      expect(clearedMic.preferredMicDeviceId, isNull);
    });
  });
}
