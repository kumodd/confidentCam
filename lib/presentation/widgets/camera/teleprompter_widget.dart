import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/script_sentence_matcher.dart';
import '../../../core/utils/spoken_language_detector.dart';
import '../../../core/utils/teleprompter_scroll_math.dart';
import '../../../services/voice_teleprompter_service.dart';

/// Shared teleprompter overlay used across Warmup, 30-Day Challenge, and
/// Content Creator AI Script recording screens.
///
/// Features:
/// - **Sentence-level voice-following auto-scroll** using the default low-latency
///   platform ASR engine with automatic Hindi / English / Hinglish language
///   detection, confidence & stability gating, and smooth `animateTo` glides
///   keeping the active sentence centered without individual word highlighting,
///   jitter, or sudden jumps.
/// - **Start / Pause / Stop** voice-tracking controls.
/// - **Mathematically scaled Fixed-Speed Auto-Scroll** (`Ticker`) preserved as
///   a user-selectable mode and automatic fallback whenever voice tracking is
///   unavailable or disabled.
class TeleprompterWidget extends StatefulWidget {
  final String title;
  final List<TeleprompterSection> sections;
  final bool isRecording;
  final bool autoScrollEnabled;
  final bool voiceSyncEnabled;
  final bool mirrorText;
  final bool solidBackground;
  final double scrollSpeed;
  final double opacity;
  final double fontSize;
  final Color? textColor;
  final String languagePreference;
  final ValueChanged<double> onSpeedChange;
  final ValueChanged<bool>? onVoiceSyncToggle;
  final ValueChanged<bool>? onMirrorToggle;
  final VoiceTeleprompterService? voiceService;

  const TeleprompterWidget({
    super.key,
    required this.title,
    required this.sections,
    required this.isRecording,
    this.autoScrollEnabled = true,
    this.voiceSyncEnabled = false,
    this.mirrorText = false,
    this.solidBackground = false,
    required this.scrollSpeed,
    required this.opacity,
    this.fontSize = 16.0,
    this.textColor,
    this.languagePreference = 'en',
    required this.onSpeedChange,
    this.onVoiceSyncToggle,
    this.onMirrorToggle,
    this.voiceService,
  });

  /// Convenience constructor for plain single-body scripts (Warmup & Challenge).
  factory TeleprompterWidget.plain({
    Key? key,
    required String script,
    required String title,
    required bool isRecording,
    bool autoScrollEnabled = true,
    bool voiceSyncEnabled = false,
    bool mirrorText = false,
    bool solidBackground = false,
    required double scrollSpeed,
    required double opacity,
    double fontSize = 16.0,
    Color? textColor,
    String languagePreference = 'en',
    required ValueChanged<double> onSpeedChange,
    ValueChanged<bool>? onVoiceSyncToggle,
    ValueChanged<bool>? onMirrorToggle,
    VoiceTeleprompterService? voiceService,
  }) {
    return TeleprompterWidget(
      key: key,
      title: title,
      sections: [TeleprompterSection(body: script)],
      isRecording: isRecording,
      autoScrollEnabled: autoScrollEnabled,
      voiceSyncEnabled: voiceSyncEnabled,
      mirrorText: mirrorText,
      solidBackground: solidBackground,
      scrollSpeed: scrollSpeed,
      opacity: opacity,
      fontSize: fontSize,
      textColor: textColor,
      languagePreference: languagePreference,
      onSpeedChange: onSpeedChange,
      onVoiceSyncToggle: onVoiceSyncToggle,
      onMirrorToggle: onMirrorToggle,
      voiceService: voiceService,
    );
  }

  @override
  State<TeleprompterWidget> createState() => _TeleprompterWidgetState();
}

