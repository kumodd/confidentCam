import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/user_progress.dart';
import '../entities/daily_completion.dart';

/// Repository interface for progress tracking operations.
abstract class ProgressRepository {
  /// Get user progress.
  Future<Either<Failure, UserProgress>> getProgress(String userId);

  /// Complete a warmup.
  Future<Either<Failure, UserProgress>> completeWarmup({
    required String userId,
    required int warmupIndex,
    required String videoPath,
  });

  /// Complete a daily challenge.
  Future<Either<Failure, UserProgress>> completeDay({
    required String userId,
    required int dayNumber,
    required String videoPath,
    required int durationSeconds,
    required List<String> checklistResponses,
  });

  /// Get all completions for a user.
  Future<Either<Failure, List<DailyCompletion>>> getCompletions(String userId);

  /// Get completion for a specific day.
  Future<Either<Failure, DailyCompletion?>> getCompletionForDay(
    String userId,
    int dayNumber,
  );

  /// Update streak (called daily).
  Future<Either<Failure, UserProgress>> updateStreak(String userId);

  /// Sync offline progress to server.
  Future<Either<Failure, void>> syncOfflineProgress();
}
