import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/di/injection_container.dart';
import '../../../../domain/repositories/script_repository.dart';
import '../../../bloc/onboarding/onboarding_bloc.dart';
import '../../../bloc/onboarding/onboarding_event.dart';
import '../../../bloc/warmup/warmup_bloc.dart';
import '../../../bloc/warmup/warmup_event.dart';
import '../../../bloc/warmup/warmup_state.dart';
import '../../onboarding/onboarding_screen.dart';
import '../../warmup/warmup_overview_screen.dart';
import '../../challenge/day_challenge_overview_screen.dart';

/// Dashboard card for the 30-Day Beginner Challenge feature.
/// This card encapsulates the entire onboarding → warmups → daily challenge flow.
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
    return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: GestureDetector(
            onTap: () => _handleCardTap(context),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFF22D3EE).withValues(alpha: 0.3),
                    const Color(0xFF06B6D4).withValues(alpha: 0.2),
                  ],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: const Color(0xFF22D3EE).withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF22D3EE).withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF22D3EE), Color(0xFF06B6D4)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Content
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Beginner Challenge',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '30-day confidence building journey',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  // Arrow
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
        .animate()
        .fadeIn(delay: 350.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Future<void> _handleCardTap(BuildContext context) async {
    final scriptRepository = sl<ScriptRepository>();

    // Check if scripts exist (either locally or remotely)
    final hasLocalScripts = await scriptRepository.hasLocalScripts(userId);
    final hasRemoteScripts = await scriptRepository.hasRemoteScripts(userId);
    final hasScripts = hasLocalScripts || hasRemoteScripts;

    if (!context.mounted) return;

    if (!hasScripts) {
      // No scripts - go through onboarding first
      _navigateToOnboarding(context);
    } else {
      // Scripts exist - go directly to warmup/challenge flow
      _navigateToChallengeFlow(context);
    }
  }

  void _navigateToOnboarding(BuildContext context) {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder:
                (_) => BlocProvider(
                  create:
                      (_) =>
                          sl<OnboardingBloc>()..add(OnboardingStarted(userId)),
                  child: const OnboardingScreen(),
                ),
          ),
        )
        .then((result) {
          if (result == true) {
            onChallengeStarted?.call();
          }
        });
  }

  void _navigateToChallengeFlow(BuildContext context) {
    // Check warmup state from parent context
    final warmupBloc = context.read<WarmupBloc>();
    final warmupState = warmupBloc.state;

    if (warmupState is WarmupOverview && !warmupState.allWarmupsComplete) {
      // Warmups not complete - go to warmup overview
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => BlocProvider.value(
                value: warmupBloc,
                child: WarmupOverviewScreen(userName: userName),
              ),
        ),
      );
    } else if (warmupState is AllWarmupsComplete ||
        (warmupState is WarmupOverview && warmupState.allWarmupsComplete)) {
      // Warmups complete - go to daily challenge
      // Get current day from ProgressBloc if available, default to day 1
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => DayChallengeOverviewScreen(
                userId: userId,
                dayNumber:
                    1, // Will be determined by the screen based on progress
              ),
        ),
      );
    } else {
      // Default: reload warmup state and navigate to warmup overview
      warmupBloc.add(WarmupStatusLoaded(userId));
      Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => BlocProvider.value(
                value: warmupBloc,
                child: WarmupOverviewScreen(userName: userName),
              ),
        ),
      );
    }
  }
}
