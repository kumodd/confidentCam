import 'dart:math' as math;

/// Computed typography and scroll-velocity geometry for a teleprompter viewport.
class TeleprompterMetrics {
  /// Inner text container width in logical pixels.
  final double viewportWidth;

  /// Inner scrollable viewport height in logical pixels.
  final double viewportHeight;

  /// User's selected base font size in logical pixels.
  final double baseFontSize;

  /// Bounded scale factor derived from the teleprompter viewport size.
  final double sizeScaleFactor;

  /// Font size after mathematical scaling to the teleprompter overlay size.
  final double effectiveFontSize;

  /// Line-height multiplier applied to the script text style.
  final double lineHeightFactor;

  /// Height of one rendered line of text in logical pixels.
  final double lineHeightPx;

  /// Vertical reading anchor inside the viewport (centered for sentence sync).
  final double focusAnchorY;

  /// Top content padding inside the scroll view.
  final double topPadding;

  /// Bottom content padding so final sentences can rest comfortably centered.
  final double bottomPadding;

  /// Estimated average words per wrapped line for this viewport width and font.
  final double estimatedWordsPerLine;

  /// Target reading pace in words per minute for the current speed multiplier.
  final double targetWpm;

  /// Mathematically scaled scroll velocity in logical pixels per second.
  final double pixelsPerSecond;

  const TeleprompterMetrics({
    required this.viewportWidth,
    required this.viewportHeight,
    required this.baseFontSize,
    required this.sizeScaleFactor,
    required this.effectiveFontSize,
    required this.lineHeightFactor,
    required this.lineHeightPx,
    required this.focusAnchorY,
    required this.topPadding,
    required this.bottomPadding,
    required this.estimatedWordsPerLine,
    required this.targetWpm,
    required this.pixelsPerSecond,
  });
}

/// Pure mathematical scaling engine for teleprompter typography, centered
/// sentence-based auto-scrolling, and fixed-speed fallback scrolling.
class TeleprompterScrollMath {
  /// Reference teleprompter scroll-body height in logical pixels (`~28-32%`
  /// of a standard phone screen).
  static const double referenceViewportHeight = 220.0;

  /// Natural conversational speaking rate at `1.0x` speed (words per minute).
  static const double baseWordsPerMinute = 135.0;

  /// Average advance width of a proportional sans-serif glyph as a fraction of
  /// font size (`Inter` / `Manrope`).
  static const double avgCharWidthRatio = 0.52;

  /// Average characters per word including trailing space.
  static const double avgCharsPerWord = 5.8;

  /// Default line-height multiplier for readable camera teleprompter text.
  static const double defaultLineHeightFactor = 1.6;

  /// Centered vertical reading zone ratio inside the teleprompter viewport.
  static const double focusAnchorRatio = 0.46;

  const TeleprompterScrollMath._();

  /// Computes the bounded size scale factor from teleprompter viewport height.
  static double computeSizeScaleFactor(double viewportHeight) {
    final safeHeight = math.max(80.0, viewportHeight);
    final rawScale = math.sqrt(safeHeight / referenceViewportHeight);
    return rawScale.clamp(0.85, 1.25);
  }

  /// Computes the mathematically scaled overlay font size for the given
  /// viewport height and user base font size.
  static double computeEffectiveFontSize({
    required double baseFontSize,
    required double viewportHeight,
  }) {
    final scale = computeSizeScaleFactor(viewportHeight);
    return (baseFontSize * scale).clamp(12.0, 28.0);
  }

  /// Computes the teleprompter overlay pixel height for a parent viewport
  /// height and user height fraction (`0.15` to `0.90`).
  static double computeOverlayHeight({
    required double containerHeight,
    required double heightFraction,
    double topInset = 0.0,
    double bottomReserve = 38.0,
  }) {
    final clampedFraction = heightFraction.clamp(0.15, 0.90);
    final maxAllowed = math.max(
      120.0,
      containerHeight - topInset - bottomReserve,
    );
    final desired = containerHeight * clampedFraction;
    return desired.clamp(120.0, math.min(containerHeight * 0.90, maxAllowed));
  }

