import 'dart:io';

import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_constants.dart';
import '../core/utils/logger.dart';
import '../domain/repositories/video_repository.dart';

/// Service for video storage operations.
/// Videos are stored PRIVATELY in app's documents directory.
/// Only accessible through this app unless explicitly exported.
abstract class VideoStorageService {
  /// Initialize storage directories.
  Future<void> initialize();

  /// Save video to permanent private storage.
  Future<String> saveVideo({
    required String tempPath,
    required String type,
    required int dayOrWarmupIndex,
    int? segmentIndex,
    required int takeNumber,
  });

  /// Get all takes for a day.
  Future<List<VideoTake>> getTakesForDay(int dayNumber);

  /// Get final video for a day.
  Future<File?> getFinalVideo(int dayNumber);

  /// Get warmup video.
  Future<File?> getWarmupVideo(int warmupIndex);

  /// Delete a video.
  Future<void> deleteVideo(String path);

  /// Cleanup takes for a day, keeping only specified path.
  Future<void> cleanupDayTakes(int dayNumber, {String? keepPath});

  /// Get total storage used by videos.
  Future<int> getStorageUsedBytes();

  /// Clear all videos.
  Future<void> clearAllVideos();

  /// Export video to camera roll/gallery (saves directly without share dialog).
  Future<bool> exportToGallery(String videoPath);

  /// Export video to a shareable location (allows user to save to Files/Downloads).
  Future<void> exportToFolder(String videoPath);

  /// Share video via apps (social media, messaging, etc.).
  Future<void> shareVideo(String videoPath);

  /// Get all videos for display in library.
  Future<List<VideoInfo>> getAllVideos();

  /// Get all takes for a warmup.
  Future<List<VideoTake>> getTakesForWarmup(int warmupIndex);
}

/// Video info for library display.
class VideoInfo {
  final String path;
  final String type; // 'warmup' or 'daily'
  final int dayOrWarmupIndex;
  final int takeNumber;
  final DateTime createdAt;
  final int sizeBytes;

  VideoInfo({
    required this.path,
    required this.type,
    required this.dayOrWarmupIndex,
    this.takeNumber = 1,
    required this.createdAt,
    required this.sizeBytes,
  });

  String get displayName {
    if (type == 'warmup') {
      return 'Warmup ${dayOrWarmupIndex + 1} - Take $takeNumber';
    }
    return 'Day $dayOrWarmupIndex - Take $takeNumber';
  }
}

class VideoStorageServiceImpl implements VideoStorageService {
  Directory? _appDirectory;

  @override
  Future<void> initialize() async {
    _appDirectory = await getApplicationDocumentsDirectory();

    // Create subdirectories (private to app)
    await Directory(
      '${_appDirectory!.path}/${AppConstants.warmupsFolderName}',
    ).create(recursive: true);
    await Directory(
      '${_appDirectory!.path}/${AppConstants.dailyFolderName}',
    ).create(recursive: true);
    await Directory(
      '${_appDirectory!.path}/${AppConstants.exportsFolderName}',
    ).create(recursive: true);

    logger.d('Video storage initialized at ${_appDirectory!.path}');
  }

  Future<Directory> _getAppDir() async {
    if (_appDirectory == null) {
      await initialize();
    }
    return _appDirectory!;
  }

  @override
  Future<String> saveVideo({
    required String tempPath,
    required String type,
    required int dayOrWarmupIndex,
    int? segmentIndex,
    required int takeNumber,
  }) async {
    final appDir = await _getAppDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    String targetPath;

    if (type == 'warmup') {
      targetPath =
          '${appDir.path}/${AppConstants.warmupsFolderName}/'
          'warmup_${dayOrWarmupIndex}_$timestamp.mp4';
    } else {
      final dayDir =
          '${appDir.path}/${AppConstants.dailyFolderName}/day_$dayOrWarmupIndex';
      await Directory(dayDir).create(recursive: true);

      if (segmentIndex != null) {
        targetPath = '$dayDir/segment_${segmentIndex}_take_$takeNumber.mp4';
      } else {
        targetPath = '$dayDir/take_$takeNumber.mp4';
      }
    }

    // Copy from temp to permanent private location
    final sourceFile = File(tempPath);
    await sourceFile.copy(targetPath);

    logger.d('Video saved privately to $targetPath');
    return targetPath;
  }

