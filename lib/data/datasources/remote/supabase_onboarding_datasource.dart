import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/exceptions.dart';
import '../../../core/utils/logger.dart';
import '../../../domain/entities/onboarding_data.dart';

/// Data source for fetching onboarding questions and goals from Supabase.
abstract class SupabaseOnboardingDataSource {
  /// Fetch all active onboarding questions.
  Future<List<OnboardingQuestion>> getQuestions();

  /// Fetch all active goal options.
  Future<List<GoalOption>> getGoalOptions();

  /// Fetch all active language options.
  Future<List<LanguageOption>> getLanguageOptions();

  /// Save user's onboarding data to profile.
  Future<void> saveOnboardingData(String userId, UserPersonalInfo data);
}

class SupabaseOnboardingDataSourceImpl implements SupabaseOnboardingDataSource {
  final SupabaseClient client;

  SupabaseOnboardingDataSourceImpl({required this.client});

  @override
  Future<List<OnboardingQuestion>> getQuestions() async {
    try {
      logger.i('Fetching onboarding questions');

      final response = await client
          .from('onboarding_questions')
          .select()
          .eq('is_active', true)
          .order('order_index');

      final questions =
          (response as List)
              .map((e) => OnboardingQuestion.fromJson(e))
              .toList();

      logger.i('Fetched ${questions.length} questions');
      return questions;
    } catch (e) {
      logger.e('Error fetching questions', e);
      throw ServerException(
        message: 'Failed to load questions',
        originalError: e,
      );
    }
  }

  @override
  Future<List<GoalOption>> getGoalOptions() async {
    try {
      logger.i('Fetching goal options');

      final response = await client
          .from('goal_options')
          .select()
          .eq('is_active', true)
          .order('order_index');

      final goals =
          (response as List).map((e) => GoalOption.fromJson(e)).toList();

      logger.i('Fetched ${goals.length} goal options');
      return goals;
    } catch (e) {
      logger.e('Error fetching goals', e);
      throw ServerException(message: 'Failed to load goals', originalError: e);
    }
  }

  @override
  Future<List<LanguageOption>> getLanguageOptions() async {
    try {
      logger.i('Fetching language options');

      final response = await client
          .from('language_options')
          .select()
          .eq('is_active', true)
          .order('order_index');

      final languages =
          (response as List).map((e) => LanguageOption.fromJson(e)).toList();

      logger.i('Fetched ${languages.length} language options');
      return languages;
    } catch (e) {
      logger.e('Error fetching languages', e);
      // Return default languages if table doesn't exist yet
      return _getDefaultLanguages();
    }
  }

  List<LanguageOption> _getDefaultLanguages() {
    return const [
      LanguageOption(
        id: '1',
        code: 'en',
        name: 'English',
        nativeName: 'English',
        description: 'Pure English content',
        orderIndex: 1,
      ),
      LanguageOption(
        id: '2',
        code: 'hi',
        name: 'Hindi',
        nativeName: 'हिन्दी',
        description: 'Pure Hindi content',
        orderIndex: 2,
      ),
      LanguageOption(
        id: '3',
        code: 'hinglish',
        name: 'Hinglish',
        nativeName: 'हिंग्लिश',
        description: 'Mix of Hindi + English - perfect for Indian creators!',
        isBilingual: true,
        primaryLanguage: 'hi',
        secondaryLanguage: 'en',
        orderIndex: 3,
      ),
    ];
  }

  @override
  Future<void> saveOnboardingData(String userId, UserPersonalInfo data) async {
    try {
      logger.i('Saving onboarding data for user $userId');

      await client.from('user_profiles').upsert({
        'user_id': userId,
        ...data.toJson(),
      });

      logger.i('Onboarding data saved');
    } catch (e) {
      logger.e('Error saving onboarding data', e);
      throw ServerException(
        message: 'Failed to save onboarding data',
        originalError: e,
      );
    }
  }
}
