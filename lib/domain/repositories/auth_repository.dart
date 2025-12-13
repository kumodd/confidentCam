import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/user.dart';

/// Repository interface for authentication operations.
abstract class AuthRepository {
  /// Send OTP to phone number.
  /// Returns [Right(void)] on success, [Left(Failure)] on error.
  Future<Either<Failure, void>> sendOtp(String phone);

  /// Verify OTP code.
  /// Returns [Right(User)] on success with user data (and whether new user).
  /// Returns [Left(Failure)] on error.
  Future<Either<Failure, (User, bool isNewUser)>> verifyOtp(
    String phone,
    String otp,
  );

  /// Check if user session is valid.
  /// Returns [Right(User)] if session valid, [Left(Failure)] if not.
  Future<Either<Failure, User>> checkSession();

  /// Logout current user.
  Future<Either<Failure, void>> logout();

  /// Delete user account.
  Future<Either<Failure, void>> deleteAccount();

  /// Sign up with email and password.
  /// Returns [Right((User, isNewUser))] on success.
  Future<Either<Failure, (User, bool isNewUser)>> signUpWithEmail(
    String email,
    String password, {
    String? phone,
  });

  /// Sign in with email and password.
  /// Returns [Right((User, isNewUser))] on success.
  Future<Either<Failure, (User, bool isNewUser)>> signInWithEmail(
    String email,
    String password,
  );

  /// Get current user ID if logged in.
  String? get currentUserId;
}
