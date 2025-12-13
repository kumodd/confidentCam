import '../../domain/entities/user_progress.dart';

/// Data model for UserProgress entity with JSON serialization.
class UserProgressModel extends UserProgress {
  const UserProgressModel({
    required super.userId,
    super.warmup0Complete = false,
    super.warmup1Complete = false,
    super.warmup2Complete = false,
    super.currentDay = 0,
    super.streak = 0,
    super.longestStreak = 0,
    super.lastCompletedDate,
    super.challengeStartedAt,
    super.challengeCompletedAt,
  });

  factory UserProgressModel.fromJson(Map<String, dynamic> json) {
    return UserProgressModel(
      userId: json['user_id'] as String,
      warmup0Complete: json['warmup_0_done'] as bool? ?? false,
      warmup1Complete: json['warmup_1_done'] as bool? ?? false,
      warmup2Complete: json['warmup_2_done'] as bool? ?? false,
      currentDay: json['current_day'] as int? ?? 0,
      streak: json['streak_count'] as int? ?? json['streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastCompletedDate:
          json['last_completion_date'] != null
              ? DateTime.parse(json['last_completion_date'] as String)
              : null,
      challengeStartedAt:
          json['challenge_started_at'] != null
              ? DateTime.parse(json['challenge_started_at'] as String)
              : null,
      challengeCompletedAt:
          json['challenge_completed_at'] != null
              ? DateTime.parse(json['challenge_completed_at'] as String)
              : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'warmup_0_done': warmup0Complete,
      'warmup_1_done': warmup1Complete,
      'warmup_2_done': warmup2Complete,
      'current_day': currentDay,
      'streak_count': streak,
      'longest_streak': longestStreak,
      'last_completion_date':
          lastCompletedDate?.toIso8601String().split('T')[0],
      'challenge_started_at': challengeStartedAt?.toIso8601String(),
      'challenge_completed_at': challengeCompletedAt?.toIso8601String(),
    };
  }

  factory UserProgressModel.fromEntity(UserProgress progress) {
    return UserProgressModel(
      userId: progress.userId,
      warmup0Complete: progress.warmup0Complete,
      warmup1Complete: progress.warmup1Complete,
      warmup2Complete: progress.warmup2Complete,
      currentDay: progress.currentDay,
      streak: progress.streak,
      longestStreak: progress.longestStreak,
      lastCompletedDate: progress.lastCompletedDate,
      challengeStartedAt: progress.challengeStartedAt,
      challengeCompletedAt: progress.challengeCompletedAt,
    );
  }

  factory UserProgressModel.initial(String userId) {
    return UserProgressModel(userId: userId);
  }

  /// Convert to local Hive storage format.
  Map<String, dynamic> toHiveJson() {
    return {
      'warmup_0_done': warmup0Complete,
      'warmup_1_done': warmup1Complete,
      'warmup_2_done': warmup2Complete,
      'current_day': currentDay,
      'streak_count': streak,
      'longest_streak': longestStreak,
      'last_completion_date': lastCompletedDate?.toIso8601String(),
      'challenge_started_at': challengeStartedAt?.toIso8601String(),
      'challenge_completed_at': challengeCompletedAt?.toIso8601String(),
    };
  }

  factory UserProgressModel.fromHiveJson(
    String userId,
    Map<String, dynamic> json,
  ) {
    return UserProgressModel(
      userId: userId,
      warmup0Complete: json['warmup_0_done'] as bool? ?? false,
      warmup1Complete: json['warmup_1_done'] as bool? ?? false,
      warmup2Complete: json['warmup_2_done'] as bool? ?? false,
      currentDay: json['current_day'] as int? ?? 0,
      streak: json['streak_count'] as int? ?? json['streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      lastCompletedDate:
          json['last_completion_date'] != null
              ? DateTime.parse(json['last_completion_date'] as String)
              : null,
      challengeStartedAt:
          json['challenge_started_at'] != null
              ? DateTime.parse(json['challenge_started_at'] as String)
              : null,
      challengeCompletedAt:
          json['challenge_completed_at'] != null
              ? DateTime.parse(json['challenge_completed_at'] as String)
              : null,
    );
  }
}
