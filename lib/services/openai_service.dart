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

Focus areas:
- Advanced techniques
- Niche-specific content for their goal
- Collaboration and engagement strategies
- Monetization tips (if relevant)
- Building a consistent content calendar

STRICT 3-PART SCRIPT FORMAT:
Each script MUST have exactly 3 parts containing ONLY spoken words:
- part1: Hook/Opening (20-40 words) - Grab attention immediately
- part2: Content/Body (80-150 words) - Deliver main value
- part3: Close/Ending (20-40 words) - End with impact

CRITICAL RULES:
1. Write ONLY the exact words to speak aloud
2. NO tips, instructions, or suggestions
3. NO labels like "Hook:", "Part 1:", "[pause]"
4. NO meta phrases like "In this video", "Today I'll show you"
5. Use short sentences (max 12 words each)
6. Use "..." for natural pause points

Return a JSON array with each script having:
{
  "dayNumber": <number>,
  "title": "<catchy title>",
  "part1": "<hook text - spoken words only>",
  "part2": "<content text - spoken words only>",
  "part3": "<closing text - spoken words only>",
  "focus": "<main skill focus>",
  "duration": "<recommended video duration>"
}

IMPORTANT: Return ONLY valid JSON array, no markdown or extra text.
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

STRICT 3-PART SCRIPT FORMAT:
Each script MUST have exactly 3 parts containing ONLY spoken words:
- part1: Hook/Opening (15-25 words) - Energizing opener
- part2: Content/Body (40-60 words) - Building confidence
- part3: Close/Ending (15-25 words) - Ready to go statement

CRITICAL RULES:
1. Write ONLY the exact words to speak aloud
2. NO tips, instructions, or suggestions
3. NO labels like "Hook:", "Part 1:", "[pause]"
4. NO meta phrases like "In this video", "Today I'll show you"
5. Use short sentences (max 12 words each)
6. Use "..." for natural pause points

Warmup 1: "First Steps" - Introduction to being on camera
Warmup 2: "Finding Your Energy" - Building energy and presence  
Warmup 3: "Ready to Start" - Final preparation before the 30-day challenge

Return a JSON array with 3 objects:
{
  "warmupIndex": <0, 1, or 2>,
  "title": "<warmup title>",
  "part1": "<hook text - spoken words only>",
  "part2": "<content text - spoken words only>",
  "part3": "<closing text - spoken words only>",
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

    final languageInstruction = _getLanguageInstruction(language);

    return '''
You are a calm camera-confidence coach who helps fearful beginners speak through personal stories, not advice.

${_getLanguageInstruction(language)}

USER:
Name: $firstName
Age: $age
Location: $location
Goal after 30 days: $goal
Challenges: $challenges
Style: $contentStyle
Platforms: $platforms
Daily time: $timeCommitment

CORE PRINCIPLES:
- Every script is a small personal story
- Speaker discovers confidence while speaking
- Fear, pauses, awkwardness are allowed
- No teaching, no coaching, no authority tone
- Confidence must naturally emerge by Day 30

30-DAY STORY ARC:
Days 1–5: Showing up despite fear  
Days 6–12: Getting used to voice and presence  
Days 13–20: Sharing thoughts and explaining ideas  
Days 21–25: Feeling heard and accepted  
Days 26–30: Feeling at home on camera  

Each day must feel like the next page of one journey.

SCRIPT FORMAT (STRICT):
Exactly 3 parts. Spoken words only.
- part1: Opening story moment
- part2: Inner thought or realization
- part3: Soft closing that moves forward

WORD LIMITS:
Days 1–5: 20–30 / 50–80 / 20–30  
Days 6–12: 25–40 / 80–120 / 25–40  
Days 13–20: 30–45 / 120–180 / 30–45  
Days 21–25: 35–55 / 180–240 / 35–55  
Days 26–30: 45–65 / 260–320 / 45–65  

LANGUAGE RULES:
- Max 12 words per sentence
- Use "..." for pauses
- No questions to audience
- No commands or advice
- No meta phrases:
  “In this video”, “Today I will”, “Let me explain”, “Tips”

PERSONALIZATION:
- Use $firstName naturally in early days only
- Casual references to $location
- Reflect beginner thoughts tied to $challenges
- Align growth slowly with $goal

OUTPUT:
Return ONLY a valid JSON array of 30 objects.

Each object:
{
  "dayNumber": <1-30>,
  "title": "<short emotional title>",
  "part1": "<spoken words only>",
  "part2": "<spoken words only>",
  "part3": "<spoken words only>",
  "focus": "<story focus>",
  "duration": "<estimated duration>"
}
''';  
  }

  String _getLanguageInstruction(String language) {
    switch (language) {
      case 'hi':
        return 'LANGUAGE: Write all script parts in Hindi (हिन्दी). Use Devanagari script.';
      case 'hinglish':
        return 'LANGUAGE: Write all script parts in Hinglish - a natural mix of Hindi and English commonly used by Indian content creators. Mix the languages naturally as young Indians speak, using Roman script.';
      case 'en':
      default:
        return 'LANGUAGE: Write all script parts in English.';
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
                  'You are a helpful camera confidence coach. You generate teleprompter scripts containing ONLY spoken words. Always respond with valid JSON only. Never include instructions, labels, or meta-commentary in scripts.',
            },
            {'role': 'user', 'content': prompt},
          ],
          'max_completion_tokens': AppConfig.maxScriptTokens,
          'temperature': 1,
        }),
      );

      logger.d('OpenAI: Received response with status ${response.statusCode}');

      if (response.statusCode != 200) {
        final errorBody = response.body;
        logger.e('OpenAI API error: ${response.statusCode} - $errorBody');

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

  /// Get the full combined script text from a script map
  static String getFullScript(Map<String, dynamic> script) {
    final part1 = script['part1'] ?? '';
    final part2 = script['part2'] ?? '';
    final part3 = script['part3'] ?? '';

    return '$part1\n\n$part2\n\n$part3'.trim();
  }

  /// Get script parts as a list for teleprompter display
  static List<String> getScriptParts(Map<String, dynamic> script) {
    return [
      script['part1'].toString(),
      script['part2'].toString(),
      script['part3'].toString(),
    ].where((part) => part.isNotEmpty).toList();
  }

  void dispose() {
    _client.close();
  }
}
