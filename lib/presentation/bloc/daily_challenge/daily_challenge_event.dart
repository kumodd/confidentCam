import 'package:equatable/equatable.dart';

/// Daily Challenge BLoC Events
abstract class DailyChallengeEvent extends Equatable {
  const DailyChallengeEvent();

  @override
  List<Object?> get props => [];
}

/// Load a specific day
class DayLoaded extends DailyChallengeEvent {
  final String userId;
  final int dayNumber;

  const DayLoaded({required this.userId, required this.dayNumber});

  @override
  List<Object?> get props => [userId, dayNumber];
}

/// Change segment (for days 1-5)
class SegmentChanged extends DailyChallengeEvent {
  final int segmentIndex;

  const SegmentChanged(this.segmentIndex);

  @override
  List<Object?> get props => [segmentIndex];
}

/// Start recording
class RecordingStarted extends DailyChallengeEvent {
  const RecordingStarted();
}

/// Stop recording
class RecordingStopped extends DailyChallengeEvent {
  final String videoPath;

  const RecordingStopped(this.videoPath);

  @override
  List<Object?> get props => [videoPath];
}

/// Select a take
class TakeSelected extends DailyChallengeEvent {
  final int takeIndex;

  const TakeSelected(this.takeIndex);

  @override
  List<Object?> get props => [takeIndex];
}

/// Delete a take
class TakeDeleted extends DailyChallengeEvent {
  final String takePath;

  const TakeDeleted(this.takePath);

  @override
  List<Object?> get props => [takePath];
}

/// Submit checklist
class ChecklistSubmitted extends DailyChallengeEvent {
  final List<String> checkedItems;

  const ChecklistSubmitted(this.checkedItems);

  @override
  List<Object?> get props => [checkedItems];
}

/// Finalize the day
class DayFinalized extends DailyChallengeEvent {
  const DayFinalized();
}

/// Preview existing takes
class PreviewTakesRequested extends DailyChallengeEvent {
  const PreviewTakesRequested();
}
