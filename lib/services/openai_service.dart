import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/utils/logger.dart';

/// Service for generating personalized scripts using OpenAI.
class OpenAiService {
  final http.Client _client;

  OpenAiService({http.Client? client}) : _client = client ?? http.Client();

  /// Generate 30 personalized daily scripts based on user profile.
  Future<List<Map<String, dynamic>>> generateScripts({
    required String firstName,
    required int age,
    required String location,
    required String goal,
    required Map<String, dynamic> onboardingAnswers,
    String language = 'en',
  }) async {
    logger.i('Generating scripts for $firstName from $location in $language');

    final prompt = _buildScriptPrompt(
      firstName: firstName,
      age: age,
      location: location,
      goal: goal,
      answers: onboardingAnswers,
      language: language,
    );

    try {
      final response = await _callOpenAI(prompt);
      final scripts = _parseScriptsResponse(response);
      logger.i('Generated ${scripts.length} scripts');
      return scripts;
    } catch (e) {
      logger.e('Failed to generate scripts', e);
      // Rethrow with actual error message
      rethrow;
    }
  }

  /// Generate extension scripts for post-30-day content.
  Future<List<Map<String, dynamic>>> generateExtensionScripts({
    required String firstName,
    required String goal,
    required int extensionNumber,
    required int startDay,
    required int endDay,
  }) async {
    logger.i(
      'Generating extension $extensionNumber scripts (Day $startDay-$endDay)',
    );

    final prompt = '''
You are a camera confidence coach helping $firstName continue their journey beyond the initial 30 days.

This is Extension $extensionNumber, covering Days $startDay to $endDay.
Their goal: $goal

Generate ${endDay - startDay + 1} advanced video scripts that build on the foundational skills.
Focus on:
- Advanced techniques
- Niche-specific content for their goal
- Collaboration and engagement strategies
- Monetization tips (if relevant)
- Building a consistent content calendar

Return a JSON array with each script having:
{
  "dayNumber": <number>,
  "title": "<catchy title>",
  "script": "<full script text 100-200 words>",
  "focus": "<main skill focus>",
  "duration": "<recommended video duration>"
}
''';

    try {
      final response = await _callOpenAI(prompt);
      return _parseScriptsResponse(response);
    } catch (e) {
      logger.e('Failed to generate extension scripts', e);
      throw Exception(
        'OpenAI script generation failed. Please check your internet connection and try again.',
      );
    }
  }

  /// Generate 3 personalized warmup scripts based on user profile.
  Future<List<Map<String, dynamic>>> generateWarmupScripts({
    required String firstName,
    required String location,
    required String goal,
    String language = 'en',
  }) async {
    logger.i('Generating warmup scripts for $firstName in $language');

    final locationText = location.isNotEmpty ? ' from $location' : '';
    final languageInstruction = _getLanguageInstruction(language);

    final prompt = '''
You are a camera confidence coach creating 3 personalized warmup scripts for $firstName$locationText.
Their goal: $goal

$languageInstruction

Create 3 short warmup scripts (30-60 seconds each) that:
- Are encouraging and personal
- Build confidence progressively
- Use their name and goal naturally
- Feel natural to read aloud
- Are written in the specified language

Warmup 1: "First Steps" - Introduction to being on camera
Warmup 2: "Finding Your Energy" - Building energy and presence  
Warmup 3: "Ready to Start" - Final preparation before the 30-day challenge

Return a JSON array with 3 objects:
{
  "warmupIndex": <0, 1, or 2>,
  "title": "<warmup title>",
  "script": "<full script text 75-120 words>",
  "focus": "<main focus of this warmup>"
}

IMPORTANT: Return ONLY valid JSON array, no markdown or extra text.
''';

    try {
      final response = await _callOpenAI(prompt);
      final scripts = _parseScriptsResponse(response);
      logger.i('Generated ${scripts.length} warmup scripts');
      return scripts;
    } catch (e) {
      logger.e('Failed to generate warmup scripts', e);
      rethrow;
    }
  }

  String _buildScriptPrompt({
    required String firstName,
    required int age,
    required String location,
    required String goal,
    required Map<String, dynamic> answers,
    String language = 'en',
  }) {
    final challenges =
        (answers['challenges'] as List?)?.join(', ') ?? 'general anxiety';
    final contentStyle =
        (answers['content_style'] as List?)?.join(', ') ?? 'educational';
    final platforms =
        (answers['platform'] as List?)?.join(', ') ?? 'social media';
    final timeCommitment = answers['time_commitment'] ?? '10-20 minutes';

    // Language instruction based on preference
    final languageInstruction = _getLanguageInstruction(language);

    return '''
You are a camera confidence coach creating a personalized 30-day video challenge.

$languageInstruction

USER PROFILE:
- Name: $firstName
- Age: $age
- Location: $location
- Goal: $goal
- Challenges: $challenges
- Content style preference: $contentStyle
- Target platforms: $platforms
- Daily time commitment: $timeCommitment

Create 30 unique, personalized video scripts with PROGRESSIVELY INCREASING DIFFICULTY:

PHASE 1 - Foundation (Days 1-5): ~75-100 words each
- Simple introductions with segmented practice
- Focus on eye contact, breathing, and basic comfort
- Include specific training segments with focus areas

PHASE 2 - Building Confidence (Days 6-12): ~150-200 words each  
- Longer continuous scripts
- Introduce storytelling elements
- Add personality and humor

PHASE 3 - Content Creation (Days 13-20): ~250-350 words each
- Niche-specific content for their goal: $goal
- Teach them to structure valuable content
- Hook, content, call-to-action format

PHASE 4 - Advanced Skills (Days 21-25): ~400-500 words each
- Complex multi-topic scripts
- Engagement strategies for $platforms
- Building authority in their niche

PHASE 5 - Mastery (Days 26-30): ~500-600 words each
- Professional-quality long-form scripts
- Complete episodes/videos
- Monetization and growth tips related to $goal

Each script MUST:
- Be personalized with their name ($firstName) and location ($location)
- Address their specific challenges: $challenges
- Relate directly to their goal: $goal
- Match their content style: $contentStyle
- Include actionable speaking prompts
- Be written in the specified language

For Days 1-5, include "segments" array with 3-4 parts each having "text" and "focus".
For Days 6-30, include full "script" text with the word count specified above.

Return a JSON array with 30 objects:
{
  "dayNumber": <1-30>,
  "title": "<catchy title>",
  "scriptType": "<segmented or full>",
  "segments": [{"part": 1, "text": "...", "focus": "..."}] // for days 1-5
  "script": "<full script text>" // for days 6-30
  "focus": "<main skill focus>",
  "wordCount": <actual word count>,
  "estimatedDuration": "<e.g., 30 seconds, 2 minutes, 3-4 minutes>"
}

IMPORTANT: Return ONLY valid JSON array, no markdown or extra text.
''';
  }

