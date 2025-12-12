import 'package:equatable/equatable.dart';

import '../../../domain/entities/warmup.dart';

/// Warmup step within a single warmup day
enum WarmupStep { intro, recording, playback, checklist }

/// Warmup BLoC States
abstract class WarmupState extends Equatable {
  const WarmupState();

  @override
  List<Object?> get props => [];
}

/// Initial warmup state
class WarmupInitial extends WarmupState {
  const WarmupInitial();
}

/// Loading warmup status
class WarmupLoading extends WarmupState {
  const WarmupLoading();
}

/// Warmup overview showing which warmups are done
class WarmupOverview extends WarmupState {
  final String userId;
  final bool warmup0Done;
  final bool warmup1Done;
  final bool warmup2Done;
  final int nextWarmupIndex;

  const WarmupOverview({
    required this.userId,
    required this.warmup0Done,
    required this.warmup1Done,
    required this.warmup2Done,
    required this.nextWarmupIndex,
  });

  bool get allWarmupsComplete => warmup0Done && warmup1Done && warmup2Done;

  @override
  List<Object?> get props => [
    userId,
    warmup0Done,
    warmup1Done,
    warmup2Done,
    nextWarmupIndex,
  ];
}

/// In a specific warmup day
class WarmupInProgress extends WarmupState {
  final int warmupIndex;
  final Warmup warmup;
  final WarmupStep step;
  final String? videoPath;

  const WarmupInProgress({
    required this.warmupIndex,
    required this.warmup,
    required this.step,
    this.videoPath,
  });

  @override
  List<Object?> get props => [warmupIndex, warmup, step, videoPath];
}

/// Recording in progress
class WarmupRecording extends WarmupState {
  final int warmupIndex;
  final Warmup warmup;

  const WarmupRecording({required this.warmupIndex, required this.warmup});

  @override
  List<Object?> get props => [warmupIndex, warmup];
}

/// Video recorded, showing playback
class WarmupPlayback extends WarmupState {
  final int warmupIndex;
  final Warmup warmup;
  final String videoPath;

  const WarmupPlayback({
    required this.warmupIndex,
    required this.warmup,
    required this.videoPath,
  });

  @override
  List<Object?> get props => [warmupIndex, warmup, videoPath];
}

/// Warmup day completed
class WarmupDayComplete extends WarmupState {
  final int warmupIndex;
  final bool isLastWarmup;

  const WarmupDayComplete({
    required this.warmupIndex,
    required this.isLastWarmup,
  });

  @override
  List<Object?> get props => [warmupIndex, isLastWarmup];
}

/// All warmups completed
class AllWarmupsComplete extends WarmupState {
  const AllWarmupsComplete();
}

/// Error state
class WarmupError extends WarmupState {
  final String message;

  const WarmupError(this.message);

  @override
  List<Object?> get props => [message];
}