class _TeleprompterWidgetState extends State<TeleprompterWidget>
    with SingleTickerProviderStateMixin {
  /// Minimum pixel delta before triggering a scroll animation (deadband avoids
  /// micro-scrolls when consecutive short sentences sit on the same visual line).
  static const double _scrollDeadbandPx = 10.0;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _contentColumnKey = GlobalKey();
  List<GlobalKey> _sectionTextKeys = [];

  late Ticker _ticker;
  Duration _lastTickElapsed = Duration.zero;
  bool _isFixedScrollPaused = false;
  bool _isUserDragging = false;

  /// True when the user explicitly clicked Stop on voice tracking.
  bool _voiceTrackingStoppedByUser = false;

  /// True when the user manually started voice-tracking rehearsal before recording.
  bool _isVoiceRehearsing = false;

  late ScriptSentenceMatcher _matcher;
  late VoiceTeleprompterService _voiceService;
  bool _ownsVoiceService = false;

  VoiceTrackingState _voiceStatus = VoiceTrackingState.stopped;
  SpokenLanguage _detectedLanguage = SpokenLanguage.unknown;
  int _confirmedSentenceIndex = 0;
  bool _isVoiceSpeaking = false;

  // Cached vertical centers of each sentence in content coordinates so we do
  // NOT recompute TextPainter layout on every ASR callback.
  List<double>? _cachedSentenceCenterYs;
  double _cachedLayoutWidth = -1;
  double _cachedLayoutFontSize = -1;
  double? _lastAnimatedTargetOffset;

  TeleprompterMetrics _currentMetrics = TeleprompterScrollMath.computeMetrics(
    viewportWidth: 300,
    viewportHeight: 200,
    baseFontSize: 16.0,
    speedMultiplier: 1.0,
  );
  double _lastViewportWidth = 300.0;
  double _lastViewportHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _rebuildMatcher();
    if (widget.voiceService != null) {
      _voiceService = widget.voiceService!;
      _ownsVoiceService = false;
    } else if (sl.isRegistered<VoiceTeleprompterService>()) {
      _voiceService = sl<VoiceTeleprompterService>();
      _ownsVoiceService = true;
    } else {
      _voiceService = VoiceTeleprompterService();
      _ownsVoiceService = true;
    }

    _ticker = createTicker(_onFixedSpeedTick);

    if (widget.isRecording) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.isRecording) {
          _startRecordingSession(resetPosition: true);
        }
      });
    }
  }

  @override
  void didUpdateWidget(TeleprompterWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_sectionsEqual(oldWidget.sections, widget.sections)) {
      _rebuildMatcher();
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    }

    if (oldWidget.fontSize != widget.fontSize) {
      _invalidateSentenceLayoutCache();
    }

    if (widget.isRecording && !oldWidget.isRecording) {
      _startRecordingSession(resetPosition: true);
      return;
    }

    if (!widget.isRecording && oldWidget.isRecording) {
      _stopRecordingSession();
      return;
    }

    if (widget.isRecording || _isVoiceRehearsing) {
      if (widget.voiceSyncEnabled != oldWidget.voiceSyncEnabled) {
        if (widget.voiceSyncEnabled) {
          _voiceTrackingStoppedByUser = false;
          _startVoiceTracking();
        } else {
          _stopVoiceTracking(byUser: false, resetCursor: false);
        }
      }
      _syncFixedSpeedTicker();
    } else if (!widget.voiceSyncEnabled && _isVoiceRehearsing) {
      _stopVoiceTracking(byUser: false, resetCursor: false);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    if (_ownsVoiceService) {
      _voiceService.dispose();
    } else {
      _voiceService.stop();
    }
    _scrollController.dispose();
    super.dispose();
  }

  bool _sectionsEqual(
    List<TeleprompterSection> a,
    List<TeleprompterSection> b,
  ) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].badgeTitle != b[i].badgeTitle || a[i].body != b[i].body) {
        return false;
      }
    }
    return true;
  }

  void _rebuildMatcher() {
    _matcher = ScriptSentenceMatcher.fromSections(widget.sections);
    _sectionTextKeys = List.generate(
      _matcher.parsedSections.length,
      (_) => GlobalKey(),
    );
    _confirmedSentenceIndex = 0;
    _lastAnimatedTargetOffset = null;
    _invalidateSentenceLayoutCache();
  }

  void _invalidateSentenceLayoutCache() {
    _cachedSentenceCenterYs = null;
    _cachedLayoutWidth = -1;
    _cachedLayoutFontSize = -1;
  }

  String get _fullPlainScript =>
      _matcher.parsedSections.map((s) => s.plainText).join('\n');

  void _startRecordingSession({required bool resetPosition}) {
    setState(() {
      _isFixedScrollPaused = false;
      _voiceTrackingStoppedByUser = false;
      _isVoiceRehearsing = false;
      _confirmedSentenceIndex = 0;
      _lastAnimatedTargetOffset = null;
      _isVoiceSpeaking = false;
    });
    _matcher.reset();

    if (resetPosition && _scrollController.hasClients) {
      _scrollController.jumpTo(0.0);
    }

    if (widget.voiceSyncEnabled) {
      _startVoiceTracking();
    } else {
      _stopVoiceTracking(byUser: false, resetCursor: false);
    }
    _syncFixedSpeedTicker();
  }

  void _stopRecordingSession() {
    _stopTicker();
    _stopVoiceTracking(byUser: false, resetCursor: false);
    if (mounted) {
      setState(() {
        _isFixedScrollPaused = false;
        _isVoiceRehearsing = false;
        _voiceTrackingStoppedByUser = false;
        _lastAnimatedTargetOffset = null;
        _isVoiceSpeaking = false;
      });
    }
  }

  /// Explicit **Start / Resume** control for voice tracking (works both while
  /// recording and in pre-recording rehearsal mode).
  Future<void> _startVoiceTracking() async {
    if (!widget.voiceSyncEnabled) {
      widget.onVoiceSyncToggle?.call(true);
    }
    if (!widget.isRecording) {
      _isVoiceRehearsing = true;
    }
    _voiceTrackingStoppedByUser = false;

    if (_voiceStatus == VoiceTrackingState.paused) {
      await _voiceService.resume();
      if (mounted) {
        setState(() => _voiceStatus = _voiceService.status);
        _syncFixedSpeedTicker();
      }
      return;
    }

    await _voiceService.start(
      languagePreference: widget.languagePreference,
      scriptText: _fullPlainScript,
      onNewUtteranceStarted: () => _matcher.beginNewUtterance(),
      onTranscript: _handleTranscript,
      onVoiceActivity: (rmsDb, isSpeaking) {
        if (!mounted) return;
        if (_isVoiceSpeaking != isSpeaking) {
          setState(() => _isVoiceSpeaking = isSpeaking);
        }
      },
      onLanguageDetected: (lang) {
        if (!mounted) return;
        if (_detectedLanguage != lang) {
          setState(() => _detectedLanguage = lang);
        }
      },
      onStatusChanged: (status) {
        if (!mounted) return;
        setState(() => _voiceStatus = status);
        _syncFixedSpeedTicker();
      },
    );
    if (mounted) _syncFixedSpeedTicker();
  }

  /// Explicit **Pause** control for voice tracking (preserves exact position).
  Future<void> _pauseVoiceTracking() async {
    await _voiceService.pause();
    if (mounted) {
      setState(() {
        _voiceStatus = VoiceTrackingState.paused;
        _isVoiceSpeaking = false;
      });
    }
  }

  /// Explicit **Stop** control for voice tracking.
  Future<void> _stopVoiceTracking({
    bool byUser = true,
    bool resetCursor = true,
  }) async {
    await _voiceService.stop();
    if (!mounted) return;
    setState(() {
      _voiceStatus = VoiceTrackingState.stopped;
      _isVoiceSpeaking = false;
      _isVoiceRehearsing = false;
      if (byUser) {
        _voiceTrackingStoppedByUser = true;
      }
      if (resetCursor) {
        _matcher.reset();
        _confirmedSentenceIndex = 0;
        _lastAnimatedTargetOffset = null;
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
      }
    });
    _syncFixedSpeedTicker();
  }

  void _handleTranscript(AsrTranscriptEvent event) {
    if (!mounted || !_isVoiceSyncDriving || _isUserDragging) return;

    final alignment = _matcher.processRecognition(
      event.text,
      alternatives: event.alternatives,
      asrConfidence: event.confidence,
      isFinal: event.isFinal,
    );

    // Only update UI & trigger a smooth scroll animation when the active
    // confirmed sentence actually changes — NEVER on every partial!
    if (alignment.moved) {
      setState(() {
        _confirmedSentenceIndex = alignment.confirmedSentenceIndex;
      });
      _animateToSentence(alignment.confirmedSentenceIndex);
    }
  }

  /// Smoothly animates the teleprompter scroll view so sentence [sentenceIndex]
  /// sits calmly around the vertical center of the viewport.
  void _animateToSentence(int sentenceIndex) {
    if (!_scrollController.hasClients || _isUserDragging) return;
    final pos = _scrollController.position;
    if (!pos.hasContentDimensions) return;
    final maxScroll = pos.maxScrollExtent;
    if (maxScroll <= 0 || _matcher.sentences.isEmpty) return;

    final clampedIdx = sentenceIndex.clamp(0, _matcher.sentences.length - 1);
    final centers = _ensureSentenceCenterYs();

    final double targetOffset;
    if (centers != null && clampedIdx < centers.length) {
      targetOffset = TeleprompterScrollMath.computeTargetOffsetForSentenceCenterY(
        sentenceCenterY: centers[clampedIdx],
        focusAnchorY: _currentMetrics.focusAnchorY,
        maxScrollExtent: maxScroll,
      );
    } else {
      targetOffset = TeleprompterScrollMath.computeEstimatedOffsetForSentenceIndex(
        sentenceIndex: clampedIdx,
        totalSentenceCount: _matcher.totalSentenceCount,
        maxScrollExtent: maxScroll,
      );
    }

    // Deadband prevents micro-scroll jitter when adjacent short sentences share
    // nearly the same vertical center.
    final referenceOffset = _lastAnimatedTargetOffset ?? pos.pixels;
    if ((targetOffset - referenceOffset).abs() < _scrollDeadbandPx &&
        (targetOffset - pos.pixels).abs() < _scrollDeadbandPx) {
      return;
    }

    _lastAnimatedTargetOffset = targetOffset;
    final duration = TeleprompterScrollMath.computeSmoothScrollDuration(
      targetOffset - pos.pixels,
    );

    _scrollController.animateTo(
      targetOffset,
      duration: duration,
      curve: Curves.easeInOutCubic,
    );
  }

  /// Measures and caches the vertical center Y (in scroll-content coordinates)
  /// of every sentence block once per viewport/font layout.
  List<double>? _ensureSentenceCenterYs() {
    if (_matcher.sentences.isEmpty) return null;

    final widthChanged = (_cachedLayoutWidth - _lastViewportWidth).abs() > 1.0;
    final fontChanged =
        (_cachedLayoutFontSize - _currentMetrics.effectiveFontSize).abs() > 0.25;
    if (_cachedSentenceCenterYs != null && !widthChanged && !fontChanged) {
      return _cachedSentenceCenterYs;
    }

    final contentCtx = _contentColumnKey.currentContext;
    final contentBox = contentCtx?.findRenderObject() as RenderBox?;
    if (contentBox == null || !contentBox.hasSize) return null;

    final sectionPainters = <int, TextPainter>{};
    final sectionTops = <int, double>{};

    for (var sIdx = 0; sIdx < _matcher.parsedSections.length; sIdx++) {
      final secCtx =
          sIdx < _sectionTextKeys.length
              ? _sectionTextKeys[sIdx].currentContext
              : null;
      final secBox = secCtx?.findRenderObject() as RenderBox?;
      if (secBox == null || !secBox.hasSize) continue;

      sectionTops[sIdx] =
          secBox.localToGlobal(Offset.zero, ancestor: contentBox).dy +
          _lensTopPadding(_currentMetrics);
      final parsed = _matcher.parsedSections[sIdx];
      final painter = TextPainter(
        text: TextSpan(
          text: parsed.plainText,
          style: _baseScriptTextStyle(_currentMetrics, const Color(0xFFF7F8F0)),
        ),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: secBox.size.width);
      sectionPainters[sIdx] = painter;
    }

    if (sectionPainters.isEmpty) return null;

    final centers = List<double>.filled(_matcher.sentences.length, 0.0);
    for (var i = 0; i < _matcher.sentences.length; i++) {
      final sentence = _matcher.sentences[i];
      final painter = sectionPainters[sentence.sectionIndex];
      final topY = sectionTops[sentence.sectionIndex];
      if (painter == null || topY == null) {
        centers[i] = i > 0 ? centers[i - 1] + _currentMetrics.lineHeightPx : 0.0;
        continue;
      }

      final parsedLen = _matcher.parsedSections[sentence.sectionIndex].plainText.length;
      final safeStart = sentence.sectionCharStart.clamp(0, parsedLen);
      final safeEnd = math.max(
        safeStart,
        sentence.sectionCharEnd.clamp(0, parsedLen),
      );
      final startCaret = painter.getOffsetForCaret(
        TextPosition(offset: safeStart),
        Rect.zero,
      );
      final endCaret = painter.getOffsetForCaret(
        TextPosition(offset: safeEnd),
        Rect.zero,
      );
      final sentenceMidY =
          ((startCaret.dy + endCaret.dy) * 0.5) +
          (_currentMetrics.lineHeightPx * 0.5);
      centers[i] = topY + sentenceMidY;
    }

    for (final painter in sectionPainters.values) {
      painter.dispose();
    }

    _cachedSentenceCenterYs = centers;
    _cachedLayoutWidth = _lastViewportWidth;
    _cachedLayoutFontSize = _currentMetrics.effectiveFontSize;
    return centers;
  }

  /// Re-anchors the sentence tracker after a manual user drag so voice sync
  /// seamlessly resumes from the sentence now closest to the center of screen.
  void _syncSentenceAnchorFromScrollOffset(double scrollOffset) {
    final centers = _ensureSentenceCenterYs();
    if (centers == null || centers.isEmpty) return;

    final viewportCenterContentY = scrollOffset + _currentMetrics.focusAnchorY;
    var closestIdx = _confirmedSentenceIndex;
    var bestDist = double.infinity;

    for (var i = 0; i < centers.length; i++) {
      final dist = (centers[i] - viewportCenterContentY).abs();
      if (dist < bestDist) {
        bestDist = dist;
        closestIdx = i;
      }
    }

    if (closestIdx != _confirmedSentenceIndex) {
      _matcher.jumpToSentence(closestIdx);
      setState(() {
        _confirmedSentenceIndex = closestIdx;
      });
    }
    _lastAnimatedTargetOffset = scrollOffset;
  }

  bool get _isVoiceTrackingActive =>
      widget.voiceSyncEnabled &&
      !_voiceTrackingStoppedByUser &&
      (widget.isRecording || _isVoiceRehearsing) &&
      _voiceStatus != VoiceTrackingState.stopped &&
      _voiceStatus != VoiceTrackingState.unavailableFallback;

  bool get _isVoiceSyncDriving =>
      _isVoiceTrackingActive && _voiceStatus != VoiceTrackingState.paused;

  bool get _isFixedSpeedFallbackDriving =>
      widget.isRecording &&
      widget.autoScrollEnabled &&
      (!widget.voiceSyncEnabled ||
          _voiceTrackingStoppedByUser ||
          _voiceStatus == VoiceTrackingState.unavailableFallback);

  /// The 60fps Ticker runs ONLY for Fixed-Speed Auto-Scroll / fallback — NEVER
  /// during Voice-Following mode (eliminating frame-by-frame recalculation and
  /// conserving battery).
  void _syncFixedSpeedTicker() {
    if (_isFixedSpeedFallbackDriving) {
      if (!_ticker.isActive) {
        _lastTickElapsed = Duration.zero;
        _ticker.start();
      }
    } else {
      _stopTicker();
    }
  }

  void _stopTicker() {
    if (_ticker.isActive) {
      _ticker.stop();
    }
    _lastTickElapsed = Duration.zero;
  }

  void _refreshMetrics(double viewportWidth, double viewportHeight) {
    double? laidOutContentHeight;
    if (_scrollController.hasClients) {
      final pos = _scrollController.position;
      if (pos.hasContentDimensions) {
        final rawHeight =
            pos.maxScrollExtent +
            pos.viewportDimension -
            _currentMetrics.topPadding -
            _currentMetrics.bottomPadding;
        if (rawHeight > 0) {
          laidOutContentHeight = rawHeight;
        }
      }
    }

    _currentMetrics = TeleprompterScrollMath.computeMetrics(
      viewportWidth: viewportWidth,
      viewportHeight: viewportHeight,
      baseFontSize: widget.fontSize,
      speedMultiplier: widget.scrollSpeed,
      totalWordCount: _matcher.totalWordCount,
      laidOutContentHeight: laidOutContentHeight,
    );
  }

  void _onFixedSpeedTick(Duration elapsed) {
    if (_lastTickElapsed == Duration.zero) {
      _lastTickElapsed = elapsed;
      return;
    }

    final dt = ((elapsed - _lastTickElapsed).inMicroseconds / 1000000.0).clamp(
      0.0,
      0.1,
    );
    _lastTickElapsed = elapsed;

    if (!mounted ||
        _isUserDragging ||
        _isFixedScrollPaused ||
        !_isFixedSpeedFallbackDriving ||
        !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;
    final maxScroll = position.maxScrollExtent;
    if (maxScroll <= 0) return;

    _refreshMetrics(_lastViewportWidth, _lastViewportHeight);
    final currentOffset = position.pixels;

    if (currentOffset < maxScroll) {
      final next = (currentOffset + _currentMetrics.pixelsPerSecond * dt)
          .clamp(0.0, maxScroll);
      _scrollController.jumpTo(next);
    }
  }

  TextStyle _baseScriptTextStyle(TeleprompterMetrics metrics, Color textColor) {
    return GoogleFonts.inter(
      color: textColor,
      fontSize: metrics.effectiveFontSize,
      height: metrics.lineHeightFactor,
      fontWeight: FontWeight.w500,
      shadows: const [
        Shadow(color: Color(0xCC000000), blurRadius: 6, offset: Offset(0, 1)),
      ],
    );
  }

  String _statusLabel() {
    if (widget.voiceSyncEnabled) {
      final langSuffix =
          _detectedLanguage != SpokenLanguage.unknown
              ? '·${_detectedLanguage.shortBadge}'
              : '';
      if (_voiceStatus == VoiceTrackingState.unavailableFallback) {
        return widget.autoScrollEnabled ? 'FALLBACK' : 'MANUAL';
      }
      if (_voiceStatus == VoiceTrackingState.paused) {
        return 'PAUSED';
      }
      if (_isVoiceTrackingActive) {
        final base =
            _voiceStatus == VoiceTrackingState.activeSpeech ? 'SYNC' : 'LIVE';
        return '$base$langSuffix';
      }
      return 'VOICE';
    }

    if (!widget.isRecording) {
      return widget.autoScrollEnabled ? 'AUTO' : 'MANUAL';
    }
    if (_isFixedScrollPaused) return 'PAUSED';
    return widget.autoScrollEnabled ? 'READING' : 'MANUAL';
  }

  Color _statusColor() {
    if (widget.voiceSyncEnabled) {
      if (_voiceStatus == VoiceTrackingState.unavailableFallback) {
        return const Color(0xFFFFCC80);
      }
      if (_voiceStatus == VoiceTrackingState.paused) {
        return const Color(0xFFE5DF7A);
      }
      if (_isVoiceTrackingActive) {
        return _voiceStatus == VoiceTrackingState.activeSpeech
            ? const Color(0xFF75D488)
            : const Color(0xFFE5DF7A);
      }
      return const Color(0xFFE5DF7A);
    }
    if (!widget.isRecording) return const Color(0xFFA6E3B4);
    if (_isFixedScrollPaused) return const Color(0xFFE5DF7A);
    return const Color(0xFFFF8A8A);
  }

  Widget _buildHeaderControlButton({
    required IconData icon,
    required String semanticLabel,
    required VoidCallback onTap,
    Color? color,
    Color? fillColor,
    Color? borderColor,
  }) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: fillColor ?? Colors.white.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.22),
            ),
          ),
          child: Icon(
            icon,
            color: color ?? const Color(0xFFF7F8F0),
            size: 13.5,
          ),
        ),
      ),
    );
  }

  /// Minimal top padding so the first spoken lines stay right below the
  /// camera lens / notch clearance without clipping ascenders.
  double _lensTopPadding(TeleprompterMetrics metrics) => 6.0;

  @override
  Widget build(BuildContext context) {
    final resolvedTextColor =
        (widget.textColor == null ||
                widget.textColor == Colors.white ||
                widget.textColor == AppColors.primaryText)
            ? const Color(0xFFF7F8F0)
            : widget.textColor!;
    final bgAlpha =
        widget.solidBackground
            ? 0.96
            : (widget.opacity * 0.65).clamp(0.06, 0.62);
    final controlsAlpha =
        widget.solidBackground
            ? 1.0
            : (bgAlpha + 0.14).clamp(0.16, 0.72);
    const onGlassText = Color(0xFFF7F8F0);
    const pillOliveText = Color(0xFFD8D478);

    final voiceRunning =
        _isVoiceTrackingActive && _voiceStatus != VoiceTrackingState.paused;
    final voicePaused = _voiceStatus == VoiceTrackingState.paused;

    final borderColor =
        widget.isRecording
            ? AppColors.error.withValues(alpha: 0.85)
            : (_isVoiceRehearsing
                ? const Color(0xFF75D488).withValues(alpha: 0.75)
                : Colors.white.withValues(alpha: 0.22));
    final borderWidth = widget.solidBackground ? 0.8 : 1.2;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF121512).withValues(alpha: bgAlpha),
        borderRadius: BorderRadius.circular(widget.solidBackground ? 0 : 18),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Viewport-scaled script body sits FIRST (right near the camera lens)
          Expanded(
            child: LayoutBuilder(
              builder: (context, bodyConstraints) {
                const horizontalPad = 14.0;
                final innerWidth = math.max(
                  120.0,
                  bodyConstraints.maxWidth - (horizontalPad * 2),
                );
                final innerHeight = math.max(80.0, bodyConstraints.maxHeight);
                if ((_lastViewportWidth - innerWidth).abs() > 1.0 ||
                    (_lastViewportHeight - innerHeight).abs() > 1.0) {
                  _invalidateSentenceLayoutCache();
                }
                _lastViewportWidth = innerWidth;
                _lastViewportHeight = innerHeight;
                _refreshMetrics(innerWidth, innerHeight);
                final metrics = _currentMetrics;
                final topPad = _lensTopPadding(metrics);

                return Stack(
                  children: [
                    // Subtle reading-zone edge markers
                    Positioned(
                      top: metrics.focusAnchorY,
                      left: 0,
                      right: 0,
                      child: IgnorePointer(
                        child: Row(
                          children: [
                            Container(
                              width: 5,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: pillOliveText.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 0.7,
                                color: Colors.white.withValues(alpha: 0.10),
                              ),
                            ),
                            Container(
                              width: 5,
                              height: 2.5,
                              decoration: BoxDecoration(
                                color: pillOliveText.withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Scrollable script text with gentle top/bottom fade & touch drag
                    NotificationListener<ScrollNotification>(
                      onNotification: (notification) {
                        if (notification is ScrollStartNotification &&
                            notification.dragDetails != null) {
                          _isUserDragging = true;
                        } else if (notification is ScrollEndNotification) {
                          if (_isUserDragging) {
                            _isUserDragging = false;
                            if (_scrollController.hasClients &&
                                _isVoiceTrackingActive) {
                              _syncSentenceAnchorFromScrollOffset(
                                _scrollController.offset,
                              );
                            }
                          }
                        }
                        return false;
                      },
                      child: ShaderMask(
                        shaderCallback: (Rect bounds) {
                          return LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.white,
                              Colors.white,
                              Colors.white.withValues(alpha: 0.0),
                            ],
                            stops: const [0.0, 0.84, 1.0],
                          ).createShader(bounds);
                        },
                        blendMode: BlendMode.dstIn,
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            if (_isVoiceTrackingActive) {
                              if (voiceRunning) {
                                _pauseVoiceTracking();
                              } else {
                                _startVoiceTracking();
                              }
                            } else if (widget.isRecording &&
                                _isFixedSpeedFallbackDriving) {
                              setState(
                                () =>
                                    _isFixedScrollPaused =
                                        !_isFixedScrollPaused,
                              );
                            }
                          },
                          child: Transform(
                            alignment: Alignment.center,
                            transform:
                                widget.mirrorText
                                    ? Matrix4.diagonal3Values(-1.0, 1.0, 1.0)
                                    : Matrix4.identity(),
                            child: SingleChildScrollView(
                              controller: _scrollController,
                              padding: EdgeInsets.fromLTRB(
                                horizontalPad,
                                topPad,
                                horizontalPad,
                                metrics.bottomPadding,
                              ),
                              physics: const BouncingScrollPhysics(),
                              child: Column(
                                key: _contentColumnKey,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: _buildSectionWidgets(
                                  metrics: metrics,
                                  resolvedTextColor: resolvedTextColor,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          Container(height: 1.0, color: Colors.white.withValues(alpha: 0.12)),
          // Teleprompter controls bar docked BELOW the script text so lines stick near lens
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF121512).withValues(alpha: controlsAlpha),
              borderRadius:
                  widget.solidBackground
                      ? BorderRadius.zero
                      : const BorderRadius.vertical(
                        bottom: Radius.circular(17),
                      ),
            ),
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color:
                          widget.isRecording
                              ? AppColors.error
                              : Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color:
                            widget.isRecording
                                ? AppColors.error
                                : pillOliveText.withValues(alpha: 0.55),
                      ),
                    ),
                    child: Text(
                      widget.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.manrope(
                        color: widget.isRecording ? onGlassText : pillOliveText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // 1-tap Voice-Following vs Fixed-Speed Mode toggle
                if (widget.onVoiceSyncToggle != null)
                  Semantics(
                    label:
                        widget.voiceSyncEnabled
                            ? 'Switch to Fixed-Speed Scrolling'
                            : 'Enable Voice-Following Mode',
                    button: true,
                    child: GestureDetector(
                      onTap:
                          () => widget.onVoiceSyncToggle!(
                            !widget.voiceSyncEnabled,
                          ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color:
                              widget.voiceSyncEnabled
                                  ? (_voiceStatus ==
                                          VoiceTrackingState.unavailableFallback
                                      ? Colors.orange.withValues(alpha: 0.28)
                                      : const Color(
                                        0xFF75D488,
                                      ).withValues(alpha: 0.24))
                                  : Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color:
                                widget.voiceSyncEnabled
                                    ? (_voiceStatus ==
                                            VoiceTrackingState
                                                .unavailableFallback
                                        ? const Color(0xFFFFB74D)
                                        : const Color(0xFF75D488))
                                    : Colors.white.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              widget.voiceSyncEnabled
                                  ? Icons.mic_rounded
                                  : Icons.mic_off_rounded,
                              color:
                                  widget.voiceSyncEnabled
                                      ? (_voiceStatus ==
                                              VoiceTrackingState
                                                  .unavailableFallback
                                          ? const Color(0xFFFFCC80)
                                          : const Color(0xFF8CE0A2))
                                      : onGlassText.withValues(alpha: 0.8),
                              size: 14,
                            ),
                            if (_isVoiceSyncDriving && _isVoiceSpeaking) ...[
                              const SizedBox(width: 4),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF75D488),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),

                // Start / Pause / Stop controls for Voice-Following Tracking
                if (widget.voiceSyncEnabled) ...[
                  const SizedBox(width: 5),
                  if (voiceRunning)
                    _buildHeaderControlButton(
                      icon: Icons.pause_rounded,
                      semanticLabel: 'Pause Voice Tracking',
                      onTap: _pauseVoiceTracking,
                    )
                  else
                    _buildHeaderControlButton(
                      icon: Icons.play_arrow_rounded,
                      semanticLabel:
                          voicePaused
                              ? 'Resume Voice Tracking'
                              : 'Start Voice Tracking',
                      onTap: _startVoiceTracking,
                      color: const Color(0xFF8CE0A2),
                      borderColor: const Color(
                        0xFF75D488,
                      ).withValues(alpha: 0.6),
                    ),
                  if (voiceRunning || voicePaused) ...[
                    const SizedBox(width: 4),
                    _buildHeaderControlButton(
                      icon: Icons.stop_rounded,
                      semanticLabel: 'Stop Voice Tracking',
                      onTap: () => _stopVoiceTracking(byUser: true),
                      color: const Color(0xFFFF8A8A),
                      borderColor: const Color(
                        0xFFFF8A8A,
                      ).withValues(alpha: 0.55),
                    ),
                  ],
                ],

                // Fixed-speed controls when recording without active voice lock
                if (widget.isRecording && _isFixedSpeedFallbackDriving) ...[
                  const SizedBox(width: 6),
                  _buildHeaderControlButton(
                    icon:
                        _isFixedScrollPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                    semanticLabel:
                        _isFixedScrollPaused
                            ? 'Resume Auto-Scroll'
                            : 'Pause Auto-Scroll',
                    onTap:
                        () => setState(
                          () => _isFixedScrollPaused = !_isFixedScrollPaused,
                        ),
                  ),
                  const SizedBox(width: 4),
                  _buildHeaderControlButton(
                    icon: Icons.remove,
                    semanticLabel: 'Decrease Scroll Speed',
                    onTap: () => widget.onSpeedChange(-0.25),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '${widget.scrollSpeed.toStringAsFixed(1)}x',
                      style: GoogleFonts.manrope(
                        color: onGlassText,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  _buildHeaderControlButton(
                    icon: Icons.add,
                    semanticLabel: 'Increase Scroll Speed',
                    onTap: () => widget.onSpeedChange(0.25),
                  ),
                ],

                if (widget.onMirrorToggle != null && !widget.isRecording) ...[
                  const SizedBox(width: 5),
                  _buildHeaderControlButton(
                    icon: Icons.flip_rounded,
                    semanticLabel:
                        widget.mirrorText
                            ? 'Disable Text Mirroring'
                            : 'Enable Text Mirroring',
                    onTap: () => widget.onMirrorToggle!(!widget.mirrorText),
                    color:
                        widget.mirrorText
                            ? const Color(0xFFE5DF7A)
                            : onGlassText.withValues(alpha: 0.85),
                    fillColor:
                        widget.mirrorText
                            ? const Color(0xFFD8D478).withValues(alpha: 0.22)
                            : null,
                    borderColor:
                        widget.mirrorText ? const Color(0xFFD8D478) : null,
                  ),
                ],

                const SizedBox(width: 6),
                Text(
                  _statusLabel(),
                  style: AppTypography.uppercaseLabel(
                    color: _statusColor(),
                    fontSize: 9.5,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Renders script sections cleanly WITHOUT individual word highlighting.
  ///
  /// During voice-following mode, completed sentences softly recede so the
  /// active sentence stays effortlessly legible around the center of screen
  /// without distracting per-word background boxes or flicker.
  List<Widget> _buildSectionWidgets({
    required TeleprompterMetrics metrics,
    required Color resolvedTextColor,
  }) {
    final baseStyle = _baseScriptTextStyle(metrics, resolvedTextColor);
    final showSentenceCue =
        widget.voiceSyncEnabled &&
        (_isVoiceTrackingActive || _voiceStatus == VoiceTrackingState.paused);
    final widgets = <Widget>[];

    for (var sIdx = 0; sIdx < _matcher.parsedSections.length; sIdx++) {
      final parsed = _matcher.parsedSections[sIdx];
      final badgeTitle = parsed.source.badgeTitle;
      final badgeColor = parsed.source.badgeColor ?? const Color(0xFFE5DF7A);

      if (sIdx > 0) {
        widgets.add(const SizedBox(height: 14));
      }

      if (badgeTitle != null && badgeTitle.isNotEmpty) {
        widgets.add(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.55)),
            ),
            child: Text(
              badgeTitle,
              style: AppTypography.uppercaseLabel(
                color: badgeColor,
                fontSize: 10,
                letterSpacing: 1.3,
              ),
            ),
          ),
        );
        widgets.add(const SizedBox(height: 6));
      }

      final spans =
          parsed.pieces.map((piece) {
            TextStyle? spanStyle;

            if (showSentenceCue && piece.sentenceIndex != null) {
              final sentIdx = piece.sentenceIndex!;
              if (sentIdx < _confirmedSentenceIndex) {
                // Completed sentences softly dimmed (no per-word boxes)
                spanStyle = TextStyle(
                  color: resolvedTextColor.withValues(alpha: 0.48),
                  fontWeight: piece.isBold ? FontWeight.w700 : FontWeight.w500,
                );
              } else if (sentIdx == _confirmedSentenceIndex) {
                // Active sentence stays full brightness and crisp
                spanStyle = TextStyle(
                  color:
                      piece.isBold
                          ? const Color(0xFFE5DF7A)
                          : resolvedTextColor,
                  fontWeight: piece.isBold ? FontWeight.w700 : FontWeight.w600,
                );
              } else if (piece.isBold) {
                spanStyle = const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE5DF7A),
                );
              }
            } else if (piece.isBold) {
              spanStyle = const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFFE5DF7A),
              );
            }

            return TextSpan(text: piece.text, style: spanStyle);
          }).toList();

      widgets.add(
        RichText(
          key: _sectionTextKeys[sIdx],
          text: TextSpan(style: baseStyle, children: spans),
        ),
      );
    }

    return widgets;
  }
}
