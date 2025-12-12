import 'package:equatable/equatable.dart';

/// User profile entity containing onboarding information.
class UserProfile extends Equatable {
  final String userId;
  final String? goal;
  final String? niche;
  final String? fear;
  final String? experience;
  final String? timezone;
  final DateTime createdAt;

  const UserProfile({
    required this.userId,
    this.goal,
    this.niche,
    this.fear,
    this.experience,
    this.timezone,
    required this.createdAt,
  });

  UserProfile copyWith({
    String? userId,
    String? goal,
    String? niche,
    String? fear,
    String? experience,
    String? timezone,
    DateTime? createdAt,
  }) {
    return UserProfile(
      userId: userId ?? this.userId,
      goal: goal ?? this.goal,
      niche: niche ?? this.niche,
      fear: fear ?? this.fear,
      experience: experience ?? this.experience,
      timezone: timezone ?? this.timezone,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isComplete =>
      goal != null && niche != null && fear != null && experience != null;

  @override
  List<Object?> get props => [
    userId,
    goal,
    niche,
    fear,
    experience,
    timezone,
    createdAt,
  ];
}
