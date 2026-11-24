import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/theme/app_theme.dart';
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
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Script Generation Failed',
              style: AppTypography.headingMedium(fontSize: 18),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: AppTypography.body()),
          const SizedBox(height: 12),
          Text(
            'Please check your internet connection and try again.',
            style: AppTypography.body(
              color: AppColors.mutedText,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(ctx).pop();
            context.read<OnboardingBloc>().add(OnboardingSubmitted());
          },
          child: Text('Retry'),
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
          return Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryOlive),
            ),
          );
        }

        if (state is OnboardingGeneratingScripts) {
          return ScriptGenerationLoadingScreen();
        }

        if (state is OnboardingInProgress) {
          return _OnboardingContent(state: state);
        }

        return Scaffold(
          backgroundColor: AppColors.background,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primaryOlive),
          ),
        );
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: state.currentStep > 0
            ? IconButton(
                icon: Icon(Icons.arrow_back_rounded),
                onPressed: () {
                  context.read<OnboardingBloc>().add(
                        OnboardingPreviousRequested(),
                      );
                },
              )
            : IconButton(
                icon: Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
        title: Text('Step ${state.currentStep + 1} of ${state.totalSteps}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  minHeight: 7,
                  value: (state.currentStep + 1) / state.totalSteps,
                  backgroundColor: AppColors.divider,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.primaryOlive,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Expanded(child: _buildStepContent(context, state)),
              const SizedBox(height: 20),
              _buildActionButton(context, state),
            ],
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
      onPressed: canProceed
          ? () {
              if (isLastStep) {
                context
                    .read<OnboardingBloc>()
                    .add(OnboardingSubmitted());
              } else {
                context
                    .read<OnboardingBloc>()
                    .add(OnboardingNextRequested());
              }
            }
          : null,
      child: Text(isLastStep ? 'Generate My Scripts' : 'Continue'),
    );
  }
}
