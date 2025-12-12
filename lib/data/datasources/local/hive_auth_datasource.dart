import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';

/// Local data source for authentication using Hive.
abstract class HiveAuthDataSource {
  /// Save session data.
  Future<void> saveSession({
    required String userId,
    required String phone,
    String? displayName,
  });

  /// Get cached session data.
  Future<Map<String, dynamic>?> getSession();

  /// Clear session data.
  Future<void> clearSession();

  /// Get cached user ID.
  String? get userId;
}

class HiveAuthDataSourceImpl implements HiveAuthDataSource {
  final Box authBox;

  HiveAuthDataSourceImpl({required this.authBox});

  @override
  Future<void> saveSession({
    required String userId,
    required String phone,
    String? displayName,
  }) async {
    try {
      logger.d('Saving session for user $userId');
      await authBox.put(AppConstants.userIdKey, userId);
      await authBox.put(AppConstants.phoneKey, phone);
      if (displayName != null) {
        await authBox.put(AppConstants.displayNameKey, displayName);
      }
    } catch (e) {
      logger.e('Error saving session', e);
      throw CacheException(message: 'Failed to save session', originalError: e);
    }
  }

  @override
  Future<Map<String, dynamic>?> getSession() async {
    try {
      final userId = authBox.get(AppConstants.userIdKey);
      if (userId == null) return null;

      return {
        'user_id': userId,
        'phone': authBox.get(AppConstants.phoneKey),
        'display_name': authBox.get(AppConstants.displayNameKey),
      };
    } catch (e) {
      logger.e('Error getting session', e);
      return null;
    }
  }

  @override
  Future<void> clearSession() async {
    try {
      logger.d('Clearing session');
      await authBox.clear();
    } catch (e) {
      logger.e('Error clearing session', e);
      throw CacheException(
        message: 'Failed to clear session',
        originalError: e,
      );
    }
  }

  @override
  String? get userId => authBox.get(AppConstants.userIdKey);
}
