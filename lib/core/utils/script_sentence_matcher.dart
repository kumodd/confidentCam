import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'spoken_language_detector.dart';

/// A single logical section of a teleprompter script.
///
/// Warmup and 30-Day Challenge scripts typically use a single unlabeled section,
/// while AI Content Creator scripts use labeled sections (`HOOK`, `CONTENT`,
/// `ENDING`).
class TeleprompterSection {
  final String? badgeTitle;
  final Color? badgeColor;
  final String body;

  const TeleprompterSection({
    this.badgeTitle,
    this.badgeColor,
    required this.body,
  });
}

/// A parsed piece of inline text inside a [TeleprompterSection].
///
/// Every piece belongs to a sentence/reading block ([sentenceIndex]) rather
/// than an individual word, preventing distracting per-word highlighting.
class TeleprompterPiece {
  /// Exact text as rendered on screen (with markdown delimiters stripped).
  final String text;

  /// Whether this piece should render bold (from `**...**` markdown).
  final bool isBold;

  /// Global 0-based sentence index this piece belongs to, or `null` for
  /// structural newlines / separators outside a sentence.
  final int? sentenceIndex;

  /// Character offset in the flattened plain text of its section.
  final int sectionCharStart;

  const TeleprompterPiece({
    required this.text,
    required this.isBold,
    required this.sectionCharStart,
    this.sentenceIndex,
  });
}

/// Parsed representation of a section ready for clean `RichText` rendering.
class ParsedTeleprompterSection {
  final TeleprompterSection source;
  final List<TeleprompterPiece> pieces;
  final String plainText;

  const ParsedTeleprompterSection({
    required this.source,
    required this.pieces,
    required this.plainText,
  });
}

/// A normalized + phonetically folded token used internally for sentence matching.
class _MatchToken {
  final String normalized;
  final String phonetic;
  final bool isStopWord;

  const _MatchToken({
    required this.normalized,
    required this.phonetic,
    required this.isStopWord,
  });

  double get weight => isStopWord ? 0.35 : 1.0;
}

/// A complete sentence or logical reading block within the script.
class ScriptSentence {
  final int index;
  final int sectionIndex;
  final int sectionCharStart;
  final int sectionCharEnd;
  final String rawText;
  final List<_MatchToken> _tokens;

  const ScriptSentence._({
    required this.index,
    required this.sectionIndex,
    required this.sectionCharStart,
    required this.sectionCharEnd,
    required this.rawText,
    required List<_MatchToken> tokens,
  }) : _tokens = tokens;

  int get wordCount => _tokens.length;

  int get contentWordCount => _tokens.where((t) => !t.isStopWord).length;

  List<String> get normalizedWords =>
      _tokens.map((t) => t.normalized).toList(growable: false);
}

/// Classification of how a speech recognition update affected sentence tracking.
enum SentenceMoveKind {
  /// Stayed on the confirmed sentence (still reading current block or pause).
  unchanged,

  /// Recognition confidence was too low; held confirmed position safely.
  heldLowConfidence,

  /// Partial update pointed to a candidate sentence but awaits confirmation.
  heldPendingConfirmation,

  /// Smoothly advanced to the next sentence (`+1`).
  nextSentence,

  /// Confirmed skip ahead across 2 or more sentences.
  skippedForward,

  /// Confirmed intentional repeat / retake of an earlier sentence.
  repeatedSentence,
}

/// Result returned from [ScriptSentenceMatcher.processRecognition].
class SentenceAlignmentResult {
  final int previousSentenceIndex;
  final int confirmedSentenceIndex;
  final int? candidateSentenceIndex;
  final double score;
  final SentenceMoveKind moveKind;

  const SentenceAlignmentResult({
    required this.previousSentenceIndex,
    required this.confirmedSentenceIndex,
    this.candidateSentenceIndex,
    required this.score,
    required this.moveKind,
  });

  bool get moved => confirmedSentenceIndex != previousSentenceIndex;
}

/// Sentence-level & paragraph-block matching engine for stable teleprompter
/// voice-following.
///
/// Key stability guarantees:
/// 1. **Sentence granularity** — never tracks or highlights individual words.
/// 2. **Confidence & stability gating** — ignores low-confidence ASR noise and
///    requires repeated consistent confirmation on partial results before
///    changing the active sentence.
/// 3. **Stay-on-current hysteresis** — prefers holding the last confirmed
///    sentence whenever the speaker is still inside it, pauses, or ASR drifts.
/// 4. **Safe skips & retakes** — allows smooth forward skips on strong multi-word
///    matches; restricts backward transitions strictly to high-confidence final
///    confirmations so transient mistakes never jerk the script backward.
/// 5. **Multilingual Hindi, English & Hinglish** — transliterates Devanagari
///    phonetically and evaluates top ASR alternatives.
class ScriptSentenceMatcher {
  static final RegExp _wordTokenRegex = RegExp(
    r"[\p{L}\p{M}\p{N}]+(?:['\u2019-][\p{L}\p{M}\p{N}]+)*",
    unicode: true,
  );
  static final RegExp _stripNonWordRegex = RegExp(
    r'[^\p{L}\p{M}\p{N}]',
    unicode: true,
  );

