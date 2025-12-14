import 'dart:convert';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/constants/app_constants.dart';
import '../../core/error/failures.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/content_script.dart';
import '../../domain/repositories/content_creator_repository.dart';
import '../datasources/remote/supabase_content_scripts_datasource.dart';

/// Implementation of ContentCreatorRepository.
/// Uses Supabase for cloud storage and OpenAI for script generation.
class ContentCreatorRepositoryImpl implements ContentCreatorRepository {
  final SupabaseContentScriptsDataSource remoteDataSource;
  final http.Client _client;
  final Uuid _uuid = const Uuid();

  ContentCreatorRepositoryImpl({
    required this.remoteDataSource,
    http.Client? client,
  }) : _client = client ?? http.Client();

  @override
  Future<Either<Failure, List<ContentScript>>> getScripts(String userId) async {
    try {
      final scripts = await remoteDataSource.getScripts(userId);
      // Sort by createdAt descending (newest first)
      scripts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Right(scripts);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load scripts: $e'));
    }
  }

  @override
  Future<Either<Failure, ContentScript?>> getScriptById(String scriptId) async {
    try {
      final script = await remoteDataSource.getScriptById(scriptId);
      return Right(script);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to load script: $e'));
    }
  }

  @override
  Future<Either<Failure, ContentScript>> saveScript(
    ContentScript script,
  ) async {
    try {
      final updatedScript = script.copyWith(updatedAt: DateTime.now());
      final savedScript = await remoteDataSource.saveScript(updatedScript);
      return Right(savedScript);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save script: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteScript(String scriptId) async {
    try {
      await remoteDataSource.deleteScript(scriptId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to delete script: $e'));
    }
  }

  @override
  Future<Either<Failure, ContentScript>> generateScript({
    required String userId,
    required String topic,
    required String audience,
    required String message,
    required String tone,
    required PromptTemplate template,
    String? customPrompt,
    required String language,
  }) async {
    try {
      final prompt = _buildGenerationPrompt(
        topic: topic,
        audience: audience,
        message: message,
        tone: tone,
        language: language,
        template: template,
        customPrompt: customPrompt,
      );

      // Call OpenAI to generate the script
      final response = await _callOpenAiForContentScript(prompt);

      final now = DateTime.now();
      final script = ContentScript(
        id: _uuid.v4(),
        userId: userId,
        title: _generateTitle(topic),
        part1: response['part1'] ?? '',
        part2: response['part2'] ?? '',
        part3: response['part3'] ?? '',
        promptTemplate: template.name,
        questionnaire: {
          'topic': topic,
          'audience': audience,
          'message': message,
          'tone': tone,
        },
        createdAt: now,
        updatedAt: now,
        isRecorded: false,
      );

      // Save to Supabase
      await remoteDataSource.saveScript(script);

      return Right(script);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to generate script: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRecorded(String scriptId) async {
    try {
      await remoteDataSource.markAsRecorded(scriptId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to mark as recorded: $e'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getContentVideoPaths(
    String userId,
  ) async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      final contentDir = Directory(
        '${appDir.path}/${AppConstants.contentFolderName}',
      );

      if (!await contentDir.exists()) {
        return const Right([]);
      }

      final files =
          await contentDir
              .list(recursive: true)
              .where((entity) => entity is File && entity.path.endsWith('.mp4'))
              .map((entity) => entity.path)
              .toList();

      return Right(files);
    } catch (e) {
      return Left(CacheFailure(message: 'Failed to load videos: $e'));
    }
  }

  String _buildGenerationPrompt({
  required String topic,
  required String audience,
  required String message,
  required String tone,
  required String language,
  required PromptTemplate template,
  String? customPrompt,
}) {
  final templateGuide = _getTemplateGuide(template);

  return '''
Create a 2–3 minute spoken video script.

CONTEXT:
Topic: $topic
Target audience: $audience
Core message: $message
Tone: $tone
Language: $language

STYLE GUIDANCE:
$templateGuide

STRUCTURE (STRICT):
- part1: Hook (20–40 words)
- part2: Main body (100–150 words)
- part3: Closing (20–40 words)

CONTENT RULES:
- Write ENTIRELY in $language language
- Spoken words only
- No explaining what the video is about
- No teaching tone, talk like a founder explaining reality
- Use examples where natural
- Slightly opinionated but practical

${customPrompt != null ? 'ADDITIONAL CONTEXT: $customPrompt' : ''}

Return ONLY valid JSON with part1, part2, part3.
''';
}
  String _getTemplateGuide(PromptTemplate template) {
    switch (template) {
      case PromptTemplate.educational:
        return '''
EDUCATIONAL STYLE:
- Start with a compelling question or problem
- Break down complex ideas simply
- End with a key takeaway
''';
      case PromptTemplate.story:
        return '''
STORY STYLE:
- Start with "There was a time when..." or similar
- Build emotional connection
- End with the lesson learned
''';
      case PromptTemplate.tips:
        return '''
TIPS & TRICKS STYLE:
- Start with the big promise
- Deliver actionable advice quickly
- End with encouragement to try it
''';
      case PromptTemplate.productReview:
        return '''
PRODUCT REVIEW STYLE:
- Start with your honest first impression
- Cover pros and cons naturally
- End with your recommendation
''';
      case PromptTemplate.dayInLife:
        return '''
DAY IN LIFE STYLE:
- Start with setting the scene
- Show behind-the-scenes moments
- End with reflection on the day
''';
      case PromptTemplate.custom:
        return '''
CUSTOM STYLE:
- Follow the user's additional instructions
- Maintain authentic voice
- Keep it engaging and natural
''';
    }
  }

 Future<Map<String, dynamic>> _callOpenAiForContentScript(
  String generationPrompt,
) async {
  logger.d('ContentCreator: Starting OpenAI API call');

  try {
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
            'content': '''
You are a founder-style short-form video script writer for teleprompter display.

CORE IDENTITY:
- Founder + operator mindset
- Practical, slightly opinionated
- No motivational fluff
- Speak like explaining to one smart person

LANGUAGE:
- Hinglish (mix of Hindi and English)
- Simple Indian conversational tone

OUTPUT FORMAT (STRICT):
Return ONLY valid JSON with this structure:
{
  "part1": "Hook/opening with markdown formatting",
  "part2": "Main content with markdown formatting", 
  "part3": "Closing with markdown formatting"
}

MARKDOWN RULES FOR TELEPROMPTER:
- Use **bold** for key words to emphasize while speaking
- Use line breaks (\\n\\n) between thoughts for natural pauses
- Use bullet points (• ) for lists of tips or points
- Keep sentences short (max 12 words)
- Use "..." for dramatic pauses

STYLE:
- Confident but grounded tone
- Clear thinking over fancy words
- No hashtags, no emojis in content
- Spoken words only - what you actually say on camera

EXAMPLE OUTPUT:
{
  "part1": "Ek baat batao...\\n\\n**90% founders** yahi galti karte hain.",
  "part2": "• Pehli baat - **system** banao, tool nahi dhundo\\n\\n• Doosri baat - **consistency** beats perfection\\n\\nJab clarity hai... toh execution easy ho jata hai.",
  "part3": "Yaad rakhna...\\n\\n**Simple systems** se hi **big results** aate hain."
}
'''
          },
          {
            'role': 'user',
            'content': generationPrompt,
          }
        ],
        'max_completion_tokens': 1200,
        'temperature': 0.9,
      }),
    );

    if (response.statusCode != 200) {
      throw Exception(
        'OpenAI API error (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body);

    if (data['choices'] == null || data['choices'].isEmpty) {
      throw Exception('No choices in OpenAI response');
    }

    final content = data['choices'][0]['message']['content'];

    if (content == null || content.isEmpty) {
      throw Exception('Empty content from OpenAI');
    }

    return _parseScriptResponse(content);
  } catch (e) {
    logger.e('ContentCreator: Exception $e');

    return {
      'part1': 'Aaj ek simple baat samajhne ki zarurat hai...',
      'part2':
          'Most log tools pe focus karte hain, system pe nahi...'
          'jab system clear hota hai, execution easy ho jata hai...',
      'part3':
          'Agar clarity hai, toh consistency apne aap aati hai...',
    };
  }
}

  Map<String, dynamic> _parseScriptResponse(String response) {
    try {
      // Clean up potential markdown formatting
      var cleaned = response.trim();
      if (cleaned.startsWith('```json')) {
        cleaned = cleaned.substring(7);
      } else if (cleaned.startsWith('```')) {
        cleaned = cleaned.substring(3);
      }
      if (cleaned.endsWith('```')) {
        cleaned = cleaned.substring(0, cleaned.length - 3);
      }
      cleaned = cleaned.trim();

      final parsed = jsonDecode(cleaned) as Map<String, dynamic>;
      return {
        'part1': parsed['part1']?.toString() ?? '',
        'part2': parsed['part2']?.toString() ?? '',
        'part3': parsed['part3']?.toString() ?? '',
      };
    } catch (e) {
      logger.e('ContentCreator: Failed to parse JSON response: $e');
      // If JSON parsing fails, try to extract content intelligently
      final lines = response.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.length >= 3) {
        return {
          'part1': lines[0],
          'part2': lines.sublist(1, lines.length - 1).join('\n'),
          'part3': lines.last,
        };
      }
      return {
        'part1': response.length > 100 ? response.substring(0, 100) : response,
        'part2': response.length > 100 ? response.substring(100) : '',
        'part3': 'Start recording now!',
      };
    }
  }

  String _generateTitle(String topic) {
    // Generate a concise title from the topic
    final words = topic.split(' ');
    if (words.length <= 3) {
      return topic;
    }
    return '${words.take(3).join(' ')}...';
  }
}
