import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';

/// Remote data source for progress tracking operations.
abstract class SupabaseProgressDataSource {
  /// Get user progress.
  Future<Map<String, dynamic>?> getProgress(String userId);

  /// Update user progress.
  Future<Map<String, dynamic>> updateProgress(
    String userId,
    Map<String, dynamic> data,
  );

  /// Create daily completion.
  Future<Map<String, dynamic>> createCompletion(Map<String, dynamic> data);

  /// Get all completions for a user.
  Future<List<Map<String, dynamic>>> getCompletions(String userId);

  /// Get completion for a specific day.
  Future<Map<String, dynamic>?> getCompletionForDay(
    String userId,
    int dayNumber,
  );
}

class SupabaseProgressDataSourceImpl implements SupabaseProgressDataSource {
  final SupabaseClient client;
  final Uuid _uuid = const Uuid();

  SupabaseProgressDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>?> getProgress(String userId) async {
    try {
      logger.d('Fetching progress for user $userId');
      final response = await client
          .from(AppConstants.userProgressTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      logger.e('Error fetching progress', e);
      throw ServerException(
        message: 'Failed to fetch progress',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateProgress(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      logger.i('Updating progress for user $userId');
      final response = await client
          .from(AppConstants.userProgressTable)
          .update(data)
          .eq('user_id', userId)
          .select()
          .single();

      logger.i('Progress updated successfully');
      return response;
    } catch (e) {
      logger.e('Error updating progress', e);
      throw ServerException(
        message: 'Failed to update progress',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createCompletion(
    Map<String, dynamic> data,
  ) async {
    try {
      // Add ID if not present
      if (!data.containsKey('id')) {
        data['id'] = _uuid.v4();
      }

      logger.i('Creating completion for day ${data['day_number']}');
      final response = await client
          .from(AppConstants.dailyCompletionsTable)
          .insert(data)
          .select()
          .single();

      logger.i('Completion created successfully');
      return response;
    } catch (e) {
      logger.e('Error creating completion', e);
      throw ServerException(
        message: 'Failed to save completion',
        originalError: e,
      );
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getCompletions(String userId) async {
    try {
      logger.d('Fetching completions for user $userId');
      final response = await client
          .from(AppConstants.dailyCompletionsTable)
          .select()
          .eq('user_id', userId)
          .order('day_number');

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      logger.e('Error fetching completions', e);
      throw ServerException(
        message: 'Failed to fetch completions',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> getCompletionForDay(
    String userId,
    int dayNumber,
  ) async {
    try {
      logger.d('Fetching completion for day $dayNumber');
      final response = await client
          .from(AppConstants.dailyCompletionsTable)
          .select()
          .eq('user_id', userId)
          .eq('day_number', dayNumber)
          .maybeSingle();

      return response;
    } catch (e) {
      logger.e('Error fetching completion for day', e);
      throw ServerException(
        message: 'Failed to fetch completion',
        originalError: e,
      );
    }
  }
}