  /// Common abbreviations that should not trigger sentence splitting on `.`.
  static const Set<String> _abbreviations = {
    'mr',
    'mrs',
    'ms',
    'dr',
    'prof',
    'sr',
    'jr',
    'st',
    'vs',
    'etc',
    'eg',
    'ie',
    'no',
  };

  /// Common short English/Hinglish glue words carrying lower sentence identity.
  static const Set<String> _stopWords = {
    'a',
    'an',
    'the',
    'to',
    'of',
    'in',
    'on',
    'is',
    'it',
    'its',
    'at',
    'be',
    'or',
    'and',
    'for',
    'my',
    'me',
    'i',
    'im',
    'we',
    'you',
    'your',
    'so',
    'do',
    'no',
    'up',
    'if',
    'am',
    'are',
    'was',
    'this',
    'that',
    'with',
    'hai',
    'hain',
    'ke',
    'ki',
    'ko',
    'ka',
    'se',
    'mein',
    'pe',
    'ye',
    'yeh',
    'toh',
    'bhi',
    'aur',
    'par',
    'ho',
  };

  /// Minimum ASR confidence accepted when the recognizer provides one (`> 0`).
  static const double minAcceptableAsrConfidence = 0.35;

  /// Minimum interval after a confirmed sentence transition before a partial
  /// update can trigger another transition (prevents rapid double-jumps).
  static const Duration partialTransitionCooldown = Duration(milliseconds: 420);

  final List<ParsedTeleprompterSection> parsedSections;
  final List<ScriptSentence> sentences;
  final int totalWordCount;

  int _confirmedSentenceIndex = 0;
  int? _pendingCandidateIndex;
  int _pendingCandidateHits = 0;
  int? _pendingBackwardIndex;
  int _pendingBackwardFinals = 0;
  DateTime? _lastTransitionAt;
  String _lastProcessedPartial = '';

  ScriptSentenceMatcher._({
    required this.parsedSections,
    required this.sentences,
    required this.totalWordCount,
  });

  /// Builds a sentence matcher from structured [TeleprompterSection] entries.
  factory ScriptSentenceMatcher.fromSections(
    List<TeleprompterSection> sections,
  ) {
    final parsed = <ParsedTeleprompterSection>[];
    final allSentences = <ScriptSentence>[];
    var totalWords = 0;

    for (var rawIdx = 0; rawIdx < sections.length; rawIdx++) {
      final section = sections[rawIdx];
      if (section.body.trim().isEmpty) continue;

      final sectionIndex = parsed.length;
      final normalizedBody = section.body.replaceAll(r'\n', '\n');
      final lines = normalizedBody.split('\n');

      // Step 1: Flatten section text with bold-span ranges tracked accurately.
      final plainBuffer = StringBuffer();
      final boldSpans = <_BoldSpan>[];
      final lineRanges = <_CharRange>[];

      for (var lineIdx = 0; lineIdx < lines.length; lineIdx++) {
        var line = lines[lineIdx];
        if (line.trimLeft().startsWith('* ')) {
          line = line.replaceFirst('* ', '• ');
        }

        final lineStart = plainBuffer.length;
        for (final seg in _splitMarkdownBold(line)) {
          if (seg.text.isEmpty) continue;
          final segStart = plainBuffer.length;
          plainBuffer.write(seg.text);
          if (seg.isBold) {
            boldSpans.add(_BoldSpan(segStart, plainBuffer.length));
          }
        }
        final lineEnd = plainBuffer.length;
        if (lineEnd > lineStart) {
          lineRanges.add(_CharRange(lineStart, lineEnd));
        }

        if (lineIdx < lines.length - 1) {
          plainBuffer.write('\n');
        }
      }

      final plainText = plainBuffer.toString();

      // Step 2: Segment each non-empty line into sentence/reading blocks.
      final sectionSentenceRanges = <_SentenceSpan>[];
      for (final lineRange in lineRanges) {
        final rawLine = plainText.substring(lineRange.start, lineRange.end);
        final localRanges = _splitLineIntoSentenceBlocks(rawLine);

        for (final local in localRanges) {
          final absStart = lineRange.start + local.start;
          final absEnd = lineRange.start + local.end;
          final slice = plainText.substring(absStart, absEnd);
          final tokens = _tokenizeText(slice);
          if (tokens.isEmpty) continue;

          // Merge tiny 1-word trailing/stray fragments into previous sentence
          // on the same line so tiny exclamations don't cause extra jumps.
          if (tokens.length == 1 &&
              sectionSentenceRanges.isNotEmpty &&
              sectionSentenceRanges.last.lineStart == lineRange.start) {
            final prev = sectionSentenceRanges.removeLast();
            final mergedText = plainText.substring(prev.start, absEnd);
            sectionSentenceRanges.add(
              _SentenceSpan(
                start: prev.start,
                end: absEnd,
                lineStart: lineRange.start,
                rawText: mergedText,
                tokens: _tokenizeText(mergedText),
              ),
            );
          } else {
            sectionSentenceRanges.add(
              _SentenceSpan(
                start: absStart,
                end: absEnd,
                lineStart: lineRange.start,
                rawText: slice,
                tokens: tokens,
              ),
            );
          }
        }
      }

      // Fallback: if a section had text without matchable tokens, still render
      // it cleanly without crashing.
      final charToSentence = List<int?>.filled(plainText.length, null);
      for (final span in sectionSentenceRanges) {
        final globalIdx = allSentences.length;
        allSentences.add(
          ScriptSentence._(
            index: globalIdx,
            sectionIndex: sectionIndex,
            sectionCharStart: span.start,
            sectionCharEnd: span.end,
            rawText: span.rawText,
            tokens: span.tokens,
          ),
        );
        totalWords += span.tokens.length;
        for (var c = span.start; c < span.end && c < plainText.length; c++) {
          charToSentence[c] = globalIdx;
        }
      }

      // Step 3: Build render pieces preserving bold styling + sentence ownership.
      final isBoldChar = List<bool>.filled(plainText.length, false);
      for (final b in boldSpans) {
        for (var c = b.start; c < b.end && c < plainText.length; c++) {
          isBoldChar[c] = true;
        }
      }

      final pieces = <TeleprompterPiece>[];
      var cursor = 0;
      while (cursor < plainText.length) {
        final bold = isBoldChar[cursor];
        final sentIdx = charToSentence[cursor];
        var next = cursor + 1;
        while (next < plainText.length &&
            isBoldChar[next] == bold &&
            charToSentence[next] == sentIdx) {
          next++;
        }
        pieces.add(
          TeleprompterPiece(
            text: plainText.substring(cursor, next),
            isBold: bold,
            sentenceIndex: sentIdx,
            sectionCharStart: cursor,
          ),
        );
        cursor = next;
      }

      parsed.add(
        ParsedTeleprompterSection(
          source: section,
          pieces: pieces,
          plainText: plainText,
        ),
      );
    }

    return ScriptSentenceMatcher._(
      parsedSections: parsed,
      sentences: allSentences,
      totalWordCount: totalWords,
    );
  }

