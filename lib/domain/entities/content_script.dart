import 'package:equatable/equatable.dart';

/// Represents a user-created content script for the Content Creator module.
/// This is completely standalone from the daily challenge scripts.
class ContentScript extends Equatable {
  final String id;
  final String userId;
  final String title;

  /// 3-part script format matching OpenAI generation
  final String part1; // Hook/Opening
  final String part2; // Content/Body
  final String part3; // Close/Ending

  /// Reference to the prompt template used for generation
  final String? promptTemplate;

  /// Questionnaire answers used for generation
  final Map<String, dynamic>? questionnaire;

  final DateTime createdAt;
  final DateTime updatedAt;

  /// Whether this script has been recorded as a video
  final bool isRecorded;

  const ContentScript({
    required this.id,
    required this.userId,
    required this.title,
    required this.part1,
    required this.part2,
    required this.part3,
    this.promptTemplate,
    this.questionnaire,
    required this.createdAt,
    required this.updatedAt,
    this.isRecorded = false,
  });

  /// Get the full combined script text
  String get fullScript {
    return '$part1\n\n$part2\n\n$part3'.trim();
  }

  /// Get script parts as a list for teleprompter display
  List<String> get scriptParts {
    return [part1, part2, part3].where((part) => part.isNotEmpty).toList();
  }

  /// Create a copy with updated fields
  ContentScript copyWith({
    String? id,
    String? userId,
    String? title,
    String? part1,
    String? part2,
    String? part3,
    String? promptTemplate,
    Map<String, dynamic>? questionnaire,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isRecorded,
  }) {
    return ContentScript(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      part1: part1 ?? this.part1,
      part2: part2 ?? this.part2,
      part3: part3 ?? this.part3,
      promptTemplate: promptTemplate ?? this.promptTemplate,
      questionnaire: questionnaire ?? this.questionnaire,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isRecorded: isRecorded ?? this.isRecorded,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'part1': part1,
      'part2': part2,
      'part3': part3,
      'promptTemplate': promptTemplate,
      'questionnaire': questionnaire,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isRecorded': isRecorded,
    };
  }

  /// Create from JSON
  factory ContentScript.fromJson(Map<String, dynamic> json) {
    return ContentScript(
      id: json['id'] as String,
      userId: json['userId'] as String,
      title: json['title'] as String,
      part1: json['part1'] as String? ?? '',
      part2: json['part2'] as String? ?? '',
      part3: json['part3'] as String? ?? '',
      promptTemplate: json['promptTemplate'] as String?,
      questionnaire: json['questionnaire'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      isRecorded: json['isRecorded'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    title,
    part1,
    part2,
    part3,
    promptTemplate,
    questionnaire,
    createdAt,
    updatedAt,
    isRecorded,
  ];
}

/// Pre-defined prompt templates for script generation.
enum PromptTemplate {
  educational('Educational', 'Teach something valuable to your audience'),
  story('Story', 'Share a personal experience or journey'),
  tips('Tips & Tricks', 'Quick actionable advice for viewers'),
  productReview('Product Review', 'Honest opinion and review format'),
  dayInLife('Day in Life', 'Behind-the-scenes content'),
  custom('Custom', 'Write your own custom prompt');

  final String displayName;
  final String description;

  const PromptTemplate(this.displayName, this.description);
}
