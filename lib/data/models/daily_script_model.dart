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
    } else if (scriptJson is Map<String, dynamic>) {
      scriptData = scriptJson;
    } else {
      scriptData = <String, dynamic>{};
    }

    final scriptType = json['script_type']?.toString() ?? 'full';

    // Robust day_number parsing
    int dayNumber = 1;
    final rawDayNumber = json['day_number'];
    if (rawDayNumber is int) {
      dayNumber = rawDayNumber;
    } else if (rawDayNumber is num) {
      dayNumber = rawDayNumber.toInt();
    } else if (rawDayNumber is String) {
      dayNumber = int.tryParse(rawDayNumber) ?? 1;
    }

    List<ScriptSegment>? segments;
    if (scriptType == 'segmented' && scriptData['segments'] != null) {
      try {
        segments =
            (scriptData['segments'] as List)
                .map(
                  (s) => ScriptSegmentModel.fromJson(s as Map<String, dynamic>),
                )
                .toList();
      } catch (e) {
        // Fallback if segments parsing fails
        segments = null;
      }
    }

    // Robust word_count parsing
    int? wordCount;
    final rawWordCount = scriptData['wordCount'] ?? scriptData['word_count'];
    if (rawWordCount is int) {
      wordCount = rawWordCount;
    } else if (rawWordCount is num) {
      wordCount = rawWordCount.toInt();
    } else if (rawWordCount is String) {
      wordCount = int.tryParse(rawWordCount);
    }

    return DailyScriptModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      dayNumber: dayNumber,
      scriptType: scriptType,
      title: scriptData['title']?.toString() ?? 'Day $dayNumber',
      fullScript: scriptData['script']?.toString(),
      segments: segments,
      wordCount: wordCount,
      estimatedDuration:
          (scriptData['estimatedDuration'] ?? scriptData['estimated_duration'])
              ?.toString(),
      createdAt:
          json['created_at'] != null
              ? DateTime.parse(json['created_at'] as String)
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    final scriptData = <String, dynamic>{'title': title};

    if (isSegmented && segments != null) {
      scriptData['segments'] =
          segments!.map((s) => (s as ScriptSegmentModel).toJson()).toList();
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
