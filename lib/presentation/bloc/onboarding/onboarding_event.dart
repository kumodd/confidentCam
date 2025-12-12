import 'package:equatable/equatable.dart';

import '../../../domain/entities/onboarding_data.dart';

/// Onboarding BLoC Events
abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

/// Start onboarding - load questions from Supabase
class OnboardingStarted extends OnboardingEvent {
  final String userId;

  const OnboardingStarted(this.userId);

  @override
  List<Object?> get props => [userId];
}

/// Update personal info (name, age, location)
class PersonalInfoUpdated extends OnboardingEvent {
  final String? firstName;
  final int? age;
  final String? location;

  const PersonalInfoUpdated({this.firstName, this.age, this.location});

  @override
  List<Object?> get props => [firstName, age, location];
}

/// User selected a goal
class GoalSelected extends OnboardingEvent {
  final GoalOption goal;
  final String? customGoal;

  const GoalSelected(this.goal, {this.customGoal});

  @override
  List<Object?> get props => [goal, customGoal];
}

/// User toggled an option in multi-select question
class AnswerToggled extends OnboardingEvent {
  final String questionKey;
  final String option;

  const AnswerToggled({required this.questionKey, required this.option});

  @override
  List<Object?> get props => [questionKey, option];
}

/// Move to next step
class OnboardingNextRequested extends OnboardingEvent {
  const OnboardingNextRequested();
}

/// Move to previous step
class OnboardingPreviousRequested extends OnboardingEvent {
  const OnboardingPreviousRequested();
}

/// Submit all onboarding answers and generate scripts
class OnboardingSubmitted extends OnboardingEvent {
  const OnboardingSubmitted();
}
