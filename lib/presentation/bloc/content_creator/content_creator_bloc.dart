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
  ContentCreatorLoaded? _lastLoadedState;

  ContentCreatorBloc({
    required this.repository,
    required this.videoStorageService,
  }) : super(ContentCreatorInitial()) {
    on<LoadScripts>(_onLoadScripts);
    on<GenerateScript>(_onGenerateScript);
    on<RefineScript>(_onRefineScript);
    on<EnhanceSpokenIdea>(_onEnhanceSpokenIdea);
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
      (scripts) {
        final prevSelected = _lastLoadedState?.selectedScript;
        final resolvedSelected =
            prevSelected != null && scripts.any((s) => s.id == prevSelected.id)
                ? scripts.firstWhere((s) => s.id == prevSelected.id)
                : (scripts.isNotEmpty ? scripts.first : null);
        final loaded = ContentCreatorLoaded(
          scripts: scripts,
          videos: videos,
          selectedScript: resolvedSelected,
        );
        _lastLoadedState = loaded;
        emit(loaded);
      },
    );
  }

  Future<void> _onGenerateScript(
    GenerateScript event,
    Emitter<ContentCreatorState> emit,
  ) async {
    _currentUserId = event.userId;
    final previousLoaded = state is ContentCreatorLoaded
        ? state as ContentCreatorLoaded
        : _lastLoadedState;
    emit(ScriptGenerating(event.template));

    final result = await repository.generateScript(
      userId: event.userId,
      topic: event.topic,
      audience: event.audience,
      message: event.message,
      tone: event.tone,
      language: event.language,
      languageCode: event.languageCode,
      template: event.template,
      length: event.length,
      platform: event.platform,
      scriptStyle: event.scriptStyle,
      ctaStyle: event.ctaStyle,
      customPrompt: event.customPrompt,
    );

    await result.fold(
      (failure) async {
        emit(ContentCreatorError(failure.message));
        if (previousLoaded != null) {
          emit(previousLoaded);
        }
      },
      (script) async {
        // First emit the generated script for the preview/refine dialog
        emit(ScriptGenerated(script));

        // Immediately keep loaded state fresh even before remote reload finishes
        if (previousLoaded != null) {
          final optimistic = previousLoaded.copyWith(
            scripts: [
              script,
              ...previousLoaded.scripts.where((s) => s.id != script.id),
            ],
          );
          _lastLoadedState = optimistic;
        }

        // Then reload all scripts so the library stays fresh
        final scriptsResult = await repository.getScripts(event.userId);
        final videos = await _loadContentVideos();

        scriptsResult.fold(
          (failure) {
            if (_lastLoadedState != null) {
              emit(_lastLoadedState!);
            } else {
              emit(ContentCreatorError(failure.message));
            }
          },
          (scripts) {
            final loaded = ContentCreatorLoaded(
              scripts: scripts,
              videos: videos,
              selectedScript: _lastLoadedState?.selectedScript,
            );
            _lastLoadedState = loaded;
            emit(loaded);
          },
        );
      },
    );
  }

  Future<void> _onRefineScript(
    RefineScript event,
    Emitter<ContentCreatorState> emit,
  ) async {
    final previousLoaded = state is ContentCreatorLoaded
        ? state as ContentCreatorLoaded
        : _lastLoadedState;
    emit(
      ScriptRefining(script: event.script, instruction: event.instruction),
    );

    final result = await repository.refineScript(
      script: event.script,
      instruction: event.instruction,
    );

    await result.fold(
      (failure) async {
        emit(ContentCreatorError(failure.message));
        if (previousLoaded != null) {
          emit(previousLoaded);
        }
      },
      (refined) async {
        emit(ScriptRefined(refined));

        final uid = _currentUserId ?? refined.userId;
        final scriptsResult = await repository.getScripts(uid);
        final videos = await _loadContentVideos();
        scriptsResult.fold(
          (_) {
            if (previousLoaded != null) {
              final updated = previousLoaded.copyWith(
                scripts: previousLoaded.scripts
                    .map((s) => s.id == refined.id ? refined : s)
                    .toList(),
                selectedScript: previousLoaded.selectedScript?.id == refined.id
                    ? refined
                    : previousLoaded.selectedScript,
              );
              _lastLoadedState = updated;
              emit(updated);
            }
          },
          (scripts) {
            final selected = previousLoaded?.selectedScript?.id == refined.id
                ? refined
                : previousLoaded?.selectedScript;
            final loaded = ContentCreatorLoaded(
              scripts: scripts,
              videos: videos,
              selectedScript: selected,
            );
            _lastLoadedState = loaded;
            emit(loaded);
          },
        );
      },
    );
  }

  Future<void> _onEnhanceSpokenIdea(
    EnhanceSpokenIdea event,
    Emitter<ContentCreatorState> emit,
  ) async {
    _currentUserId = event.userId;
    final previousLoaded =
        state is ContentCreatorLoaded
            ? state as ContentCreatorLoaded
            : _lastLoadedState;

    emit(IdeaEnhancing(event.transcript));

    final ideaResult = await repository.enhanceSpokenIdea(
      transcript: event.transcript,
      languageCode: event.languageCode,
      languageText: event.language,
      toneHint: event.toneHint,
      lengthHint: event.lengthHint,
      platformHint: event.platformHint,
    );

    await ideaResult.fold(
      (failure) async {
        emit(ContentCreatorError(failure.message));
        if (previousLoaded != null) {
          emit(previousLoaded);
        }
      },
      (idea) async {
        emit(IdeaEnhanced(idea: idea, autoGenerating: event.autoGenerate));

        if (!event.autoGenerate) {
          if (previousLoaded != null) {
            emit(previousLoaded);
          }
          return;
        }

        // Seamless voice-to-script workflow: immediately generate full script
        // from the AI-enhanced structured brief!
        emit(ScriptGenerating(idea.suggestedTemplate));
        final scriptResult = await repository.generateScript(
          userId: event.userId,
          topic: idea.topic,
          audience: idea.audience,
          message: idea.coreMessage,
          tone: idea.suggestedTone,
          language: event.language,
          languageCode: event.languageCode,
          template: idea.suggestedTemplate,
          length: idea.suggestedLength,
          platform: idea.suggestedPlatform,
          scriptStyle: event.scriptStyle,
        );

        await scriptResult.fold(
          (failure) async {
            emit(ContentCreatorError(failure.message));
            if (previousLoaded != null) {
              emit(previousLoaded);
            }
          },
          (script) async {
            emit(ScriptGenerated(script));

            final scriptsResult = await repository.getScripts(event.userId);
            final videos = await _loadContentVideos();
            scriptsResult.fold(
              (_) {
                if (previousLoaded != null) {
                  final updated = previousLoaded.copyWith(
                    scripts: [
                      script,
                      ...previousLoaded.scripts.where((s) => s.id != script.id),
                    ],
                    selectedScript: script,
                  );
                  _lastLoadedState = updated;
                  emit(updated);
                }
              },
              (scripts) {
                final loaded = ContentCreatorLoaded(
                  scripts: scripts,
                  videos: videos,
                  selectedScript: script,
                );
                _lastLoadedState = loaded;
                emit(loaded);
              },
            );
          },
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
    final baseState =
        state is ContentCreatorLoaded
            ? state as ContentCreatorLoaded
            : _lastLoadedState;
    if (baseState != null) {
      final updated = baseState.copyWith(
        selectedScript: event.script,
        clearSelectedScript: event.script == null,
      );
      _lastLoadedState = updated;
      emit(updated);
    } else if (event.script != null) {
      final loaded = ContentCreatorLoaded(
        scripts: [event.script!],
        videos: const [],
        selectedScript: event.script,
      );
      _lastLoadedState = loaded;
      emit(loaded);
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
    _lastLoadedState = null;
    emit(ContentCreatorInitial());
  }
}