  String _getLanguageInstruction(String language) {
    switch (language) {
      case 'hi':
        return 'LANGUAGE: Write all scripts in Hindi (हिन्दी). Use Devanagari script.';
      case 'hinglish':
        return 'LANGUAGE: Write all scripts in Hinglish - a natural mix of Hindi and English commonly used by Indian content creators. Mix the languages naturally as young Indians speak, using Roman script.';
      case 'en':
      default:
        return 'LANGUAGE: Write all scripts in English.';
    }
  }

  Future<String> _callOpenAI(String prompt) async {
    logger.d('OpenAI: Starting API call');
    logger.d(
      'OpenAI: Using model ${AppConfig.openAiModel}, max_tokens: ${AppConfig.maxScriptTokens}',
    );

    try {
      logger.d(
        'OpenAI: Sending request to ${AppConfig.openAiBaseUrl}/chat/completions',
      );

      final response = await _client.post(
        Uri.parse('${AppConfig.openAiBaseUrl}/chat/completions'),
        headers: {
          'Authorization': 'Bearer ${AppConfig.openAiApiKey}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': AppConfig.openAiModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a helpful camera confidence coach. Always respond with valid JSON only.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_tokens': AppConfig.maxScriptTokens,
          'temperature': 0.7,
        }),
      );

      logger.d('OpenAI: Received response with status ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = response.body;
        logger.e('OpenAI API error: ${response.statusCode} - $errorBody');

        // Parse error message from response
        String errorMessage = 'OpenAI API error (${response.statusCode})';
        try {
          final errorData = jsonDecode(errorBody);
          if (errorData['error'] != null &&
              errorData['error']['message'] != null) {
            errorMessage = errorData['error']['message'];
          }
        } catch (_) {}

        throw Exception(errorMessage);
      }

      final data = jsonDecode(response.body);

      // Check if response was truncated
      final finishReason = data['choices']?[0]?['finish_reason'];
      logger.d('OpenAI: finish_reason = $finishReason');

      if (finishReason == 'length') {
        logger.w('OpenAI: Response was truncated due to max_tokens limit!');
        throw Exception(
          'Response was truncated. Please try again with fewer scripts or increase token limit.',
        );
      }

      final content = data['choices'][0]['message']['content'] as String;
      logger.d('OpenAI: Received ${content.length} characters of content');
      logger.d(
        'OpenAI: Content preview: ${content.substring(0, content.length > 200 ? 200 : content.length)}...',
      );

      return content;
    } catch (e) {
      logger.e('OpenAI: Exception occurred: ${e.runtimeType} - $e');
      if (e is Exception) rethrow;
      throw Exception('Network error: ${e.toString()}');
    }
  }

  List<Map<String, dynamic>> _parseScriptsResponse(String response) {
    logger.d('Parsing: Starting to parse OpenAI response');
    logger.d('Parsing: Response length: ${response.length} characters');

    // Clean up response - remove markdown code blocks if present
    var cleaned = response.trim();

    if (cleaned.startsWith('```json')) {
      logger.d('Parsing: Removing ```json prefix');
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith('```')) {
      logger.d('Parsing: Removing ``` prefix');
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      logger.d('Parsing: Removing ``` suffix');
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    logger.d('Parsing: Cleaned response length: ${cleaned.length} characters');

    // Check if JSON looks complete
    if (!cleaned.endsWith(']')) {
      logger.e('Parsing: Response appears truncated - does not end with ]');
      logger.e(
        'Parsing: Last 100 chars: ${cleaned.substring(cleaned.length > 100 ? cleaned.length - 100 : 0)}',
      );
      throw Exception(
        'OpenAI response was truncated. Please increase max_tokens in app_config.dart (currently ${AppConfig.maxScriptTokens}). Recommended: 16000+ for 30 scripts.',
      );
    }

    try {
      logger.d('Parsing: Attempting JSON decode');
      final List<dynamic> parsed = jsonDecode(cleaned);
      logger.i('Parsing: Successfully parsed ${parsed.length} scripts');
      return parsed.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      logger.e('Parsing: JSON decode failed: $e');
      logger.e(
        'Parsing: First 500 chars: ${cleaned.substring(0, cleaned.length > 500 ? 500 : cleaned.length)}',
      );
      logger.e(
        'Parsing: Last 500 chars: ${cleaned.substring(cleaned.length > 500 ? cleaned.length - 500 : 0)}',
      );
      throw Exception(
        'Failed to parse OpenAI response. The response may be truncated or malformed. Error: $e',
      );
    }
  }

  void dispose() {
    _client.close();
  }
}