  @override
  Future<List<VideoTake>> getTakesForDay(int dayNumber) async {
    final appDir = await _getAppDir();
    final dayDir = Directory(
      '${appDir.path}/${AppConstants.dailyFolderName}/day_$dayNumber',
    );

    if (!await dayDir.exists()) {
      return [];
    }

    final takes = <VideoTake>[];

    await for (final entity in dayDir.list()) {
      if (entity is File && entity.path.endsWith('.mp4')) {
        final stat = await entity.stat();
        final filename = entity.path.split('/').last;

        // Extract take number from filename
        int takeNumber = 1;
        final match = RegExp(r'take_(\d+)').firstMatch(filename);
        if (match != null) {
          takeNumber = int.parse(match.group(1)!);
        }

        takes.add(
          VideoTake(
            path: entity.path,
            durationSeconds: 0,
            takeNumber: takeNumber,
            createdAt: stat.modified,
          ),
        );
      }
    }

    takes.sort((a, b) => a.takeNumber.compareTo(b.takeNumber));
    return takes;
  }

  @override
  Future<File?> getFinalVideo(int dayNumber) async {
    final takes = await getTakesForDay(dayNumber);
    if (takes.isEmpty) return null;

    return File(takes.last.path);
  }

  @override
  Future<File?> getWarmupVideo(int warmupIndex) async {
    final appDir = await _getAppDir();
    final warmupDir = Directory(
      '${appDir.path}/${AppConstants.warmupsFolderName}',
    );

    if (!await warmupDir.exists()) {
      return null;
    }

    File? latestFile;
    DateTime? latestTime;

    await for (final entity in warmupDir.list()) {
      if (entity is File &&
          entity.path.contains('warmup_${warmupIndex}_') &&
          entity.path.endsWith('.mp4')) {
        final stat = await entity.stat();
        if (latestTime == null || stat.modified.isAfter(latestTime)) {
          latestFile = entity;
          latestTime = stat.modified;
        }
      }
    }

    return latestFile;
  }

  @override
  Future<List<VideoTake>> getTakesForWarmup(int warmupIndex) async {
    final appDir = await _getAppDir();
    final warmupDir = Directory(
      '${appDir.path}/${AppConstants.warmupsFolderName}',
    );

    if (!await warmupDir.exists()) {
      return [];
    }

    final takes = <VideoTake>[];
    int takeCounter = 0;

    await for (final entity in warmupDir.list()) {
      if (entity is File &&
          entity.path.contains('warmup_${warmupIndex}_') &&
          entity.path.endsWith('.mp4')) {
        final stat = await entity.stat();
        takeCounter++;

        takes.add(
          VideoTake(
            path: entity.path,
            durationSeconds: 0,
            takeNumber: takeCounter,
            createdAt: stat.modified,
          ),
        );
      }
    }

    // Sort by creation time so oldest is take 1
    takes.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Reassign take numbers in order
    for (var i = 0; i < takes.length; i++) {
      takes[i] = VideoTake(
        path: takes[i].path,
        durationSeconds: takes[i].durationSeconds,
        takeNumber: i + 1,
        createdAt: takes[i].createdAt,
      );
    }

    return takes;
  }

