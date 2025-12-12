import 'dart:convert';

import '../../domain/entities/daily_script.dart';

/// Data model for ScriptSegment with JSON serialization.
class ScriptSegmentModel extends ScriptSegment {
  const ScriptSegmentModel({
    required super.part,
    required super.text,
    required super.focus,
  });

  factory ScriptSegmentModel.fromJson(Map<String, dynamic> json) {
    return ScriptSegmentModel(
      part: json['part'] as int,
      text: json['text'] as String,
      focus: json['focus'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {'part': part, 'text': text, 'focus': focus};
  }
}

/// Data model for DailyScript entity with JSON serialization.
class DailyScriptModel extends DailyScript {
  const DailyScriptModel({
    required super.id,
    required super.userId,
    required super.dayNumber,
    required super.scriptType,
    required super.title,
    super.fullScript,
    super.segments,
    super.wordCount,
    super.estimatedDuration,
    required super.createdAt,
  });

  factory DailyScriptModel.fromJson(Map<String, dynamic> json) {
    final scriptJson = json['script_json'];
    Map<String, dynamic> scriptData;

    if (scriptJson is String) {
      scriptData = jsonDecode(scriptJson) as Map<String, dynamic>;
    } else {
      scriptData = scriptJson as Map<String, dynamic>;
    }

    final scriptType = json['script_type'] as String;

    List<ScriptSegment>? segments;
    if (scriptType == 'segmented' && scriptData['segments'] != null) {
      segments = (scriptData['segments'] as List)
          .map((s) => ScriptSegmentModel.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return DailyScriptModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      dayNumber: json['day_number'] as int,
      scriptType: scriptType,
      title: scriptData['title'] as String? ?? 'Day ${json['day_number']}',
      fullScript: scriptData['script'] as String?,
      segments: segments,
      wordCount: scriptData['word_count'] as int?,
      estimatedDuration: scriptData['estimated_duration'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    final scriptData = <String, dynamic>{'title': title};

    if (isSegmented && segments != null) {
      scriptData['segments'] = segments!
          .map((s) => (s as ScriptSegmentModel).toJson())
          .toList();
    } else {
      scriptData['script'] = fullScript;
      scriptData['word_count'] = wordCount;
      scriptData['estimated_duration'] = estimatedDuration;
    }

    return {
      'id': id,
      'user_id': userId,
      'day_number': dayNumber,
      'script_type': scriptType,
      'script_json': scriptData,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory DailyScriptModel.fromEntity(DailyScript script) {
    return DailyScriptModel(
      id: script.id,
      userId: script.userId,
      dayNumber: script.dayNumber,
      scriptType: script.scriptType,
      title: script.title,
      fullScript: script.fullScript,
      segments: script.segments,
      wordCount: script.wordCount,
      estimatedDuration: script.estimatedDuration,
      createdAt: script.createdAt,
    );
  }
}