  /// Convenience constructor for plain single-body scripts.
  factory ScriptSentenceMatcher.fromPlainText(String script) {
    return ScriptSentenceMatcher.fromSections([
      TeleprompterSection(body: script),
    ]);
  }

  int get confirmedSentenceIndex => _confirmedSentenceIndex;

  int get totalSentenceCount => sentences.length;

  ScriptSentence? get currentSentence =>
      (_confirmedSentenceIndex >= 0 &&
              _confirmedSentenceIndex < sentences.length)
          ? sentences[_confirmedSentenceIndex]
          : null;

  void reset() {
    _confirmedSentenceIndex = 0;
    _pendingCandidateIndex = null;
    _pendingCandidateHits = 0;
    _pendingBackwardIndex = null;
    _pendingBackwardFinals = 0;
    _lastTransitionAt = null;
    _lastProcessedPartial = '';
  }

  /// Manually anchors tracking to [sentenceIndex] (e.g. after user touch drag).
  void jumpToSentence(int sentenceIndex) {
    if (sentences.isEmpty) {
      _confirmedSentenceIndex = 0;
      return;
    }
    _confirmedSentenceIndex = sentenceIndex.clamp(0, sentences.length - 1);
    _pendingCandidateIndex = null;
    _pendingCandidateHits = 0;
    _pendingBackwardIndex = null;
    _pendingBackwardFinals = 0;
  }

  /// Clears transient per-utterance partial confirmation state when a new
  /// speech segment begins while preserving [confirmedSentenceIndex].
  void beginNewUtterance() {
    _lastProcessedPartial = '';
  }

