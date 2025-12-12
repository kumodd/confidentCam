import 'package:dartz/dartz.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/network/network_info.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/daily_completion.dart';
import '../../domain/entities/user_progress.dart';
import '../../domain/repositories/progress_repository.dart';
import '../datasources/local/hive_progress_datasource.dart';
import '../datasources/remote/supabase_progress_datasource.dart';
import '../models/daily_completion_model.dart';
import '../models/user_progress_model.dart';

/// Implementation of ProgressRepository with offline-first support.
class ProgressRepositoryImpl implements ProgressRepository {
  final SupabaseProgressDataSource remoteDataSource;
  final HiveProgressDataSource localDataSource;
  final NetworkInfo networkInfo;

  ProgressRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserProgress>> getProgress(String userId) async {
    try {
      // Try to get from remote if online
      if (await networkInfo.isConnected) {
        try {
          final data = await remoteDataSource.getProgress(userId);
          if (data != null) {
            final progress = UserProgressModel.fromJson(data);
            // Cache locally
            await localDataSource.cacheProgress(data);
            return Right(progress);
          }
        } catch (e) {
          logger.w('Failed to get remote progress, falling back to cache', e);
        }
      }

      // Fallback to local cache
      final cached = await localDataSource.getProgress();
      if (cached != null) {
        return Right(UserProgressModel.fromHiveJson(userId, cached));
      }

      // Return initial progress if nothing cached
      return Right(UserProgressModel.initial(userId));
    } catch (e) {
      logger.e('Error getting progress', e);
      return Right(UserProgressModel.initial(userId));
    }
  }

  @override
  Future<Either<Failure, UserProgress>> completeWarmup({
    required String userId,
    required int warmupIndex,
    required String videoPath,
  }) async {
    try {
      final progressResult = await getProgress(userId);

      return progressResult.fold((failure) => Left(failure), (
        currentProgress,
      ) async {
        // Update progress based on warmup index
        Map<String, dynamic> updateData;

        switch (warmupIndex) {
          case 0:
            updateData = {'warmup_0_complete': true};
            break;
          case 1:
            updateData = {'warmup_1_complete': true};
            break;
          case 2:
            updateData = {
              'warmup_2_complete': true,
              'challenge_started_at': DateTime.now().toIso8601String(),
            };
            break;
          default:
            return const Left(
              ValidationFailure(message: 'Invalid warmup index'),
            );
        }

        if (await networkInfo.isConnected) {
          try {
            final updated = await remoteDataSource.updateProgress(
              userId,
              updateData,
            );
            final progress = UserProgressModel.fromJson(updated);
            await localDataSource.cacheProgress(updated);
            return Right(progress);
          } on ServerException catch (e) {
            return Left(ServerFailure(message: e.message));
          }
        } else {
          // Queue for sync and update local
          await localDataSource.addToOfflineQueue({
            'action': 'complete_warmup',
            'user_id': userId,
            'warmup_index': warmupIndex,
            'video_path': videoPath,
          });

          // Update local cache
          final cached = await localDataSource.getProgress() ?? {};
          cached.addAll(updateData);
          await localDataSource.cacheProgress(cached);

          return Right(UserProgressModel.fromHiveJson(userId, cached));
        }
      });
    } catch (e) {
      logger.e('Error completing warmup', e);
      return const Left(ServerFailure(message: 'Failed to complete warmup'));
    }
  }

