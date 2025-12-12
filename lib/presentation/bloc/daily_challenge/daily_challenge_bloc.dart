import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/daily_script.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../../../domain/repositories/script_repository.dart';
import '../../../domain/repositories/video_repository.dart';
import 'daily_challenge_event.dart';
import 'daily_challenge_state.dart';

/// BLoC for handling daily challenge flow.
class DailyChallengeBloc
    extends Bloc<DailyChallengeEvent, DailyChallengeState> {
  final ScriptRepository scriptRepository;
  final ProgressRepository progressRepository;
  final VideoRepository videoRepository;

  String? _userId;
  int? _currentDayNumber;
  DailyScript? _currentScript;
  List<VideoTake> _takes = [];

  DailyChallengeBloc({
    required this.scriptRepository,
    required this.progressRepository,
    required this.videoRepository,
  }) : super(const DayChallengeInitial()) {
    on<DayLoaded>(_onDayLoaded);
    on<SegmentChanged>(_onSegmentChanged);
    on<RecordingStarted>(_onRecordingStarted);
    on<RecordingStopped>(_onRecordingStopped);
    on<TakeSelected>(_onTakeSelected);
    on<TakeDeleted>(_onTakeDeleted);
    on<ChecklistSubmitted>(_onChecklistSubmitted);
    on<DayFinalized>(_onDayFinalized);
    on<PreviewTakesRequested>(_onPreviewTakesRequested);
  }

  Future<void> _onDayLoaded(
    DayLoaded event,
    Emitter<DailyChallengeState> emit,
  ) async {
    emit(const DayChallengeLoading());

    _userId = event.userId;
    _currentDayNumber = event.dayNumber;

    // Load script for this day
    final scriptResult = await scriptRepository.getScriptForDay(
      event.userId,
      event.dayNumber,
    );

    final script = scriptResult.fold((failure) => null, (script) => script);

    if (script == null) {
      emit(DayChallengeError('Script not found for day ${event.dayNumber}'));
      return;
    }

    _currentScript = script;

    // Load existing takes
    final takesResult = await videoRepository.getTakesForDay(event.dayNumber);
    _takes = takesResult.fold((failure) => [], (takes) => takes);

    emit(
      DayChallengeReady(
        dayNumber: event.dayNumber,
        script: script,
        currentSegment: script.isSegmented ? 0 : null,
        takes: _takes,
      ),
    );
  }

  void _onSegmentChanged(
    SegmentChanged event,
    Emitter<DailyChallengeState> emit,
  ) {
    if (state is DayChallengeReady && _currentScript != null) {
      final current = state as DayChallengeReady;
      emit(
        DayChallengeReady(
          dayNumber: current.dayNumber,
          script: _currentScript!,
          currentSegment: event.segmentIndex,
          takes: _takes,
          selectedTakeIndex: current.selectedTakeIndex,
        ),
      );
    }
  }

  void _onRecordingStarted(
    RecordingStarted event,
    Emitter<DailyChallengeState> emit,
  ) {
    if (_currentScript == null || _currentDayNumber == null) return;

    int? segmentIndex;
    if (state is DayChallengeReady) {
      segmentIndex = (state as DayChallengeReady).currentSegment;
    }

    emit(
      DayChallengeRecording(
        dayNumber: _currentDayNumber!,
        script: _currentScript!,
        segmentIndex: segmentIndex,
      ),
    );
  }

  Future<void> _onRecordingStopped(
    RecordingStopped event,
    Emitter<DailyChallengeState> emit,
  ) async {
    if (_currentDayNumber == null) return;

    int? segmentIndex;
    if (state is DayChallengeRecording) {
      segmentIndex = (state as DayChallengeRecording).segmentIndex;
    }

    // Calculate next take number as max existing + 1
    final nextTakeNumber =
        _takes.isEmpty
            ? 1
            : _takes.map((t) => t.takeNumber).reduce((a, b) => a > b ? a : b) +
                1;

    // Save video
    final saveResult = await videoRepository.saveVideo(
      tempPath: event.videoPath,
      type: 'daily',
      dayOrWarmupIndex: _currentDayNumber!,
      segmentIndex: segmentIndex,
      takeNumber: nextTakeNumber,
    );

    await saveResult.fold(
      (failure) async {
        emit(DayChallengeError(failure.message));
      },
      (savedPath) async {
        // Reload takes
        final takesResult = await videoRepository.getTakesForDay(
          _currentDayNumber!,
        );
        _takes = takesResult.fold((failure) => _takes, (takes) => takes);

        emit(
          DayChallengePlayback(
            dayNumber: _currentDayNumber!,
            script: _currentScript!,
            takes: _takes,
            selectedTakeIndex: _takes.length - 1,
          ),
        );
      },
    );
  }

  void _onTakeSelected(TakeSelected event, Emitter<DailyChallengeState> emit) {
    if (state is DayChallengePlayback && _currentScript != null) {
      emit(
        DayChallengePlayback(
          dayNumber: _currentDayNumber!,
          script: _currentScript!,
          takes: _takes,
          selectedTakeIndex: event.takeIndex,
        ),
      );
    }
  }

  Future<void> _onTakeDeleted(
    TakeDeleted event,
    Emitter<DailyChallengeState> emit,
  ) async {
    await videoRepository.deleteTake(event.takePath);

    // Reload takes
    final takesResult = await videoRepository.getTakesForDay(
      _currentDayNumber!,
    );
    _takes = takesResult.fold((failure) => [], (takes) => takes);

    if (state is DayChallengePlayback && _currentScript != null) {
      emit(
        DayChallengePlayback(
          dayNumber: _currentDayNumber!,
          script: _currentScript!,
          takes: _takes,
          selectedTakeIndex: _takes.isEmpty ? -1 : _takes.length - 1,
        ),
      );
    }
  }

  Future<void> _onChecklistSubmitted(
    ChecklistSubmitted event,
    Emitter<DailyChallengeState> emit,
  ) async {
    if (state is DayChallengePlayback) {
      final current = state as DayChallengePlayback;

      // Validate checklist - need at least 3 items checked
      if (event.checkedItems.length < 3) {
        // Stay on playback, could show a warning
        logger.w('Checklist not complete: ${event.checkedItems.length} items');
        return;
      }

      emit(
        DayChallengeChecklist(
          dayNumber: current.dayNumber,
          selectedTake: current.selectedTake,
        ),
      );
    }
  }

  Future<void> _onDayFinalized(
    DayFinalized event,
    Emitter<DailyChallengeState> emit,
  ) async {
    if (_userId == null || state is! DayChallengeChecklist) return;

    final current = state as DayChallengeChecklist;

    emit(const DayChallengeLoading());

    // Complete the day
    final result = await progressRepository.completeDay(
      userId: _userId!,
      dayNumber: current.dayNumber,
      videoPath: current.selectedTake.path,
      durationSeconds: current.selectedTake.durationSeconds,
      checklistResponses: [], // Already validated
    );

    result.fold(
      (failure) {
        emit(DayChallengeError(failure.message));
      },
      (progress) {
        logger.i('Day ${current.dayNumber} completed');

        // Cleanup other takes
        videoRepository.cleanupDayTakes(
          current.dayNumber,
          keepPath: current.selectedTake.path,
        );

        emit(
          DayChallengeComplete(
            dayNumber: current.dayNumber,
            newStreak: progress.streak,
            isChallengeComplete: current.dayNumber == 30,
          ),
        );
      },
    );
  }

  void _onPreviewTakesRequested(
    PreviewTakesRequested event,
    Emitter<DailyChallengeState> emit,
  ) {
    if (state is DayChallengeReady && _currentScript != null) {
      final current = state as DayChallengeReady;
      if (current.takes.isNotEmpty) {
        emit(
          DayChallengePlayback(
            dayNumber: current.dayNumber,
            script: _currentScript!,
            takes: current.takes,
            selectedTakeIndex: 0,
          ),
        );
      }
    }
  }
}
