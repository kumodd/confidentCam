import 'package:dartz/dartz.dart';

import '../../core/error/exceptions.dart';
import '../../core/error/failures.dart';
import '../../core/network/network_info.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/repositories/user_repository.dart';
import '../datasources/remote/supabase_user_datasource.dart';
import '../models/user_profile_model.dart';

/// Implementation of UserRepository.
class UserRepositoryImpl implements UserRepository {
  final SupabaseUserDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  UserRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, UserProfile?>> getProfile(String userId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final data = await remoteDataSource.getProfile(userId);
      if (data == null) return const Right(null);

      return Right(UserProfileModel.fromJson(data));
    } on ServerException catch (e) {
      logger.e('Server error getting profile', e);
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      logger.e('Error getting profile', e);
      return const Left(ServerFailure(message: 'Failed to get profile'));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> createProfile({
    required String userId,
    required String goal,
    required String niche,
    required String fear,
    required String experience,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final data = {
        'user_id': userId,
        'goal': goal,
        'niche': niche,
        'fear': fear,
        'experience': experience,
        'timezone': DateTime.now().timeZoneName,
        'created_at': DateTime.now().toIso8601String(),
      };

      final result = await remoteDataSource.createProfile(data);
      return Right(UserProfileModel.fromJson(result));
    } on ServerException catch (e) {
      logger.e('Server error creating profile', e);
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      logger.e('Error creating profile', e);
      return const Left(ServerFailure(message: 'Failed to create profile'));
    }
  }

  @override
  Future<Either<Failure, UserProfile>> updateProfile(
    UserProfile profile,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      final model = UserProfileModel.fromEntity(profile);
      final result = await remoteDataSource.updateProfile(
        profile.userId,
        model.toJson(),
      );
      return Right(UserProfileModel.fromJson(result));
    } on ServerException catch (e) {
      logger.e('Server error updating profile', e);
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      logger.e('Error updating profile', e);
      return const Left(ServerFailure(message: 'Failed to update profile'));
    }
  }

  @override
  Future<Either<Failure, void>> updateDisplayName(
    String userId,
    String displayName,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure());
    }

    try {
      await remoteDataSource.updateDisplayName(userId, displayName);
      return const Right(null);
    } on ServerException catch (e) {
      logger.e('Server error updating display name', e);
      return Left(ServerFailure(message: e.message));
    } catch (e) {
      logger.e('Error updating display name', e);
      return const Left(ServerFailure(message: 'Failed to update name'));
    }
  }
}
