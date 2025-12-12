import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../../core/utils/logger.dart';
import '../../domain/repositories/video_repository.dart';
import '../../services/video_storage_service.dart';

/// Implementation of VideoRepository for local video storage.
class VideoRepositoryImpl implements VideoRepository {
  final VideoStorageService videoStorageService;

  VideoRepositoryImpl({required this.videoStorageService});

  @override
  Future<Either<Failure, String>> saveVideo({
    required String tempPath,
    required String type,
    required int dayOrWarmupIndex,
    int? segmentIndex,
    int? takeNumber,
  }) async {
    try {
      final savedPath = await videoStorageService.saveVideo(
        tempPath: tempPath,
        type: type,
        dayOrWarmupIndex: dayOrWarmupIndex,
        segmentIndex: segmentIndex,
        takeNumber: takeNumber ?? 1,
      );
      return Right(savedPath);
    } catch (e) {
      logger.e('Error saving video', e);
      return const Left(RecordingFailure(message: 'Failed to save video'));
    }
  }

  @override
  Future<Either<Failure, List<VideoTake>>> getTakesForDay(int dayNumber) async {
    try {
      final takes = await videoStorageService.getTakesForDay(dayNumber);
      return Right(takes);
    } catch (e) {
      logger.e('Error getting takes for day $dayNumber', e);
      return const Right([]);
    }
  }

  @override
  Future<Either<Failure, File?>> getFinalVideo(int dayNumber) async {
    try {
      final file = await videoStorageService.getFinalVideo(dayNumber);
      return Right(file);
    } catch (e) {
      logger.e('Error getting final video for day $dayNumber', e);
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, void>> deleteTake(String videoPath) async {
    try {
      await videoStorageService.deleteVideo(videoPath);
      return const Right(null);
    } catch (e) {
      logger.e('Error deleting take', e);
      return const Left(RecordingFailure(message: 'Failed to delete video'));
    }
  }

  @override
  Future<Either<Failure, void>> cleanupDayTakes(
    int dayNumber, {
    String? keepPath,
  }) async {
    try {
      await videoStorageService.cleanupDayTakes(dayNumber, keepPath: keepPath);
      return const Right(null);
    } catch (e) {
      logger.e('Error cleaning up day takes', e);
      return const Right(null); // Non-critical failure
    }
  }

  @override
  Future<Either<Failure, File?>> getWarmupVideo(int warmupIndex) async {
    try {
      final file = await videoStorageService.getWarmupVideo(warmupIndex);
      return Right(file);
    } catch (e) {
      logger.e('Error getting warmup video', e);
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, int>> getStorageUsedBytes() async {
    try {
      final bytes = await videoStorageService.getStorageUsedBytes();
      return Right(bytes);
    } catch (e) {
      logger.e('Error getting storage used', e);
      return const Right(0);
    }
  }

  @override
  Future<Either<Failure, void>> clearAllVideos() async {
    try {
      await videoStorageService.clearAllVideos();
      return const Right(null);
    } catch (e) {
      logger.e('Error clearing all videos', e);
      return const Left(RecordingFailure(message: 'Failed to clear videos'));
    }
  }

  @override
  Future<Either<Failure, void>> exportToCameraRoll(String videoPath) async {
    try {
      await videoStorageService.exportToGallery(videoPath);
      return const Right(null);
    } catch (e) {
      logger.e('Error exporting to camera roll', e);
      return const Left(RecordingFailure(message: 'Failed to export video'));
    }
  }

  @override
  Future<Either<Failure, void>> exportToFolder(String videoPath) async {
    try {
      await videoStorageService.exportToFolder(videoPath);
      return const Right(null);
    } catch (e) {
      logger.e('Error exporting to folder', e);
      return const Left(RecordingFailure(message: 'Failed to export video'));
    }
  }
}
