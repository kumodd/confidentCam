import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../bloc/onboarding/onboarding_bloc.dart';
import '../../../bloc/onboarding/onboarding_event.dart';
import '../../../bloc/onboarding/onboarding_state.dart';
import 'option_card.dart';

/// Step 2: Goal Selection
class GoalSelectionStep extends StatefulWidget {
  final OnboardingInProgress state;

  const GoalSelectionStep({super.key, required this.state});

  @override
  State<GoalSelectionStep> createState() => GoalSelectionStepState();
}

class GoalSelectionStepState extends State<GoalSelectionStep> {
  late TextEditingController _customGoalController;
  bool _showCustomInput = false;

  @override
  void initState() {
    super.initState();
    _customGoalController = TextEditingController(
      text: widget.state.customGoal ?? '',
    );
    _showCustomInput = widget.state.selectedGoal?.key == 'custom';
  }

  @override
  void dispose() {
    _customGoalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "What's your main goal?",
            style: AppTypography.headingLarge(fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            "We'll tailor your scripts to help you achieve this",
            style: AppTypography.body(),
          ),
          const SizedBox(height: 22),
          ...widget.state.goalOptions.map((goal) {
            final isSelected = widget.state.selectedGoal?.key == goal.key;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: OptionCard(
                text: goal.text,
                subtitle: goal.description,
                isSelected: isSelected,
                onTap: () {
                  setState(() {
                    _showCustomInput = goal.key == 'custom';
                  });
                  context.read<OnboardingBloc>().add(
                        GoalSelected(
                          goal,
                          customGoal: goal.key == 'custom'
                              ? _customGoalController.text
                              : null,
                        ),
                      );
                },
              ),
            );
          }),
          if (_showCustomInput) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _customGoalController,
              onChanged: (value) {
                if (widget.state.selectedGoal?.key == 'custom') {
                  context.read<OnboardingBloc>().add(
                        GoalSelected(
                          widget.state.selectedGoal!,
                          customGoal: value,
                        ),
                      );
                }
              },
              maxLines: 2,
              style: AppTypography.bodyStrong(),
              decoration: const InputDecoration(
                hintText: 'Describe your custom goal...',
              ),
            ),
          ],
        ],
      ),
    );
  }
}
