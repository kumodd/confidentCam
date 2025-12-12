import '../../domain/entities/daily_completion.dart';

/// Data model for DailyCompletion entity with JSON serialization.
class DailyCompletionModel extends DailyCompletion {
  const DailyCompletionModel({
    required super.id,
    required super.userId,
    required super.dayNumber,
    required super.videoFilename,
    super.durationSeconds,
    required super.checklistResponses,
    required super.completedAt,
  });

  factory DailyCompletionModel.fromJson(Map<String, dynamic> json) {
    List<String> checklist = [];
    if (json['checklist_responses'] != null) {
      if (json['checklist_responses'] is List) {
        checklist = (json['checklist_responses'] as List).cast<String>();
      }
    }

    return DailyCompletionModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dayNumber: json['day_number'] as int,
      videoFilename: json['video_filename'] as String,
      durationSeconds: json['duration_seconds'] as int?,
      checklistResponses: checklist,
      completedAt: DateTime.parse(json['completed_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'day_number': dayNumber,
      'video_filename': videoFilename,
      'duration_seconds': durationSeconds,
      'checklist_responses': checklistResponses,
      'completed_at': completedAt.toIso8601String(),
    };
  }

  factory DailyCompletionModel.fromEntity(DailyCompletion completion) {
    return DailyCompletionModel(
      id: completion.id,
      userId: completion.userId,
      dayNumber: completion.dayNumber,
      videoFilename: completion.videoFilename,
      durationSeconds: completion.durationSeconds,
      checklistResponses: completion.checklistResponses,
      completedAt: completion.completedAt,
    );
  }
}
