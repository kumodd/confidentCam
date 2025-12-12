import 'package:equatable/equatable.dart';

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

  // User input
  final String? firstName;
  final int? age;
  final String? location;
  final GoalOption? selectedGoal;
  final String? customGoal;
  final Map<String, List<String>> answers; // questionKey -> selected options

  const OnboardingInProgress({
    required this.userId,
    required this.currentStep,
    required this.totalSteps,
    required this.questions,
    required this.goalOptions,
    this.firstName,
    this.age,
    this.location,
    this.selectedGoal,
    this.customGoal,
    this.answers = const {},
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
    String? firstName,
    int? age,
    String? location,
    GoalOption? selectedGoal,
    String? customGoal,
    Map<String, List<String>>? answers,
  }) {
    return OnboardingInProgress(
      userId: userId ?? this.userId,
      currentStep: currentStep ?? this.currentStep,
      totalSteps: totalSteps ?? this.totalSteps,
      questions: questions ?? this.questions,
      goalOptions: goalOptions ?? this.goalOptions,
      firstName: firstName ?? this.firstName,
      age: age ?? this.age,
      location: location ?? this.location,
      selectedGoal: selectedGoal ?? this.selectedGoal,
      customGoal: customGoal ?? this.customGoal,
      answers: answers ?? this.answers,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    currentStep,
    totalSteps,
    questions,
    goalOptions,
    firstName,
    age,
    location,
    selectedGoal,
    customGoal,
    answers,
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