  @override
  Future<Either<Failure, UserProgress>> completeDay({
    required String userId,
    required int dayNumber,
    required String videoPath,
    required int durationSeconds,
    required List<String> checklistResponses,
  }) async {
    try {
      final progressResult = await getProgress(userId);

      return progressResult.fold((failure) => Left(failure), (
        currentProgress,
      ) async {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Calculate new streak
        int newStreak = 1;
        if (currentProgress.lastCompletedDate != null) {
          final lastDate = currentProgress.lastCompletedDate!;
          final yesterday = today.subtract(const Duration(days: 1));

          if (lastDate.year == yesterday.year &&
              lastDate.month == yesterday.month &&
              lastDate.day == yesterday.day) {
            newStreak = currentProgress.streak + 1;
          } else if (lastDate.year == today.year &&
              lastDate.month == today.month &&
              lastDate.day == today.day) {
            newStreak = currentProgress.streak; // Already completed today
          }
        }

        final longestStreak = newStreak > currentProgress.longestStreak
            ? newStreak
            : currentProgress.longestStreak;

        final updateData = {
          'current_day': dayNumber,
          'streak': newStreak,
          'longest_streak': longestStreak,
          'last_completed_date': today.toIso8601String().split('T')[0],
        };

        // Add challenge completed if day 30
        if (dayNumber == 30) {
          updateData['challenge_completed_at'] = now.toIso8601String();
        }

        final completionData = {
          'user_id': userId,
          'day_number': dayNumber,
          'video_filename': videoPath.split('/').last,
          'duration_seconds': durationSeconds,
          'checklist_responses': checklistResponses,
          'completed_at': now.toIso8601String(),
        };

        if (await networkInfo.isConnected) {
          try {
            // Create completion record
            await remoteDataSource.createCompletion(completionData);

            // Update progress
            final updated = await remoteDataSource.updateProgress(
              userId,
              updateData,
            );
            final progress = UserProgressModel.fromJson(updated);
            await localDataSource.cacheProgress(updated);

            return Right(progress);
          } on ServerException catch (e) {
            return Left(ServerFailure(message: e.message));
          }
        } else {
          // Queue for sync
          await localDataSource.addToOfflineQueue({
            'action': 'complete_day',
            'user_id': userId,
            'day_number': dayNumber,
            'completion_data': completionData,
            'progress_update': updateData,
          });

          // Update local cache
          final cached = await localDataSource.getProgress() ?? {};
          cached.addAll(updateData);
          await localDataSource.cacheProgress(cached);

          return Right(UserProgressModel.fromHiveJson(userId, cached));
        }
      });
    } catch (e) {
      logger.e('Error completing day', e);
      return const Left(ServerFailure(message: 'Failed to complete day'));
    }
  }

  @override
  Future<Either<Failure, List<DailyCompletion>>> getCompletions(
    String userId,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Right([]); // Could cache completions but not critical
    }

    try {
      final data = await remoteDataSource.getCompletions(userId);
      final completions = data
          .map((json) => DailyCompletionModel.fromJson(json))
          .toList();
      return Right(completions);
    } on ServerException catch (e) {
      logger.e('Server error getting completions', e);
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      logger.e('Error getting completions', e);
      return const Right([]);
    }
  }

  @override
  Future<Either<Failure, DailyCompletion?>> getCompletionForDay(
    String userId,
    int dayNumber,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Right(null);
    }

    try {
      final data = await remoteDataSource.getCompletionForDay(
        userId,
        dayNumber,
      );
      if (data == null) return const Right(null);
      return Right(DailyCompletionModel.fromJson(data));
    } catch (e) {
      logger.e('Error getting completion for day', e);
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, UserProgress>> updateStreak(String userId) async {
    // This is typically called on app start to check/reset streak
    return getProgress(userId);
  }

  @override
  Future<Either<Failure, void>> syncOfflineProgress() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final queue = await localDataSource.getOfflineQueue();

      for (final action in queue) {
        final actionType = action['action'] as String;

        try {
          switch (actionType) {
            case 'complete_warmup':
              final userId = action['user_id'] as String;
              final warmupIndex = action['warmup_index'] as int;
              final updateData = <String, dynamic>{};

              if (warmupIndex == 0) updateData['warmup_0_complete'] = true;
              if (warmupIndex == 1) updateData['warmup_1_complete'] = true;
              if (warmupIndex == 2) {
                updateData['warmup_2_complete'] = true;
                updateData['challenge_started_at'] = DateTime.now()
                    .toIso8601String();
              }

              await remoteDataSource.updateProgress(userId, updateData);
              break;

            case 'complete_day':
              final completionData =
                  action['completion_data'] as Map<String, dynamic>;
              final progressUpdate =
                  action['progress_update'] as Map<String, dynamic>;
              final userId = action['user_id'] as String;

              await remoteDataSource.createCompletion(completionData);
              await remoteDataSource.updateProgress(userId, progressUpdate);
              break;
          }
        } catch (e) {
          logger.e('Error syncing action: $actionType', e);
          // Continue with other actions
        }
      }

      await localDataSource.clearOfflineQueue();
      return const Right(null);
    } catch (e) {
      logger.e('Error syncing offline progress', e);
      return const Left(SyncFailure());
    }
  }
}
