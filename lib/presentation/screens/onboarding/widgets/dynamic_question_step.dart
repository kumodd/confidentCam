import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/onboarding_data.dart';
import '../../../bloc/onboarding/onboarding_bloc.dart';
import '../../../bloc/onboarding/onboarding_event.dart';
import '../../../bloc/onboarding/onboarding_state.dart';
import 'option_card.dart';

/// Dynamic Question Step (multi-select from Supabase)
class DynamicQuestionStep extends StatelessWidget {
  final OnboardingInProgress state;
  final OnboardingQuestion question;

  const DynamicQuestionStep({
    super.key,
    required this.state,
    required this.question,
  });

  @override
  Widget build(BuildContext context) {
    final selectedOptions = state.answers[question.key] ?? [];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question.questionText,
            style: AppTypography.headingLarge(fontSize: 23),
          ),
          const SizedBox(height: 6),
          Text(
            question.isMultiSelect
                ? 'Select all that apply'
                : 'Select one option',
            style: AppTypography.body(),
          ),
          const SizedBox(height: 22),
          ...question.options.map((option) {
            final isSelected = selectedOptions.contains(option);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OptionCard(
                text: option,
                isSelected: isSelected,
                showCheckbox: question.isMultiSelect,
                onTap: () {
                  context.read<OnboardingBloc>().add(
                        AnswerToggled(
                          questionKey: question.key,
                          option: option,
                        ),
                      );
                },
              ),
            );
          }),
        ],
      ),
    );
  }
}
