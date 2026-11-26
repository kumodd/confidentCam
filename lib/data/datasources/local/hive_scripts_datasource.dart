import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';

/// Local data source for 30-day & warmup scripts using Hive, isolated per user.
abstract class HiveScriptsDataSource {
  /// Get all cached scripts for [userId].
  Future<List<Map<String, dynamic>>> getScripts(String userId);

  /// Get script for a specific day for [userId].
  Future<Map<String, dynamic>?> getScriptForDay(String userId, int dayNumber);

  /// Cache daily scripts for [userId].
  Future<void> cacheScripts(String userId, List<Map<String, dynamic>> scripts);

  /// Check if scripts are cached locally for [userId].
  Future<bool> hasScripts(String userId);

  /// Clear cached scripts (for [userId] if supplied, or all cached scripts).
  Future<void> clearScripts({String? userId});

  /// Cache warmup scripts for [userId].
  Future<void> cacheWarmupScripts(
    String userId,
    List<Map<String, dynamic>> scripts,
  );

  /// Get cached warmup script for [userId] and [warmupIndex].
  Future<Map<String, dynamic>?> getWarmupScript(
    String userId,
    int warmupIndex,
  );
}

class HiveScriptsDataSourceImpl implements HiveScriptsDataSource {
  final Box scriptsBox;

  HiveScriptsDataSourceImpl({required this.scriptsBox});

  String _dayKey(String userId, int dayNumber) => '${userId}_day_$dayNumber';
  String _warmupKey(String userId, int index) => '${userId}_warmup_$index';
  String _hasCachedKey(String userId) => '${userId}_has_cached_scripts';

  @override
  Future<List<Map<String, dynamic>>> getScripts(String userId) async {
    try {
      final scripts = <Map<String, dynamic>>[];

      for (int i = 1; i <= 30; i++) {
        final script = await getScriptForDay(userId, i);
        if (script != null) {
          scripts.add(script);
        }
      }

      return scripts;
    } catch (e) {
      logger.e('Error getting cached scripts for $userId', e);
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getScriptForDay(
    String userId,
    int dayNumber,
  ) async {
    try {
      final key = _dayKey(userId, dayNumber);
      final cached = scriptsBox.get(key);

      if (cached == null) return null;

      if (cached is String) {
        return jsonDecode(cached) as Map<String, dynamic>;
      } else if (cached is Map) {
        return Map<String, dynamic>.from(cached);
      }

      return null;
    } catch (e) {
      logger.e('Error getting cached script for day $dayNumber', e);
      return null;
    }
  }

  @override
  Future<void> cacheScripts(
    String userId,
    List<Map<String, dynamic>> scripts,
  ) async {
    try {
      if (scripts.isEmpty) return;

      int cachedCount = 0;
      for (final script in scripts) {
        int? dayNumber;
        final rawDayNumber = script['day_number'];
        if (rawDayNumber is int) {
          dayNumber = rawDayNumber;
        } else if (rawDayNumber is num) {
          dayNumber = rawDayNumber.toInt();
        } else if (rawDayNumber is String) {
          dayNumber = int.tryParse(rawDayNumber);
        }

        if (dayNumber == null || dayNumber <= 0) continue;

        final key = _dayKey(userId, dayNumber);
        await scriptsBox.put(key, jsonEncode(script));
        cachedCount++;
      }

      if (cachedCount > 0) {
        await scriptsBox.put(_hasCachedKey(userId), true);
      }
      logger.i('Cached $cachedCount/${scripts.length} scripts locally for $userId');
    } catch (e, stackTrace) {
      logger.e('Error caching scripts for $userId: $e', e, stackTrace);
      throw CacheException(
        message: 'Failed to cache scripts',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> hasScripts(String userId) async {
    return scriptsBox.get(_hasCachedKey(userId)) == true;
  }

  @override
  Future<void> clearScripts({String? userId}) async {
    try {
      if (userId == null || userId.isEmpty) {
        await scriptsBox.clear();
        return;
      }
      final prefix = '${userId}_';
      final keysToRemove =
          scriptsBox.keys
              .whereType<String>()
              .where((k) => k.startsWith(prefix))
              .toList();
      if (keysToRemove.isNotEmpty) {
        await scriptsBox.deleteAll(keysToRemove);
      }
    } catch (e) {
      logger.e('Error clearing scripts', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getWarmupScript(
    String userId,
    int warmupIndex,
  ) async {
    try {
      final key = _warmupKey(userId, warmupIndex);
      final cached = scriptsBox.get(key);

      if (cached == null) return null;

      if (cached is String) {
        return jsonDecode(cached) as Map<String, dynamic>;
      } else if (cached is Map) {
        return Map<String, dynamic>.from(cached);
      }

      return null;
    } catch (e) {
      logger.e('Error getting cached warmup script for index $warmupIndex', e);
      return null;
    }
  }

  @override
  Future<void> cacheWarmupScripts(
    String userId,
    List<Map<String, dynamic>> scripts,
  ) async {
    try {
      int cachedCount = 0;
      for (final script in scripts) {
        int? index;
        final rawIndex = script['warmupIndex'];
        if (rawIndex is int) {
          index = rawIndex;
        } else if (rawIndex is num) {
          index = rawIndex.toInt();
        } else if (rawIndex is String) {
          index = int.tryParse(rawIndex);
        }

        if (index == null) continue;

        final key = _warmupKey(userId, index);
        await scriptsBox.put(key, jsonEncode(script));
        cachedCount++;
      }
      logger.i('Cached $cachedCount/${scripts.length} warmup scripts locally for $userId');
    } catch (e, stackTrace) {
      logger.e('Error caching warmup scripts: $e', e, stackTrace);
      throw CacheException(
        message: 'Failed to cache warmup scripts',
        originalError: e,
      );
    }
  }
}
