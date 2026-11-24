import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/config/prompt_config.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/entities/onboarding_data.dart';
import '../../../bloc/onboarding/onboarding_bloc.dart';
import '../../../bloc/onboarding/onboarding_event.dart';
import '../../../bloc/onboarding/onboarding_state.dart';

/// Step 1: Personal Info (name, age, location)
class PersonalInfoStep extends StatefulWidget {
  final OnboardingInProgress state;

  const PersonalInfoStep({super.key, required this.state});

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
            style: AppTypography.headingLarge(fontSize: 24),
          ),
          const SizedBox(height: 6),
          Text(
            "We'll create custom scripts just for you",
            style: AppTypography.body(),
          ),
          const SizedBox(height: 22),

          SageCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _nameController,
                  label: 'FIRST NAME',
                  hint: 'Enter your first name',
                  icon: Icons.person_outline_rounded,
                  onChanged: (_) => _updateInfo(),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _ageController,
                  label: 'AGE',
                  hint: 'Enter your age',
                  icon: Icons.cake_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => _updateInfo(),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _locationController,
                  label: 'LOCATION (CITY/TOWN)',
                  hint: 'Where are you from?',
                  icon: Icons.location_on_outlined,
                  onChanged: (_) => _updateInfo(),
                ),
                if (widget.state.languageOptions.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'SCRIPT LANGUAGE',
                    style: AppTypography.uppercaseLabel(
                      fontSize: 11,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildLanguageSelector(context),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          SageCard(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCRIPT STYLE',
                  style: AppTypography.uppercaseLabel(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How would you like your scripts to feel?',
                  style: AppTypography.body(fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildPromptModeSelector(context),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'EXPRESSION STYLE',
                  style: AppTypography.uppercaseLabel(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'How polished should your scripts sound?',
                  style: AppTypography.body(fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildHumanTouchSelector(context),
                const SizedBox(height: 18),
                const Divider(),
                const SizedBox(height: 16),
                Text(
                  'CULTURAL CONTEXT',
                  style: AppTypography.uppercaseLabel(
                    fontSize: 11,
                    color: AppColors.secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Who is your primary audience?',
                  style: AppTypography.body(fontSize: 13),
                ),
                const SizedBox(height: 12),
                _buildCultureSelector(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromptModeSelector(BuildContext context) {
    final options = [
      (PromptMode.selfDiscovery, 'Self Discovery', 'Feel safe being seen'),
      (
        PromptMode.clarityTraining,
        'Clarity Training',
        'Clear thinking through speaking',
      ),
      (
        PromptMode.storytelling,
        'Storytelling',
        'Connect through shared moments',
      ),
      (
        PromptMode.authorityBuild,
        'Authority Build',
        'Calm, grounded presence',
      ),
      (PromptMode.rawDiary, 'Raw Diary', 'Honest expression without polish'),
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
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.olivePillFill
                  : AppColors.background,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryOlive
                    : AppColors.divider,
                width: isSelected ? 1.6 : 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  option.$2,
                  style: AppTypography.bodyStrong(
                    fontSize: 13.5,
                    color: isSelected
                        ? AppColors.primaryOlive
                        : AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  option.$3,
                  style: AppTypography.body(
                    color: AppColors.secondaryText,
                    fontSize: 11.5,
                  ),
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
      (HumanTouchLevel.raw, 'Raw', 'Real & unfiltered'),
      (HumanTouchLevel.natural, 'Natural', 'Flowing & warm'),
      (HumanTouchLevel.composed, 'Composed', 'Calm & controlled'),
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
              margin: EdgeInsets.only(
                right: option.$1 != HumanTouchLevel.composed ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.olivePillFill
                    : AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryOlive
                      : AppColors.divider,
                  width: isSelected ? 1.6 : 1.1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.$2,
                    style: AppTypography.bodyStrong(
                      fontSize: 13.5,
                      color: isSelected
                          ? AppColors.primaryOlive
                          : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.$3,
                    style: AppTypography.body(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
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
        'Indian Context',
        'Overcoming self-doubt & judgement',
      ),
      (AudienceCulture.global, 'Global', 'Universal audience context'),
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
              margin: EdgeInsets.only(
                right: option.$1 == AudienceCulture.india ? 8 : 0,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.olivePillFill
                    : AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primaryOlive
                      : AppColors.divider,
                  width: isSelected ? 1.6 : 1.1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    option.$2,
                    style: AppTypography.bodyStrong(
                      fontSize: 13.5,
                      color: isSelected
                          ? AppColors.primaryOlive
                          : AppColors.primaryText,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    option.$3,
                    style: AppTypography.body(
                      color: AppColors.secondaryText,
                      fontSize: 11,
                    ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.inputBorder,
        border: Border.all(color: AppColors.divider, width: 1.2),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<LanguageOption>(
          value: widget.state.selectedLanguage,
          isExpanded: true,
          dropdownColor: AppColors.background,
          style: AppTypography.bodyStrong(),
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            color: AppColors.secondaryText,
          ),
          hint: Text(
            'Select language',
            style: AppTypography.body(color: AppColors.mutedText),
          ),
          items: widget.state.languageOptions.map((lang) {
            return DropdownMenuItem<LanguageOption>(
              value: lang,
              child: Row(
                children: [
                  Icon(
                    Icons.language_rounded,
                    color: AppColors.primaryOlive,
                    size: 19,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      lang.nativeName,
                      style: AppTypography.bodyStrong(fontSize: 14.5),
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
          style: AppTypography.uppercaseLabel(
            fontSize: 11,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: AppTypography.bodyStrong(),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: AppColors.secondaryText, size: 20),
            hintText: hint,
            fillColor: AppColors.background,
          ),
        ),
      ],
    );
  }
}
