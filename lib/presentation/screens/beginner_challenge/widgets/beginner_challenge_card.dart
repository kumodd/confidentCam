import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/repositories/script_repository.dart';
import '../../../bloc/onboarding/onboarding_bloc.dart';
import '../../../bloc/onboarding/onboarding_event.dart';
import '../../../bloc/progress/progress_bloc.dart';
import '../../../bloc/warmup/warmup_bloc.dart';
import '../../../bloc/warmup/warmup_event.dart';
import '../../../bloc/warmup/warmup_state.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../warmup/warmup_overview_screen.dart';
import '../../challenge/day_challenge_overview_screen.dart';

/// Dashboard metric card for the 30-Day Beginner Challenge feature.
class BeginnerChallengeCard extends StatelessWidget {
  final String userId;
  final String? userName;
  final VoidCallback? onChallengeStarted;

  const BeginnerChallengeCard({
    super.key,
    required this.userId,
    this.userName,
    this.onChallengeStarted,
  });

  @override
  Widget build(BuildContext context) {
    return SageMetricCard(
      icon: Icons.rocket_launch_outlined,
      iconColor: AppColors.primaryOlive,
      label: 'CHALLENGE',
      value: '30-Day Plan',
      subtitle: 'Beginner Challenge',
      showWaveAccent: true,
      waveColor: AppColors.primaryOlive,
      onTap: () => launchFlow(
        context,
        userId: userId,
        userName: userName,
        onChallengeStarted: onChallengeStarted,
      ),
    );
  }

  static Future<void> launchFlow(
    BuildContext context, {
    required String userId,
    String? userName,
    VoidCallback? onChallengeStarted,
  }) async {
    final scriptRepository = sl<ScriptRepository>();

    final hasLocalScripts = await scriptRepository.hasLocalScripts(userId);
    final hasRemoteScripts = await scriptRepository.hasRemoteScripts(userId);
    final hasScripts = hasLocalScripts || hasRemoteScripts;

    if (!context.mounted) return;

    if (!hasScripts) {
      _navigateToOnboarding(
        context,
        userId: userId,
        onChallengeStarted: onChallengeStarted,
      );
    } else {
      _navigateToChallengeFlow(
        context,
        userId: userId,
        userName: userName,
      );
    }
  }

  static void _navigateToOnboarding(
    BuildContext context, {
    required String userId,
    VoidCallback? onChallengeStarted,
  }) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (_) => BlocProvider(
              create: (_) =>
                  sl<OnboardingBloc>()..add(OnboardingStarted(userId)),
              child: OnboardingScreen(),
            ),
          ),
        )
        .then((result) {
          if (result == true) {
            onChallengeStarted?.call();
          }
        });
  }

  static void _navigateToChallengeFlow(
    BuildContext context, {
    required String userId,
    String? userName,
  }) {
    final warmupBloc = context.read<WarmupBloc>();
    final warmupState = warmupBloc.state;

    if (warmupState is WarmupOverview && !warmupState.allWarmupsComplete) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: warmupBloc,
            child: WarmupOverviewScreen(userName: userName),
          ),
        ),
      );
    } else if (warmupState is AllWarmupsComplete ||
        (warmupState is WarmupOverview && warmupState.allWarmupsComplete)) {
      final progressState = context.read<ProgressBloc>().state;
      final nextDay = progressState is ProgressLoadSuccess
          ? (progressState.progress.currentDay + 1).clamp(1, 30)
          : 1;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DayChallengeOverviewScreen(
            userId: userId,
            dayNumber: nextDay,
          ),
        ),
      );
    } else {
      warmupBloc.add(WarmupStatusLoaded(userId));
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BlocProvider.value(
            value: warmupBloc,
            child: WarmupOverviewScreen(userName: userName),
          ),
        ),
      );
    }
  }
}
