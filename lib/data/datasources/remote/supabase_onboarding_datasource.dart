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

  /// Fetch saved onboarding data for a user (for on-demand script generation).
  Future<UserPersonalInfo?> getOnboardingData(String userId);

  /// Sync updated script language preference to Supabase user_profiles.
  Future<void> updateLanguagePreference(String userId, String languageCode);
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
      if (e is PostgrestException) {
        throw ServerException(
          message: 'Failed to save onboarding data: ${e.message} (details: ${e.details})',
          code: e.code,
          originalError: e,
        );
      }
      throw ServerException(
        message: 'Failed to save onboarding data: $e',
        originalError: e,
      );
    }
  }

  @override
  Future<UserPersonalInfo?> getOnboardingData(String userId) async {
    try {
      logger.i('Fetching onboarding data for user $userId');

      final response =
          await client
              .from('user_profiles')
              .select()
              .eq('user_id', userId)
              .maybeSingle();

      if (response == null) {
        logger.w('No onboarding data found for user $userId');
        return null;
      }

      // Parse answers from JSON (prefer canonical 'onboarding_answers' column,
      // fallback to legacy 'answers' key if present)
      Map<String, List<String>> answers = {};
      final rawAnswers = response['onboarding_answers'] ?? response['answers'];
      if (rawAnswers is Map) {
        answers = rawAnswers.map((k, v) {
          final list = v is List
              ? v.map((e) => e.toString()).toList()
              : <String>[v.toString()];
          return MapEntry(k.toString(), list);
        });
      }

      // Prefer canonical 'goal_category' column written by UserPersonalInfo.toJson()
      final goalKey =
          (response['goal_category'] as String?)?.trim().isNotEmpty == true
              ? response['goal_category'] as String
              : (response['goal'] as String? ?? '');
      final customGoal = response['custom_goal'] as String?;

      // Resolve human-readable goal_text for non-custom goals so Week 2-5 prompts
      // receive meaningful goal descriptions instead of raw slugs like '10k_followers'
      String? resolvedGoalText;
      if ((customGoal == null || customGoal.trim().isEmpty) &&
          goalKey.isNotEmpty) {
        try {
          final goalRow =
              await client
                  .from('goal_options')
                  .select('goal_text')
                  .eq('goal_key', goalKey)
                  .maybeSingle();
          resolvedGoalText = goalRow?['goal_text'] as String?;
        } catch (_) {}
      }

      return UserPersonalInfo(
        firstName: response['first_name'] as String? ?? '',
        age: response['age'] as int? ?? 25,
        location: response['location'] as String? ?? '',
        goalKey: goalKey,
        customGoal: customGoal,
        resolvedGoalText: resolvedGoalText,
        languagePreference: response['language_preference'] as String? ?? 'en',
        answers: answers,
      );
    } catch (e) {
      logger.e('Error fetching onboarding data', e);
      return null;
    }
  }

  @override
  Future<void> updateLanguagePreference(
    String userId,
    String languageCode,
  ) async {
    try {
      await client
          .from('user_profiles')
          .update({'language_preference': languageCode})
          .eq('user_id', userId);
      logger.i('Synced language_preference=$languageCode to Supabase for $userId');
    } catch (e) {
      logger.w('Failed to sync language_preference to Supabase: $e');
    }
  }
}
