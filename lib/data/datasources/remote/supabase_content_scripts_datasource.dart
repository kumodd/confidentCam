import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/content_script.dart';

/// Supabase data source for content creator scripts.
/// Stores scripts in a dedicated 'content_scripts' table.
class SupabaseContentScriptsDataSource {
  final SupabaseClient _client;
  
  static const String _tableName = 'content_scripts';

  SupabaseContentScriptsDataSource({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  /// Get all content scripts for a user.
  Future<List<ContentScript>> getScripts(String userId) async {
    try {
      logger.d('Fetching content scripts from Supabase for user: $userId');

      final response = await _client
          .from(_tableName)
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final scripts = (response as List)
          .map((json) => _fromSupabaseJson(json as Map<String, dynamic>))
          .toList();

      logger.i('Fetched ${scripts.length} content scripts');
      return scripts;
    } catch (e) {
      logger.e('Error fetching content scripts', e);
      rethrow;
    }
  }

  /// Get a specific script by ID.
  Future<ContentScript?> getScriptById(String scriptId) async {
    try {
      final response = await _client
          .from(_tableName)
          .select()
          .eq('id', scriptId)
          .maybeSingle();

      if (response == null) return null;
      return _fromSupabaseJson(response);
    } catch (e) {
      logger.e('Error fetching script by id: $scriptId', e);
      return null;
    }
  }

  /// Save a script (insert or update via upsert).
  Future<ContentScript> saveScript(ContentScript script) async {
    try {
      logger.d('Saving content script to Supabase: ${script.id}');

      final data = _toSupabaseJson(script);
      
      final response = await _client
          .from(_tableName)
          .upsert(data)
          .select()
          .single();

      logger.i('Script saved successfully: ${script.id}');
      return _fromSupabaseJson(response);
    } catch (e) {
      logger.e('Error saving content script', e);
      rethrow;
    }
  }

  /// Delete a script by ID.
  Future<void> deleteScript(String scriptId) async {
    try {
      logger.d('Deleting content script: $scriptId');

      await _client.from(_tableName).delete().eq('id', scriptId);

      logger.i('Script deleted successfully: $scriptId');
    } catch (e) {
      logger.e('Error deleting content script', e);
      rethrow;
    }
  }

  /// Mark a script as recorded.
  Future<void> markAsRecorded(String scriptId) async {
    try {
      await _client.from(_tableName).update({
        'is_recorded': true,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', scriptId);

      logger.i('Script marked as recorded: $scriptId');
    } catch (e) {
      logger.e('Error marking script as recorded', e);
      rethrow;
    }
  }

  /// Clear all scripts for a user.
  Future<void> clearUserScripts(String userId) async {
    try {
      await _client.from(_tableName).delete().eq('user_id', userId);
      logger.i('Cleared all scripts for user: $userId');
    } catch (e) {
      logger.e('Error clearing user scripts', e);
      rethrow;
    }
  }

  /// Convert Supabase JSON (snake_case) to ContentScript entity.
  ContentScript _fromSupabaseJson(Map<String, dynamic> json) {
    return ContentScript(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      title: json['title'] as String,
      part1: json['part1'] as String? ?? '',
      part2: json['part2'] as String? ?? '',
      part3: json['part3'] as String? ?? '',
      promptTemplate: json['prompt_template'] as String?,
      questionnaire: json['questionnaire'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      isRecorded: json['is_recorded'] as bool? ?? false,
    );
  }

  /// Convert ContentScript entity to Supabase JSON (snake_case).
  Map<String, dynamic> _toSupabaseJson(ContentScript script) {
    return {
      'id': script.id,
      'user_id': script.userId,
      'title': script.title,
      'part1': script.part1,
      'part2': script.part2,
      'part3': script.part3,
      'prompt_template': script.promptTemplate,
      'questionnaire': script.questionnaire,
      'created_at': script.createdAt.toIso8601String(),
      'updated_at': script.updatedAt.toIso8601String(),
      'is_recorded': script.isRecorded,
    };
  }
}
