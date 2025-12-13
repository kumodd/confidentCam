import 'dart:convert';

import 'package:hive/hive.dart';

import '../../../domain/entities/content_script.dart';

/// Local data source for content creator scripts using Hive.
/// Completely standalone from the existing HiveScriptsDataSource.
abstract class HiveContentScriptsDataSource {
  /// Get all content scripts for a user.
  Future<List<ContentScript>> getScripts(String userId);

  /// Get a specific script by ID.
  Future<ContentScript?> getScriptById(String scriptId);

  /// Save a script (create or update).
  Future<void> saveScript(ContentScript script);

  /// Delete a script by ID.
  Future<void> deleteScript(String scriptId);

  /// Mark a script as recorded.
  Future<void> markAsRecorded(String scriptId);

  /// Clear all scripts for a user.
  Future<void> clearUserScripts(String userId);
}

/// Implementation of HiveContentScriptsDataSource.
class HiveContentScriptsDataSourceImpl implements HiveContentScriptsDataSource {
  final Box contentScriptsBox;

  HiveContentScriptsDataSourceImpl({required this.contentScriptsBox});

  /// Key format: userId_scripts -> JSON list of scripts
  String _userKey(String userId) => '${userId}_content_scripts';

  @override
  Future<List<ContentScript>> getScripts(String userId) async {
    final key = _userKey(userId);
    final data = contentScriptsBox.get(key);

    if (data == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(data as String);
      return jsonList
          .map((json) => ContentScript.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<ContentScript?> getScriptById(String scriptId) async {
    // We need to search through all users - this is a simple implementation
    final allKeys = contentScriptsBox.keys.whereType<String>().toList();

    for (final key in allKeys) {
      if (!key.endsWith('_content_scripts')) continue;

      final data = contentScriptsBox.get(key);
      if (data == null) continue;

      try {
        final List<dynamic> jsonList = jsonDecode(data as String);
        for (final json in jsonList) {
          if (json['id'] == scriptId) {
            return ContentScript.fromJson(json as Map<String, dynamic>);
          }
        }
      } catch (e) {
        continue;
      }
    }

    return null;
  }

  @override
  Future<void> saveScript(ContentScript script) async {
    final key = _userKey(script.userId);
    final scripts = await getScripts(script.userId);

    // Check if updating existing script
    final existingIndex = scripts.indexWhere((s) => s.id == script.id);
    if (existingIndex >= 0) {
      scripts[existingIndex] = script;
    } else {
      scripts.add(script);
    }

    final jsonList = scripts.map((s) => s.toJson()).toList();
    await contentScriptsBox.put(key, jsonEncode(jsonList));
  }

  @override
  Future<void> deleteScript(String scriptId) async {
    final script = await getScriptById(scriptId);
    if (script == null) return;

    final key = _userKey(script.userId);
    final scripts = await getScripts(script.userId);
    scripts.removeWhere((s) => s.id == scriptId);

    final jsonList = scripts.map((s) => s.toJson()).toList();
    await contentScriptsBox.put(key, jsonEncode(jsonList));
  }

  @override
  Future<void> markAsRecorded(String scriptId) async {
    final script = await getScriptById(scriptId);
    if (script == null) return;

    final updatedScript = script.copyWith(
      isRecorded: true,
      updatedAt: DateTime.now(),
    );

    await saveScript(updatedScript);
  }

  @override
  Future<void> clearUserScripts(String userId) async {
    final key = _userKey(userId);
    await contentScriptsBox.delete(key);
  }
}
