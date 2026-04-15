import 'package:equatable/equatable.dart';

/// Warmup BLoC Events
abstract class WarmupEvent extends Equatable {
  const WarmupEvent();

  @override
  List<Object?> get props => [];
}

/// Load warmup status
class WarmupStatusLoaded extends WarmupEvent {
  final String userId;

  const WarmupStatusLoaded(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Start a warmup day
class WarmupStarted extends WarmupEvent {
  final int warmupIndex;

  const WarmupStarted(this.warmupIndex);

  @override
  List<Object?> get props => [warmupIndex];
}

/// Recording started
class WarmupRecordingStarted extends WarmupEvent {
  const WarmupRecordingStarted();
}

/// Recording stopped
class WarmupRecordingStopped extends WarmupEvent {
  final String videoPath;
  final String? customScriptText;

  const WarmupRecordingStopped(this.videoPath, {this.customScriptText});

  @override
  List<Object?> get props => [videoPath, customScriptText];
}

/// Checklist submitted
class WarmupChecklistSubmitted extends WarmupEvent {
  final int warmupIndex;
  final List<String> checkedItems;
  final String videoPath;

  const WarmupChecklistSubmitted({
    required this.warmupIndex,
    required this.checkedItems,
    required this.videoPath,
  });

  @override
  List<Object?> get props => [warmupIndex, checkedItems, videoPath];
}

/// Retry recording
class WarmupRetryRequested extends WarmupEvent {
  const WarmupRetryRequested();
}

/// Reload warmup status (uses stored userId)
class WarmupReloadRequested extends WarmupEvent {
  const WarmupReloadRequested();
}
