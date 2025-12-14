import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/config/app_config.dart';
import '../core/config/prompt_config.dart';
import '../core/utils/logger.dart';

/// Service for generating personalized scripts using OpenAI.
class OpenAiService {
  final http.Client _client;

  OpenAiService({http.Client? client}) : _client = client ?? http.Client();

  /// Generate 30 personalized daily scripts based on user profile.
  /// @deprecated Use generateWeeklyScripts for better performance and longer scripts.
  Future<List<Map<String, dynamic>>> generateScripts({
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
    logger.i('Generating scripts for $firstName from $location in $language');
    logger.i(
      'Prompt mode: $promptMode, Human touch: $humanTouch, Culture: $culture',
    );

    final prompt = _buildScriptPrompt(
      firstName: firstName,
      age: age,
      location: location,
      goal: goal,
      answers: onboardingAnswers,
      language: language,
      promptMode: promptMode,
      humanTouch: humanTouch,
      culture: culture,
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

  /// Generate scripts for a specific week (7 scripts per week).
  /// Word count scales progressively.
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
    // Calculate day range for this week
    final startDay = (weekNumber - 1) * 7 + 1;
    final endDay = weekNumber * 7;
    final clampedEndDay = endDay > 30 ? 30 : endDay;
    final scriptCount = clampedEndDay - startDay + 1;

    if (scriptCount <= 0) {
      logger.w(
        'Week $weekNumber has no days to generate (days $startDay-$clampedEndDay)',
      );
      return [];
    }

    // Get word count range for this week
    final wordRange = _getWordRangeForWeek(weekNumber);

    logger.i(
      'Generating Week $weekNumber scripts (Day $startDay-$clampedEndDay, ${wordRange.$1}-${wordRange.$2} words each)',
    );
    logger.i(
      'Prompt mode: $promptMode, Human touch: $humanTouch, Culture: $culture',
    );

    final prompt = _buildWeeklyScriptPrompt(
      weekNumber: weekNumber,
      startDay: startDay,
      endDay: clampedEndDay,
      scriptCount: scriptCount,
      minWords: wordRange.$1,
      maxWords: wordRange.$2,
      firstName: firstName,
      age: age,
      location: location,
      goal: goal,
      answers: onboardingAnswers,
      language: language,
      promptMode: promptMode,
      humanTouch: humanTouch,
      culture: culture,
    );

    try {
      final response = await _callOpenAI(prompt);
      final scripts = _parseScriptsResponse(response);

      // Post-process: ensure each script has a dayNumber
      for (int i = 0; i < scripts.length; i++) {
        final expectedDay = startDay + i;
        if (scripts[i]['dayNumber'] == null) {
          scripts[i]['dayNumber'] = expectedDay;
        }
        // Also add title and other fields if missing
        scripts[i]['title'] ??= 'Day $expectedDay';
        scripts[i]['focus'] ??= 'confidence building';
        scripts[i]['duration'] ??= '1-2 minutes';
      }

      logger.i('Generated ${scripts.length} scripts for Week $weekNumber');
      return scripts;
    } catch (e) {
      logger.e('Failed to generate Week $weekNumber scripts', e);
      rethrow;
    }
  }

  /// Get minimum and maximum word count for a given week.
  (int, int) _getWordRangeForWeek(int weekNumber) {
    switch (weekNumber) {
      case 1:
        return (175, 225);
      case 2:
        return (225, 275);
      case 3:
        return (275, 325);
      case 4:
        return (325, 375);
      case 5:
      default:
        return (375, 425);
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
You are an expert social media scriptwriter helping $firstName.
Goal: $goal

Generate ${endDay - startDay + 1} high-retention video scripts.

STRICT FORMATTING (Viral Structure):
Each script MUST have exactly 3 parts containing ONLY spoken words.

1. part1 (The Hook - 20-40 words): 
   - NO "Hello" or "Welcome back". 
   - Start immediately with a controversial statement, a question, or a strong realization.
   - Example: "Stop doing this if you want to succeed." or "I learned this the hard way."

2. part2 (The Body - 80-150 words):
   - Deliver the value.
   - Use short, punchy sentences.
   - Speak like a human, not a book. Use colloquialisms where appropriate.

3. part3 (The CTA - 20-40 words):
   - A clear closing thought.
   - A specific call to action (e.g., "Save this for later").

CRITICAL RULES:
1. Write ONLY the exact words to speak aloud
2. NO narration like "One day I went to..." (Storybook style). Use "You" and "I" in the present moment.
3. NO labels like "Hook:", "Part 1:", "[pause]"
4. NO meta phrases like "In this video", "Today I'll show you"

Return a JSON array with each script having:
{
  "dayNumber": <number>,
  "title": "<catchy clickbait style title>",
  "part1": "<spoken words only>",
  "part2": "<spoken words only>",
  "part3": "<spoken words only>",
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

Create 3 short warmup scripts (30-60 seconds each).

ANTI-ROBOTIC INSTRUCTIONS:
- Do not write like a generic AI.
- Write like a real person talking to a friend on FaceTime.
- Use sentence fragments. It's okay to be casual.

STRICT 3-PART SCRIPT FORMAT:
- part1 (The Hook): High energy opener. No "Hi, I am..." - jump straight into the feeling.
- part2 (The Meat): The core message about confidence.
- part3 (The Outro): A firm commitment statement.

CRITICAL RULES:
1. Write ONLY the exact words to speak aloud
2. NO tips, instructions, or suggestions
3. NO labels like "Hook:", "Part 1:"
4. NO meta phrases like "In this video"

Warmup 1: "First Steps"
Warmup 2: "Finding Your Energy"
Warmup 3: "Ready to Start"

Return a JSON array with 3 objects:
{
  "warmupIndex": <0, 1, or 2>,
  "title": "<warmup title>",
  "part1": "<spoken words only>",
  "part2": "<spoken words only>",
  "part3": "<spoken words only>",
  "focus": "<main focus of this warmup>"
}
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
    required PromptMode promptMode,
    required HumanTouchLevel humanTouch,
    required AudienceCulture culture,
    String language = 'en',
  }) {
    final profile = PromptConfigFactory.build(
      mode: promptMode,
      humanTouch: humanTouch,
      culture: culture,
    );

    final challenges =
        (answers['challenges'] as List?)?.join(', ') ?? 'self-doubt';

    return '''
${_getLanguageInstruction(language)}

SYSTEM PERSONA:
${profile.systemPersona}

USER CONTEXT:
Name: $firstName
Age: $age
Location: $location
Goal: $goal
Challenges: $challenges

TONE & STYLE GUIDELINES (CRITICAL):
1. NOT A STORYBOOK: Do not use narrative past tense (e.g., "Once I walked down the road...").
2. CONVERSATIONAL: Write exactly how a human speaks. Use contractions (can't, won't, I'm).
3. ACTIVE VOICE: Speak directly to the viewer (Use "You").
4. RAW & AUTHENTIC: Avoid corporate or overly poetic language. Keep it grounded.

STRUCTURE (The 3-Part Hook-Body-Close):
- part1: THE HOOK. 1 sentence that stops the scroll. A bold claim, a question, or a vulnerable admission.
- part2: THE BODY. Elaborate on the hook. Share the insight. Keep it punchy.
- part3: THE CLOSE. A final takeaway or call to action.

OUTPUT FORMAT (STRICT JSON):
Return ONLY a valid JSON array of 30 objects.

Each object MUST have this structure:
{
  "dayNumber": <1-30>,
  "title": "<catchy title>",
  "part1": "<spoken hook text>",
  "part2": "<spoken body text>",
  "part3": "<spoken close text>",
  "focus": "<emotional focus>",
  "duration": "<estimated duration>"
}
''';
  }

  /// Build prompt for weekly script generation with progressive word counts.
  String _buildWeeklyScriptPrompt({
    required int weekNumber,
    required int startDay,
    required int endDay,
    required int scriptCount,
    required int minWords,
    required int maxWords,
    required String firstName,
    required int age,
    required String location,
    required String goal,
    required Map<String, dynamic> answers,
    required PromptMode promptMode,
    required HumanTouchLevel humanTouch,
    required AudienceCulture culture,
    String language = 'en',
  }) {
    final profile = PromptConfigFactory.build(
      mode: promptMode,
      humanTouch: humanTouch,
      culture: culture,
    );

    final challenges =
        (answers['challenges'] as List?)?.join(', ') ?? 'self-doubt';

    // Calculate word distribution for parts
    final part1Words = (minWords * 0.15).round(); // ~15% for hook (punchy)
    final part2Words = (minWords * 0.70).round(); // ~70% for body
    final part3Words = (minWords * 0.15).round(); // ~15% for close

    return '''
${_getLanguageInstruction(language)}

WEEK $weekNumber OF 30-DAY CONFIDENCE JOURNEY
Generate $scriptCount scripts for Days $startDay to $endDay.

USER CONTEXT:
Name: $firstName
Age: $age
Location: $location
Goal: $goal
Challenges: $challenges

SYSTEM PERSONA & VIBE:
${profile.systemPersona}
${profile.coreIntent}

*** ANTI-STORYBOOK PROTOCOL ***
The output often sounds like a diary entry or a storybook. THIS IS FORBIDDEN.
- DO NOT start with "Today I want to talk about..."
- DO NOT start with "Once upon a time..."
- DO NOT use flowery, poetic adjectives.
- DO write in specific, spoken-word sentences.
- DO use "You" to address the audience directly.
- DO mimic natural speech patterns (pauses, short fragments).

SCRIPT FORMULA (Strict 3-Part Structure):

1. part1 (The Hook):
   - Length: $part1Words words.
   - Purpose: Grab attention immediately.
   - Style: A controversial opinion, a direct question, or a "Me too" moment.
   - Example: "I used to think [X] was true. I was wrong."

2. part2 (The Body):
   - Length: $part2Words words.
   - Purpose: Deliver the value/insight.
   - Style: Conversational explanation. If telling a story, keep it in the "now". connect the user's struggle to the solution.

3. part3 (The Close):
   - Length: $part3Words words.
   - Purpose: Sign off.
   - Style: A punchy one-liner summary and a request for engagement.

WORD COUNT REQUIREMENTS:
- Total per script: $minWords to $maxWords words

OUTPUT FORMAT (STRICT JSON):
Return ONLY a valid JSON array of $scriptCount objects.

Each object MUST have this exact structure:
{
  "dayNumber": <integer from $startDay to $endDay>,
  "title": "<catchy 3-5 word title>",
  "part1": "<spoken hook text>",
  "part2": "<spoken body text>",
  "part3": "<spoken close text>",
  "focus": "<emotional focus>",
  "duration": "<estimated duration>"
}
''';
  }

  String _getLanguageInstruction(String language) {
    switch (language) {
      case 'hi':
        return 'LANGUAGE: Write all script parts in Hindi (हिन्दी). Use Devanagari script. Tone: Casual conversational Hindi.';
      case 'hinglish':
        return 'LANGUAGE: Write all script parts in Hinglish - a natural mix of Hindi and English commonly used by Indian content creators (e.g., "Life mein problems toh aati rahengi"). Mix the languages naturally using Roman script.';
      case 'en':
      default:
        return 'LANGUAGE: Write all script parts in English. Tone: Casual, Spoken-word, American/International English.';
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
                  'You are a viral content scriptwriter. You write scripts meant to be SPOKEN, not read. You hate "storybook" narration. You love punchy, short sentences. Always respond with valid JSON.',
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
