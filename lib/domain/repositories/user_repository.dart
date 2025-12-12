import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/user_profile.dart';

/// Repository interface for user profile operations.
abstract class UserRepository {
  /// Get user profile.
  Future<Either<Failure, UserProfile?>> getProfile(String userId);

  /// Create user profile after onboarding.
  Future<Either<Failure, UserProfile>> createProfile({
    required String userId,
    required String goal,
    required String niche,
    required String fear,
    required String experience,
  });

  /// Update user profile.
  Future<Either<Failure, UserProfile>> updateProfile(UserProfile profile);

  /// Update display name.
  Future<Either<Failure, void>> updateDisplayName(
    String userId,
    String displayName,
  );
}
