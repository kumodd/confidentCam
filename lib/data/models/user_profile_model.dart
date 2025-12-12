import '../../domain/entities/user_profile.dart';

/// Data model for UserProfile entity with JSON serialization.
class UserProfileModel extends UserProfile {
  const UserProfileModel({
    required super.userId,
    super.goal,
    super.niche,
    super.fear,
    super.experience,
    super.timezone,
    required super.createdAt,
  });

  factory UserProfileModel.fromJson(Map<String, dynamic> json) {
    return UserProfileModel(
      userId: json['user_id'] as String,
      goal: json['goal'] as String?,
      niche: json['niche'] as String?,
      fear: json['fear'] as String?,
      experience: json['experience'] as String?,
      timezone: json['timezone'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'goal': goal,
      'niche': niche,
      'fear': fear,
      'experience': experience,
      'timezone': timezone,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory UserProfileModel.fromEntity(UserProfile profile) {
    return UserProfileModel(
      userId: profile.userId,
      goal: profile.goal,
      niche: profile.niche,
      fear: profile.fear,
      experience: profile.experience,
      timezone: profile.timezone,
      createdAt: profile.createdAt,
    );
  }
}
