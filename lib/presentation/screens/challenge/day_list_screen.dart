import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/daily_completion.dart';
import '../../../domain/entities/user_progress.dart';
import '../../bloc/daily_challenge/daily_challenge_bloc.dart';
import '../../bloc/daily_challenge/daily_challenge_event.dart';
import '../../bloc/progress/progress_bloc.dart';
import 'day_challenge_overview_screen.dart';
import 'day_details_screen.dart';

/// Day list screen showing 30-day challenge grid.
class DayListScreen extends StatelessWidget {
  final String userId;

  const DayListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
        ),
      ),
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            const SliverAppBar(
              floating: true,
              backgroundColor: Colors.transparent,
              title: Text('30-Day Challenge'),
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: BlocBuilder<ProgressBloc, ProgressState>(
                builder: (context, state) {
                  UserProgress? progress;
                  if (state is ProgressLoadSuccess) {
                    progress = state.progress;
                  }

                  return SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _DayCard(
                        day: index + 1,
                        progress: progress,
                        userId: userId,
                        onTap: () => _openDay(context, index + 1, progress),
                      ),
                      childCount: 30,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                        ),
                  );
                },
              ),
            ),
            // Legend
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _LegendItem(
                      color: const Color(0xFF22C55E),
                      label: 'Complete',
                    ),
                    const SizedBox(width: 24),
                    _LegendItem(
                      color: Theme.of(context).colorScheme.primary,
                      label: 'Current',
                    ),
                    const SizedBox(width: 24),
                    _LegendItem(color: Colors.white24, label: 'Locked'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDay(BuildContext context, int day, UserProgress? progress) {
    if (progress == null) return;

    final warmupsComplete = progress.warmupsComplete;
    final isCompleted = progress.isDayCompleted(day);
    final isUnlocked = progress.isDayUnlocked(day);
    final currentDay = progress.currentDay;

    // Check if warmups are complete first
    if (!warmupsComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Complete all warmups first!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // If day is completed, show options dialog
    if (isCompleted) {
      final completion = progress.getCompletionForDay(day);
      _showCompletedDayDialog(context, day, completion, progress);
      return;
    }

    // Check if day is unlocked (calendar day check)
    if (!isUnlocked) {
      // Check if it's the next day but not a new calendar day yet
      if (day == currentDay + 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Come back tomorrow to record this day!'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complete Day ${day - 1} first!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    // Navigate to day challenge overview for recording
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider(
              create:
                  (_) =>
                      sl<DailyChallengeBloc>()
                        ..add(DayLoaded(userId: userId, dayNumber: day)),
              child: DayChallengeOverviewScreen(userId: userId, dayNumber: day),
            ),
      ),
    );
  }

  void _showCompletedDayDialog(
    BuildContext context,
    int day,
    DailyCompletion? completion,
    UserProgress progress,
  ) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Text(
              'Day Already Completed! 🎉',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'You\'ve already completed Day $day. What would you like to do?',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Navigate to details if completion exists
                  if (completion != null) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => DayDetailsScreen(
                              userId: userId,
                              dayNumber: day,
                              completion: completion,
                              progress: progress,
                            ),
                      ),
                    );
                  }
                },
                child: const Text('View Details'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  // Navigate to re-record
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => BlocProvider(
                            create:
                                (_) =>
                                    sl<DailyChallengeBloc>()..add(
                                      DayLoaded(userId: userId, dayNumber: day),
                                    ),
                            child: DayChallengeOverviewScreen(
                              userId: userId,
                              dayNumber: day,
                            ),
                          ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF22C55E),
                ),
                child: const Text('Record Again'),
              ),
            ],
          ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final int day;
  final UserProgress? progress;
  final String userId;
  final VoidCallback onTap;

  const _DayCard({
    required this.day,
    required this.progress,
    required this.userId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final currentDay = progress?.currentDay ?? 0;
    final warmupsComplete = progress?.warmupsComplete ?? false;
    final isComplete =
        progress?.completedDays.any((c) => c.dayNumber == day) ?? false;
    final isUnlocked = progress?.isDayUnlocked(day) ?? false;
    final isCurrent = day == currentDay + 1 && warmupsComplete && isUnlocked;

    Color getBackgroundColor() {
      if (isComplete) return const Color(0xFF22C55E);
      if (isCurrent) return Theme.of(context).colorScheme.primary;
      return const Color(0xFF1E1E2E);
    }

    Color getBorderColor() {
      if (isComplete) return const Color(0xFF22C55E);
      if (isCurrent) return Theme.of(context).colorScheme.primary;
      if (isUnlocked) return Colors.white24;
      return Colors.white12;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: getBackgroundColor(),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: getBorderColor()),
          boxShadow:
              isCurrent
                  ? [
                    BoxShadow(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ]
                  : null,
        ),
        child: Center(
          child:
              isComplete
                  ? const Icon(Icons.check, color: Colors.white, size: 20)
                  : !isUnlocked
                  ? const Icon(Icons.lock, color: Colors.white24, size: 18)
                  : Text(
                    '$day',
                    style: TextStyle(
                      color: isCurrent ? Colors.white : Colors.white70,
                      fontWeight:
                          isCurrent ? FontWeight.bold : FontWeight.normal,
                      fontSize: isCurrent ? 16 : 14,
                    ),
                  ),
        ),
      ),
    ).animate().fadeIn(delay: (day * 20).ms, duration: 200.ms);
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: Colors.white54, fontSize: 12)),
      ],
    );
  }
}
