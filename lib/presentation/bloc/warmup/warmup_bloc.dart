import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/warmup.dart';
import '../../../domain/repositories/progress_repository.dart';
import '../../../domain/repositories/video_repository.dart';
import 'warmup_event.dart';
import 'warmup_state.dart';

/// BLoC for handling warmup flow.
class WarmupBloc extends Bloc<WarmupEvent, WarmupState> {
  final ProgressRepository progressRepository;
  final VideoRepository videoRepository;

  String? _userId;

  /// Get stored userId for reloading
  String? get userId => _userId;

  WarmupBloc({required this.progressRepository, required this.videoRepository})
    : super(const WarmupInitial()) {
    on<WarmupStatusLoaded>(_onStatusLoaded);
    on<WarmupStarted>(_onWarmupStarted);
    on<WarmupRecordingStarted>(_onRecordingStarted);
    on<WarmupRecordingStopped>(_onRecordingStopped);
    on<WarmupChecklistSubmitted>(_onChecklistSubmitted);
    on<WarmupRetryRequested>(_onRetryRequested);
    on<WarmupReloadRequested>(_onReloadRequested);
  }

  Future<void> _onStatusLoaded(
    WarmupStatusLoaded event,
    Emitter<WarmupState> emit,
  ) async {
    emit(const WarmupLoading());
    _userId = event.userId;

    final result = await progressRepository.getProgress(event.userId);

    result.fold(
      (failure) {
        emit(WarmupError(failure.message));
      },
      (progress) {
        if (progress.allWarmupsComplete) {
          emit(const AllWarmupsComplete());
        } else {
          emit(
            WarmupOverview(
              userId: event.userId,
              warmup0Done: progress.warmup0Complete,
              warmup1Done: progress.warmup1Complete,
              warmup2Done: progress.warmup2Complete,
              nextWarmupIndex: progress.nextWarmupIndex,
            ),
          );
        }
      },
    );
  }

  /// Reload status using stored userId
  Future<void> _onReloadRequested(
    WarmupReloadRequested event,
    Emitter<WarmupState> emit,
  ) async {
    if (_userId == null) {
      logger.w('Cannot reload: no userId stored');
      return;
    }

    // Don't show loading - just refresh
    final result = await progressRepository.getProgress(_userId!);

    result.fold(
      (failure) {
        emit(WarmupError(failure.message));
      },
      (progress) {
        if (progress.allWarmupsComplete) {
          emit(const AllWarmupsComplete());
        } else {
          emit(
            WarmupOverview(
              userId: _userId!,
              warmup0Done: progress.warmup0Complete,
              warmup1Done: progress.warmup1Complete,
              warmup2Done: progress.warmup2Complete,
              nextWarmupIndex: progress.nextWarmupIndex,
            ),
          );
        }
      },
    );
  }

  void _onWarmupStarted(WarmupStarted event, Emitter<WarmupState> emit) {
    final warmup = Warmups.getByIndex(event.warmupIndex);
    if (warmup == null) {
      emit(const WarmupError('Invalid warmup index'));
      return;
    }

    emit(
      WarmupInProgress(
        warmupIndex: event.warmupIndex,
        warmup: warmup,
        step: WarmupStep.intro,
      ),
    );
  }

  void _onRecordingStarted(
    WarmupRecordingStarted event,
    Emitter<WarmupState> emit,
  ) {
    if (state is WarmupInProgress) {
      final current = state as WarmupInProgress;
      emit(
        WarmupRecording(
          warmupIndex: current.warmupIndex,
          warmup: current.warmup,
        ),
      );
    }
  }

  Future<void> _onRecordingStopped(
    WarmupRecordingStopped event,
    Emitter<WarmupState> emit,
  ) async {
    // Get current warmup info - try from multiple state types
    int warmupIndex;
    Warmup warmup;

    if (state is WarmupRecording) {
      final current = state as WarmupRecording;
      warmupIndex = current.warmupIndex;
      warmup = current.warmup;
    } else if (state is WarmupInProgress) {
      final current = state as WarmupInProgress;
      warmupIndex = current.warmupIndex;
      warmup = current.warmup;
    } else {
      // Unexpected state - can't save video without warmup context
      logger.w('_onRecordingStopped called in unexpected state: ${state.runtimeType}');
      emit(const WarmupError('Unable to save video - invalid state'));
      return;
    }

    logger.i('Saving warmup $warmupIndex video');

    // Save video
    final saveResult = await videoRepository.saveVideo(
      tempPath: event.videoPath,
      type: 'warmup',
      dayOrWarmupIndex: warmupIndex,
    );

    saveResult.fold(
      (failure) {
        logger.e('Failed to save warmup video: ${failure.message}');
        emit(WarmupError(failure.message));
      },
      (savedPath) {
        logger.i('Warmup video saved: $savedPath');
        emit(
          WarmupPlayback(
            warmupIndex: warmupIndex,
            warmup: warmup,
            videoPath: savedPath,
          ),
        );
      },
    );
  }

  Future<void> _onChecklistSubmitted(
    WarmupChecklistSubmitted event,
    Emitter<WarmupState> emit,
  ) async {
    if (_userId == null) {
      emit(const WarmupError('User not found'));
      return;
    }

    emit(const WarmupLoading());

    final result = await progressRepository.completeWarmup(
      userId: _userId!,
      warmupIndex: event.warmupIndex,
      videoPath: event.videoPath,
    );

    result.fold(
      (failure) {
        emit(WarmupError(failure.message));
      },
      (progress) {
        logger.i('Warmup ${event.warmupIndex} completed');

        final isLastWarmup = event.warmupIndex == 2;

        emit(
          WarmupDayComplete(
            warmupIndex: event.warmupIndex,
            isLastWarmup: isLastWarmup,
          ),
        );

        // After completion, reload status
        if (isLastWarmup) {
          emit(const AllWarmupsComplete());
        }
      },
    );
  }

  void _onRetryRequested(
    WarmupRetryRequested event,
    Emitter<WarmupState> emit,
  ) {
    if (state is WarmupPlayback) {
      final current = state as WarmupPlayback;
      emit(
        WarmupInProgress(
          warmupIndex: current.warmupIndex,
          warmup: current.warmup,
          step: WarmupStep.recording,
        ),
      );
    }
  }
}
