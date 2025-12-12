import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';

/// Local data source for progress using Hive.
abstract class HiveProgressDataSource {
  /// Get cached progress.
  Future<Map<String, dynamic>?> getProgress();

  /// Cache progress.
  Future<void> cacheProgress(Map<String, dynamic> data);

  /// Clear cached progress.
  Future<void> clearProgress();

  /// Add to offline queue.
  Future<void> addToOfflineQueue(Map<String, dynamic> action);

  /// Get offline queue.
  Future<List<Map<String, dynamic>>> getOfflineQueue();

  /// Clear offline queue.
  Future<void> clearOfflineQueue();
}

class HiveProgressDataSourceImpl implements HiveProgressDataSource {
  final Box progressBox;

  static const String _progressKey = 'cached_progress';
  static const String _offlineQueueKey = 'offline_queue';

  HiveProgressDataSourceImpl({required this.progressBox});

  @override
  Future<Map<String, dynamic>?> getProgress() async {
    try {
      final cached = progressBox.get(_progressKey);
      if (cached == null) return null;

      if (cached is String) {
        return jsonDecode(cached) as Map<String, dynamic>;
      } else if (cached is Map) {
        return Map<String, dynamic>.from(cached);
      }

      return null;
    } catch (e) {
      logger.e('Error getting cached progress', e);
      return null;
    }
  }

  @override
  Future<void> cacheProgress(Map<String, dynamic> data) async {
    try {
      logger.d('Caching progress');
      await progressBox.put(_progressKey, jsonEncode(data));
    } catch (e) {
      logger.e('Error caching progress', e);
      throw CacheException(
        message: 'Failed to cache progress',
        originalError: e,
      );
    }
  }

  @override
  Future<void> clearProgress() async {
    try {
      await progressBox.delete(_progressKey);
    } catch (e) {
      logger.e('Error clearing progress', e);
    }
  }

  @override
  Future<void> addToOfflineQueue(Map<String, dynamic> action) async {
    try {
      final queue = await getOfflineQueue();
      queue.add({...action, 'timestamp': DateTime.now().toIso8601String()});
      await progressBox.put(_offlineQueueKey, jsonEncode(queue));
      logger.d('Added action to offline queue');
    } catch (e) {
      logger.e('Error adding to offline queue', e);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    try {
      final cached = progressBox.get(_offlineQueueKey);
      if (cached == null) return [];

      final decoded = jsonDecode(cached as String);
      return List<Map<String, dynamic>>.from(
        (decoded as List).map((e) => Map<String, dynamic>.from(e)),
      );
    } catch (e) {
      logger.e('Error getting offline queue', e);
      return [];
    }
  }

  @override
  Future<void> clearOfflineQueue() async {
    try {
      await progressBox.delete(_offlineQueueKey);
    } catch (e) {
      logger.e('Error clearing offline queue', e);
    }
  }
}
