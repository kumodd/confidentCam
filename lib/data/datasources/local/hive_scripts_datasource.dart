import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';

/// Local data source for scripts using Hive.
abstract class HiveScriptsDataSource {
  /// Get all cached scripts.
  Future<List<Map<String, dynamic>>> getScripts();

  /// Get script for a specific day.
  Future<Map<String, dynamic>?> getScriptForDay(int dayNumber);

  /// Cache scripts.
  Future<void> cacheScripts(List<Map<String, dynamic>> scripts);

  /// Check if scripts are cached.
  Future<bool> hasScripts();

  /// Clear cached scripts.
  Future<void> clearScripts();

  /// Cache warmup scripts.
  Future<void> cacheWarmupScripts(List<Map<String, dynamic>> scripts);

  /// Get script for a specific warmup index.
  Future<Map<String, dynamic>?> getWarmupScript(int warmupIndex);
}

class HiveScriptsDataSourceImpl implements HiveScriptsDataSource {
  final Box scriptsBox;

  static const String _scriptsKeyPrefix = 'day_';
  static const String _warmupKeyPrefix = 'warmup_';
  static const String _hasCachedKey = 'has_cached_scripts';

  HiveScriptsDataSourceImpl({required this.scriptsBox});

  @override
  Future<List<Map<String, dynamic>>> getScripts() async {
    try {
      final scripts = <Map<String, dynamic>>[];

      for (int i = 1; i <= 30; i++) {
        final script = await getScriptForDay(i);
        if (script != null) {
          scripts.add(script);
        }
      }

      return scripts;
    } catch (e) {
      logger.e('Error getting cached scripts', e);
      return [];
    }
  }

  @override
  Future<Map<String, dynamic>?> getScriptForDay(int dayNumber) async {
    try {
      final key = '$_scriptsKeyPrefix$dayNumber';
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
  Future<void> cacheScripts(List<Map<String, dynamic>> scripts) async {
    try {
      logger.i('=== CACHING SCRIPTS LOCALLY ===');
      logger.i('Total scripts to cache: ${scripts.length}');

      if (scripts.isEmpty) {
        logger.w('No scripts to cache!');
        return;
      }

      // Log first script structure for debugging
      logger.d('First script keys: ${scripts.first.keys.toList()}');
      logger.d('First script day_number: ${scripts.first['day_number']}');

      int cachedCount = 0;
      for (final script in scripts) {
        // Robust day_number extraction
        int? dayNumber;
        final rawDayNumber = script['day_number'];
        if (rawDayNumber is int) {
          dayNumber = rawDayNumber;
        } else if (rawDayNumber is num) {
          dayNumber = rawDayNumber.toInt();
        } else if (rawDayNumber is String) {
          dayNumber = int.tryParse(rawDayNumber);
        }

        if (dayNumber == null) {
          logger.e(
            'Script has invalid day_number: $rawDayNumber (${rawDayNumber?.runtimeType})',
          );
          logger.e('Script data: $script');
          continue;
        }

        final key = '$_scriptsKeyPrefix$dayNumber';
        await scriptsBox.put(key, jsonEncode(script));
        cachedCount++;
      }

      await scriptsBox.put(_hasCachedKey, true);
      logger.i(
        '=== SCRIPTS CACHED SUCCESSFULLY: $cachedCount/${scripts.length} ===',
      );
    } catch (e, stackTrace) {
      logger.e('=== ERROR CACHING SCRIPTS ===');
      logger.e('Error: $e');
      logger.e('Stack trace: $stackTrace');
      throw CacheException(
        message: 'Failed to cache scripts',
        originalError: e,
      );
    }
  }

  @override
  Future<bool> hasScripts() async {
    return scriptsBox.get(_hasCachedKey) == true;
  }

  @override
  Future<void> clearScripts() async {
    try {
      await scriptsBox.clear();
    } catch (e) {
      logger.e('Error clearing scripts', e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getWarmupScript(int warmupIndex) async {
    try {
      final key = '$_warmupKeyPrefix$warmupIndex';
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
  Future<void> cacheWarmupScripts(List<Map<String, dynamic>> scripts) async {
    try {
      logger.i('=== CACHING WARMUP SCRIPTS LOCALLY ===');
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

        if (index == null) {
          logger.e('Warmup script has invalid index: $rawIndex');
          continue;
        }

        final key = '$_warmupKeyPrefix$index';
        await scriptsBox.put(key, jsonEncode(script));
        cachedCount++;
      }
      logger.i('=== WARMUP SCRIPTS CACHED SUCCESSFULLY: $cachedCount/${scripts.length} ===');
    } catch (e, stackTrace) {
      logger.e('Error caching warmup scripts: $e');
      throw CacheException(message: 'Failed to cache warmup scripts', originalError: e);
    }
  }
}
