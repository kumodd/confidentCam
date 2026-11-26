import 'dart:async';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/constants/app_constants.dart';
import '../../core/error/failures.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/content_script.dart';
import '../../domain/repositories/content_creator_repository.dart';
import '../datasources/local/hive_content_scripts_datasource.dart';
import '../datasources/remote/supabase_content_scripts_datasource.dart';

/// Implementation of [ContentCreatorRepository].
///
/// Uses the unified Supabase `generate-script` Edge Function for generation &
/// refinement (Structured Outputs, multi-language, zero client OpenAI keys),
/// Supabase Postgres for cloud sync, and [HiveContentScriptsDataSource] for
/// offline read-through caching.
class ContentCreatorRepositoryImpl implements ContentCreatorRepository {
  static const String _functionName = 'generate-script';
  static const Duration _edgeTimeout = Duration(seconds: 50);

  final SupabaseContentScriptsDataSource remoteDataSource;
  final HiveContentScriptsDataSource? localDataSource;
  final SupabaseClient? _supabaseClient;
  final Uuid _uuid = const Uuid();

  ContentCreatorRepositoryImpl({
    required this.remoteDataSource,
    this.localDataSource,
    SupabaseClient? supabaseClient,
  }) : _supabaseClient = supabaseClient;

  SupabaseClient get _supabase => _supabaseClient ?? Supabase.instance.client;

  @override
  Future<Either<Failure, List<ContentScript>>> getScripts(String userId) async {
    try {
      final scripts = await remoteDataSource.getScripts(userId);
      scripts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Refresh local offline cache silently
      if (localDataSource != null) {
        try {
          await localDataSource!.clearUserScripts(userId);
          for (final s in scripts) {
            await localDataSource!.saveScript(s);
          }
        } catch (cacheErr) {
          logger.w('ContentCreator local cache sync warning: $cacheErr');
        }
      }

      return Right(scripts);
    } catch (e) {
      // Fallback to local offline Hive cache if remote fetch fails
      if (localDataSource != null) {
        try {
          final cached = await localDataSource!.getScripts(userId);
          if (cached.isNotEmpty) {
            cached.sort((a, b) => b.createdAt.compareTo(a.createdAt));
            logger.i(
              'ContentCreator: Serving ${cached.length} offline cached scripts',
            );
            return Right(cached);
          }
        } catch (_) {}
      }
      return Left(ServerFailure(message: 'Failed to load scripts: $e'));
    }
  }