  /// Computes full teleprompter metrics including mathematically scaled
  /// [TeleprompterMetrics.pixelsPerSecond] for fixed-speed fallback mode.
  static TeleprompterMetrics computeMetrics({
    required double viewportWidth,
    required double viewportHeight,
    required double baseFontSize,
    required double speedMultiplier,
    int totalWordCount = 0,
    double? laidOutContentHeight,
    double lineHeightFactor = defaultLineHeightFactor,
  }) {
    final safeWidth = math.max(120.0, viewportWidth);
    final safeHeight = math.max(80.0, viewportHeight);
    final clampedSpeed = speedMultiplier.clamp(0.25, 3.0);

    final sizeScale = computeSizeScaleFactor(safeHeight);
    final effectiveFontSize = (baseFontSize * sizeScale).clamp(12.0, 28.0);
    final lineHeightPx = effectiveFontSize * lineHeightFactor;

    final charsPerLine = math.max(
      12.0,
      safeWidth / (avgCharWidthRatio * effectiveFontSize),
    );
    final wordsPerLine = math.max(2.0, charsPerLine / avgCharsPerWord);

    final targetWpm = baseWordsPerMinute * clampedSpeed;
    final wordsPerSecond = targetWpm / 60.0;

    final geometricPxPerWord = lineHeightPx / wordsPerLine;
    double effectivePxPerWord = geometricPxPerWord;

    if (laidOutContentHeight != null &&
        laidOutContentHeight > 0 &&
        totalWordCount >= 8) {
      final empiricalPxPerWord = laidOutContentHeight / totalWordCount;
      effectivePxPerWord = empiricalPxPerWord.clamp(
        geometricPxPerWord * 0.65,
        geometricPxPerWord * 1.85,
      );
    }

    final pixelsPerSecond = wordsPerSecond * effectivePxPerWord;
    final focusAnchorY = safeHeight * focusAnchorRatio;
    final topPadding = (safeHeight * 0.14).clamp(12.0, 48.0);
    final bottomPadding = (safeHeight * 0.54).clamp(56.0, 260.0);

    return TeleprompterMetrics(
      viewportWidth: safeWidth,
      viewportHeight: safeHeight,
      baseFontSize: baseFontSize,
      sizeScaleFactor: sizeScale,
      effectiveFontSize: effectiveFontSize,
      lineHeightFactor: lineHeightFactor,
      lineHeightPx: lineHeightPx,
      focusAnchorY: focusAnchorY,
      topPadding: topPadding,
      bottomPadding: bottomPadding,
      estimatedWordsPerLine: wordsPerLine,
      targetWpm: targetWpm,
      pixelsPerSecond: pixelsPerSecond,
    );
  }

  /// Computes the target scroll offset that places the vertical midpoint of an
  /// active sentence ([sentenceCenterY] in content coordinates) around the
  /// vertical center ([focusAnchorY]) of the teleprompter viewport.
  static double computeTargetOffsetForSentenceCenterY({
    required double sentenceCenterY,
    required double focusAnchorY,
    required double maxScrollExtent,
  }) {
    if (maxScrollExtent <= 0) return 0.0;
    return (sentenceCenterY - focusAnchorY).clamp(0.0, maxScrollExtent);
  }

  /// Fallback target scroll offset estimated proportionally from sentence
  /// progress when exact vertical layout coordinates are unavailable.
  static double computeEstimatedOffsetForSentenceIndex({
    required int sentenceIndex,
    required int totalSentenceCount,
    required double maxScrollExtent,
  }) {
    if (totalSentenceCount <= 1 || maxScrollExtent <= 0) return 0.0;
    final progress = (sentenceIndex / (totalSentenceCount - 1)).clamp(0.0, 1.0);
    return progress * maxScrollExtent;
  }

  /// Computes a smooth, calm transition duration proportional to the scroll
  /// distance in pixels so short moves feel effortless and skipped sentences
  /// glide smoothly without jarring jumps.
  static Duration computeSmoothScrollDuration(double distancePx) {
    final absDist = distancePx.abs();
    final ms = (420 + (absDist * 1.45)).round().clamp(420, 950);
    return Duration(milliseconds: ms);
  }
}
