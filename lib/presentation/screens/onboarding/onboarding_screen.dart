import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/prompt_config.dart';
import '../../../domain/entities/onboarding_data.dart';
import '../../bloc/onboarding/onboarding_bloc.dart';
import '../../bloc/onboarding/onboarding_event.dart';
import '../../bloc/onboarding/onboarding_state.dart';
import 'widgets/dynamic_question_step.dart';
import 'widgets/goal_selection_step.dart';
import 'widgets/personal_info_step.dart';
import 'widgets/script_generation_loading_screen.dart';


void _showErrorDialog(BuildContext context, String message) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder:
        (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1E1E2E),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red[400], size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Script Generation Failed',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              const Text(
                'Please check your internet connection and try again.',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).pop(); // Exit onboarding
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                // Retry - trigger the complete event again
                context.read<OnboardingBloc>().add(const OnboardingSubmitted());
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
  );
}

/// Dynamic onboarding screen with multi-select questions.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingComplete) {
          Navigator.of(context).pop(true);
        } else if (state is OnboardingFailure) {
          _showErrorDialog(context, state.message);
        }
      },
      builder: (context, state) {
        if (state is OnboardingLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (state is OnboardingGeneratingScripts) {
          return const ScriptGenerationLoadingScreen();
        }

        if (state is OnboardingInProgress) {
          return _OnboardingContent(state: state);
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

class _OnboardingContent extends StatelessWidget {
  final OnboardingInProgress state;

  const _OnboardingContent({required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading:
            state.currentStep > 0
                ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios),
                  onPressed: () {
                    context.read<OnboardingBloc>().add(
                      const OnboardingPreviousRequested(),
                    );
                  },
                )
                : IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
        title: Text('Step ${state.currentStep + 1} of ${state.totalSteps}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Skip'),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0F0F1A), Color(0xFF1E1E2E)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: (state.currentStep + 1) / state.totalSteps,
                  backgroundColor: Colors.white12,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),

                const SizedBox(height: 32),

                // Content based on step
                Expanded(child: _buildStepContent(context, state)),

                const SizedBox(height: 24),

                // Next/Submit button
                _buildActionButton(context, state),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, OnboardingInProgress state) {
    if (state.currentStep == 0) {
      return PersonalInfoStep(state: state);
    } else if (state.currentStep == 1) {
      return GoalSelectionStep(state: state);
    } else {
      // Dynamic question
      final question = state.currentQuestion;
      if (question != null) {
        return DynamicQuestionStep(state: state, question: question);
      }
      return const SizedBox.shrink();
    }
  }

  Widget _buildActionButton(BuildContext context, OnboardingInProgress state) {
    final isLastStep = state.currentStep == state.totalSteps - 1;
    final canProceed = state.canProceed;

    return ElevatedButton(
      onPressed:
          canProceed
              ? () {
                if (isLastStep) {
                  context.read<OnboardingBloc>().add(
                    const OnboardingSubmitted(),
                  );
                } else {
                  context.read<OnboardingBloc>().add(
                    const OnboardingNextRequested(),
                  );
                }
              }
              : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(
        isLastStep ? 'Generate My Scripts' : 'Continue',
        style: const TextStyle(fontSize: 18),
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

