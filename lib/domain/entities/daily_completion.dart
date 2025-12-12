import 'package:equatable/equatable.dart';

/// Daily completion entity tracking completed days.
class DailyCompletion extends Equatable {
  final String id;
  final String userId;
  final int dayNumber;
  final String videoFilename;
  final int? durationSeconds;
  final List<String> checklistResponses;
  final DateTime completedAt;

  const DailyCompletion({
    required this.id,
    required this.userId,
    required this.dayNumber,
    required this.videoFilename,
    this.durationSeconds,
    required this.checklistResponses,
    required this.completedAt,
  });

  @override
  List<Object?> get props => [
    id,
    userId,
    dayNumber,
    videoFilename,
    durationSeconds,
    checklistResponses,
    completedAt,
  ];
}
