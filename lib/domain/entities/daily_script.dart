import 'package:equatable/equatable.dart';

/// Represents a script segment for days 1-5.
class ScriptSegment extends Equatable {
  final int part;
  final String text;
  final String focus;

  const ScriptSegment({
    required this.part,
    required this.text,
    required this.focus,
  });

  @override
  List<Object?> get props => [part, text, focus];
}

/// Daily script entity for the 30-day challenge.
class DailyScript extends Equatable {
  final String id;
  final String userId;
  final int dayNumber;
  final String scriptType; // 'segmented' or 'full'
  final String title;
  final String? fullScript; // For days 6-30
  final List<ScriptSegment>? segments; // For days 1-5
  final int? wordCount;
  final String? estimatedDuration;
  final DateTime createdAt;

  const DailyScript({
    required this.id,
    required this.userId,
    required this.dayNumber,
    required this.scriptType,
    required this.title,
    this.fullScript,
    this.segments,
    this.wordCount,
    this.estimatedDuration,
    required this.createdAt,
  });

  /// Check if this is a segmented script (days 1-5)
  bool get isSegmented => scriptType == 'segmented';

  /// Get the full text content (either full script or combined segments)
  String get fullText {
    if (isSegmented && segments != null) {
      return segments!.map((s) => s.text).join(' ');
    }
    return fullScript ?? '';
  }

  /// Get segment count for segmented scripts
  int get segmentCount => segments?.length ?? 0;

  @override
  List<Object?> get props => [
    id,
    userId,
    dayNumber,
    scriptType,
    title,
    fullScript,
    segments,
    wordCount,
    estimatedDuration,
    createdAt,
  ];
}
