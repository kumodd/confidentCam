import 'package:equatable/equatable.dart';

import '../../../domain/entities/daily_script.dart';
import '../../../domain/repositories/video_repository.dart';

/// Daily Challenge BLoC States
abstract class DailyChallengeState extends Equatable {
  const DailyChallengeState();

  @override
  List<Object?> get props => [];
}

/// Initial state
class DayChallengeInitial extends DailyChallengeState {
  const DayChallengeInitial();
}

/// Loading day data
class DayChallengeLoading extends DailyChallengeState {
  const DayChallengeLoading();
}

/// Generating scripts for a week on-demand
class DayChallengeGeneratingScripts extends DailyChallengeState {
  final int weekNumber;

  const DayChallengeGeneratingScripts({required this.weekNumber});

  @override
  List<Object?> get props => [weekNumber];
}

/// Day ready to record
class DayChallengeReady extends DailyChallengeState {
  final int dayNumber;
  final DailyScript script;
  final int? currentSegment; // For segmented days
  final List<VideoTake> takes;
  final int selectedTakeIndex;

  const DayChallengeReady({
    required this.dayNumber,
    required this.script,
    this.currentSegment,
    this.takes = const [],
    this.selectedTakeIndex = -1,
  });

  bool get isSegmented => script.isSegmented;

  @override
  List<Object?> get props => [
    dayNumber,
    script,
    currentSegment,
    takes,
    selectedTakeIndex,
  ];
}

/// Recording in progress
class DayChallengeRecording extends DailyChallengeState {
  final int dayNumber;
  final DailyScript script;
  final int? segmentIndex;

  const DayChallengeRecording({
    required this.dayNumber,
    required this.script,
    this.segmentIndex,
  });

  @override
  List<Object?> get props => [dayNumber, script, segmentIndex];
}

/// Playback/review takes
class DayChallengePlayback extends DailyChallengeState {
  final int dayNumber;
  final DailyScript script;
  final List<VideoTake> takes;
  final int selectedTakeIndex;

  const DayChallengePlayback({
    required this.dayNumber,
    required this.script,
    required this.takes,
    required this.selectedTakeIndex,
  });

  VideoTake get selectedTake => takes[selectedTakeIndex];

  @override
  List<Object?> get props => [dayNumber, script, takes, selectedTakeIndex];
}

/// Checklist screen
class DayChallengeChecklist extends DailyChallengeState {
  final int dayNumber;
  final VideoTake selectedTake;

  const DayChallengeChecklist({
    required this.dayNumber,
    required this.selectedTake,
  });

  @override
  List<Object?> get props => [dayNumber, selectedTake];
}

/// Day completed
class DayChallengeComplete extends DailyChallengeState {
  final int dayNumber;
  final int newStreak;
  final bool isChallengeComplete;

  const DayChallengeComplete({
    required this.dayNumber,
    required this.newStreak,
    this.isChallengeComplete = false,
  });

  @override
  List<Object?> get props => [dayNumber, newStreak, isChallengeComplete];
}

/// Error state
class DayChallengeError extends DailyChallengeState {
  final String message;

  const DayChallengeError(this.message);

  @override
  List<Object?> get props => [message];
}
