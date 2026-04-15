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

  // ---------------------------------------------------------------------------
  // OTP lockout persistence (Fix #8)
  // ---------------------------------------------------------------------------

  /// Increment the OTP attempt counter and return the new count.
  Future<int> incrementOtpAttempts();

  /// Return the current OTP attempt count.
  int get otpAttempts;

  /// Persist a lockout end timestamp.
  Future<void> setOtpLockout(DateTime lockedUntil);

  /// Return the lockout end timestamp, or null if not locked.
  DateTime? get otpLockoutUntil;

  /// Clear the OTP lockout state (called on successful verification or expiry).
  Future<void> clearOtpLockout();
}

class HiveAuthDataSourceImpl implements HiveAuthDataSource {
  final Box authBox;

  // Internal Hive key names
  static const _otpAttemptsKey = 'otp_attempts';
  static const _otpLockoutKey = 'otp_lockout_until';

  HiveAuthDataSourceImpl({required this.authBox});

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

  // ---------------------------------------------------------------------------
  // OTP lockout persistence implementation (Fix #8)
  // ---------------------------------------------------------------------------

  @override
  Future<int> incrementOtpAttempts() async {
    final current = otpAttempts;
    final newCount = current + 1;
    await authBox.put(_otpAttemptsKey, newCount);
    return newCount;
  }

  @override
  int get otpAttempts => authBox.get(_otpAttemptsKey, defaultValue: 0) as int;

  @override
  Future<void> setOtpLockout(DateTime lockedUntil) async {
    await authBox.put(_otpLockoutKey, lockedUntil.toIso8601String());
  }

  @override
  DateTime? get otpLockoutUntil {
    final raw = authBox.get(_otpLockoutKey) as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> clearOtpLockout() async {
    await authBox.delete(_otpAttemptsKey);
    await authBox.delete(_otpLockoutKey);
  }
}

