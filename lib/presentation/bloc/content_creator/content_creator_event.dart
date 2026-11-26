import 'package:equatable/equatable.dart';

import '../../../domain/entities/content_script.dart';

/// Events for ContentCreatorBloc
abstract class ContentCreatorEvent extends Equatable {
  const ContentCreatorEvent();

  @override
  List<Object?> get props => [];
}

/// Load all scripts for a user
class LoadScripts extends ContentCreatorEvent {
  final String userId;

  const LoadScripts(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Generate a new script from questionnaire and template
class GenerateScript extends ContentCreatorEvent {
  final String userId;
  final String topic;
  final String audience;
  final String message;
  final String tone;
  final String language;
  final String? languageCode;
  final PromptTemplate template;
  final String length;
  final String platform;
  final String scriptStyle;
  final String ctaStyle;
  final String? customPrompt;

  const GenerateScript({
    required this.userId,
    required this.topic,
    required this.audience,
    required this.message,
    required this.tone,
    required this.language,
    this.languageCode,
    required this.template,
    this.length = 'medium',
    this.platform = 'reels_shorts',
    this.scriptStyle = 'spoken_natural',
    this.ctaStyle = 'auto',
    this.customPrompt,
  });

  @override
  List<Object?> get props => [
    userId,
    topic,
    audience,
    message,
    tone,
    language,
    languageCode,
    template,
    length,
    platform,
    scriptStyle,
    ctaStyle,
    customPrompt,
  ];
}

/// Refine an existing script with a quick action or custom instruction
class RefineScript extends ContentCreatorEvent {
  final ContentScript script;
  final String instruction;

  const RefineScript({required this.script, required this.instruction});

  @override
  List<Object?> get props => [script, instruction];
}

/// Analyze a raw Speech-to-Text spoken idea with AI to produce a structured
/// content brief, optionally chaining directly into full script generation.
class EnhanceSpokenIdea extends ContentCreatorEvent {
  final String userId;
  final String transcript;
  final String language;
  final String? languageCode;
  final String scriptStyle;
  final String? toneHint;
  final String? lengthHint;
  final String? platformHint;
  final bool autoGenerate;

  const EnhanceSpokenIdea({
    required this.userId,
    required this.transcript,
    required this.language,
    this.languageCode,
    this.scriptStyle = 'spoken_natural',
    this.toneHint,
    this.lengthHint,
    this.platformHint,
    this.autoGenerate = true,
  });

  @override
  List<Object?> get props => [
    userId,
    transcript,
    language,
    languageCode,
    scriptStyle,
    toneHint,
    lengthHint,
    platformHint,
    autoGenerate,
  ];
}

/// Save a script to the library
class SaveScript extends ContentCreatorEvent {
  final ContentScript script;

  const SaveScript(this.script);

  @override
  List<Object?> get props => [script];
}

/// Update an existing script
class UpdateScript extends ContentCreatorEvent {
  final ContentScript script;

  const UpdateScript(this.script);

  @override
  List<Object?> get props => [script];
}

/// Delete a script from the library
class DeleteScript extends ContentCreatorEvent {
  final String scriptId;

  const DeleteScript(this.scriptId);

  @override
  List<Object?> get props => [scriptId];
}

/// Select a script for recording
class SelectScript extends ContentCreatorEvent {
  final ContentScript? script;

  const SelectScript(this.script);

  @override
  List<Object?> get props => [script];
}

/// Mark a script as recorded
class MarkScriptRecorded extends ContentCreatorEvent {
  final String scriptId;

  const MarkScriptRecorded(this.scriptId);

  @override
  List<Object?> get props => [scriptId];
}

/// Load videos for content creator
class LoadContentVideos extends ContentCreatorEvent {
  final String userId;

  const LoadContentVideos(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Clear any error state
class ClearError extends ContentCreatorEvent {}

/// Reset to initial state
class ResetContentCreator extends ContentCreatorEvent {}