  /// Processes a partial or final ASR recognition result and determines whether
  /// the active confirmed sentence should change.
  SentenceAlignmentResult processRecognition(
    String recognizedText, {
    List<String> alternatives = const [],
    double? asrConfidence,
    bool isFinal = false,
    DateTime? timestamp,
  }) {
    final prev = _confirmedSentenceIndex;
    if (sentences.isEmpty) {
      return const SentenceAlignmentResult(
        previousSentenceIndex: 0,
        confirmedSentenceIndex: 0,
        score: 0.0,
        moveKind: SentenceMoveKind.unchanged,
      );
    }

    final now = timestamp ?? DateTime.now();
    final primary = recognizedText.trim();
    if (primary.isEmpty) {
      if (isFinal) beginNewUtterance();
      return SentenceAlignmentResult(
        previousSentenceIndex: prev,
        confirmedSentenceIndex: prev,
        score: 0.0,
        moveKind: SentenceMoveKind.unchanged,
      );
    }

    // 1. Confidence gate: hold reading position when ASR confidence is poor.
    if (asrConfidence != null &&
        asrConfidence > 0.0 &&
        asrConfidence < minAcceptableAsrConfidence) {
      _clearPendingForward();
      return SentenceAlignmentResult(
        previousSentenceIndex: prev,
        confirmedSentenceIndex: prev,
        score: 0.0,
        moveKind: SentenceMoveKind.heldLowConfidence,
      );
    }

    // 2. Skip redundant identical partials to avoid double-counting stability.
    if (!isFinal && primary == _lastProcessedPartial) {
      return SentenceAlignmentResult(
        previousSentenceIndex: prev,
        confirmedSentenceIndex: prev,
        candidateSentenceIndex: _pendingCandidateIndex,
        score: 0.0,
        moveKind: SentenceMoveKind.unchanged,
      );
    }
    if (!isFinal) {
      _lastProcessedPartial = primary;
    } else {
      _lastProcessedPartial = '';
    }

    // 3. Collect tokenized hypotheses (primary + up to 2 alternatives).
    final hypotheses = <List<_MatchToken>>[];
    final primaryTokens = _tokenizeText(primary);
    if (primaryTokens.isNotEmpty) {
      hypotheses.add(primaryTokens);
    }
    for (final alt in alternatives.take(2)) {
      final altTrim = alt.trim();
      if (altTrim.isEmpty || altTrim == primary) continue;
      final altTokens = _tokenizeText(altTrim);
      if (altTokens.isNotEmpty) {
        hypotheses.add(altTokens);
      }
    }

    if (hypotheses.isEmpty) {
      return SentenceAlignmentResult(
        previousSentenceIndex: prev,
        confirmedSentenceIndex: prev,
        score: 0.0,
        moveKind: SentenceMoveKind.unchanged,
      );
    }

    final primaryCount = hypotheses.first.length;
    final primaryContentCount =
        hypotheses.first.where((t) => !t.isStopWord).length;

    // Require enough lexical evidence so stray 1-2 word partials never jitter.
    if (!isFinal && (primaryCount < 3 || primaryContentCount < 2)) {
      return SentenceAlignmentResult(
        previousSentenceIndex: prev,
        confirmedSentenceIndex: prev,
        score: 0.0,
        moveKind: SentenceMoveKind.unchanged,
      );
    }
    if (isFinal && primaryCount < 2 && primaryContentCount < 1) {
      return SentenceAlignmentResult(
        previousSentenceIndex: prev,
        confirmedSentenceIndex: prev,
        score: 0.0,
        moveKind: SentenceMoveKind.unchanged,
      );
    }

    // 4. Score current sentence and bounded neighbor sentences.
    //    We score both the recent utterance window and the trailing clause so
    //    continuous speech across a sentence boundary transitions cleanly.
    final curEval = _bestScoreForSentence(sentences[prev], hypotheses);

    // Forward candidates: local window [prev + 1 .. prev + 4], plus wider skip
    // [prev + 5 .. prev + 10] only when spoken evidence is substantial.
    final maxForward = math.min(
      sentences.length - 1,
      prev + (primaryContentCount >= 3 && primaryCount >= 4 ? 10 : 4),
    );
    _SentenceEval? bestForward;
    for (var idx = prev + 1; idx <= maxForward; idx++) {
      final eval = _bestScoreForSentence(sentences[idx], hypotheses);
      if (!_passesForwardThreshold(
        eval: eval,
        delta: idx - prev,
        curScore: curEval.score,
        isFinal: isFinal,
      )) {
        continue;
      }
      if (bestForward == null ||
          _rankForwardCandidate(eval, idx - prev) >
              _rankForwardCandidate(bestForward, bestForward.sentenceIndex - prev)) {
        bestForward = eval;
      }
    }

    // 5. Stay-on-current hysteresis: if the speaker is still solidly inside
    //    the confirmed sentence (and hasn't clearly moved on), HOLD steady!
    if (bestForward != null) {
      final delta = bestForward.sentenceIndex - prev;
      final stayMargin = isFinal ? 0.06 : 0.11;
      final strongTailTakeover =
          delta == 1 &&
          bestForward.tailScore >= 0.68 &&
          bestForward.tailScore > curEval.tailScore + 0.14;

      if (!strongTailTakeover &&
          curEval.score >= 0.48 &&
          curEval.score >= bestForward.score - stayMargin) {
        _clearPendingForward();
        _pendingBackwardFinals = 0;
        return SentenceAlignmentResult(
          previousSentenceIndex: prev,
          confirmedSentenceIndex: prev,
          score: curEval.score,
          moveKind: SentenceMoveKind.unchanged,
        );
      }

      // 6. Temporal stability confirmation for forward transitions.
      if (isFinal) {
        return _commitTransition(
          prev: prev,
          next: bestForward.sentenceIndex,
          score: bestForward.score,
          kind:
              delta == 1
                  ? SentenceMoveKind.nextSentence
                  : SentenceMoveKind.skippedForward,
          now: now,
        );
      }

      // Partial transition cooldown prevents cascading double-jumps.
      if (_lastTransitionAt != null &&
          now.difference(_lastTransitionAt!) < partialTransitionCooldown) {
        return SentenceAlignmentResult(
          previousSentenceIndex: prev,
          confirmedSentenceIndex: prev,
          candidateSentenceIndex: bestForward.sentenceIndex,
          score: bestForward.score,
          moveKind: SentenceMoveKind.heldPendingConfirmation,
        );
      }

      if (_pendingCandidateIndex == bestForward.sentenceIndex) {
        _pendingCandidateHits++;
      } else {
        _pendingCandidateIndex = bestForward.sentenceIndex;
        _pendingCandidateHits = 1;
      }

      final requiredPartialHits = delta == 1 ? 2 : 3;
      if (_pendingCandidateHits >= requiredPartialHits) {
        return _commitTransition(
          prev: prev,
          next: bestForward.sentenceIndex,
          score: bestForward.score,
          kind:
              delta == 1
                  ? SentenceMoveKind.nextSentence
                  : SentenceMoveKind.skippedForward,
          now: now,
        );
      }

      return SentenceAlignmentResult(
        previousSentenceIndex: prev,
        confirmedSentenceIndex: prev,
        candidateSentenceIndex: bestForward.sentenceIndex,
        score: bestForward.score,
        moveKind: SentenceMoveKind.heldPendingConfirmation,
      );
    }

    // No forward candidate qualified: clear any stale forward pending state.
    _clearPendingForward();

    // 7. Guarded backward retake check (STRICTLY on final results only!).
    //    Partial results NEVER scroll backward.
    if (isFinal && prev > 0) {
      final minBack = math.max(0, prev - 2);
      final nextScore =
          (prev + 1 < sentences.length)
              ? _bestScoreForSentence(sentences[prev + 1], hypotheses).score
              : 0.0;
      final referenceMax = math.max(curEval.score, nextScore);

      _SentenceEval? bestBack;
      for (var idx = prev - 1; idx >= minBack; idx--) {
        final eval = _bestScoreForSentence(sentences[idx], hypotheses);
        final strongRetake =
            eval.score >= 0.70 &&
            eval.matchedWords >= 3 &&
            eval.matchedContentWords >= 2 &&
            eval.score >= referenceMax + 0.22;
        if (!strongRetake) continue;
        if (bestBack == null || eval.score > bestBack.score) {
          bestBack = eval;
        }
      }

      if (bestBack != null) {
        final veryHighConfidenceSingleFinal =
            bestBack.score >= 0.78 &&
            bestBack.matchedWords >= 4 &&
            (asrConfidence == null || asrConfidence <= 0 || asrConfidence >= 0.72);

        if (_pendingBackwardIndex == bestBack.sentenceIndex) {
          _pendingBackwardFinals++;
        } else {
          _pendingBackwardIndex = bestBack.sentenceIndex;
          _pendingBackwardFinals = 1;
        }

        if (veryHighConfidenceSingleFinal || _pendingBackwardFinals >= 2) {
          return _commitTransition(
            prev: prev,
            next: bestBack.sentenceIndex,
            score: bestBack.score,
            kind: SentenceMoveKind.repeatedSentence,
            now: now,
          );
        }

        return SentenceAlignmentResult(
          previousSentenceIndex: prev,
          confirmedSentenceIndex: prev,
          candidateSentenceIndex: bestBack.sentenceIndex,
          score: bestBack.score,
          moveKind: SentenceMoveKind.heldPendingConfirmation,
        );
      } else {
        _pendingBackwardIndex = null;
        _pendingBackwardFinals = 0;
      }
    }

    // Hold confirmed reading position cleanly.
    return SentenceAlignmentResult(
      previousSentenceIndex: prev,
      confirmedSentenceIndex: prev,
      score: curEval.score,
      moveKind: SentenceMoveKind.unchanged,
    );
  }

