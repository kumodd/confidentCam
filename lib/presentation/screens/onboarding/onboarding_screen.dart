import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/config/prompt_config.dart';
import '../../../domain/entities/onboarding_data.dart';
import '../../bloc/onboarding/onboarding_bloc.dart';
import '../../bloc/onboarding/onboarding_event.dart';
import '../../bloc/onboarding/onboarding_state.dart';

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
          return const _ScriptGenerationLoadingScreen();
        }

        if (state is OnboardingInProgress) {
          return _OnboardingContent(state: state);
        }

        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      },
    );
  }
}

/// Animated loading screen with rotating motivational quotes
class _ScriptGenerationLoadingScreen extends StatefulWidget {
  const _ScriptGenerationLoadingScreen();

  @override
  State<_ScriptGenerationLoadingScreen> createState() =>
      _ScriptGenerationLoadingScreenState();
}

class _ScriptGenerationLoadingScreenState
    extends State<_ScriptGenerationLoadingScreen> {
  int _currentQuoteIndex = 0;

  static const _motivationalQuotes = [
    "Your voice matters. The world needs to hear it.",
    "Every expert was once a beginner.",
    "Confidence is a skill. You're building it now.",
    "The camera is your friend, not your critic.",
    "Small steps lead to big transformations.",
    "You're braver than you believe.",
    "Progress over perfection, always.",
    "Your unique perspective is your superpower.",
    "Today's discomfort is tomorrow's strength.",
    "You're not just recording. You're growing.",
    "Authenticity beats perfection every time.",
    "One video at a time, you'll get there.",
    "The only way out is through. Keep going.",
    "Your future self will thank you for starting.",
    "Embrace the awkward. It's part of the journey.",
  ];

  @override
  void initState() {
    super.initState();
    _startQuoteRotation();
  }

  void _startQuoteRotation() {
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _currentQuoteIndex =
              (_currentQuoteIndex + 1) % _motivationalQuotes.length;
        });
        _startQuoteRotation();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated loading indicator
                SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      const Color(0xFF6366F1).withValues(alpha: 0.8),
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 2000.ms),
                const SizedBox(height: 48),
                // Main message
                const Text(
                  'Creating Your Personalized Journey',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(duration: 600.ms),
                const SizedBox(height: 12),
                Text(
                  'Generating 30 unique scripts just for you...',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 16,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 300.ms),
                const SizedBox(height: 8),
                Text(
                  'This may take 2-3 minutes',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 500.ms),
                const SizedBox(height: 64),
                // Motivational quote with animation
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.format_quote,
                        color: const Color(0xFF6366F1).withValues(alpha: 0.5),
                        size: 32,
                      ),
                      const SizedBox(height: 16),
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 500),
                        child: Text(
                          _motivationalQuotes[_currentQuoteIndex],
                          key: ValueKey<int>(_currentQuoteIndex),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontStyle: FontStyle.italic,
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ).animate().fadeIn(delay: 800.ms).slideY(begin: 0.2, end: 0),
              ],
            ),
          ),
        ),
      ),
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

          const SizedBox(height: 24),

          // Language Selection
          if (widget.state.languageOptions.isNotEmpty) ...[
            Text(
              'Script Language',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Colors.white70,
              ),
            ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              'Choose the language for your daily scripts',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.white38,
              ),
            ).animate().fadeIn(delay: 475.ms, duration: 400.ms),
            const SizedBox(height: 12),
            _buildLanguageSelector(context).animate().fadeIn(delay: 500.ms, duration: 400.ms),
          ],

          const SizedBox(height: 32),

          // Script Style (PromptMode)
          Text(
            '🎭 Script Style',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 550.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'How would you like your scripts to feel?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white38,
            ),
          ).animate().fadeIn(delay: 575.ms, duration: 400.ms),
          const SizedBox(height: 12),
          _buildPromptModeSelector(context).animate().fadeIn(delay: 600.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Human Touch Level
          Text(
            '✨ Expression Style',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 650.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'How polished should your scripts sound?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white38,
            ),
          ).animate().fadeIn(delay: 675.ms, duration: 400.ms),
          const SizedBox(height: 12),
          _buildHumanTouchSelector(context).animate().fadeIn(delay: 700.ms, duration: 400.ms),

          const SizedBox(height: 24),

          // Audience Culture
          Text(
            '🌍 Cultural Context',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ).animate().fadeIn(delay: 750.ms, duration: 400.ms),
          const SizedBox(height: 8),
          Text(
            'Who is your primary audience?',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Colors.white38,
            ),
          ).animate().fadeIn(delay: 775.ms, duration: 400.ms),
          const SizedBox(height: 12),
          _buildCultureSelector(context).animate().fadeIn(delay: 800.ms, duration: 400.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPromptModeSelector(BuildContext context) {
    final options = [
      (PromptMode.selfDiscovery, '🌱 Self Discovery', 'Feel safe being seen'),
      (PromptMode.clarityTraining, '💭 Clarity Training', 'Clear thinking through speaking'),
      (PromptMode.storytelling, '📖 Storytelling', 'Connect through shared moments'),
      (PromptMode.authorityBuild, '🎯 Authority Build', 'Calm, grounded presence'),
      (PromptMode.rawDiary, '📓 Raw Diary', 'Honest expression without polish'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((option) {
        final isSelected = widget.state.promptMode == option.$1;
        return GestureDetector(
          onTap: () {
            context.read<OnboardingBloc>().add(
              PromptConfigUpdated(promptMode: option.$1),
            );
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : const Color(0xFF252538),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white10,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(option.$2, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                const SizedBox(height: 2),
                Text(option.$3, style: TextStyle(color: Colors.white38, fontSize: 11)),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildHumanTouchSelector(BuildContext context) {
    final options = [
      (HumanTouchLevel.raw, '🌊 Raw', 'Messy, real, unfiltered'),
      (HumanTouchLevel.natural, '🍃 Natural', 'Imperfect but flowing'),
      (HumanTouchLevel.composed, '🎭 Composed', 'Calm and controlled'),
    ];

    return Row(
      children: options.map((option) {
        final isSelected = widget.state.humanTouchLevel == option.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<OnboardingBloc>().add(
                PromptConfigUpdated(humanTouchLevel: option.$1),
              );
            },
            child: Container(
              margin: EdgeInsets.only(right: option.$1 != HumanTouchLevel.composed ? 8 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : const Color(0xFF252538),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white10,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(option.$2, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(option.$3, style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCultureSelector(BuildContext context) {
    final options = [
      (AudienceCulture.india, '🇮🇳 Indian Context', 'Quiet self-doubt, fear of judgement'),
      (AudienceCulture.global, '🌐 Global', 'Universal, no cultural specifics'),
    ];

    return Row(
      children: options.map((option) {
        final isSelected = widget.state.audienceCulture == option.$1;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              context.read<OnboardingBloc>().add(
                PromptConfigUpdated(audienceCulture: option.$1),
              );
            },
            child: Container(
              margin: EdgeInsets.only(right: option.$1 == AudienceCulture.india ? 8 : 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : const Color(0xFF252538),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white10,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(option.$2, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(option.$3, style: TextStyle(color: Colors.white38, fontSize: 10), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF252538),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LanguageOption>(
          value: widget.state.selectedLanguage,
          isExpanded: true,
          dropdownColor: const Color(0xFF252538),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white54),
          hint: const Text(
            'Select language',
            style: TextStyle(color: Colors.white38),
          ),
          items: widget.state.languageOptions.map((lang) {
            return DropdownMenuItem<LanguageOption>(
              value: lang,
              child: Row(
                children: [
                  Icon(
                    Icons.language,
                    color: Theme.of(context).colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          lang.nativeName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (lang.description != null)
                          Text(
                            lang.description!,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (lang) {
            if (lang != null) {
              context.read<OnboardingBloc>().add(LanguageSelected(lang));
            }
          },
        ),
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
