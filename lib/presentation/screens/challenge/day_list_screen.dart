import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_config.dart';
import '../../../core/config/remote_config_service.dart';
import '../../../core/di/injection_container.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/daily_completion.dart';
import '../../../domain/entities/user_progress.dart';
import '../../bloc/progress/progress_bloc.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../warmup/warmup_overview_screen.dart';
import 'day_challenge_overview_screen.dart';
import 'day_details_screen.dart';

/// Day list screen showing 30-day challenge grid in the sage & olive design system.
class DayListScreen extends StatelessWidget {
  final String userId;

  const DayListScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 16, 22, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '30-Day Challenge',
                      style: AppTypography.headingLarge(fontSize: 25),
                    ),
                    OlivePillBadge(
                      label: 'Daily Grid',
                      icon: Icons.calendar_today_outlined,
                    ),
                  ],
                ),
              ),
            ),

            // Summary status card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 16),
                child: BlocBuilder<ProgressBloc, ProgressState>(
                  builder: (context, state) {
                    final progress =
                        state is ProgressLoadSuccess ? state.progress : null;
                    final completed = progress?.currentDay ?? 0;
                    final warmupsDone = progress?.warmupsComplete ?? false;
                    return SageStatusCard(
                      title: warmupsDone
                          ? 'Progress: $completed of 30 Days'
                          : 'Warmups Required First',
                      subtitle: warmupsDone
                          ? 'Complete one video challenge each day to build lasting camera confidence'
                          : 'Finish all 3 warmups before unlocking Day 1 of the 30-day challenge',
                      actionLabel: warmupsDone ? 'Day ${(completed + 1).clamp(1, 30)}' : 'Warmups',
                      onActionTap: () {
                        if (!warmupsDone) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => BlocProvider.value(
                                value: context.read<WarmupBloc>(),
                                child: WarmupOverviewScreen(),
                              ),
                            ),
                          );
                        } else {
                          _openDay(
                            context,
                            (completed + 1).clamp(1, 30),
                            progress,
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            // 30-Day Grid inside a SageCard container
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
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
                        SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5,
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                        ),
                  );
                },
              ),
            ),

            // Legend
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: SageCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 14,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _LegendItem(
                        color: AppColors.secondaryGreen,
                        label: 'Complete',
                      ),
                      _LegendItem(
                        color: AppColors.primaryOlive,
                        label: 'Current',
                      ),
                      _LegendItem(
                        color: AppColors.divider,
                        label: 'Locked',
                      ),
                    ],
                  ),
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

    final remoteConfig =
        sl.isRegistered<RemoteConfigService>()
            ? sl<RemoteConfigService>()
            : null;
    final warmupsComplete = progress.warmupsComplete;
    final isCompleted = progress.isDayCompleted(day);
    final isUnlocked = progress.isDayUnlocked(
      day,
      devMode: remoteConfig?.devMode ?? AppConfig.devMode,
      isPremium: remoteConfig?.isPremiumUser ?? AppConfig.isPremiumUser,
    );
    final currentDay = progress.currentDay;

    if (!warmupsComplete) {
      _showLockedDayDialog(
        context,
        'Complete Warmups First!',
        'You need to complete all 3 warmup videos before starting the 30-day challenge.',
        'Go to Warmups',
        Icons.play_circle_outline_rounded,
        onAction: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => BlocProvider.value(
                value: context.read<WarmupBloc>(),
                child: WarmupOverviewScreen(),
              ),
            ),
          );
        },
      );
      return;
    }

    if (isCompleted) {
      final completion = progress.getCompletionForDay(day);
      _showCompletedDayDialog(context, day, completion, progress);
      return;
    }

    if (!isUnlocked) {
      if (day == currentDay + 1) {
        final now = DateTime.now();
        final lastDate = progress.lastCompletedDate;

        String message = 'Great job completing Day $currentDay!\n\n';
        if (lastDate != null) {
          final todayStart = DateTime(now.year, now.month, now.day);
          final lastDateStart = DateTime(
            lastDate.year,
            lastDate.month,
            lastDate.day,
          );

          if (todayStart.isAtSameMomentAs(lastDateStart)) {
            message +=
                'Day $day will unlock tomorrow. Come back then to continue your streak!';
          } else {
            message += 'Day $day is ready for you!';
          }
        } else {
          message += 'Day $day will unlock tomorrow.';
        }

        _showLockedDayDialog(
          context,
          'Come Back Tomorrow!',
          message,
          'Got It',
          Icons.schedule_rounded,
        );
      } else if (day > currentDay + 1) {
        _showLockedDayDialog(
          context,
          'Day $day Locked',
          'Complete Day ${currentDay + 1} first to unlock this day.\n\nOne day at a time - consistency is key!',
          'OK',
          Icons.lock_outline_rounded,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Complete Day ${day - 1} first!'),
          ),
        );
      }
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            DayChallengeOverviewScreen(userId: userId, dayNumber: day),
      ),
    );
  }

  void _showLockedDayDialog(
    BuildContext context,
    String title,
    String message,
    String buttonText,
    IconData icon, {
    VoidCallback? onAction,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: AppColors.primaryOlive, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: AppTypography.headingMedium(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(message, style: AppTypography.body()),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onAction?.call();
            },
            child: Text(buttonText),
          ),
        ],
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
      builder: (ctx) => AlertDialog(
        title: Text(
          'Day $day Completed!',
          style: AppTypography.headingMedium(fontSize: 19),
        ),
        content: Text(
          "You've already completed Day $day. What would you like to do?",
          style: AppTypography.body(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              if (completion != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DayDetailsScreen(
                      userId: userId,
                      dayNumber: day,
                      completion: completion,
                      progress: progress,
                    ),
                  ),
                );
              }
            },
            child: Text('View Details'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DayChallengeOverviewScreen(
                    userId: userId,
                    dayNumber: day,
                  ),
                ),
              );
            },
            child: Text('Record Again'),
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
    final remoteConfig =
        sl.isRegistered<RemoteConfigService>()
            ? sl<RemoteConfigService>()
            : null;
    final isUnlocked =
        progress?.isDayUnlocked(
          day,
          devMode: remoteConfig?.devMode ?? AppConfig.devMode,
          isPremium: remoteConfig?.isPremiumUser ?? AppConfig.isPremiumUser,
        ) ??
        false;
    final isCurrent = day == currentDay + 1 && warmupsComplete && isUnlocked;

    Color getBackgroundColor() {
      if (isComplete) return AppColors.navPill;
      if (isCurrent) return AppColors.primaryOlive;
      return AppColors.cardSurface;
    }

    Color getBorderColor() {
      if (isComplete) return AppColors.secondaryGreen;
      if (isCurrent) return AppColors.primaryOlive;
      return AppColors.divider;
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: getBackgroundColor(),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: getBorderColor(),
            width: isCurrent || isComplete ? 1.6 : 1.1,
          ),
        ),
        child: Center(
          child: isComplete
              ? Icon(
                  Icons.check_rounded,
                  color: AppColors.secondaryGreen,
                  size: 20,
                )
              : !isUnlocked
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$day',
                          style: GoogleFonts.manrope(
                            color: AppColors.mutedText,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Icon(
                          Icons.lock_outline_rounded,
                          color: AppColors.mutedText,
                          size: 12,
                        ),
                      ],
                    )
                  : Text(
                      '$day',
                      style: GoogleFonts.manrope(
                        color: isCurrent
                            ? AppColors.background
                            : AppColors.primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
        ),
      ),
    );
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
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: AppTypography.bodyStrong(
            color: AppColors.secondaryText,
            fontSize: 12.5,
          ),
        ),
      ],
    );
  }
}
