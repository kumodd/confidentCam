import 'package:equatable/equatable.dart';

/// Achievement entity for gamification.
class Achievement extends Equatable {
  final String key;
  final String title;
  final String description;
  final String icon;
  final DateTime? unlockedAt;

  const Achievement({
    required this.key,
    required this.title,
    required this.description,
    required this.icon,
    this.unlockedAt,
  });

  bool get isUnlocked => unlockedAt != null;

  Achievement copyWith({
    String? key,
    String? title,
    String? description,
    String? icon,
    DateTime? unlockedAt,
  }) {
    return Achievement(
      key: key ?? this.key,
      title: title ?? this.title,
      description: description ?? this.description,
      icon: icon ?? this.icon,
      unlockedAt: unlockedAt ?? this.unlockedAt,
    );
  }

  @override
  List<Object?> get props => [key, title, description, icon, unlockedAt];
}

/// Predefined achievements for the app.
class Achievements {
  static const List<Achievement> all = [
    Achievement(
      key: 'first_step',
      title: 'First Step',
      description: 'Complete Warmup 1',
      icon: '👣',
    ),
    Achievement(
      key: 'warmed_up',
      title: 'Warmed Up',
      description: 'Complete all warmups',
      icon: '🌅',
    ),
    Achievement(
      key: 'day_one_done',
      title: 'Day One Done',
      description: 'Complete Day 1',
      icon: '1️⃣',
    ),
    Achievement(
      key: 'first_week',
      title: 'First Week',
      description: 'Complete Day 7',
      icon: '📅',
    ),
    Achievement(
      key: 'halfway',
      title: 'Halfway There',
      description: 'Complete Day 15',
      icon: '🎯',
    ),
    Achievement(
      key: 'almost_there',
      title: 'Almost There',
      description: 'Complete Day 25',
      icon: '🏃',
    ),
    Achievement(
      key: 'champion',
      title: 'Challenge Champion',
      description: 'Complete Day 30',
      icon: '🏆',
    ),
    Achievement(
      key: 'perfect_week',
      title: 'Perfect Week',
      description: '7-day streak',
      icon: '💪',
    ),
    Achievement(
      key: 'unstoppable',
      title: 'Unstoppable',
      description: '14-day streak',
      icon: '🚀',
    ),
    Achievement(
      key: 'legend',
      title: 'Legend',
      description: '30-day streak',
      icon: '👑',
    ),
    Achievement(
      key: 'night_owl',
      title: 'Night Owl',
      description: 'Record after 10 PM',
      icon: '🦉',
    ),
    Achievement(
      key: 'early_bird',
      title: 'Early Bird',
      description: 'Record before 7 AM',
      icon: '🐦',
    ),
    Achievement(
      key: 'retake_master',
      title: 'Retake Master',
      description: '5+ takes in one day',
      icon: '🎬',
    ),
  ];

  static Achievement? getByKey(String key) {
    try {
      return all.firstWhere((a) => a.key == key);
    } catch (e) {
      return null;
    }
  }
}