  SentenceAlignmentResult _commitTransition({
    required int prev,
    required int next,
    required double score,
    required SentenceMoveKind kind,
    required DateTime now,
  }) {
    _confirmedSentenceIndex = next;
    _lastTransitionAt = now;
    _clearPendingForward();
    _pendingBackwardIndex = null;
    _pendingBackwardFinals = 0;
    return SentenceAlignmentResult(
      previousSentenceIndex: prev,
      confirmedSentenceIndex: next,
      candidateSentenceIndex: next,
      score: score,
      moveKind: kind,
    );
  }

  void _clearPendingForward() {
    _pendingCandidateIndex = null;
    _pendingCandidateHits = 0;
  }

  bool _passesForwardThreshold({
    required _SentenceEval eval,
    required int delta,
    required double curScore,
    required bool isFinal,
  }) {
    final sent = sentences[eval.sentenceIndex];
    final isShortSentence = sent.wordCount <= 3;

    if (delta == 1) {
      final minScore = isFinal ? 0.48 : 0.54;
      final minWords = isShortSentence && isFinal ? 2 : (isFinal ? 2 : 3);
      final minContent = isShortSentence ? 1 : (isFinal ? 1 : 2);
      return eval.score >= minScore &&
          eval.matchedWords >= minWords &&
          eval.matchedContentWords >= minContent;
    }

    if (delta <= 4) {
      final minScore = isFinal ? 0.62 : 0.68;
      return eval.score >= minScore &&
          eval.matchedWords >= 3 &&
          eval.matchedContentWords >= 2 &&
          eval.score >= curScore + 0.16;
    }

    // Wide skip (5..10 sentences ahead): requires strong multi-word evidence.
    return eval.score >= 0.74 &&
        eval.matchedWords >= 4 &&
        eval.matchedContentWords >= 3 &&
        eval.score >= curScore + 0.24;
  }

  /// Slight proximity preference for natural sequential reading (`+1`) over
  /// distant coincidences with similar scores.
  double _rankForwardCandidate(_SentenceEval eval, int delta) {
    final distancePenalty = (delta - 1) * 0.045;
    return eval.score - distancePenalty;
  }

