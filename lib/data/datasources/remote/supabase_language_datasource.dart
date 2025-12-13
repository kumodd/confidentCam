import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/logger.dart';
import '../../../domain/entities/onboarding_data.dart';

/// Supabase data source for language options.
class SupabaseLanguageDataSource {
  final SupabaseClient _client;

  SupabaseLanguageDataSource({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Fetch all active language options, ordered by order_index.
  Future<List<LanguageOption>> getLanguageOptions() async {
    try {
      logger.d('Fetching language options from Supabase');

      final response = await _client
          .from('language_options')
          .select()
          .eq('is_active', true)
          .order('order_index', ascending: true);

      final options =
          (response as List)
              .map(
                (json) => LanguageOption.fromJson(json as Map<String, dynamic>),
              )
              .toList();

      logger.i('Fetched ${options.length} language options');
      return options;
    } catch (e) {
      logger.e('Error fetching language options', e);
      rethrow;
    }
  }

  /// Get a specific language option by code.
  Future<LanguageOption?> getLanguageByCode(String languageCode) async {
    try {
      final response =
          await _client
              .from('language_options')
              .select()
              .eq('language_code', languageCode)
              .eq('is_active', true)
              .maybeSingle();

      if (response == null) return null;
      return LanguageOption.fromJson(response);
    } catch (e) {
      logger.e('Error fetching language by code: $languageCode', e);
      return null;
    }
  }
}
