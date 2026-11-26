import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/prompt_config.dart';
import '../core/network/network_helper.dart';
import '../core/utils/logger.dart';

/// Service for generating personalized 30-day challenge & warmup scripts via
/// the unified Supabase `generate-script` Edge Function (Structured Outputs,
/// all 12 database languages, zero OpenAI keys in client builds).
class OpenAiService {
  final SupabaseClient? _client;

  static const String _functionName = 'generate-script';
  static const Duration _edgeTimeout = Duration(seconds: 50);

  OpenAiService({SupabaseClient? client}) : _client = client;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  /// Generate scripts for a specific week (up to 7 scripts per week).
  ///
  /// For Weeks 4–5 (longer 325–425 word scripts), splits generation into two
  /// parallel 3–4 day batches so total wall-clock latency stays fast without
  /// risking timeout or output truncation.
  Future<List<Map<String, dynamic>>> generateWeeklyScripts({
    required int weekNumber,
    required String firstName,
    required int age,
    required String location,
    required String goal,
    required Map<String, dynamic> onboardingAnswers,
    String language = 'en',
    PromptMode promptMode = PromptMode.selfDiscovery,
    HumanTouchLevel humanTouch = HumanTouchLevel.natural,
    AudienceCulture culture = AudienceCulture.india,
  }) async {
    final startDay = (weekNumber - 1) * 7 + 1;
    final clampedEndDay = (weekNumber * 7).clamp(1, 30);
    final scriptCount = clampedEndDay - startDay + 1;

    if (scriptCount <= 0) {
      logger.w(
        'Week $weekNumber has no days to generate (days $startDay-$clampedEndDay)',
      );
      return [];
    }

    final profile = PromptConfigFactory.build(
      mode: promptMode,
      humanTouch: humanTouch,
      culture: culture,
    );

    final profilePayload = <String, String>{
      'systemPersona': profile.systemPersona,
      'coreIntent': profile.coreIntent,
      'speakerMindset': profile.speakerMindset,
      'emotionalArc': profile.emotionalArc,
      'forbiddenPatterns': profile.forbiddenPatterns,
      'closingBehavior': profile.closingBehavior,
      'humanSpeechRules': profile.humanSpeechRules,
      'audienceMirrorRules': profile.audienceMirrorRules,
      'culturalRules': profile.culturalRules,
    };

    logger.i(
      'Generating Week $weekNumber scripts (Days $startDay-$clampedEndDay) in $language via Edge Function',
    );

    try {
      List<Map<String, dynamic>> scripts;

      // Split larger Weeks 4-5 into 2 parallel sub-batches for fast, reliable completion.
      if (weekNumber >= 4 && scriptCount >= 5) {
        final midDay = startDay + (scriptCount ~/ 2) - 1;
        final batches = await Future.wait([
          _invokeWeeklyBatch(
            weekNumber: weekNumber,
            startDay: startDay,
            endDay: midDay,
            firstName: firstName,
            age: age,
            location: location,
            goal: goal,
            onboardingAnswers: onboardingAnswers,
            language: language,
            promptProfile: profilePayload,
          ),
          _invokeWeeklyBatch(
            weekNumber: weekNumber,
            startDay: midDay + 1,
            endDay: clampedEndDay,
            firstName: firstName,
            age: age,
            location: location,
            goal: goal,
            onboardingAnswers: onboardingAnswers,
            language: language,
            promptProfile: profilePayload,
          ),
        ]);
        scripts = [...batches[0], ...batches[1]];
      } else {
        scripts = await _invokeWeeklyBatch(
          weekNumber: weekNumber,
          startDay: startDay,
          endDay: clampedEndDay,
          firstName: firstName,
          age: age,
          location: location,
          goal: goal,
          onboardingAnswers: onboardingAnswers,
          language: language,
          promptProfile: profilePayload,
        );
      }

      // Normalize dayNumber and required defaults cleanly
      for (var i = 0; i < scripts.length; i++) {
        final expectedDay = startDay + i;
        scripts[i]['dayNumber'] ??= expectedDay;
        scripts[i]['title'] ??= 'Day $expectedDay';
        scripts[i]['focus'] ??= 'Camera confidence';
        scripts[i]['duration'] ??= '1-2 minutes';
      }

      scripts.sort(
        (a, b) =>
            ((a['dayNumber'] as num?)?.toInt() ?? 0).compareTo(
              (b['dayNumber'] as num?)?.toInt() ?? 0,
            ),
      );

      logger.i('Generated ${scripts.length} scripts for Week $weekNumber');
      return scripts;
    } catch (e) {
      logger.e('Failed to generate Week $weekNumber scripts', e);
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> _invokeWeeklyBatch({
    required int weekNumber,
    required int startDay,
    required int endDay,
    required String firstName,
    required int age,
    required String location,
    required String goal,
    required Map<String, dynamic> onboardingAnswers,
    required String language,
    required Map<String, String> promptProfile,
  }) async {
    final data = await _invokeEdge({
      'action': 'weekly',
      'weekNumber': weekNumber,
      'startDay': startDay,
      'endDay': endDay,
      'firstName': firstName,
      'age': age,
      'location': location,
      'goal': goal,
      'onboardingAnswers': onboardingAnswers,
      'languageCode': language,
      'promptProfile': promptProfile,
    });

    final rawScripts = data['scripts'];
    if (rawScripts is! List || rawScripts.isEmpty) {
      throw Exception('Script service returned an empty weekly batch.');
    }

    return rawScripts
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Generate 3 personalized warmup scripts via the unified Edge Function.
  Future<List<Map<String, dynamic>>> generateWarmupScripts({
    required String firstName,
    required String location,
    required String goal,
    String language = 'en',
  }) async {
    logger.i('Generating warmup scripts for $firstName in $language via Edge Function');

    try {
      final data = await _invokeEdge({
        'action': 'warmup',
        'firstName': firstName,
        'location': location,
        'goal': goal,
        'languageCode': language,
      });

      final rawScripts = data['scripts'];
      if (rawScripts is! List || rawScripts.isEmpty) {
        throw Exception('Script service returned empty warmup scripts.');
      }

      final scripts =
          rawScripts
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
      logger.i('Generated ${scripts.length} warmup scripts');
      return scripts;
    } catch (e) {
      logger.e('Failed to generate warmup scripts', e);
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _invokeEdge(Map<String, dynamic> body) async {
    return NetworkHelper.withRetryAndTimeout(
      () async {
        final response = await _supabase.functions.invoke(
          _functionName,
          body: body,
        );

        final status = response.status;
        final payload = response.data;

        if (status != 200) {
          final errMsg =
              payload is Map && payload['error'] != null
                  ? payload['error'].toString()
                  : 'Script service error (HTTP $status)';
          if (status == 429 || status >= 500) {
            // Prefix with retryable marker for NetworkHelper
            throw TimeoutException('Transient upstream error ($status): $errMsg');
          }
          throw Exception(errMsg);
        }

        if (payload is Map<String, dynamic>) {
          return payload;
        }
        if (payload is Map) {
          return Map<String, dynamic>.from(payload);
        }
        throw Exception('Invalid response format from script service');
      },
      timeout: _edgeTimeout,
      maxAttempts: 2,
    );
  }

  /// Get the full combined script text from a script map.
  static String getFullScript(Map<String, dynamic> script) {
    final part1 = script['part1'] ?? '';
    final part2 = script['part2'] ?? '';
    final part3 = script['part3'] ?? '';

    return '$part1\n\n$part2\n\n$part3'.trim();
  }

  /// Get script parts as a list for teleprompter display.
  static List<String> getScriptParts(Map<String, dynamic> script) {
    return [
      script['part1']?.toString() ?? '',
      script['part2']?.toString() ?? '',
      script['part3']?.toString() ?? '',
    ].where((part) => part.isNotEmpty).toList();
  }
}
