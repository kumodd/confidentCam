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
    String? email,
    DateTime? createdAt,
  });

  /// Get cached session data.
  Future<Map<String, dynamic>?> getSession();

  /// Clear session data.
  Future<void> clearSession();

  /// Get cached user ID.
  String? get userId;

  /// Get persisted OTP failed attempt count for [identifier] (email or phone).
  int getOtpAttempts(String identifier);

  /// Get persisted OTP lockout expiry timestamp for [identifier], if any.
  DateTime? getOtpLockoutUntil(String identifier);

  /// Persist OTP failed attempt count and optional lockout expiry.
  Future<void> saveOtpAttemptState(
    String identifier, {
    required int attempts,
    DateTime? lockoutUntil,
  });

  /// Clear persisted OTP attempt count and lockout for [identifier].
  Future<void> clearOtpAttemptState(String identifier);
}

class HiveAuthDataSourceImpl implements HiveAuthDataSource {
  final Box authBox;

  HiveAuthDataSourceImpl({required this.authBox});

  String _normalizeIdentifier(String identifier) =>
      identifier.trim().toLowerCase();

  @override
  Future<void> saveSession({
    required String userId,
    required String phone,
    String? displayName,
    String? email,
    DateTime? createdAt,
  }) async {
    try {
      logger.d('Saving session for user $userId');
      await authBox.put(AppConstants.userIdKey, userId);
      await authBox.put(AppConstants.phoneKey, phone);
      if (displayName != null) {
        await authBox.put(AppConstants.displayNameKey, displayName);
      }
      if (email != null) {
        await authBox.put('email', email);
      }
      if (createdAt != null) {
        await authBox.put('created_at', createdAt.toIso8601String());
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
        'email': authBox.get('email'),
        'created_at': authBox.get('created_at'),
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
      await authBox.deleteAll([
        AppConstants.sessionTokenKey,
        AppConstants.userIdKey,
        AppConstants.phoneKey,
        AppConstants.displayNameKey,
        'email',
        'created_at',
      ]);
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

  @override
  int getOtpAttempts(String identifier) {
    final key = '${AppConstants.otpAttemptsPrefix}${_normalizeIdentifier(identifier)}';
    final raw = authBox.get(key);
    return raw is int ? raw : 0;
  }

  @override
  DateTime? getOtpLockoutUntil(String identifier) {
    final key =
        '${AppConstants.otpLockoutUntilPrefix}${_normalizeIdentifier(identifier)}';
    final raw = authBox.get(key);
    if (raw is String) {
      return DateTime.tryParse(raw);
    }
    return null;
  }

  @override
  Future<void> saveOtpAttemptState(
    String identifier, {
    required int attempts,
    DateTime? lockoutUntil,
  }) async {
    final normalized = _normalizeIdentifier(identifier);
    await authBox.put('${AppConstants.otpAttemptsPrefix}$normalized', attempts);
    final lockoutKey = '${AppConstants.otpLockoutUntilPrefix}$normalized';
    if (lockoutUntil != null) {
      await authBox.put(lockoutKey, lockoutUntil.toIso8601String());
    } else {
      await authBox.delete(lockoutKey);
    }
  }

  @override
  Future<void> clearOtpAttemptState(String identifier) async {
    final normalized = _normalizeIdentifier(identifier);
    await authBox.delete('${AppConstants.otpAttemptsPrefix}$normalized');
    await authBox.delete('${AppConstants.otpLockoutUntilPrefix}$normalized');
  }
}
