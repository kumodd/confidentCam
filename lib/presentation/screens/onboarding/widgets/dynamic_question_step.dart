import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../domain/entities/onboarding_data.dart';
import '../../../bloc/onboarding/onboarding_bloc.dart';
import '../../../bloc/onboarding/onboarding_event.dart';
import '../../../bloc/onboarding/onboarding_state.dart';
import 'option_card.dart';

/// Dynamic Question Step (multi-select from Supabase)
class DynamicQuestionStep extends StatelessWidget {
  final OnboardingInProgress state;
  final OnboardingQuestion question;

  const DynamicQuestionStep({required this.state, required this.question});

  @override
  Widget build(BuildContext context) {
    final selectedOptions = state.answers[question.key] ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionText,
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 8),

          Text(
            question.isMultiSelect
                ? 'Select all that apply'
                : 'Select one option',
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Options
          ...question.options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = selectedOptions.contains(option);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OptionCard(
                text: option,
                isSelected: isSelected,
                showCheckbox: question.isMultiSelect,
                onTap: () {
                  context.read<OnboardingBloc>().add(
                    AnswerToggled(questionKey: question.key, option: option),
                  );
                },
              ),
            ).animate().fadeIn(delay: (150 + index * 50).ms, duration: 300.ms);
          }),
        ],
      ),
    );
  }
}
