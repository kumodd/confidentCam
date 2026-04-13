import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/config/app_config.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';

/// Remote data source for script operations.
abstract class SupabaseScriptDataSource {
  /// Get all scripts for a user.
  Future<List<Map<String, dynamic>>> getScripts(String userId);

  /// Get script for a specific day.
  Future<Map<String, dynamic>?> getScriptForDay(String userId, int dayNumber);

  /// Save scripts (batch).
  Future<void> saveScripts(List<Map<String, dynamic>> scripts);

  /// Delete all scripts for a user.
  Future<void> deleteScripts(String userId);
}

class SupabaseScriptDataSourceImpl implements SupabaseScriptDataSource {
  final SupabaseClient client;

  SupabaseScriptDataSourceImpl({required this.client});

  @override
  Future<List<Map<String, dynamic>>> getScripts(String userId) async {
    try {
      logger.d('Fetching scripts for user $userId');
      final response = await client
          .from(AppConstants.dailyScriptsTable)
          .select()
          .eq('user_id', userId)
          .order('day_number')
          .timeout(AppConfig.apiTimeout);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      logger.e('Error fetching scripts', e);
      throw ServerException(
        message: 'Failed to fetch scripts',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> getScriptForDay(
    String userId,
    int dayNumber,
  ) async {
    try {
      logger.d('Fetching script for day $dayNumber');
      final response = await client
          .from(AppConstants.dailyScriptsTable)
          .select()
          .eq('user_id', userId)
          .eq('day_number', dayNumber)
          .maybeSingle()
          .timeout(AppConfig.apiTimeout);

      return response;
    } catch (e) {
      logger.e('Error fetching script for day', e);
      throw ServerException(
        message: 'Failed to fetch script',
        originalError: e,
      );
    }
  }

  @override
  Future<void> saveScripts(List<Map<String, dynamic>> scripts) async {
    try {
      logger.i('=== SAVING SCRIPTS TO SUPABASE ===');
      logger.i('Total scripts to save: ${scripts.length}');

      if (scripts.isNotEmpty) {
        logger.i('First script sample:');
        logger.i('  - id: ${scripts.first['id']}');
        logger.i('  - user_id: ${scripts.first['user_id']}');
        logger.i('  - day_number: ${scripts.first['day_number']}');
        logger.i('  - script_type: ${scripts.first['script_type']}');
        logger.i(
          '  - script_json keys: ${(scripts.first['script_json'] as Map?)?.keys.toList()}',
        );
      }

      await client
          .from(AppConstants.dailyScriptsTable)
          .upsert(scripts, onConflict: 'user_id,day_number')
          .timeout(AppConfig.apiTimeout);

      logger.i('=== SCRIPTS SAVED TO SUPABASE SUCCESSFULLY ===');
    } catch (e) {
      logger.e('=== FAILED TO SAVE SCRIPTS TO SUPABASE ===');
      logger.e('Error: $e');
      throw ServerException(
        message: 'Failed to save scripts',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteScripts(String userId) async {
    try {
      logger.i('Deleting scripts for user $userId');
      await client
          .from(AppConstants.dailyScriptsTable)
          .delete()
          .eq('user_id', userId)
          .timeout(AppConfig.apiTimeout);

      logger.i('Scripts deleted successfully');
    } catch (e) {
      logger.e('Error deleting scripts', e);
      throw ServerException(
        message: 'Failed to delete scripts',
        originalError: e,
      );
    }
  }
}
