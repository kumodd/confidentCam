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
}

class HiveScriptsDataSourceImpl implements HiveScriptsDataSource {
  final Box scriptsBox;

  static const String _scriptsKeyPrefix = 'day_';
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
      logger.d('Caching ${scripts.length} scripts');

      for (final script in scripts) {
        final dayNumber = script['day_number'] as int;
        final key = '$_scriptsKeyPrefix$dayNumber';
        await scriptsBox.put(key, jsonEncode(script));
      }

      await scriptsBox.put(_hasCachedKey, true);
      logger.d('Scripts cached successfully');
    } catch (e) {
      logger.e('Error caching scripts', e);
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
}
