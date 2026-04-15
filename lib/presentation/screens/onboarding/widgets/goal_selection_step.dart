import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../bloc/onboarding/onboarding_bloc.dart';
import '../../../bloc/onboarding/onboarding_event.dart';
import '../../../bloc/onboarding/onboarding_state.dart';
import 'option_card.dart';

/// Step 2: Goal Selection
class GoalSelectionStep extends StatefulWidget {
  final OnboardingInProgress state;

  const GoalSelectionStep({required this.state});

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
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 8),

          Text(
            "We'll tailor your scripts to help you achieve this",
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Goal options
          ...widget.state.goalOptions.asMap().entries.map((entry) {
            final index = entry.key;
            final goal = entry.value;
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
                      customGoal:
                          goal.key == 'custom'
                              ? _customGoalController.text
                              : null,
                    ),
                  );
                },
              ),
            ).animate().fadeIn(delay: (150 + index * 50).ms, duration: 300.ms);
          }),

          // Custom goal input
          if (_showCustomInput) ...[
            const SizedBox(height: 16),
            TextField(
              controller: _customGoalController,
              onChanged: (value) {
                if (widget.state.selectedGoal?.key == 'custom') {
                  context.read<OnboardingBloc>().add(
                    GoalSelected(widget.state.selectedGoal!, customGoal: value),
                  );
                }
              },
              maxLines: 2,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Describe your custom goal...',
                hintStyle: const TextStyle(color: Colors.white38),
                filled: true,
                fillColor: const Color(0xFF1E1E2E),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ).animate().fadeIn(duration: 300.ms),
          ],
        ],
      ),
    );
  }
}
