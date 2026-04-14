import 'package:dartz/dartz.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/network/network_info.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/local/hive_auth_datasource.dart';
import '../datasources/remote/supabase_auth_datasource.dart';
import '../models/user_model.dart';

/// Implementation of AuthRepository with network-aware operations.
class AuthRepositoryImpl implements AuthRepository {
  final SupabaseAuthDataSource remoteDataSource;
  final HiveAuthDataSource localDataSource;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, void>> sendOtp(String phone) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      await remoteDataSource.sendOtp(phone);
      return const Right(null);
    } on AuthException catch (e) {
      logger.e('Auth error sending OTP', e);
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      logger.e('Server error sending OTP', e);
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      logger.e('Unexpected error sending OTP', e);
      return const Left(
        ServerFailure(message: 'Failed to send verification code'),
      );
    }
  }

  @override
  Future<Either<Failure, (User, bool)>> verifyOtp(
    String phone,
    String otp,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final (userData, isNewUser) = await remoteDataSource.verifyOtp(
        phone,
        otp,
      );
      final user = UserModel.fromJson(userData);

      // Cache session locally
      await localDataSource.saveSession(
        userId: user.id,
        phone: user.phone ?? "",
        displayName: user.displayName,
        email: user.email,
        createdAt: user.createdAt,
      );

      return Right((user, isNewUser));
    } on AuthException catch (e) {
      logger.e('Auth error verifying OTP', e);

      if (e.code == 'auth/otp-expired') {
        return Left(AuthFailure.otpExpired());
      }

      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      logger.e('Server error verifying OTP', e);
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      logger.e('Unexpected error verifying OTP', e);
      return Left(AuthFailure.invalidOtp());
    }
  }

  @override
  Future<Either<Failure, User>> checkSession() async {
    try {
      // First check Supabase session if online
      if (await networkInfo.isConnected) {
        final userData = await remoteDataSource.getCurrentUser();
        if (userData != null) {
          final user = UserModel.fromJson(userData);

          // Update local cache
          await localDataSource.saveSession(
            userId: user.id,
            phone: user.phone ?? "",
            displayName: user.displayName,
            email: user.email,
            createdAt: user.createdAt,
          );

          return Right(user);
        }
      }

      // Fallback to local cache for offline support
      final cachedSession = await localDataSource.getSession();
      if (cachedSession != null && cachedSession['user_id'] != null) {
        // Restore createdAt from cache, fall back to epoch if missing
        final createdAtStr = cachedSession['created_at'] as String?;
        final createdAt = createdAtStr != null
            ? DateTime.tryParse(createdAtStr) ?? DateTime(2024)
            : DateTime(2024);
        return Right(
          User(
            id: cachedSession['user_id'] as String,
            phone: cachedSession['phone'] as String? ?? '',
            email: cachedSession['email'] as String?,
            displayName: cachedSession['display_name'] as String?,
            createdAt: createdAt,
          ),
        );
      }

      return Left(AuthFailure.sessionExpired());
    } catch (e) {
      logger.e('Error checking session', e);
      return Left(AuthFailure.sessionExpired());
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    try {
      // Clear local session first
      await localDataSource.clearSession();

      // Then logout from Supabase if online
      if (await networkInfo.isConnected) {
        await remoteDataSource.logout();
      }

      return const Right(null);
    } catch (e) {
      logger.e('Error during logout', e);
      // Still clear local session even if remote fails
      await localDataSource.clearSession();
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    if (!await networkInfo.isConnected) {
      return const Left(
        NetworkFailure(
          message: 'Internet connection required to delete account.',
        ),
      );
    }

    try {
      await remoteDataSource.deleteAccount();
      await localDataSource.clearSession();
      return const Right(null);
    } on ServerException catch (e) {
      logger.e('Server error deleting account', e);
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      logger.e('Error deleting account', e);
      return const Left(ServerFailure(message: 'Failed to delete account'));
    }
  }

  @override
  Future<Either<Failure, (User, bool)>> signUpWithEmail(
    String email,
    String password, {
    String? phone,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final (userData, isNewUser) = await remoteDataSource.signUpWithEmail(
        email,
        password,
        phone: phone,
      );
      final user = UserModel.fromJson(userData);

      // Cache session locally
      await localDataSource.saveSession(
        userId: user.id,
        phone: user.phone ?? "",
        displayName: user.displayName ?? "",
        email: user.email,
        createdAt: user.createdAt,
      );

      return Right((user, isNewUser));
    } on AuthException catch (e) {
      logger.e('Auth error during email sign up', e);
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      logger.e('Server error during email sign up', e);
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      logger.e('Unexpected error during email sign up', e);
      return const Left(ServerFailure(message: 'Failed to create account'));
    }
  }

  @override
  Future<Either<Failure, (User, bool)>> signInWithEmail(
    String email,
    String password,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final (userData, isNewUser) = await remoteDataSource.signInWithEmail(
        email,
        password,
      );
      final user = UserModel.fromJson(userData);

      // Cache session locally
      await localDataSource.saveSession(
        userId: user.id,
        phone: user.phone ?? "",
        displayName: user.displayName ?? "",
        email: user.email,
        createdAt: user.createdAt,
      );

      return Right((user, isNewUser));
    } on AuthException catch (e) {
      logger.e('Auth error during email sign in', e);
      return Left(AuthFailure(message: e.message, code: e.code));
    } on ServerException catch (e) {
      logger.e('Server error during email sign in', e);
      return Left(ServerFailure(message: e.message, code: e.code));
    } catch (e) {
      logger.e('Unexpected error during email sign in', e);
      return const Left(ServerFailure(message: 'Failed to sign in'));
    }
  }

  @override
  String? get currentUserId =>
      remoteDataSource.currentUserId ?? localDataSource.userId;
}
