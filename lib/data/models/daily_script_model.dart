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
    if (scriptType == 'segmented') {
      try {
        if (scriptData['segments'] != null) {
          // Standard segments array format
          segments =
              (scriptData['segments'] as List)
                  .map(
                    (s) =>
                        ScriptSegmentModel.fromJson(s as Map<String, dynamic>),
                  )
                  .toList();
        } else if (scriptData['part1'] != null) {
          // OpenAI format: part1, part2, part3 as separate fields
          final segmentsList = <ScriptSegment>[];
          final focus =
              scriptData['focus']?.toString() ?? 'Building confidence';

          if (scriptData['part1'] != null) {
            segmentsList.add(
              ScriptSegmentModel(
                part: 1,
                text: scriptData['part1'].toString(),
                focus: focus,
              ),
            );
          }
          if (scriptData['part2'] != null) {
            segmentsList.add(
              ScriptSegmentModel(
                part: 2,
                text: scriptData['part2'].toString(),
                focus: focus,
              ),
            );
          }
          if (scriptData['part3'] != null) {
            segmentsList.add(
              ScriptSegmentModel(
                part: 3,
                text: scriptData['part3'].toString(),
                focus: focus,
              ),
            );
          }

          if (segmentsList.isNotEmpty) {
            segments = segmentsList;
          }
        }
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

    // Build fullScript - try 'script' field first, then combine parts
    String? fullScript = scriptData['script']?.toString();
    if (fullScript == null || fullScript.isEmpty) {
      // Fallback: combine part1, part2, part3 for full scripts
      final parts = <String>[];
      if (scriptData['part1'] != null)
        parts.add(scriptData['part1'].toString());
      if (scriptData['part2'] != null)
        parts.add(scriptData['part2'].toString());
      if (scriptData['part3'] != null)
        parts.add(scriptData['part3'].toString());
      if (parts.isNotEmpty) {
        fullScript = parts.join(' ');
      }
    }

    return DailyScriptModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      dayNumber: dayNumber,
      scriptType: scriptType,
      title: scriptData['title']?.toString() ?? 'Day $dayNumber',
      fullScript: fullScript,
      segments: segments,
      wordCount: wordCount,
      estimatedDuration:
          (scriptData['estimatedDuration'] ??
                  scriptData['estimated_duration'] ??
                  scriptData['duration'])
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
