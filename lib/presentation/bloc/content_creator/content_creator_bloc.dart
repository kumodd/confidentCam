import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/content_script.dart';
import '../../../domain/repositories/content_creator_repository.dart';
import '../../../services/video_storage_service.dart';
import 'content_creator_event.dart';
import 'content_creator_state.dart';

/// BLoC for managing Content Creator state.
/// Handles script generation, management, and video listing.
class ContentCreatorBloc
    extends Bloc<ContentCreatorEvent, ContentCreatorState> {
  final ContentCreatorRepository repository;
  final VideoStorageService videoStorageService;

  String? _currentUserId;

  ContentCreatorBloc({
    required this.repository,
    required this.videoStorageService,
  }) : super(ContentCreatorInitial()) {
    on<LoadScripts>(_onLoadScripts);
    on<GenerateScript>(_onGenerateScript);
    on<SaveScript>(_onSaveScript);
    on<UpdateScript>(_onUpdateScript);
    on<DeleteScript>(_onDeleteScript);
    on<SelectScript>(_onSelectScript);
    on<MarkScriptRecorded>(_onMarkScriptRecorded);
    on<LoadContentVideos>(_onLoadContentVideos);
    on<ClearError>(_onClearError);
    on<ResetContentCreator>(_onReset);
  }

  Future<void> _onLoadScripts(
    LoadScripts event,
    Emitter<ContentCreatorState> emit,
  ) async {
    _currentUserId = event.userId;
    emit(ContentCreatorLoading());

    final scriptsResult = await repository.getScripts(event.userId);
    final videos = await _loadContentVideos();

    scriptsResult.fold(
      (failure) => emit(ContentCreatorError(failure.message)),
      (scripts) => emit(ContentCreatorLoaded(scripts: scripts, videos: videos)),
    );
  }

  Future<void> _onGenerateScript(
    GenerateScript event,
    Emitter<ContentCreatorState> emit,
  ) async {
    _currentUserId = event.userId;
    emit(ScriptGenerating(event.template));

    final result = await repository.generateScript(
      userId: event.userId,
      topic: event.topic,
      audience: event.audience,
      message: event.message,
      tone: event.tone,
      language: event.language,
      template: event.template,
      customPrompt: event.customPrompt,
    );

    await result.fold(
      (failure) async => emit(ContentCreatorError(failure.message)),
      (script) async {
        // First emit the generated script for the dialog
        emit(ScriptGenerated(script));
        
        // Then reload all scripts so the list is updated
        final scriptsResult = await repository.getScripts(event.userId);
        final videos = await _loadContentVideos();
        
        scriptsResult.fold(
          (failure) => emit(ContentCreatorError(failure.message)),
          (scripts) => emit(ContentCreatorLoaded(scripts: scripts, videos: videos)),
        );
      },
    );
  }

  Future<void> _onSaveScript(
    SaveScript event,
    Emitter<ContentCreatorState> emit,
  ) async {
    final currentState = state;

    final result = await repository.saveScript(event.script);

    result.fold((failure) => emit(ContentCreatorError(failure.message)), (
      savedScript,
    ) async {
      // Reload scripts after save
      if (_currentUserId != null) {
        add(LoadScripts(_currentUserId!));
      } else if (currentState is ContentCreatorLoaded) {
        final updatedScripts = List<ContentScript>.from(currentState.scripts);
        final existingIndex = updatedScripts.indexWhere(
          (s) => s.id == savedScript.id,
        );
        if (existingIndex >= 0) {
          updatedScripts[existingIndex] = savedScript;
        } else {
          updatedScripts.insert(0, savedScript);
        }
        emit(currentState.copyWith(scripts: updatedScripts));
      }
    });
  }

  Future<void> _onUpdateScript(
    UpdateScript event,
    Emitter<ContentCreatorState> emit,
  ) async {
    final result = await repository.saveScript(event.script);

    result.fold((failure) => emit(ContentCreatorError(failure.message)), (
      updatedScript,
    ) {
      final currentState = state;
      if (currentState is ContentCreatorLoaded) {
        final updatedScripts =
            currentState.scripts.map((s) {
              return s.id == updatedScript.id ? updatedScript : s;
            }).toList();
        emit(currentState.copyWith(scripts: updatedScripts));
      }
    });
  }

  Future<void> _onDeleteScript(
    DeleteScript event,
    Emitter<ContentCreatorState> emit,
  ) async {
    final currentState = state;

    final result = await repository.deleteScript(event.scriptId);

    result.fold((failure) => emit(ContentCreatorError(failure.message)), (_) {
      if (currentState is ContentCreatorLoaded) {
        final updatedScripts =
            currentState.scripts.where((s) => s.id != event.scriptId).toList();

        // Clear selected script if it was deleted
        final selectedScript =
            currentState.selectedScript?.id == event.scriptId
                ? null
                : currentState.selectedScript;

        emit(
          currentState.copyWith(
            scripts: updatedScripts,
            selectedScript: selectedScript,
            clearSelectedScript: selectedScript == null,
          ),
        );
      }
    });
  }

  void _onSelectScript(SelectScript event, Emitter<ContentCreatorState> emit) {
    final currentState = state;
    if (currentState is ContentCreatorLoaded) {
      emit(
        currentState.copyWith(
          selectedScript: event.script,
          clearSelectedScript: event.script == null,
        ),
      );
    }
  }

  Future<void> _onMarkScriptRecorded(
    MarkScriptRecorded event,
    Emitter<ContentCreatorState> emit,
  ) async {
    final result = await repository.markAsRecorded(event.scriptId);

    result.fold((failure) => emit(ContentCreatorError(failure.message)), (_) {
      final currentState = state;
      if (currentState is ContentCreatorLoaded) {
        final updatedScripts =
            currentState.scripts.map((s) {
              return s.id == event.scriptId ? s.copyWith(isRecorded: true) : s;
            }).toList();
        emit(currentState.copyWith(scripts: updatedScripts));
      }
    });
  }

  Future<void> _onLoadContentVideos(
    LoadContentVideos event,
    Emitter<ContentCreatorState> emit,
  ) async {
    final currentState = state;
    final videos = await _loadContentVideos();

    if (currentState is ContentCreatorLoaded) {
      emit(currentState.copyWith(videos: videos));
    }
  }

  Future<List<VideoInfo>> _loadContentVideos() async {
    try {
      final allVideos = await videoStorageService.getAllVideos();
      // Filter for content type videos only
      return allVideos.where((v) => v.type == 'content').toList();
    } catch (e) {
      return [];
    }
  }

  void _onClearError(ClearError event, Emitter<ContentCreatorState> emit) {
    if (_currentUserId != null) {
      add(LoadScripts(_currentUserId!));
    } else {
      emit(ContentCreatorInitial());
    }
  }

  void _onReset(ResetContentCreator event, Emitter<ContentCreatorState> emit) {
    _currentUserId = null;
    emit(ContentCreatorInitial());
  }
}