  _SentenceEval _bestScoreForSentence(
    ScriptSentence sentence,
    List<List<_MatchToken>> hypotheses,
  ) {
    var best = _SentenceEval.empty(sentence.index);

    for (final hyp in hypotheses) {
      // 1. Evaluate recent full slice (up to last 18 words)
      final fullSlice =
          hyp.length > 18 ? hyp.sublist(hyp.length - 18) : hyp;
      final fullEval = _scoreFragmentAgainstSentence(sentence, fullSlice);

      // 2. Evaluate trailing clause slice (last 7 words) so continuous speech
      //    rolling smoothly into the next sentence registers cleanly.
      var tailScore = fullEval.score;
      _SentenceEval chosen = fullEval;

      if (hyp.length > 7) {
        final tailSlice = hyp.sublist(hyp.length - 7);
        final tailEval = _scoreFragmentAgainstSentence(sentence, tailSlice);
        tailScore = tailEval.score;
        if (tailEval.score > chosen.score && tailEval.matchedWords >= 2) {
          chosen = tailEval;
        }
      }

      final combined = _SentenceEval(
        sentenceIndex: sentence.index,
        score: chosen.score,
        tailScore: tailScore,
        matchedWords: chosen.matchedWords,
        matchedContentWords: chosen.matchedContentWords,
      );

      if (combined.score > best.score) {
        best = combined;
      }
    }

    return best;
  }

  /// Order-aware, content-weighted fragment-to-sentence similarity.
  ///
  /// Works naturally for both complete sentences and partial sentence fragments
  /// while rejecting out-of-order bag-of-words coincidences.
  _SentenceEval _scoreFragmentAgainstSentence(
    ScriptSentence sentence,
    List<_MatchToken> query,
  ) {
    final sTokens = sentence._tokens;
    if (sTokens.isEmpty || query.isEmpty) {
      return _SentenceEval.empty(sentence.index);
    }

    // Try starting alignment from any reasonable anchor in query (handles
    // utterances that start with trailing words of the previous sentence).
    var bestScore = 0.0;
    var bestMatchedWords = 0;
    var bestMatchedContent = 0;

    final maxAnchorStart = math.max(0, query.length - 2);
    for (var startQ = 0; startQ <= maxAnchorStart; startQ++) {
      final subQuery = startQ == 0 ? query : query.sublist(startQ);
      if (subQuery.length < 2 && sTokens.length > 2) break;

      var sCursor = 0;
      var matchedWeight = 0.0;
      var totalQueryWeight = 0.0;
      var matchedWords = 0;
      var matchedContent = 0;
      var consecutivePairs = 0;
      int? lastMatchedSentencePos;

      for (final qTok in subQuery) {
        totalQueryWeight += qTok.weight;
      }
      if (totalQueryWeight <= 0) continue;

      for (final qTok in subQuery) {
        // Search monotonically forward from sCursor (allowing skipped words).
        var bestSim = 0.0;
        var bestPos = -1;
        final searchEnd = math.min(sTokens.length, sCursor + 8);

        for (var j = sCursor; j < searchEnd; j++) {
          final sim = _tokenSimilarity(qTok, sTokens[j]);
          if (sim > bestSim) {
            bestSim = sim;
            bestPos = j;
            if (sim >= 0.99) break;
          }
        }

        // Fallback: if first match hasn't anchored yet, scan the full sentence
        // (supports jumping in mid-sentence or fragment matching).
        if (bestPos == -1 && lastMatchedSentencePos == null) {
          for (var j = searchEnd; j < sTokens.length; j++) {
            final sim = _tokenSimilarity(qTok, sTokens[j]);
            if (sim > bestSim) {
              bestSim = sim;
              bestPos = j;
              if (sim >= 0.99) break;
            }
          }
        }

        if (bestPos != -1 && bestSim >= 0.74) {
          matchedWeight += qTok.weight * bestSim;
          matchedWords++;
          if (!qTok.isStopWord) {
            matchedContent++;
          }
          if (lastMatchedSentencePos != null &&
              bestPos > lastMatchedSentencePos &&
              (bestPos - lastMatchedSentencePos) <= 2) {
            consecutivePairs++;
          }
          lastMatchedSentencePos = bestPos;
          sCursor = bestPos + 1;
        }
      }

      if (matchedWords == 0) continue;

      var totalSentenceWeight = 0.0;
      for (final sTok in sTokens) {
        totalSentenceWeight += sTok.weight;
      }

      final precision = (matchedWeight / totalQueryWeight).clamp(0.0, 1.0);
      final recall =
          totalSentenceWeight > 0
              ? (matchedWeight / totalSentenceWeight).clamp(0.0, 1.0)
              : 0.0;
      final possiblePairs = math.max(1, matchedWords - 1);
      final orderBigramRatio =
          matchedWords >= 2
              ? (consecutivePairs / possiblePairs).clamp(0.0, 1.0)
              : 0.0;

      // Penalize very tiny suffix sub-queries slightly unless they match cleanly.
      final lengthFactor =
          subQuery.length >= 3 ? 1.0 : (sTokens.length <= 3 ? 0.98 : 0.90);
      final rawScore =
          (0.56 * precision + 0.24 * recall + 0.20 * orderBigramRatio) *
          lengthFactor;

      if (rawScore > bestScore) {
        bestScore = rawScore;
        bestMatchedWords = matchedWords;
        bestMatchedContent = matchedContent;
      }

      // Only scan up to first 6 anchor offsets to keep O(1) microsecond cost.
      if (startQ >= 5) break;
    }

    return _SentenceEval(
      sentenceIndex: sentence.index,
      score: bestScore.clamp(0.0, 1.0),
      tailScore: bestScore.clamp(0.0, 1.0),
      matchedWords: bestMatchedWords,
      matchedContentWords: bestMatchedContent,
    );
  }

