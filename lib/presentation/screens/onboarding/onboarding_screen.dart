import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';

import '../../../domain/entities/onboarding_data.dart';
import '../../bloc/onboarding/onboarding_bloc.dart';
import '../../bloc/onboarding/onboarding_event.dart';
import '../../bloc/onboarding/onboarding_state.dart';

/// Dynamic onboarding screen with multi-select questions.
class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<OnboardingBloc, OnboardingState>(
      listener: (context, state) {
        if (state is OnboardingGeneratingScripts) {
          EasyLoading.show(status: state.message);
        } else if (state is OnboardingComplete) {
          EasyLoading.dismiss();
          Navigator.of(context).pop(true);
        } else if (state is OnboardingFailure) {
          EasyLoading.dismiss();
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        } else {
          EasyLoading.dismiss();
        }
      },
      builder: (context, state) {
        if (state is OnboardingLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
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
      return _PersonalInfoStep(state: state);
    } else if (state.currentStep == 1) {
      return _GoalSelectionStep(state: state);
    } else {
      // Dynamic question
      final question = state.currentQuestion;
      if (question != null) {
        return _DynamicQuestionStep(state: state, question: question);
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

/// Step 1: Personal Info (name, age, location)
class _PersonalInfoStep extends StatefulWidget {
  final OnboardingInProgress state;

  const _PersonalInfoStep({required this.state});

  @override
  State<_PersonalInfoStep> createState() => _PersonalInfoStepState();
}

class _PersonalInfoStepState extends State<_PersonalInfoStep> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _locationController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.state.firstName ?? '');
    _ageController = TextEditingController(
      text: widget.state.age?.toString() ?? '',
    );
    _locationController = TextEditingController(
      text: widget.state.location ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  void _updateInfo() {
    final age = int.tryParse(_ageController.text);
    context.read<OnboardingBloc>().add(
      PersonalInfoUpdated(
        firstName: _nameController.text.trim(),
        age: age,
        location: _locationController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Let's personalize your journey",
            style: Theme.of(context).textTheme.headlineMedium,
          ).animate().fadeIn(duration: 400.ms),

          const SizedBox(height: 8),

          Text(
            "We'll create custom scripts just for you",
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(color: Colors.white54),
          ).animate().fadeIn(delay: 100.ms, duration: 400.ms),

          const SizedBox(height: 32),

          // Name field
          _buildTextField(
            controller: _nameController,
            label: 'First Name',
            hint: 'Enter your first name',
            icon: Icons.person_outline,
            onChanged: (_) => _updateInfo(),
          ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

          const SizedBox(height: 20),

          // Age field
          _buildTextField(
            controller: _ageController,
            label: 'Age',
            hint: 'Enter your age',
            icon: Icons.cake_outlined,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => _updateInfo(),
          ).animate().fadeIn(delay: 300.ms, duration: 400.ms),

          const SizedBox(height: 20),

          // Location field
          _buildTextField(
            controller: _locationController,
            label: 'Location (City/Town)',
            hint: 'Where are you from?',
            icon: Icons.location_on_outlined,
            onChanged: (_) => _updateInfo(),
          ).animate().fadeIn(delay: 400.ms, duration: 400.ms),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: const TextStyle(color: Colors.white, fontSize: 16),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.white54),
            hintText: hint,
            filled: true,
            fillColor: const Color(0xFF1E1E2E),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Step 2: Goal Selection
class _GoalSelectionStep extends StatefulWidget {
  final OnboardingInProgress state;

  const _GoalSelectionStep({required this.state});

  @override
  State<_GoalSelectionStep> createState() => _GoalSelectionStepState();
}

class _GoalSelectionStepState extends State<_GoalSelectionStep> {
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
              child: _OptionCard(
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

/// Dynamic Question Step (multi-select from Supabase)
class _DynamicQuestionStep extends StatelessWidget {
  final OnboardingInProgress state;
  final OnboardingQuestion question;

  const _DynamicQuestionStep({required this.state, required this.question});

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
              child: _OptionCard(
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

/// Reusable option card widget
class _OptionCard extends StatelessWidget {
  final String text;
  final String? subtitle;
  final bool isSelected;
  final bool showCheckbox;
  final VoidCallback onTap;

  const _OptionCard({
    required this.text,
    this.subtitle,
    required this.isSelected,
    this.showCheckbox = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
                  : const Color(0xFF1E1E2E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color:
                isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.white12,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            if (showCheckbox) ...[
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white38,
                    width: 2,
                  ),
                ),
                child:
                    isSelected
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: isSelected ? Colors.white : Colors.white70,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: Colors.white38),
                    ),
                  ],
                ],
              ),
            ),
            if (!showCheckbox && isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }
}
