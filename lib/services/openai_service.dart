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
  }) async {
    logger.i('Generating scripts for $firstName from $location');

    final prompt = _buildScriptPrompt(
      firstName: firstName,
      age: age,
      location: location,
      goal: goal,
      answers: onboardingAnswers,
    );

    try {
      final response = await _callOpenAI(prompt);
      final scripts = _parseScriptsResponse(response);
      logger.i('Generated ${scripts.length} scripts');
      return scripts;
    } catch (e) {
      logger.e('Failed to generate scripts', e);
      // Return fallback scripts if API fails
      return _generateFallbackScripts(firstName, goal);
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
      return _generateFallbackExtensionScripts(firstName, startDay, endDay);
    }
  }

  /// Generate 3 personalized warmup scripts based on user profile.
  Future<List<Map<String, dynamic>>> generateWarmupScripts({
    required String firstName,
    required String location,
    required String goal,
  }) async {
    logger.i('Generating warmup scripts for $firstName');

    final locationText = location.isNotEmpty ? ' from $location' : '';

    final prompt = '''
You are a camera confidence coach creating 3 personalized warmup scripts for $firstName$locationText.
Their goal: $goal

Create 3 short warmup scripts (30-60 seconds each) that:
- Are encouraging and personal
- Build confidence progressively
- Use their name and goal naturally
- Feel natural to read aloud

Warmup 1: "First Steps" - Introduction to being on camera
Warmup 2: "Finding Your Energy" - Building energy and presence  
Warmup 3: "Ready to Start" - Final preparation before the 30-day challenge

Return a JSON array with 3 objects:
{
  "warmupIndex": <0, 1, or 2>,
  "title": "<warmup title>",
  "script": "<full script text 50-100 words>",
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
      return _generateFallbackWarmupScripts(firstName, goal, location);
    }
  }

  List<Map<String, dynamic>> _generateFallbackWarmupScripts(
    String firstName,
    String goal,
    String location,
  ) {
    final locationText = location.isNotEmpty ? ' from $location' : '';

    return [
      {
        'warmupIndex': 0,
        'title': 'First Steps',
        'script':
            "Hi, I'm $firstName$locationText! This is my very first step toward my goal to $goal. I know this won't be perfect, and that's completely okay. What matters is that I'm showing up and taking action. Let's begin this journey together!",
        'focus': 'Introduction',
      },
      {
        'warmupIndex': 1,
        'title': 'Finding Your Energy',
        'script':
            "Hey everyone! $firstName here again. Today I'm working on bringing more energy and positivity. I'm one step closer to $goal. Each day I show up, I'm proving to myself that I can do this! Let's keep this momentum going!",
        'focus': 'Energy and presence',
      },
      {
        'warmupIndex': 2,
        'title': 'Ready to Start',
        'script':
            "What's up! It's $firstName and I'm on my final warmup before the 30-day challenge begins! I've already grown so much just by practicing these warmups. I'm ready to achieve my goal to $goal. Consistency beats perfection. Let's crush this challenge!",
        'focus': 'Preparation and confidence',
      },
    ];
  }

  String _buildScriptPrompt({
    required String firstName,
    required int age,
    required String location,
    required String goal,
    required Map<String, dynamic> answers,
  }) {
    final challenges =
        (answers['challenges'] as List?)?.join(', ') ?? 'general anxiety';
    final contentStyle =
        (answers['content_style'] as List?)?.join(', ') ?? 'educational';
    final platforms =
        (answers['platform'] as List?)?.join(', ') ?? 'social media';
    final timeCommitment = answers['time_commitment'] ?? '10-20 minutes';

    return '''
You are a camera confidence coach creating a personalized 30-day video challenge.

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

PHASE 1 - Foundation (Days 1-5): ~50-75 words each
- Simple introductions with segmented practice
- Focus on eye contact, breathing, and basic comfort
- Include specific training segments with focus areas

PHASE 2 - Building Confidence (Days 6-12): ~100-150 words each  
- Longer continuous scripts
- Introduce storytelling elements
- Add personality and humor

PHASE 3 - Content Creation (Days 13-20): ~200-300 words each
- Niche-specific content for their goal: $goal
- Teach them to structure valuable content
- Hook, content, call-to-action format

PHASE 4 - Advanced Skills (Days 21-25): ~350-400 words each
- Complex multi-topic scripts
- Engagement strategies for $platforms
- Building authority in their niche

PHASE 5 - Mastery (Days 26-30): ~450-500 words each
- Professional-quality long-form scripts
- Complete episodes/videos
- Monetization and growth tips related to $goal

Each script MUST:
- Be personalized with their name ($firstName) and location ($location)
- Address their specific challenges: $challenges
- Relate directly to their goal: $goal
- Match their content style: $contentStyle
- Include actionable speaking prompts

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

  Future<String> _callOpenAI(String prompt) async {
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

    if (response.statusCode != 200) {
      logger.e('OpenAI API error: ${response.statusCode} - ${response.body}');
      throw Exception('OpenAI API error: ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return data['choices'][0]['message']['content'];
  }

  List<Map<String, dynamic>> _parseScriptsResponse(String response) {
    // Clean up response - remove markdown code blocks if present
    var cleaned = response.trim();
    if (cleaned.startsWith('```json')) {
      cleaned = cleaned.substring(7);
    }
    if (cleaned.startsWith('```')) {
      cleaned = cleaned.substring(3);
    }
    if (cleaned.endsWith('```')) {
      cleaned = cleaned.substring(0, cleaned.length - 3);
    }
    cleaned = cleaned.trim();

    final List<dynamic> parsed = jsonDecode(cleaned);
    return parsed.map((e) => e as Map<String, dynamic>).toList();
  }

  List<Map<String, dynamic>> _generateFallbackScripts(
    String name,
    String goal,
  ) {
    logger.w('Using fallback scripts');

    final List<Map<String, dynamic>> scripts = [];

    for (int day = 1; day <= 30; day++) {
      if (day <= 5) {
        scripts.add({
          'dayNumber': day,
          'title': 'Day $day: Getting Started',
          'scriptType': 'segmented',
          'segments': [
            {
              'part': 1,
              'text':
                  'Hi, I\'m $name and I\'m on day $day of my camera confidence journey.',
              'focus': 'Introduction',
            },
            {
              'part': 2,
              'text':
                  'Today I\'m practicing being natural on camera. My goal is $goal.',
              'focus': 'Purpose',
            },
            {
              'part': 3,
              'text': 'Thanks for being part of my journey. See you tomorrow!',
              'focus': 'Closing',
            },
          ],
          'focus': 'Building comfort',
          'wordCount': 50,
          'estimatedDuration': '30 seconds',
        });
      } else {
        scripts.add({
          'dayNumber': day,
          'title': 'Day $day: Building Momentum',
          'scriptType': 'full',
          'script':
              'Hey everyone, it\'s $name here on day $day! I\'m getting more comfortable on camera every day. My goal is still $goal, and I\'m making progress. Today I want to share something I\'ve learned - consistency beats perfection. Just showing up matters. Thanks for watching!',
          'focus':
              day <= 15
                  ? 'Confidence building'
                  : day <= 25
                  ? 'Content creation'
                  : 'Mastery',
          'wordCount': 75,
          'estimatedDuration': '45 seconds',
        });
      }
    }

    return scripts;
  }

  List<Map<String, dynamic>> _generateFallbackExtensionScripts(
    String name,
    int startDay,
    int endDay,
  ) {
    final List<Map<String, dynamic>> scripts = [];

    for (int day = startDay; day <= endDay; day++) {
      scripts.add({
        'dayNumber': day,
        'title': 'Day $day: Advanced Skills',
        'script':
            'Welcome back! I\'m $name on day $day. Now that I\'ve completed the initial 30-day challenge, I\'m taking my skills to the next level. In this extension phase, I\'m focusing on more advanced techniques and growing my audience. Let\'s keep going!',
        'focus': 'Advanced techniques',
        'duration': '1 minute',
      });
    }

    return scripts;
  }

  void dispose() {
    _client.close();
  }
}