  /// Splits a single non-empty line into natural sentence / reading blocks.
  static List<_CharRange> _splitLineIntoSentenceBlocks(String line) {
    final trimmedStart = line.length - line.trimLeft().length;
    final trimmedEnd = line.trimRight().length;
    if (trimmedStart >= trimmedEnd) return const [];

    final ranges = <_CharRange>[];
    var blockStart = trimmedStart;

    for (var i = trimmedStart; i < trimmedEnd; i++) {
      final ch = line[i];
      final isSentenceEnd =
          ch == '.' || ch == '!' || ch == '?' || ch == '।' || ch == '॥';
      if (!isSentenceEnd) continue;

      // Keep decimal numbers (e.g. "1.5") intact.
      if (ch == '.' &&
          i > trimmedStart &&
          i + 1 < trimmedEnd &&
          _isAsciiDigit(line.codeUnitAt(i - 1)) &&
          _isAsciiDigit(line.codeUnitAt(i + 1))) {
        continue;
      }

      // Advance past repeated punctuation ("...", "?!", closing quotes/brackets).
      var end = i + 1;
      while (end < trimmedEnd &&
          '.,!?"\'\u2019\u201D)]।॥'.contains(line[end])) {
        end++;
      }

      // Keep common abbreviations ("Mr.", "Dr.", "e.g.") inside the sentence.
      if (ch == '.' && end == i + 1) {
        final preceding = line.substring(blockStart, i);
        final lastWord =
            preceding
                .split(RegExp(r'\s+'))
                .last
                .replaceAll(RegExp(r'[^A-Za-z]'), '')
                .toLowerCase();
        if (_abbreviations.contains(lastWord)) {
          continue;
        }
      }

      // Must be followed by end-of-line or whitespace to close a sentence.
      if (end < trimmedEnd && line[end].trim().isNotEmpty) {
        continue;
      }

      _addTrimmedOrSplitClause(line, blockStart, end, ranges);

      var nextStart = end;
      while (nextStart < trimmedEnd && line[nextStart].trim().isEmpty) {
        nextStart++;
      }
      blockStart = nextStart;
      i = nextStart - 1;
    }

    if (blockStart < trimmedEnd) {
      _addTrimmedOrSplitClause(line, blockStart, trimmedEnd, ranges);
    }

    return ranges;
  }

  /// Splits unusually long unpunctuated blocks (> 24 words) on natural clause
  /// boundaries so the teleprompter can keep each active clause centered.
  static void _addTrimmedOrSplitClause(
    String line,
    int start,
    int end,
    List<_CharRange> out,
  ) {
    while (start < end && line[start].trim().isEmpty) {
      start++;
    }
    while (end > start && line[end - 1].trim().isEmpty) {
      end--;
    }
    if (start >= end) return;

    final slice = line.substring(start, end);
    final wordMatches = _wordTokenRegex.allMatches(slice).toList();
    if (wordMatches.length <= 24) {
      out.add(_CharRange(start, end));
      return;
    }

    // Find a clause delimiter (;, :, —, ,) closest to the middle of the block.
    final midChar = slice.length ~/ 2;
    int? bestSplit;
    var bestDist = slice.length;
    for (var i = 0; i < slice.length - 1; i++) {
      final ch = slice[i];
      if ((ch == ';' || ch == ':' || ch == ',' || ch == '—' || ch == '–') &&
          slice[i + 1].trim().isEmpty) {
        final dist = (i - midChar).abs();
        if (dist < bestDist && i > slice.length * 0.25 && i < slice.length * 0.75) {
          bestDist = dist;
          bestSplit = i + 1;
        }
      }
    }

    final splitOffset =
        bestSplit ?? wordMatches[wordMatches.length ~/ 2].start;
    _addTrimmedOrSplitClause(line, start, start + splitOffset, out);
    _addTrimmedOrSplitClause(line, start + splitOffset, end, out);
  }

  static bool _isAsciiDigit(int cu) => cu >= 0x30 && cu <= 0x39;

  /// Normalizes English, Devanagari Hindi, or Romanized Hinglish text into
  /// phonetic Latin tokens.
  static String normalizeWord(String raw) {
    var text = raw.toLowerCase().replaceAll("'", '').replaceAll('\u2019', '');
    if (DevanagariTransliterator.containsDevanagari(text)) {
      text = DevanagariTransliterator.toLatin(text);
    }
    return text.replaceAll(_stripNonWordRegex, '');
  }

