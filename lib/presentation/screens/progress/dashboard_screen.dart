import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/entities/user.dart';
import '../../../domain/entities/user_progress.dart';
import '../../bloc/progress/progress_bloc.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../bloc/warmup/warmup_event.dart';
import '../../bloc/warmup/warmup_state.dart';
import '../../widgets/dashboard/guide_section.dart';
import '../warmup/warmup_overview_screen.dart';
import '../challenge/day_list_screen.dart';
import '../challenge/day_challenge_overview_screen.dart';
import '../videos/my_videos_screen.dart';
import '../settings/settings_screen.dart';
import '../content_creator/widgets/content_creator_card.dart';
import '../beginner_challenge/widgets/beginner_challenge_card.dart';

/// Main dashboard screen redesigned to match the reference visual benchmark.
class DashboardScreen extends StatefulWidget {
  final User user;
  final bool isNewUser;

  const DashboardScreen({
    super.key,
    required this.user,
    required this.isNewUser,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressBloc>().add(ProgressLoaded(widget.user.id));
      context.read<WarmupBloc>().add(WarmupStatusLoaded(widget.user.id));
    });
  }

  void _onChallengeStarted() {
    context.read<ProgressBloc>().add(ProgressLoaded(widget.user.id));
    context.read<WarmupBloc>().add(WarmupStatusLoaded(widget.user.id));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: _buildBody(),
      bottomNavigationBar: SageBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          SageNavItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard_rounded,
            label: 'Home',
          ),
          SageNavItem(
            icon: Icons.calendar_today_outlined,
            activeIcon: Icons.calendar_today_rounded,
            label: 'Days',
          ),
          SageNavItem(
            icon: Icons.videocam_outlined,
            activeIcon: Icons.videocam_rounded,
            label: 'Videos',
          ),
          SageNavItem(
            icon: Icons.settings_outlined,
            activeIcon: Icons.settings_rounded,
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return IndexedStack(
      index: _currentIndex,
      children: [
        _buildHomeTab(),
        DayListScreen(userId: widget.user.id),
        MyVideosScreen(),
        SettingsScreen(),
      ],
    );
  }

  Widget _buildHomeTab() {
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          // Top header bar matching reference screenshot ("AmpereFlow" header style)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 16, 18, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ConfidentCam',
                          style: AppTypography.headingLarge(fontSize: 25),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Welcome back, ${widget.user.displayName ?? 'Creator'}',
                          style: AppTypography.body(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '30-Day Schedule',
                    onPressed: () => setState(() => _currentIndex = 1),
                    icon: Icon(
                      Icons.diamond_outlined,
                      color: AppColors.secondaryGreen,
                      size: 24,
                    ),
                  ),
                  GestureDetector(
                    onTap: () => setState(() => _currentIndex = 3),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: AppColors.cardSurface,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.divider,
                          width: 1.4,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          (widget.user.displayName ?? 'C')
                              .characters
                              .first
                              .toUpperCase(),
                          style: GoogleFonts.manrope(
                            color: AppColors.primaryOlive,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Hero open circular arc gauge matching the reference screenshot
          SliverToBoxAdapter(
            child: BlocBuilder<ProgressBloc, ProgressState>(
              builder: (context, state) {
                final progress = state is ProgressLoadSuccess
                    ? state.progress
                    : UserProgress(
                        userId: widget.user.id,
                        currentDay: 0,
                        streak: 0,
                        longestStreak: 0,
                        completedDays: [],
                      );
                return _buildHeroArcSection(progress);
              },
            ),
          ),

          // Active status banner card matching "Monitoring Active" card in reference screenshot
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 16),
              child: _buildStatusBannerSection(),
            ),
          ),

          // 2-Column metric & feature grid cards matching reference screenshot
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: _buildTwoColumnFeatureGrid(),
            ),
          ),

          // Quick Actions 2-column metric cards
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: _buildQuickActionsGrid(),
            ),
          ),

          // Creator's Guide Section
          SliverToBoxAdapter(child: GuideSection()),

          SliverToBoxAdapter(child: SizedBox(height: 36)),
        ],
      ),
    );
  }

  Widget _buildHeroArcSection(UserProgress progress) {
    final completedCount = progress.currentDay.clamp(0, 30);
    final activeDay = (completedCount + 1).clamp(1, 30);
    final ratio = completedCount > 0
        ? (completedCount / 30.0).clamp(0.15, 1.0)
        : 0.92;
    final percentage = ((completedCount / 30.0) * 100).round();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Center(
        child: OliveArcGauge(
          progress: ratio,
          primaryValue: completedCount > 0 ? '$percentage' : 'Day $activeDay',
          primaryUnit: completedCount > 0 ? '%' : '/30',
          statusLabel: completedCount >= 30
              ? 'CHALLENGE COMPLETE'
              : '30-DAY CHALLENGE',
          pillText: '${progress.streak}d Streak • Best ${progress.longestStreak}d',
          onTap: () => setState(() => _currentIndex = 1),
          size: 282,
        ),
      ),
    );
  }

  Widget _buildStatusBannerSection() {
    return BlocBuilder<ProgressBloc, ProgressState>(
      builder: (context, progressState) {
        final hasScripts =
            progressState is ProgressLoadSuccess && progressState.hasScripts;

        if (!hasScripts) {
          return SageStatusCard(
            title: 'Journey Ready to Start',
            subtitle:
                'Personalize your 30-day teleprompter scripts, warmups, and daily camera practice',
            actionLabel: 'Start',
            onActionTap: () {
              BeginnerChallengeCard.launchFlow(
                context,
                userId: widget.user.id,
                userName: widget.user.displayName,
                onChallengeStarted: _onChallengeStarted,
              );
            },
          );
        }

        return BlocBuilder<WarmupBloc, WarmupState>(
          builder: (context, warmupState) {
            if (warmupState is WarmupOverview &&
                !warmupState.allWarmupsComplete) {
              return SageStatusCard(
                title: 'Complete Warmups',
                subtitle:
                    '${warmupState.warmupsCompleted}/3 warmups done • Powers camera presence and vocal clarity',
                actionLabel: 'Continue',
                onActionTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => BlocProvider.value(
                        value: context.read<WarmupBloc>(),
                        child: WarmupOverviewScreen(
                          userName: widget.user.displayName,
                        ),
                      ),
                    ),
                  );
                },
              );
            }

            final progress = progressState.progress;
            final currentDay = progress.currentDay;
            final nextDay = (currentDay + 1).clamp(1, 30);
            final canRecord = progress.canRecordNextDay;
            final isComplete = progress.isChallengeComplete;

            if (isComplete) {
              return SageStatusCard(
                title: 'Challenge Complete!',
                subtitle:
                    'You finished all 30 days of camera confidence practice',
                actionLabel: 'Review',
                onActionTap: () => setState(() => _currentIndex = 1),
              );
            }

            if (!canRecord && currentDay > 0) {
              return SageStatusCard(
                title: 'Day $currentDay Complete',
                subtitle:
                    'Day $nextDay unlocks tomorrow • Consistency builds lasting confidence',
                actionLabel: 'Details',
                onActionTap: _showComeBackTomorrowDialog,
              );
            }

            return SageStatusCard(
              title: "Today's Challenge • Day $nextDay",
              subtitle:
                  'Powers daily speaking confidence, teleprompter flow, and self-review',
              actionLabel: 'Record',
              onActionTap: () => _navigateToDailyChallenge(nextDay),
            );
          },
        );
      },
    );
  }

  Widget _buildTwoColumnFeatureGrid() {
    return Row(
      children: [
        Expanded(
          child: ContentCreatorCard(userId: widget.user.id),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: BeginnerChallengeCard(
            userId: widget.user.id,
            userName: widget.user.displayName,
            onChallengeStarted: _onChallengeStarted,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    return BlocBuilder<ProgressBloc, ProgressState>(
      builder: (context, state) {
        final currentDay =
            state is ProgressLoadSuccess ? state.progress.currentDay : 0;
        final streak =
            state is ProgressLoadSuccess ? state.progress.streak : 0;
        final bestStreak =
            state is ProgressLoadSuccess ? state.progress.longestStreak : 0;

        return Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: SageMetricCard(
                    icon: Icons.calendar_today_outlined,
                    iconColor: AppColors.secondaryGreen,
                    label: 'SCHEDULE',
                    value: 'Day ${currentDay.clamp(0, 30)}/30',
                    onTap: () => setState(() => _currentIndex = 1),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SageMetricCard(
                    icon: Icons.local_fire_department_outlined,
                    iconColor: AppColors.error,
                    label: 'STREAK',
                    value: '$streak Days',
                    valueColor: streak > 0
                        ? AppColors.secondaryGreen
                        : AppColors.primaryText,
                    showWaveAccent: true,
                    waveColor: AppColors.error,
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Current streak: $streak days • Best streak: $bestStreak days',
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: SageMetricCard(
                    icon: Icons.emoji_events_outlined,
                    iconColor: AppColors.primaryOlive,
                    label: 'ACHIEVEMENTS',
                    value: 'Best ${bestStreak}d',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Achievements coming soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: SageMetricCard(
                    icon: Icons.help_outline_rounded,
                    iconColor: AppColors.secondaryGreen,
                    label: 'TIPS',
                    value: 'Coach Guide',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Tips coming soon!'),
                          duration: Duration(seconds: 1),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  void _showComeBackTomorrowDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.schedule_rounded,
              color: AppColors.primaryOlive,
              size: 24,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Great Job Today!',
                style: AppTypography.headingMedium(fontSize: 19),
              ),
            ),
          ],
        ),
        content: Text(
          "You've completed today's challenge!\n\nYour next day will unlock tomorrow. Consistency is key to building confidence!",
          style: AppTypography.body(),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Got It'),
          ),
        ],
      ),
    );
  }

  void _navigateToDailyChallenge(int dayNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayChallengeOverviewScreen(
          userId: widget.user.id,
          dayNumber: dayNumber,
        ),
      ),
    );
  }
}

extension on WarmupOverview {
  int get warmupsCompleted {
    int count = 0;
    if (warmup0Done) count++;
    if (warmup1Done) count++;
    if (warmup2Done) count++;
    return count;
  }
}
