import 'package:equatable/equatable.dart';

import '../../../core/config/prompt_config.dart';
import '../../../domain/entities/onboarding_data.dart';

/// Onboarding BLoC States
abstract class OnboardingState extends Equatable {
  const OnboardingState();

  @override
  List<Object?> get props => [];
}

/// Initial - loading questions
class OnboardingInitial extends OnboardingState {
  const OnboardingInitial();
}

/// Loading questions from Supabase
class OnboardingLoading extends OnboardingState {
  const OnboardingLoading();
}

/// Onboarding in progress with current step
class OnboardingInProgress extends OnboardingState {
  final String userId;
  final int currentStep; // 0=personal, 1=goal, 2+=dynamic questions
  final int totalSteps;

  // Questions loaded from Supabase
  final List<OnboardingQuestion> questions;
  final List<GoalOption> goalOptions;
  final List<LanguageOption> languageOptions;

  // User input
  final String? firstName;
  final int? age;
  final String? location;
  final LanguageOption? selectedLanguage;
  final GoalOption? selectedGoal;
  final String? customGoal;
  final Map<String, List<String>> answers; // questionKey -> selected options

  // Prompt configuration
  final PromptMode promptMode;
  final HumanTouchLevel humanTouchLevel;
  final AudienceCulture audienceCulture;

  const OnboardingInProgress({
    required this.userId,
    required this.currentStep,
    required this.totalSteps,
    required this.questions,
    required this.goalOptions,
    this.languageOptions = const [],
    this.firstName,
    this.age,
    this.location,
    this.selectedLanguage,
    this.selectedGoal,
    this.customGoal,
    this.answers = const {},
    this.promptMode = PromptMode.selfDiscovery,
    this.humanTouchLevel = HumanTouchLevel.natural,
    this.audienceCulture = AudienceCulture.india,
  });

  /// Check if current step can proceed
  bool get canProceed {
    if (currentStep == 0) {
      // Personal info - require name and age
      return firstName != null &&
          firstName!.isNotEmpty &&
          age != null &&
          age! > 0;
    }
    if (currentStep == 1) {
      // Goal selection
      return selectedGoal != null;
    }
    // Dynamic questions - require at least one selection
    final questionIndex = currentStep - 2;
    if (questionIndex < questions.length) {
      final question = questions[questionIndex];
      final selected = answers[question.key] ?? [];
      return selected.isNotEmpty;
    }
    return true;
  }

  /// Get current question (for dynamic questions)
  OnboardingQuestion? get currentQuestion {
    final questionIndex = currentStep - 2;
    if (questionIndex >= 0 && questionIndex < questions.length) {
      return questions[questionIndex];
    }
    return null;
  }

  /// Build UserPersonalInfo from current state
  UserPersonalInfo toPersonalInfo() {
    return UserPersonalInfo(
      firstName: firstName ?? '',
      age: age ?? 0,
      location: location ?? '',
      goalKey: selectedGoal?.key ?? '',
      customGoal: customGoal,
      answers: answers,
    );
  }

  OnboardingInProgress copyWith({
    String? userId,
    int? currentStep,
    int? totalSteps,
    List<OnboardingQuestion>? questions,
    List<GoalOption>? goalOptions,
    List<LanguageOption>? languageOptions,
    String? firstName,
    int? age,
    String? location,
    LanguageOption? selectedLanguage,
    GoalOption? selectedGoal,
    String? customGoal,
    Map<String, List<String>>? answers,
    PromptMode? promptMode,
    HumanTouchLevel? humanTouchLevel,
    AudienceCulture? audienceCulture,
  }) {
    return OnboardingInProgress(
      userId: userId ?? this.userId,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      questions: questions ?? this.questions,
      goalOptions: goalOptions ?? this.goalOptions,
      languageOptions: languageOptions ?? this.languageOptions,
      firstName: firstName ?? this.firstName,
      age: age ?? this.age,
      location: location ?? this.location,
      selectedLanguage: selectedLanguage ?? this.selectedLanguage,
      selectedGoal: selectedGoal ?? this.selectedGoal,
      customGoal: customGoal ?? this.customGoal,
      answers: answers ?? this.answers,
      promptMode: promptMode ?? this.promptMode,
      humanTouchLevel: humanTouchLevel ?? this.humanTouchLevel,
      audienceCulture: audienceCulture ?? this.audienceCulture,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    currentStep,
    totalSteps,
    questions,
    goalOptions,
    languageOptions,
    firstName,
    age,
    location,
    selectedLanguage,
    selectedGoal,
    customGoal,
    answers,
    promptMode,
    humanTouchLevel,
    audienceCulture,
  ];
}

/// Generating personalized scripts
class OnboardingGeneratingScripts extends OnboardingState {
  final String message;

  const OnboardingGeneratingScripts({
    this.message = 'Creating your personalized scripts...',
  });

  @override
  List<Object?> get props => [message];
}

/// Onboarding complete
class OnboardingComplete extends OnboardingState {
  const OnboardingComplete();
}

/// Onboarding failed
class OnboardingFailure extends OnboardingState {
  final String message;

  const OnboardingFailure(this.message);

  @override
  List<Object?> get props => [message];
}
