import 'package:equatable/equatable.dart';

import 'daily_completion.dart';

/// User progress entity tracking warmups, streak, and daily progress.
class UserProgress extends Equatable {
  final String userId;
  final bool warmup0Complete;
  final bool warmup1Complete;
  final bool warmup2Complete;
  final int currentDay;
  final int streak;
  final int longestStreak;
  final DateTime? lastCompletedDate;
  final DateTime? challengeStartedAt;
  final DateTime? challengeCompletedAt;
  final List<DailyCompletion> completedDays;

  const UserProgress({
    required this.userId,
    this.warmup0Complete = false,
    this.warmup1Complete = false,
    this.warmup2Complete = false,
    this.currentDay = 0,
    this.streak = 0,
    this.longestStreak = 0,
    this.lastCompletedDate,
    this.challengeStartedAt,
    this.challengeCompletedAt,
    this.completedDays = const [],
  });

  /// Check if all warmups are completed (alias)
  bool get warmupsComplete =>
      warmup0Complete && warmup1Complete && warmup2Complete;

  /// Check if all warmups are completed
  bool get allWarmupsComplete =>
      warmup0Complete && warmup1Complete && warmup2Complete;

  /// Get number of warmups completed
  int get warmupsCompleted {
    int count = 0;
    if (warmup0Complete) count++;
    if (warmup1Complete) count++;
    if (warmup2Complete) count++;
    return count;
  }

  /// Check if challenge is completed (Day 30 done)
  bool get isChallengeComplete => challengeCompletedAt != null;

  /// Check if a specific warmup is complete
  bool isWarmupComplete(int index) {
    switch (index) {
      case 0:
        return warmup0Complete;
      case 1:
        return warmup1Complete;
      case 2:
        return warmup2Complete;
      default:
        return false;
    }
  }

  /// Get next available warmup index (-1 if all done)
  int get nextWarmupIndex {
    if (!warmup0Complete) return 0;
    if (!warmup1Complete) return 1;
    if (!warmup2Complete) return 2;
    return -1;
  }

  /// Check if a specific day is unlocked
  /// Day unlocks only if:
  /// 1. All warmups complete
  /// 2. Day is <= currentDay (already completed), OR
  /// 3. Day is currentDay + 1 AND it's a new calendar day since last completion
  /// 4. DevMode is enabled (bypasses all restrictions)
  /// 5. Premium user can access without waiting
  bool isDayUnlocked(int day, {bool devMode = false, bool isPremium = false}) {
    if (day < 1 || day > 30) return false;
    if (!allWarmupsComplete) return false;

    // DevMode bypasses all day restrictions
    if (devMode) return true;

    // Already completed days are always unlocked
    if (day <= currentDay) return true;

    // Premium users can access next day without waiting
    if (isPremium && day == currentDay + 1) return true;

    // Next day (currentDay + 1) is only unlocked if it's a new calendar day
    if (day == currentDay + 1) {
      // If no days completed yet, day 1 is unlocked
      if (lastCompletedDate == null) return day == 1;

      // Check if today is a new day compared to lastCompletedDate (4:00 AM reset window)
      final now = DateTime.now();
      final logicalNow = now.subtract(const Duration(hours: 4));
      final logicalLastDate = lastCompletedDate!.subtract(const Duration(hours: 4));

      final today = DateTime(logicalNow.year, logicalNow.month, logicalNow.day);
      final lastDate = DateTime(logicalLastDate.year, logicalLastDate.month, logicalLastDate.day);

      return today.isAfter(lastDate);
    }

    return false;
  }

  /// Check if next day can be recorded today (new calendar day)
  bool get canRecordNextDay {
    if (!allWarmupsComplete) return false;
    if (currentDay >= 30) return false;

    // If no days completed yet, can start day 1
    if (lastCompletedDate == null) return true;

    final now = DateTime.now();
    final logicalNow = now.subtract(const Duration(hours: 4));
    final logicalLastDate = lastCompletedDate!.subtract(const Duration(hours: 4));

    final today = DateTime(logicalNow.year, logicalNow.month, logicalNow.day);
    final lastDate = DateTime(logicalLastDate.year, logicalLastDate.month, logicalLastDate.day);

    return today.isAfter(lastDate);
  }

  /// Check if a specific day is completed
  bool isDayCompleted(int day) {
    return day <= currentDay;
  }

  /// Get completion details for a specific day
  DailyCompletion? getCompletionForDay(int day) {
    try {
      return completedDays.firstWhere((c) => c.dayNumber == day);
    } catch (_) {
      return null;
    }
  }

  UserProgress copyWith({
    String? userId,
    bool? warmup0Complete,
    bool? warmup1Complete,
    bool? warmup2Complete,
    int? currentDay,
    int? streak,
    int? longestStreak,
    DateTime? lastCompletedDate,
    DateTime? challengeStartedAt,
    DateTime? challengeCompletedAt,
    List<DailyCompletion>? completedDays,
  }) {
    return UserProgress(
      userId: userId ?? this.userId,
      warmup0Complete: warmup0Complete ?? this.warmup0Complete,
      warmup1Complete: warmup1Complete ?? this.warmup1Complete,
      warmup2Complete: warmup2Complete ?? this.warmup2Complete,
      currentDay: currentDay ?? this.currentDay,
      streak: streak ?? this.streak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      challengeStartedAt: challengeStartedAt ?? this.challengeStartedAt,
      challengeCompletedAt: challengeCompletedAt ?? this.challengeCompletedAt,
      completedDays: completedDays ?? this.completedDays,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    warmup0Complete,
    warmup1Complete,
    warmup2Complete,
    currentDay,
    streak,
    longestStreak,
    lastCompletedDate,
    challengeStartedAt,
    challengeCompletedAt,
    completedDays,
  ];
}