  @override
  Future<void> deleteVideo(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
      logger.d('Deleted video at $path');
    }
  }

  @override
  Future<void> cleanupDayTakes(int dayNumber, {String? keepPath}) async {
    final takes = await getTakesForDay(dayNumber);

    for (final take in takes) {
      if (take.path != keepPath) {
        await deleteVideo(take.path);
      }
    }
  }

  @override
  Future<int> getStorageUsedBytes() async {
    final appDir = await _getAppDir();
    int totalBytes = 0;

    Future<void> calculateDir(Directory dir) async {
      if (!await dir.exists()) return;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final stat = await entity.stat();
          totalBytes += stat.size;
        }
      }
    }

    await calculateDir(
      Directory('${appDir.path}/${AppConstants.warmupsFolderName}'),
    );
    await calculateDir(
      Directory('${appDir.path}/${AppConstants.dailyFolderName}'),
    );

    return totalBytes;
  }

  @override
  Future<void> clearAllVideos() async {
    final appDir = await _getAppDir();

    final warmupDir = Directory(
      '${appDir.path}/${AppConstants.warmupsFolderName}',
    );
    final dailyDir = Directory(
      '${appDir.path}/${AppConstants.dailyFolderName}',
    );

    if (await warmupDir.exists()) {
      await warmupDir.delete(recursive: true);
      await warmupDir.create();
    }

    if (await dailyDir.exists()) {
      await dailyDir.delete(recursive: true);
      await dailyDir.create();
    }

    logger.i('All videos cleared');
  }

  @override
  Future<bool> exportToGallery(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        logger.e('Video not found for export: $videoPath');
        return false;
      }

      // Use gal package to save directly to camera roll/gallery
      // This does NOT show share dialog, it saves directly
      await Gal.putVideo(videoPath, album: 'ConfidentCam');
      logger.i('Video saved to gallery: $videoPath');
      return true;
    } on GalException catch (e) {
      logger.e('Gal error exporting to gallery: ${e.type.name}', e);
      return false;
    } catch (e) {
      logger.e('Error exporting to gallery', e);
      return false;
    }
  }

  @override
  Future<void> exportToFolder(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        logger.e('Video not found for export: $videoPath');
        return;
      }

      // Copy to exports folder with a user-friendly name
      final appDir = await _getAppDir();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final exportPath =
          '${appDir.path}/${AppConstants.exportsFolderName}/'
          'ConfidentCam_$timestamp.mp4';

      await file.copy(exportPath);

      // Use share to allow user to save to Files/Downloads
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(exportPath)],
          title: 'ConfidentCam Video Export',
        ),
      );
      logger.i('Video exported to folder: $exportPath');
    } catch (e) {
      logger.e('Error exporting to folder', e);
    }
  }

  /// Share video via apps (social media, messaging, etc.)
  @override
  Future<void> shareVideo(String videoPath) async {
    try {
      final file = File(videoPath);
      if (!await file.exists()) {
        logger.e('Video not found for share: $videoPath');
        return;
      }

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(videoPath)],
          text: 'Check out my ConfidentCam video!',
        ),
      );
      logger.i('Video shared: $videoPath');
    } catch (e) {
      logger.e('Error sharing video', e);
    }
  }

  @override
  Future<List<VideoInfo>> getAllVideos() async {
    final videos = <VideoInfo>[];
    final appDir = await _getAppDir();

    // Get warmup videos and group by warmup index to calculate take numbers
    final warmupDir = Directory(
      '${appDir.path}/${AppConstants.warmupsFolderName}',
    );
    if (await warmupDir.exists()) {
      // Group warmup files by index
      final warmupsByIndex = <int, List<Map<String, dynamic>>>{};

      await for (final entity in warmupDir.list()) {
        if (entity is File && entity.path.endsWith('.mp4')) {
          final stat = await entity.stat();
          final filename = entity.path.split('/').last;

          // Extract warmup index
          int warmupIndex = 0;
          final match = RegExp(r'warmup_(\d+)').firstMatch(filename);
          if (match != null) {
            warmupIndex = int.parse(match.group(1)!);
          }

          warmupsByIndex.putIfAbsent(warmupIndex, () => []);
          warmupsByIndex[warmupIndex]!.add({'path': entity.path, 'stat': stat});
        }
      }

      // Sort and assign take numbers within each warmup index
      for (final warmupIndex in warmupsByIndex.keys) {
        final warmupFiles = warmupsByIndex[warmupIndex]!;
        warmupFiles.sort(
          (a, b) => (a['stat'] as FileStat).modified.compareTo(
            (b['stat'] as FileStat).modified,
          ),
        );

        for (var i = 0; i < warmupFiles.length; i++) {
          final file = warmupFiles[i];
          videos.add(
            VideoInfo(
              path: file['path'] as String,
              type: 'warmup',
              dayOrWarmupIndex: warmupIndex,
              takeNumber: i + 1,
              createdAt: (file['stat'] as FileStat).modified,
              sizeBytes: (file['stat'] as FileStat).size,
            ),
          );
        }
      }
    }

    // Get daily videos
    final dailyDir = Directory(
      '${appDir.path}/${AppConstants.dailyFolderName}',
    );
    if (await dailyDir.exists()) {
      await for (final dayFolder in dailyDir.list()) {
        if (dayFolder is Directory) {
          final dayName = dayFolder.path.split('/').last;
          final dayMatch = RegExp(r'day_(\d+)').firstMatch(dayName);
          if (dayMatch != null) {
            final dayNumber = int.parse(dayMatch.group(1)!);

            // Collect all files for this day
            final dayFiles = <Map<String, dynamic>>[];
            await for (final entity in dayFolder.list()) {
              if (entity is File && entity.path.endsWith('.mp4')) {
                final stat = await entity.stat();
                final filename = entity.path.split('/').last;

                // Try to extract take number from filename
                int takeNumber = 1;
                final takeMatch = RegExp(r'take_(\d+)').firstMatch(filename);
                if (takeMatch != null) {
                  takeNumber = int.parse(takeMatch.group(1)!);
                }

                dayFiles.add({
                  'path': entity.path,
                  'stat': stat,
                  'takeNumber': takeNumber,
                });
              }
            }

            // Sort by take number (or by date if take numbers are missing)
            dayFiles.sort(
              (a, b) =>
                  (a['takeNumber'] as int).compareTo(b['takeNumber'] as int),
            );

            for (final file in dayFiles) {
              videos.add(
                VideoInfo(
                  path: file['path'] as String,
                  type: 'daily',
                  dayOrWarmupIndex: dayNumber,
                  takeNumber: file['takeNumber'] as int,
                  createdAt: (file['stat'] as FileStat).modified,
                  sizeBytes: (file['stat'] as FileStat).size,
                ),
              );
            }
          }
        }
      }
    }

    // Sort by creation date (newest first)
    videos.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return videos;
  }
}