  /// Collapses common English / Hindi / Hinglish phonetic variants so minor
  /// accent or transliteration differences still score cleanly.
  static String phoneticFold(String normalized) {
    if (normalized.isEmpty) return '';
    var s = normalized
        .replaceAll('ph', 'f')
        .replaceAll('bh', 'b')
        .replaceAll('dh', 'd')
        .replaceAll('gh', 'g')
        .replaceAll('kh', 'k')
        .replaceAll('th', 't')
        .replaceAll('chh', 'ch')
        .replaceAll('sh', 's')
        .replaceAll('aa', 'a')
        .replaceAll('ee', 'i')
        .replaceAll('oo', 'u')
        .replaceAll('v', 'w')
        .replaceAll('z', 'j')
        .replaceAll('q', 'k');

    final sb = StringBuffer();
    String? prev;
    for (var i = 0; i < s.length; i++) {
      final ch = s[i];
      if (ch != prev) {
        sb.write(ch);
        prev = ch;
      }
    }
    return sb.toString();
  }

  static List<_MatchToken> _tokenizeText(String text) {
    final tokens = <_MatchToken>[];
    for (final match in _wordTokenRegex.allMatches(text)) {
      final norm = normalizeWord(match.group(0) ?? '');
      if (norm.isEmpty) continue;
      tokens.add(
        _MatchToken(
          normalized: norm,
          phonetic: phoneticFold(norm),
          isStopWord: _stopWords.contains(norm) || norm.length <= 2,
        ),
      );
    }
    return tokens;
  }

  static double _tokenSimilarity(_MatchToken spoken, _MatchToken script) {
    final a = spoken.normalized;
    final b = script.normalized;
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

    if (spoken.phonetic.isNotEmpty && spoken.phonetic == script.phonetic) {
      return 0.93;
    }

    // Prefix tolerance for longer words (e.g., partial suffix or pluralization)
    final minLen = math.min(a.length, b.length);
    final maxLen = math.max(a.length, b.length);
    if (minLen >= 4 &&
        (b.startsWith(a) || a.startsWith(b)) &&
        minLen / maxLen >= 0.70) {
      return 0.86;
    }

    if (maxLen <= 2) return 0.0;
    if ((a.length - b.length).abs() > 3) return 0.0;

    final distRaw = _levenshtein(a, b);
    final simRaw = 1.0 - (distRaw / maxLen);

    final maxPhon = math.max(spoken.phonetic.length, script.phonetic.length);
    final simPhon =
        maxPhon >= 3
            ? 1.0 - (_levenshtein(spoken.phonetic, script.phonetic) / maxPhon)
            : 0.0;

    final best = math.max(simRaw, simPhon * 0.95);
    return best >= 0.74 ? best : 0.0;
  }

  static int _levenshtein(String a, String b) {
    final m = a.length;
    final n = b.length;
    if (m == 0) return n;
    if (n == 0) return m;

    var prev = List<int>.generate(n + 1, (i) => i);
    var curr = List<int>.filled(n + 1, 0);

    for (var i = 1; i <= m; i++) {
      curr[0] = i;
      final ca = a.codeUnitAt(i - 1);
      for (var j = 1; j <= n; j++) {
        final cost = ca == b.codeUnitAt(j - 1) ? 0 : 1;
        final deletion = prev[j] + 1;
        final insertion = curr[j - 1] + 1;
        final substitution = prev[j - 1] + cost;
        curr[j] = math.min(math.min(deletion, insertion), substitution);
      }
      final tmp = prev;
      prev = curr;
      curr = tmp;
    }
    return prev[n];
  }

  static List<_MarkdownSegment> _splitMarkdownBold(String line) {
    final segments = <_MarkdownSegment>[];
    final parts = line.split('**');
    for (var i = 0; i < parts.length; i++) {
      if (parts[i].isEmpty) continue;
      segments.add(_MarkdownSegment(text: parts[i], isBold: i.isOdd));
    }
    if (segments.isEmpty && line.isNotEmpty) {
      segments.add(_MarkdownSegment(text: line, isBold: false));
    }
    return segments;
  }
}

class _MarkdownSegment {
  final String text;
  final bool isBold;
  const _MarkdownSegment({required this.text, required this.isBold});
}

class _CharRange {
  final int start;
  final int end;
  const _CharRange(this.start, this.end);
}

class _BoldSpan {
  final int start;
  final int end;
  const _BoldSpan(this.start, this.end);
}

class _SentenceSpan {
  final int start;
  final int end;
  final int lineStart;
  final String rawText;
  final List<_MatchToken> tokens;

  const _SentenceSpan({
    required this.start,
    required this.end,
    required this.lineStart,
    required this.rawText,
    required this.tokens,
  });
}

class _SentenceEval {
  final int sentenceIndex;
  final double score;
  final double tailScore;
  final int matchedWords;
  final int matchedContentWords;

  const _SentenceEval({
    required this.sentenceIndex,
    required this.score,
    required this.tailScore,
    required this.matchedWords,
    required this.matchedContentWords,
  });

  factory _SentenceEval.empty(int index) => _SentenceEval(
    sentenceIndex: index,
    score: 0.0,
    tailScore: 0.0,
    matchedWords: 0,
    matchedContentWords: 0,
  );
}
