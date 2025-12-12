import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';

/// Remote data source for user profile operations.
abstract class SupabaseUserDataSource {
  /// Get user profile.
  Future<Map<String, dynamic>?> getProfile(String userId);

  /// Create user profile.
  Future<Map<String, dynamic>> createProfile(Map<String, dynamic> data);

  /// Update user profile.
  Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> data,
  );

  /// Update display name.
  Future<void> updateDisplayName(String userId, String displayName);
}

class SupabaseUserDataSourceImpl implements SupabaseUserDataSource {
  final SupabaseClient client;

  SupabaseUserDataSourceImpl({required this.client});

  @override
  Future<Map<String, dynamic>?> getProfile(String userId) async {
    try {
      logger.d('Fetching profile for user $userId');
      final response = await client
          .from(AppConstants.userProfilesTable)
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      logger.e('Error fetching profile', e);
      throw ServerException(
        message: 'Failed to fetch profile',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> createProfile(Map<String, dynamic> data) async {
    try {
      logger.i('Creating profile for user ${data['user_id']}');
      final response = await client
          .from(AppConstants.userProfilesTable)
          .insert(data)
          .select()
          .single();

      logger.i('Profile created successfully');
      return response;
    } catch (e) {
      logger.e('Error creating profile', e);
      throw ServerException(
        message: 'Failed to create profile',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>> updateProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    try {
      logger.i('Updating profile for user $userId');
      final response = await client
          .from(AppConstants.userProfilesTable)
          .update(data)
          .eq('user_id', userId)
          .select()
          .single();

      logger.i('Profile updated successfully');
      return response;
    } catch (e) {
      logger.e('Error updating profile', e);
      throw ServerException(
        message: 'Failed to update profile',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateDisplayName(String userId, String displayName) async {
    try {
      logger.i('Updating display name for user $userId');
      await client
          .from(AppConstants.usersTable)
          .update({
            'display_name': displayName,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', userId);

      logger.i('Display name updated successfully');
    } catch (e) {
      logger.e('Error updating display name', e);
      throw ServerException(
        message: 'Failed to update display name',
        originalError: e,
      );
    }
  }
}
