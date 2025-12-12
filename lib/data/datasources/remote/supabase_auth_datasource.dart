import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exceptions.dart' as app;
import '../../../core/utils/logger.dart';

/// Remote data source for authentication using Supabase.
abstract class SupabaseAuthDataSource {
  /// Send OTP to phone number.
  Future<void> sendOtp(String phone);

  /// Verify OTP code.
  /// Returns (user data, isNewUser).
  Future<(Map<String, dynamic>, bool)> verifyOtp(String phone, String otp);

  /// Get current session user.
  Future<Map<String, dynamic>?> getCurrentUser();

  /// Logout.
  Future<void> logout();

  /// Delete account.
  Future<void> deleteAccount();

  /// Get current user ID.
  String? get currentUserId;
}

class SupabaseAuthDataSourceImpl implements SupabaseAuthDataSource {
  final SupabaseClient client;

  SupabaseAuthDataSourceImpl({required this.client});

  @override
  Future<void> sendOtp(String phone) async {
    try {
      logger.i('Sending OTP to $phone');
      await client.auth.signInWithOtp(phone: phone);
      logger.i('OTP sent successfully');
    } on AuthException catch (e) {
      logger.e('Auth error sending OTP', e);
      throw app.AuthException(
        message: e.message,
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      logger.e('Error sending OTP', e);
      throw app.ServerException(
        message: 'Failed to send verification code',
        originalError: e,
      );
    }
  }

  @override
  Future<(Map<String, dynamic>, bool)> verifyOtp(
    String phone,
    String otp,
  ) async {
    try {
      logger.i('Verifying OTP for $phone');
      final response = await client.auth.verifyOTP(
        phone: phone,
        token: otp,
        type: OtpType.sms,
      );

      if (response.user == null) {
        throw const app.AuthException(
          message: 'Verification failed',
          code: 'auth/verification-failed',
        );
      }

      final user = response.user!;
      final isNewUser = user.createdAt == user.updatedAt;

      logger.i('OTP verified. New user: $isNewUser');

      // Check if user exists in users table
      final existingUser =
          await client.from('users').select().eq('id', user.id).maybeSingle();

      if (existingUser == null) {
        // Create user record
        logger.i('Creating new user record');
        final userData = {
          'id': user.id,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        };
        await client.from('users').insert(userData);

        // Create initial progress record
        await client.from('user_progress').insert({'user_id': user.id});

        return (userData, true);
      }

      return (existingUser, false);
    } on AuthException catch (e) {
      logger.e('Auth error verifying OTP', e);
      if (e.message.contains('expired')) {
        throw const app.AuthException(
          message: 'Code expired. Please request a new one.',
          code: 'auth/otp-expired',
        );
      }
      throw app.AuthException(
        message: e.message,
        code: e.statusCode,
        originalError: e,
      );
    } on app.AuthException {
      rethrow;
    } catch (e) {
      logger.e('Error verifying OTP', e);
      throw app.ServerException(
        message: 'Verification failed',
        originalError: e,
      );
    }
  }

  @override
  Future<Map<String, dynamic>?> getCurrentUser() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) return null;

      final userId = session.user.id;
      final user =
          await client.from('users').select().eq('id', userId).maybeSingle();

      return user;
    } catch (e) {
      logger.e('Error getting current user', e);
      return null;
    }
  }

  @override
  Future<void> logout() async {
    try {
      logger.i('Logging out');
      await client.auth.signOut();
      logger.i('Logged out successfully');
    } catch (e) {
      logger.e('Error logging out', e);
      throw app.ServerException(message: 'Failed to logout', originalError: e);
    }
  }

  @override
  Future<void> deleteAccount() async {
    try {
      final session = client.auth.currentSession;
      if (session == null) {
        throw const app.AuthException(
          message: 'No user logged in',
          code: 'auth/no-user',
        );
      }

      logger.i('Deleting account for user ${session.user.id}');

      // Call the Edge Function to delete account (requires admin privileges)
      final response = await client.functions.invoke(
        'delete_account',
        headers: {'Authorization': 'Bearer ${session.accessToken}'},
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Unknown error';
        logger.e('Edge function error: $error');
        throw app.ServerException(
          message: error.toString(),
          code: response.status.toString(),
        );
      }

      // Sign out locally after successful deletion
      await client.auth.signOut();

      logger.i('Account deleted successfully');
    } on app.AuthException {
      rethrow;
    } on app.ServerException {
      rethrow;
    } catch (e) {
      logger.e('Error deleting account', e);
      throw app.ServerException(
        message: 'Failed to delete account',
        originalError: e,
      );
    }
  }

  @override
  String? get currentUserId => client.auth.currentSession?.user.id;
}
