import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/di/injection_container.dart';
import '../../../domain/entities/user.dart';
import '../../bloc/onboarding/onboarding_bloc.dart';
import '../../bloc/onboarding/onboarding_event.dart';
import '../../bloc/progress/progress_bloc.dart';
import '../../bloc/warmup/warmup_bloc.dart';
import '../../bloc/warmup/warmup_event.dart';
import '../../bloc/warmup/warmup_state.dart';
import '../../widgets/dashboard/guide_section.dart';
import '../onboarding/onboarding_screen.dart';
import '../warmup/warmup_overview_screen.dart';
import '../challenge/day_list_screen.dart';
import '../challenge/day_challenge_overview_screen.dart';
import '../videos/my_videos_screen.dart';
import '../settings/settings_screen.dart';

/// Main dashboard screen after authentication.
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

    // Load data using existing BLoCs from parent
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProgressBloc>().add(ProgressLoaded(widget.user.id));
      context.read<WarmupBloc>().add(WarmupStatusLoaded(widget.user.id));

      // If new user, navigate to onboarding
      if (widget.isNewUser) {
        _navigateToOnboarding();
      }
    });
  }

  void _navigateToOnboarding() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BlocProvider(
              create:
                  (_) =>
                      sl<OnboardingBloc>()
                        ..add(OnboardingStarted(widget.user.id)),
              child: const OnboardingScreen(),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: _buildBody(), bottomNavigationBar: _buildBottomNav());
  }

  Widget _buildBody() {
    switch (_currentIndex) {
      case 0:
        return _buildHomeTab();
      case 1:
        return DayListScreen(userId: widget.user.id);
      case 2:
        return const MyVideosScreen();
      case 3:
        return const SettingsScreen();
      default:
        return _buildHomeTab();
    }
  }

  Widget _buildHomeTab() {
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
            // App bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back,',
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(color: Colors.white54),
                        ),
                        Text(
                          widget.user.displayName ?? 'Confident Creator',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        (widget.user.displayName ?? 'C')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(duration: 400.ms),
            ),

            // Progress card
            SliverToBoxAdapter(
              child: BlocBuilder<ProgressBloc, ProgressState>(
                builder: (context, state) {
                  if (state is ProgressLoadSuccess) {
                    return _buildProgressCard(state.progress);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            // Warmup or Today's challenge
            SliverToBoxAdapter(
              child: BlocBuilder<WarmupBloc, WarmupState>(
                builder: (context, state) {
                  if (state is WarmupOverview && !state.allWarmupsComplete) {
                    return _buildWarmupCard(state);
                  } else if (state is AllWarmupsComplete) {
                    return _buildTodaysChallengeCard();
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),

            // Quick actions
            SliverToBoxAdapter(child: _buildQuickActions()),

            // Guide Section
            const SliverToBoxAdapter(child: GuideSection()),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressCard(dynamic progress) {
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF6366F1), Color(0xFFA855F7)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('Day', '${progress.currentDay}/30'),
                _buildStatItem('Streak', '🔥 ${progress.streak}'),
                _buildStatItem('Best', '${progress.longestStreak} days'),
              ],
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 100.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildWarmupCard(WarmupOverview state) {
    return Padding(
          padding: const EdgeInsets.all(24),
          child: GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder:
                      (_) => BlocProvider.value(
                        value: context.read<WarmupBloc>(),
                        child: WarmupOverviewScreen(
                          userName: widget.user.displayName,
                        ),
                      ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF1E1E2E),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFF22D3EE).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      color: Color(0xFF22D3EE),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Complete Warmups',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${state.warmupsCompleted}/3 warmups done',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  int get warmupsCompleted {
    final state = context.read<WarmupBloc>().state;
    if (state is WarmupOverview) {
      int count = 0;
      if (state.warmup0Done) count++;
      if (state.warmup1Done) count++;
      if (state.warmup2Done) count++;
      return count;
    }
    return 0;
  }

  Widget _buildTodaysChallengeCard() {
    return BlocBuilder<ProgressBloc, ProgressState>(
      builder: (context, progressState) {
        final currentDay =
            progressState is ProgressLoadSuccess
                ? progressState.progress.currentDay + 1
                : 1;

        return GestureDetector(
          onTap: () => _navigateToDailyChallenge(currentDay),
          child: Padding(
                padding: const EdgeInsets.all(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.3),
                        Theme.of(
                          context,
                        ).colorScheme.secondary.withValues(alpha: 0.2),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(
                          Icons.videocam_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Today's Challenge - Day $currentDay",
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to start recording',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .animate()
              .fadeIn(delay: 200.ms, duration: 400.ms)
              .slideY(begin: 0.2, end: 0),
        );
      },
    );
  }

  void _navigateToDailyChallenge(int dayNumber) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (_) => DayChallengeOverviewScreen(
              userId: widget.user.id,
              dayNumber: dayNumber,
            ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick Actions', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.calendar_today_rounded,
                  label: 'Schedule',
                  color: const Color(0xFFF472B6),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.emoji_events_rounded,
                  label: 'Achievements',
                  color: const Color(0xFFFBBF24),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildQuickActionButton(
                  icon: Icons.help_outline_rounded,
                  label: 'Tips',
                  color: const Color(0xFF22D3EE),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Home', 0),
              _buildNavItem(Icons.calendar_month_rounded, 'Days', 1),
              _buildNavItem(Icons.video_library_rounded, 'Videos', 2),
              _buildNavItem(Icons.settings_rounded, 'Settings', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;

    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration:
            isSelected
                ? BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                )
                : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color:
                  isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.white54,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color:
                    isSelected
                        ? Theme.of(context).colorScheme.primary
                        : Colors.white54,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ],
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
