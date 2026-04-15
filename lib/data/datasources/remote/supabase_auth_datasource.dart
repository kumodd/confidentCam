import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/error/exceptions.dart' as app;
import '../../../core/utils/logger.dart';

/// Remote data source for authentication using Supabase.
abstract class SupabaseAuthDataSource {
  /// Send OTP to phone number.
  Future<void> sendOtp(String phone);

  /// Verify OTP code.
  /// Returns (user data, isNewUser).
  Future<(Map<String, dynamic>, bool)> verifyOtp(String phone, String otp);

  /// Sign up with email and password.
  Future<(Map<String, dynamic>, bool)> signUpWithEmail(
    String email,
    String password, {
    String? phone,
  });

  /// Sign in with email and password.
  Future<(Map<String, dynamic>, bool)> signInWithEmail(
    String email,
    String password,
  );

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
      await client.auth.signInWithOtp(phone: phone).timeout(AppConfig.apiTimeout);
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
      ).timeout(AppConfig.apiTimeout);

      if (response.user == null) {
        throw const app.AuthException(
          message: 'Verification failed',
          code: 'auth/verification-failed',
        );
      }

      final user = response.user!;
      logger.i('OTP verified for user: ${user.id}');

      // Fix #6: Use DB record existence as the authoritative isNewUser signal.
      // Supabase updates updatedAt on every session-refresh, making the
      // old (createdAt == updatedAt) heuristic unreliable for returning users.
      final existingUser = await client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(AppConfig.apiTimeout);

      final isNewUser = existingUser == null;
      logger.i('isNewUser (DB check): $isNewUser');

      if (isNewUser) {
        // Create user record
        logger.i('Creating new user record');
        final userData = {
          'id': user.id,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        };
        await client.from('users').insert(userData).timeout(AppConfig.apiTimeout);

        // Create initial progress record
        await client.from('user_progress').insert({'user_id': user.id}).timeout(AppConfig.apiTimeout);

        return (userData, true);
      }

      return (existingUser!, false);
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
  Future<(Map<String, dynamic>, bool)> signUpWithEmail(
    String email,
    String password, {
    String? phone,
  }) async {
    try {
      logger.i('📧 Starting email signup for: $email');
      if (phone != null) {
        logger.d('Phone provided: $phone');
      }
      logger.d('Calling Supabase auth.signUp...');

      final response = await client.auth.signUp(
        email: email,
        password: password,
      );

      logger.d('Supabase auth.signUp response received');

      if (response.user == null) {
        logger.e('❌ Email signup failed - no user in response');
        throw const app.AuthException(
          message: 'Sign up failed',
          code: 'auth/signup-failed',
        );
      }

      final user = response.user!;
      logger.i('✅ Auth user created successfully: ${user.id}');
      logger.d(
        'User email: ${user.email}, Confirmed: ${user.emailConfirmedAt != null}',
      );

      // Check if session exists (for immediate login without email confirmation)
      final session = response.session;

      if (session != null) {
        // User is logged in, create user record via edge function
        logger.d('Session exists, creating user record via edge function...');

        try {
          final edgeResponse = await client.functions.invoke(
            'create_user_record',
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
            body: {'email': email, 'phone': phone},
          );

          if (edgeResponse.status == 200) {
            final data = edgeResponse.data as Map<String, dynamic>;
            logger.i('✅ User record created via edge function');
            return (
              data['user'] as Map<String, dynamic>,
              data['isNew'] as bool,
            );
          } else {
            logger.w('⚠️ Edge function returned ${edgeResponse.status}');
            // Fall through to try polling
          }
        } catch (e) {
          logger.w('⚠️ Edge function failed: $e, trying polling...');
        }
      }

      // Fallback: Wait for database trigger or try polling (reduced to 3 attempts)
      logger.d('Checking for user record...');
      Map<String, dynamic>? userData;

      for (int i = 0; i < 3; i++) {
        await Future.delayed(const Duration(milliseconds: 300));
        logger.d('Checking for user record (attempt ${i + 1}/3)...');

        try {
          userData =
              await client
                  .from('users')
                  .select()
                  .eq('id', user.id)
                  .maybeSingle();

          if (userData != null) {
            logger.i('✅ User record found in database');
            break;
          }
        } catch (e) {
          logger.d('Check error (will retry): $e');
        }
      }

      // Fix #7: isNewUser must reflect whether we actually *found* or *created*
      // the record — not always hardcode true.
      final bool isActuallyNew = userData == null;

      if (isActuallyNew) {
        logger.i('📧 No user record yet - will be created on first sign in');
        userData = {
          'id': user.id,
          'email': email,
          'phone': phone,
          'created_at': DateTime.now().toIso8601String(),
        };
      }

      logger.i('📧 Email signup completed successfully (isNew=$isActuallyNew)');
      return (userData!, isActuallyNew);
    } on AuthException catch (e) {
      logger.e('❌ Supabase Auth error during email signup', e);
      logger.e('Error code: ${e.statusCode}, Message: ${e.message}');
      throw app.AuthException(
        message: e.message,
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      logger.e('❌ Unexpected error during email signup', e);
      throw app.ServerException(
        message: 'Failed to create account',
        originalError: e,
      );
    }
  }

  @override
  Future<(Map<String, dynamic>, bool)> signInWithEmail(
    String email,
    String password,
  ) async {
    try {
      logger.i('🔐 Starting email signin for: $email');
      logger.d('Calling Supabase auth.signInWithPassword...');

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      ).timeout(AppConfig.apiTimeout);

      logger.d('Supabase auth.signInWithPassword response received');

      if (response.user == null) {
        logger.e('❌ Email signin failed - no user in response');
        throw const app.AuthException(
          message: 'Sign in failed',
          code: 'auth/signin-failed',
        );
      }

      final user = response.user!;
      logger.i('✅ Auth signin successful: ${user.id}');
      logger.d(
        'Session created, access token present: ${response.session?.accessToken != null}',
      );

      // Get user from database
      logger.d('Fetching user record from database...');
      final existingUser = await client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle()
          .timeout(AppConfig.apiTimeout);

      if (existingUser != null) {
        logger.i('✅ User record found in database');
        logger.d('User data: $existingUser');
        return (existingUser, false);
      }

      // User exists in auth but not in database - create record
      logger.w('⚠️ User exists in auth but not in database - creating record');
      final userData = {
        'id': user.id,
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      };

      logger.d('Inserting user record...');
      await client.from('users').insert(userData);

      logger.d('Inserting user_progress record...');
      await client.from('user_progress').insert({'user_id': user.id});

      logger.i('✅ User and progress records created');
      logger.i('🔐 Email signin completed successfully');
      return (userData, true);
    } on AuthException catch (e) {
      logger.e('❌ Supabase Auth error during email signin', e);
      logger.e('Error code: ${e.statusCode}, Message: ${e.message}');

      String message = e.message;
      if (message.contains('Invalid login credentials')) {
        logger.d('Translating error message to user-friendly version');
        message = 'Invalid email or password';
      } else if (message.contains('Email not confirmed')) {
        logger.d('User email not confirmed yet');
        message = 'Please verify your email before signing in';
      }

      throw app.AuthException(
        message: message,
        code: e.statusCode,
        originalError: e,
      );
    } catch (e) {
      logger.e('❌ Unexpected error during email signin', e);
      throw app.ServerException(message: 'Failed to sign in', originalError: e);
    }
  }

  @override
  String? get currentUserId => client.auth.currentSession?.user.id;
}
