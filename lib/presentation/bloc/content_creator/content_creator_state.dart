import 'package:equatable/equatable.dart';

import '../../../domain/entities/content_script.dart';
import '../../../services/video_storage_service.dart';

/// States for ContentCreatorBloc
abstract class ContentCreatorState extends Equatable {
  const ContentCreatorState();

  @override
  List<Object?> get props => [];
}

/// Initial state before any data is loaded
class ContentCreatorInitial extends ContentCreatorState {}

/// Loading scripts or videos
class ContentCreatorLoading extends ContentCreatorState {}

/// Scripts and videos loaded successfully
class ContentCreatorLoaded extends ContentCreatorState {
  final List<ContentScript> scripts;
  final List<VideoInfo> videos;
  final ContentScript? selectedScript;
  final PromptTemplate? selectedTemplate;

  const ContentCreatorLoaded({
    required this.scripts,
    required this.videos,
    this.selectedScript,
    this.selectedTemplate,
  });

  ContentCreatorLoaded copyWith({
    List<ContentScript>? scripts,
    List<VideoInfo>? videos,
    ContentScript? selectedScript,
    PromptTemplate? selectedTemplate,
    bool clearSelectedScript = false,
  }) {
    return ContentCreatorLoaded(
      scripts: scripts ?? this.scripts,
      videos: videos ?? this.videos,
      selectedScript:
          clearSelectedScript ? null : selectedScript ?? this.selectedScript,
      selectedTemplate: selectedTemplate ?? this.selectedTemplate,
    );
  }

  @override
  List<Object?> get props => [
    scripts,
    videos,
    selectedScript,
    selectedTemplate,
  ];
}

/// Generating a script using AI
class ScriptGenerating extends ContentCreatorState {
  final PromptTemplate template;

  const ScriptGenerating(this.template);

  @override
  List<Object?> get props => [template];
}

/// Script generated successfully
class ScriptGenerated extends ContentCreatorState {
  final ContentScript script;

  const ScriptGenerated(this.script);

  @override
  List<Object?> get props => [script];
}

/// Error state
class ContentCreatorError extends ContentCreatorState {
  final String message;

  const ContentCreatorError(this.message);

  @override
  List<Object?> get props => [message];
}
