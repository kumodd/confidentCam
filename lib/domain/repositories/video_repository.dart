import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';

/// Represents a video take.
class VideoTake {
  final String path;
  final int durationSeconds;
  final int takeNumber;
  final DateTime createdAt;

  const VideoTake({
    required this.path,
    required this.durationSeconds,
    required this.takeNumber,
    required this.createdAt,
  });
}

/// Repository interface for video storage operations.
abstract class VideoRepository {
  /// Save a recorded video.
  Future<Either<Failure, String>> saveVideo({
    required String tempPath,
    required String type, // 'warmup' or 'daily'
    required int dayOrWarmupIndex,
    int? segmentIndex,
    int? takeNumber,
  });

  /// Get all takes for a day.
  Future<Either<Failure, List<VideoTake>>> getTakesForDay(int dayNumber);

  /// Get final video for a day.
  Future<Either<Failure, File?>> getFinalVideo(int dayNumber);

  /// Delete a specific take.
  Future<Either<Failure, void>> deleteTake(String videoPath);

  /// Delete all takes for a day except the final one.
  Future<Either<Failure, void>> cleanupDayTakes(
    int dayNumber, {
    String? keepPath,
  });

  /// Get warmup video.
  Future<Either<Failure, File?>> getWarmupVideo(int warmupIndex);

  /// Get total storage used by videos.
  Future<Either<Failure, int>> getStorageUsedBytes();

  /// Clear all videos.
  Future<Either<Failure, void>> clearAllVideos();

  /// Export video to camera roll/gallery.
  Future<Either<Failure, void>> exportToCameraRoll(String videoPath);

  /// Export video to folder (Files/Downloads).
  Future<Either<Failure, void>> exportToFolder(String videoPath);
}
