import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/logger.dart';
import '../../../data/datasources/remote/supabase_onboarding_datasource.dart';
import '../../../services/openai_service.dart';
import '../../../domain/repositories/script_repository.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

/// BLoC for handling dynamic onboarding flow.
class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  final SupabaseOnboardingDataSource onboardingDataSource;
  final ScriptRepository scriptRepository;
  final OpenAiService openAiService;

  /// Cache the last valid in-progress state for retry functionality
  OnboardingInProgress? _lastValidState;

  OnboardingBloc({
    required this.onboardingDataSource,
    required this.scriptRepository,
    required this.openAiService,
  }) : super(const OnboardingInitial()) {
    on<OnboardingStarted>(_onStarted);
    on<PersonalInfoUpdated>(_onPersonalInfoUpdated);
    on<GoalSelected>(_onGoalSelected);
    on<AnswerToggled>(_onAnswerToggled);
    on<OnboardingNextRequested>(_onNextRequested);
    on<OnboardingPreviousRequested>(_onPreviousRequested);
    on<OnboardingSubmitted>(_onSubmitted);
  }

  Future<void> _onStarted(
    OnboardingStarted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(const OnboardingLoading());

    try {
      // Load questions and goals from Supabase
      final questions = await onboardingDataSource.getQuestions();
      final goalOptions = await onboardingDataSource.getGoalOptions();

      logger.i(
        'Loaded ${questions.length} questions, ${goalOptions.length} goals',
      );

      // Total steps: personal info (1) + goal (1) + dynamic questions
      final totalSteps = 2 + questions.length;

      emit(
        OnboardingInProgress(
          userId: event.userId,
          currentStep: 0,
          totalSteps: totalSteps,
          questions: questions,
          goalOptions: goalOptions,
        ),
      );
    } catch (e) {
      logger.e('Failed to load onboarding data', e);
      emit(const OnboardingFailure('Failed to load. Please try again.'));
    }
  }

  void _onPersonalInfoUpdated(
    PersonalInfoUpdated event,
    Emitter<OnboardingState> emit,
  ) {
    if (state is OnboardingInProgress) {
      final current = state as OnboardingInProgress;
      emit(
        current.copyWith(
          firstName: event.firstName ?? current.firstName,
          age: event.age ?? current.age,
          location: event.location ?? current.location,
        ),
      );
    }
  }

  void _onGoalSelected(GoalSelected event, Emitter<OnboardingState> emit) {
    if (state is OnboardingInProgress) {
      final current = state as OnboardingInProgress;
      emit(
        current.copyWith(
          selectedGoal: event.goal,
          customGoal: event.customGoal,
        ),
      );
    }
  }

  void _onAnswerToggled(AnswerToggled event, Emitter<OnboardingState> emit) {
    if (state is OnboardingInProgress) {
      final current = state as OnboardingInProgress;
      final answers = Map<String, List<String>>.from(current.answers);

      final currentAnswers = List<String>.from(
        answers[event.questionKey] ?? [],
      );

      if (currentAnswers.contains(event.option)) {
        currentAnswers.remove(event.option);
      } else {
        // Check if question allows multi-select
        final question = current.questions.firstWhere(
          (q) => q.key == event.questionKey,
          orElse: () => current.questions.first,
        );

        if (!question.isMultiSelect) {
          currentAnswers.clear();
        }
        currentAnswers.add(event.option);
      }

      answers[event.questionKey] = currentAnswers;
      emit(current.copyWith(answers: answers));
    }
  }

  void _onNextRequested(
    OnboardingNextRequested event,
    Emitter<OnboardingState> emit,
  ) {
    if (state is OnboardingInProgress) {
      final current = state as OnboardingInProgress;

      if (!current.canProceed) {
        logger.w('Cannot proceed - validation failed');
        return;
      }

      if (current.currentStep < current.totalSteps - 1) {
        emit(current.copyWith(currentStep: current.currentStep + 1));
      }
    }
  }

  void _onPreviousRequested(
    OnboardingPreviousRequested event,
    Emitter<OnboardingState> emit,
  ) {
    if (state is OnboardingInProgress) {
      final current = state as OnboardingInProgress;
      if (current.currentStep > 0) {
        emit(current.copyWith(currentStep: current.currentStep - 1));
      }
    }
  }

  Future<void> _onSubmitted(
    OnboardingSubmitted event,
    Emitter<OnboardingState> emit,
  ) async {
    // Get the state to use - either current OnboardingInProgress or cached state for retry
    late OnboardingInProgress current;

    if (state is OnboardingInProgress) {
      current = state as OnboardingInProgress;
      _lastValidState = current; // Cache for potential retry
    } else if (_lastValidState != null) {
      // Retry scenario - use cached state
      current = _lastValidState!;
      logger.i('Using cached state for retry');
    } else {
      logger.e('No valid state for submission');
      emit(
        const OnboardingFailure('Unable to retry. Please restart onboarding.'),
      );
      return;
    }

    final personalInfo = current.toPersonalInfo();

    emit(
      const OnboardingGeneratingScripts(message: 'Saving your preferences...'),
    );

    try {
      // Save onboarding data to Supabase
      await onboardingDataSource.saveOnboardingData(
        current.userId,
        personalInfo,
      );

      // Check if scripts already exist for this user (avoid double OpenAI calls)
      final hasScripts = await scriptRepository.hasLocalScripts(current.userId);

      if (hasScripts) {
        logger.i('Scripts already exist, skipping OpenAI generation');
        _lastValidState = null; // Clear cache on success
        emit(const OnboardingComplete());
        return;
      }

      emit(
        const OnboardingGeneratingScripts(
          message: 'Creating your personalized 30-day scripts...',
        ),
      );

      // Generate scripts using OpenAI
      final goal =
          current.customGoal ??
          current.selectedGoal?.text ??
          'build camera confidence';

      final scripts = await openAiService.generateScripts(
        firstName: personalInfo.firstName,
        age: personalInfo.age,
        location: personalInfo.location,
        goal: goal,
        onboardingAnswers: personalInfo.answers.map((k, v) => MapEntry(k, v)),
      );

      logger.i('OpenAI generation complete: ${scripts.length} scripts');

      // Save scripts to repository
      logger.i('Saving scripts to repository...');
      final saveResult = await scriptRepository.saveGeneratedScripts(
        userId: current.userId,
        scripts: scripts,
      );

      // Check if save was successful
      saveResult.fold(
        (failure) {
          logger.e('Failed to save scripts: ${failure.message}');
          throw Exception('Failed to save scripts: ${failure.message}');
        },
        (_) {
          logger.i('Scripts saved successfully!');
        },
      );

      logger.i(
        'Onboarding complete - ${scripts.length} scripts generated and saved',
      );
      _lastValidState = null; // Clear cache on success
      emit(const OnboardingComplete());
    } catch (e) {
      logger.e('Onboarding error', e);
      // Keep _lastValidState so retry can use it
      emit(OnboardingFailure('Error: ${e.toString()}'));
    }
  }
}