  @override
  Future<Either<Failure, ContentScript?>> getScriptById(String scriptId) async {
    try {
      final script = await remoteDataSource.getScriptById(scriptId);
      if (script != null) return Right(script);
      if (localDataSource != null) {
        return Right(await localDataSource!.getScriptById(scriptId));
      }
      return const Right(null);
    } catch (e) {
      if (localDataSource != null) {
        final cached = await localDataSource!.getScriptById(scriptId);
        if (cached != null) return Right(cached);
      }
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
      try {
        await localDataSource?.saveScript(savedScript);
      } catch (_) {}
      return Right(savedScript);
    } catch (e) {
      return Left(ServerFailure(message: 'Failed to save script: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteScript(String scriptId) async {
    try {
      await remoteDataSource.deleteScript(scriptId);
      try {
        await localDataSource?.deleteScript(scriptId);
      } catch (_) {}
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
    required String language,
    String? languageCode,
    required PromptTemplate template,
    String length = 'medium',
    String platform = 'reels_shorts',
    String scriptStyle = 'spoken_natural',
    String ctaStyle = 'auto',
    String? customPrompt,
  }) async {
    try {
      final resolvedLangCode =
          (languageCode != null && languageCode.trim().isNotEmpty)
              ? languageCode.trim().toLowerCase()
              : _inferLanguageCode(language);

      final payload = await _invokeGenerateEdge({
        'action': 'generate',
        'template': _mapTemplateKey(template),
        'topic': topic.trim(),
        'audience': audience.trim(),
        'coreMessage': message.trim(),
        'tone': tone.trim().toLowerCase(),
        'length': length,
        'platform': platform,
        'ctaStyle': ctaStyle,
        'languageCode': resolvedLangCode,
        'languageText': language,
        'scriptStyle': scriptStyle,
        'markdownMode': true,
        if (customPrompt != null && customPrompt.trim().isNotEmpty)
          'customPrompt': customPrompt.trim(),
      });

      final title = (payload['title'] as String?)?.trim();
      final part1 = (payload['part1'] as String?)?.trim() ?? '';
      final part2 = (payload['part2'] as String?)?.trim() ?? '';
      final part3 = (payload['part3'] as String?)?.trim() ?? '';

      if (part1.isEmpty && part2.isEmpty) {
        return const Left(
          ServerFailure(
            message: 'AI returned an empty script. Please try again.',
          ),
        );
      }

      final rawAlts = payload['hookAlternatives'];
      final hookAlternatives =
          rawAlts is List
              ? rawAlts
                  .map((e) => e.toString().trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
              : <String>[];
      final meta = payload['meta'] is Map
          ? Map<String, dynamic>.from(payload['meta'] as Map)
          : const <String, dynamic>{};

      final now = DateTime.now();
      final script = ContentScript(
        id: _uuid.v4(),
        userId: userId,
        title: (title != null && title.isNotEmpty) ? title : topic.trim(),
        part1: part1,
        part2: part2,
        part3: part3,
        promptTemplate: template.name,
        questionnaire: {
          'topic': topic.trim(),
          'audience': audience.trim(),
          'message': message.trim(),
          'tone': tone,
          'language': language,
          'languageCode': resolvedLangCode,
          'length': length,
          'platform': platform,
          'scriptStyle': scriptStyle,
          'ctaStyle': ctaStyle,
          'hookAlternatives': hookAlternatives,
          if (meta['wordCount'] != null) 'wordCount': meta['wordCount'],
          if (meta['estimatedSeconds'] != null)
            'estimatedSeconds': meta['estimatedSeconds'],
        },
        createdAt: now,
        updatedAt: now,
        isRecorded: false,
      );

      final saved = await remoteDataSource.saveScript(script);
      try {
        await localDataSource?.saveScript(saved);
      } catch (_) {}

      return Right(saved);
    } catch (e) {
      logger.e('ContentCreator generateScript failed', e);
      return Left(ServerFailure(message: _cleanErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, ContentScript>> refineScript({
    required ContentScript script,
    required String instruction,
  }) async {
    try {
      final langCode = script.languageCode ?? 'en';
      final langText = script.questionnaire?['language'] as String?;

      final payload = await _invokeGenerateEdge({
        'action': 'refine',
        'refineInstruction': instruction,
        'languageCode': langCode,
        if (langText != null) 'languageText': langText,
        'scriptStyle': script.scriptStyle ?? 'spoken_natural',
        'markdownMode': true,
        'existingScript': {
          'title': script.title,
          'part1': script.part1,
          'part2': script.part2,
          'part3': script.part3,
        },
      });

      final title = (payload['title'] as String?)?.trim();
      final part1 = (payload['part1'] as String?)?.trim() ?? script.part1;
      final part2 = (payload['part2'] as String?)?.trim() ?? script.part2;
      final part3 = (payload['part3'] as String?)?.trim() ?? script.part3;

      final rawAlts = payload['hookAlternatives'];
      final hookAlternatives =
          rawAlts is List
              ? rawAlts
                  .map((e) => e.toString().trim())
                  .where((s) => s.isNotEmpty)
                  .toList()
              : script.hookAlternatives;
      final meta = payload['meta'] is Map
          ? Map<String, dynamic>.from(payload['meta'] as Map)
          : const <String, dynamic>{};

      final updatedQuestionnaire = Map<String, dynamic>.from(
        script.questionnaire ?? const {},
      );
      updatedQuestionnaire['hookAlternatives'] = hookAlternatives;
      if (meta['wordCount'] != null) {
        updatedQuestionnaire['wordCount'] = meta['wordCount'];
      }
      if (meta['estimatedSeconds'] != null) {
        updatedQuestionnaire['estimatedSeconds'] = meta['estimatedSeconds'];
      }

      final refined = script.copyWith(
        title: (title != null && title.isNotEmpty) ? title : script.title,
        part1: part1,
        part2: part2,
        part3: part3,
        questionnaire: updatedQuestionnaire,
        updatedAt: DateTime.now(),
      );

      final saved = await remoteDataSource.saveScript(refined);
      try {
        await localDataSource?.saveScript(saved);
      } catch (_) {}

      return Right(saved);
    } catch (e) {
      logger.e('ContentCreator refineScript failed', e);
      return Left(ServerFailure(message: _cleanErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, EnhancedScriptIdea>> enhanceSpokenIdea({
    required String transcript,
    String? languageCode,
    String? languageText,
    String? toneHint,
    String? lengthHint,
    String? platformHint,
  }) async {
    try {
      final cleanTranscript = transcript.trim();
      if (cleanTranscript.length < 3) {
        return const Left(
          ServerFailure(
            message: 'Please speak a few words about your video idea first.',
          ),
        );
      }

      final resolvedLangCode =
          (languageCode != null && languageCode.trim().isNotEmpty)
              ? languageCode.trim().toLowerCase()
              : _inferLanguageCode(languageText ?? 'en');

      final payload = await _invokeGenerateEdge({
        'action': 'enhance_idea',
        'spokenTranscript': cleanTranscript,
        'languageCode': resolvedLangCode,
        if (languageText != null && languageText.trim().isNotEmpty)
          'languageText': languageText.trim(),
        if (toneHint != null && toneHint.trim().isNotEmpty) 'tone': toneHint,
        if (lengthHint != null && lengthHint.trim().isNotEmpty)
          'length': lengthHint,
        if (platformHint != null && platformHint.trim().isNotEmpty)
          'platform': platformHint,
      });

      final topic = (payload['topic'] as String?)?.trim() ?? cleanTranscript;
      final audience =
          (payload['audience'] as String?)?.trim() ??
          'Creators and viewers interested in this topic';
      final coreMessage =
          (payload['coreMessage'] as String?)?.trim() ?? cleanTranscript;

      final idea = EnhancedScriptIdea(
        rawTranscript: cleanTranscript,
        topic: topic,
        audience: audience,
        coreMessage: coreMessage,
        suggestedTemplate: PromptTemplate.fromKey(
          payload['suggestedTemplate'] as String?,
        ),
        suggestedTone: (payload['suggestedTone'] as String?)?.trim() ?? 'Casual',
        suggestedLength:
            (payload['suggestedLength'] as String?)?.trim() ?? 'medium',
        suggestedPlatform:
            (payload['suggestedPlatform'] as String?)?.trim() ?? 'reels_shorts',
        summaryNote: (payload['summaryNote'] as String?)?.trim() ?? '',
      );

      return Right(idea);
    } catch (e) {
      logger.e('ContentCreator enhanceSpokenIdea failed', e);
      return Left(ServerFailure(message: _cleanErrorMessage(e)));
    }
  }

  @override
  Future<Either<Failure, void>> markAsRecorded(String scriptId) async {
    try {
      await remoteDataSource.markAsRecorded(scriptId);
      try {
        await localDataSource?.markAsRecorded(scriptId);
      } catch (_) {}
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

  Future<Map<String, dynamic>> _invokeGenerateEdge(
    Map<String, dynamic> body,
  ) async {
    final response = await _supabase.functions
        .invoke(_functionName, body: body)
        .timeout(_edgeTimeout);

    final status = response.status;
    final data = response.data;

    if (status != 200) {
      final errMsg =
          data is Map && data['error'] != null
              ? data['error'].toString()
              : 'Script service error (HTTP $status)';
      throw Exception(errMsg);
    }

    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    throw Exception('Unexpected response from script generator');
  }

  String _mapTemplateKey(PromptTemplate template) {
    switch (template) {
      case PromptTemplate.educational:
        return 'educational';
      case PromptTemplate.story:
        return 'story';
      case PromptTemplate.tips:
        return 'tips';
      case PromptTemplate.productReview:
        return 'review';
      case PromptTemplate.dayInLife:
        return 'dayinlife';
      case PromptTemplate.custom:
        return 'custom';
    }
  }

  String _inferLanguageCode(String languageName) {
    final lower = languageName.trim().toLowerCase();
    const map = {
      'english': 'en',
      'en': 'en',
      'hindi': 'hi',
      'hi': 'hi',
      'hinglish': 'hinglish',
      'tamil': 'ta',
      'ta': 'ta',
      'telugu': 'te',
      'te': 'te',
      'tanglish': 'tanglish',
      'marathi': 'mr',
      'mr': 'mr',
      'bengali': 'bn',
      'bn': 'bn',
      'gujarati': 'gu',
      'gu': 'gu',
      'kannada': 'kn',
      'kn': 'kn',
      'malayalam': 'ml',
      'ml': 'ml',
      'punjabi': 'pa',
      'pa': 'pa',
    };
    return map[lower] ?? 'en';
  }

  String _cleanErrorMessage(Object e) {
    if (e is TimeoutException) {
      return 'Script generation timed out. Please check your connection and retry.';
    }
    final raw = e.toString();
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }
}
