import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/prompt_config.dart';
import '../../../../domain/entities/onboarding_data.dart';
import '../../../bloc/onboarding/onboarding_bloc.dart';
import '../../../bloc/onboarding/onboarding_event.dart';
import '../../../bloc/onboarding/onboarding_state.dart';

/// Step 1: Personal Info (name, age, location)
class PersonalInfoStep extends StatefulWidget {
  final OnboardingInProgress state;

  const PersonalInfoStep({required this.state});

  @override
  State<PersonalInfoStep> createState() => PersonalInfoStepState();
}

class PersonalInfoStepState extends State<PersonalInfoStep> {
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
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(color: Colors.white70),
            ).animate().fadeIn(delay: 450.ms, duration: 400.ms),
            const SizedBox(height: 8),
            Text(
              'Choose the language for your daily scripts',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.white38),
            ).animate().fadeIn(delay: 475.ms, duration: 400.ms),
            const SizedBox(height: 12),
            _buildLanguageSelector(
              context,
            ).animate().fadeIn(delay: 500.ms, duration: 400.ms),
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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white38),
          ).animate().fadeIn(delay: 575.ms, duration: 400.ms),
          const SizedBox(height: 12),
          _buildPromptModeSelector(
            context,
          ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white38),
          ).animate().fadeIn(delay: 675.ms, duration: 400.ms),
          const SizedBox(height: 12),
          _buildHumanTouchSelector(
            context,
          ).animate().fadeIn(delay: 700.ms, duration: 400.ms),

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
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.white38),
          ).animate().fadeIn(delay: 775.ms, duration: 400.ms),
          const SizedBox(height: 12),
          _buildCultureSelector(
            context,
          ).animate().fadeIn(delay: 800.ms, duration: 400.ms),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPromptModeSelector(BuildContext context) {
    final options = [
      (PromptMode.selfDiscovery, '🌱 Self Discovery', 'Feel safe being seen'),
      (
        PromptMode.clarityTraining,
        '💭 Clarity Training',
        'Clear thinking through speaking',
      ),
      (
        PromptMode.storytelling,
        '📖 Storytelling',
        'Connect through shared moments',
      ),
      (
        PromptMode.authorityBuild,
        '🎯 Authority Build',
        'Calm, grounded presence',
      ),
      (PromptMode.rawDiary, '📓 Raw Diary', 'Honest expression without polish'),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children:
          options.map((option) {
            final isSelected = widget.state.promptMode == option.$1;
            return GestureDetector(
              onTap: () {
                context.read<OnboardingBloc>().add(
                  PromptConfigUpdated(promptMode: option.$1),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color:
                      isSelected
                          ? Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2)
                          : const Color(0xFF252538),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color:
                        isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white10,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      option.$2,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      option.$3,
                      style: TextStyle(color: Colors.white38, fontSize: 11),
                    ),
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
      children:
          options.map((option) {
            final isSelected = widget.state.humanTouchLevel == option.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  context.read<OnboardingBloc>().add(
                    PromptConfigUpdated(humanTouchLevel: option.$1),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: option.$1 != HumanTouchLevel.composed ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2)
                            : const Color(0xFF252538),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white10,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.$2,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        option.$3,
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
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
      (
        AudienceCulture.india,
        '🇮🇳 Indian Context',
        'Quiet self-doubt, fear of judgement',
      ),
      (AudienceCulture.global, '🌐 Global', 'Universal, no cultural specifics'),
    ];

    return Row(
      children:
          options.map((option) {
            final isSelected = widget.state.audienceCulture == option.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  context.read<OnboardingBloc>().add(
                    PromptConfigUpdated(audienceCulture: option.$1),
                  );
                },
                child: Container(
                  margin: EdgeInsets.only(
                    right: option.$1 == AudienceCulture.india ? 8 : 0,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.2)
                            : const Color(0xFF252538),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color:
                          isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white10,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        option.$2,
                        style: TextStyle(
                          color: isSelected ? Colors.white : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        option.$3,
                        style: TextStyle(color: Colors.white38, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
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
          items:
              widget.state.languageOptions.map((lang) {
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
