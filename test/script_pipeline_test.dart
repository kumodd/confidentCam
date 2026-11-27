import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:confident_cam/core/error/failures.dart';
import 'package:confident_cam/data/datasources/local/hive_content_scripts_datasource.dart';
import 'package:confident_cam/data/datasources/local/hive_scripts_datasource.dart';
import 'package:confident_cam/data/datasources/remote/supabase_content_scripts_datasource.dart';
import 'package:confident_cam/data/repositories/content_creator_repository_impl.dart';
import 'package:confident_cam/domain/entities/content_script.dart';
import 'package:confident_cam/domain/entities/onboarding_data.dart';
import 'package:confident_cam/domain/repositories/content_creator_repository.dart';
import 'package:confident_cam/presentation/bloc/content_creator/content_creator_bloc.dart';
import 'package:confident_cam/presentation/bloc/content_creator/content_creator_event.dart';
import 'package:confident_cam/presentation/bloc/content_creator/content_creator_state.dart';
import 'package:confident_cam/presentation/bloc/onboarding/onboarding_state.dart';
import 'package:confident_cam/services/video_storage_service.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockRemoteContentScriptsDataSource extends Mock
    implements SupabaseContentScriptsDataSource {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockContentCreatorRepository extends Mock
    implements ContentCreatorRepository {}

class _MockVideoStorageService extends Mock implements VideoStorageService {}

class _FakeContentScript extends Fake implements ContentScript {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeContentScript());
    registerFallbackValue(PromptTemplate.educational);
  });

  group('OnboardingInProgress & UserPersonalInfo fidelity', () {
    test('preserves selectedLanguage code and resolvedGoalText in toPersonalInfo()', () {
      final state = OnboardingInProgress(
        userId: 'user-1',
        currentStep: 2,
        totalSteps: 5,
        questions: const [],
        goalOptions: const [
          GoalOption(
            id: 'g1',
            key: 'content_creator',
            text: 'Grow as a confident content creator',
            orderIndex: 1,
          ),
        ],
        languageOptions: const [
          LanguageOption(
            id: 'l1',
            code: 'ta',
            name: 'Tamil',
            nativeName: 'தமிழ்',
            orderIndex: 1,
          ),
        ],
        firstName: 'Ananya',
        age: 26,
        location: 'Chennai',
        selectedLanguage: const LanguageOption(
          id: 'l1',
          code: 'ta',
          name: 'Tamil',
          nativeName: 'தமிழ்',
          orderIndex: 1,
        ),
        selectedGoal: const GoalOption(
          id: 'g1',
          key: 'content_creator',
          text: 'Grow as a confident content creator',
          orderIndex: 1,
        ),
        answers: const {
          'biggest_fear': ['Forgetting my lines'],
        },
      );

      final info = state.toPersonalInfo();
      expect(info.languagePreference, equals('ta'));
      expect(info.goalKey, equals('content_creator'));
      expect(info.resolvedGoalText, equals('Grow as a confident content creator'));
      expect(info.displayGoal, equals('Grow as a confident content creator'));
      expect(info.answers['biggest_fear'], equals(['Forgetting my lines']));
    });

    test('prefers customGoal when goalKey is other, falls back cleanly when unset', () {
      const customInfo = UserPersonalInfo(
        firstName: 'Dev',
        age: 30,
        location: 'Pune',
        goalKey: 'other',
        customGoal: 'Host a weekly product teardown show',
        resolvedGoalText: 'Other',
      );
      expect(customInfo.displayGoal, equals('Host a weekly product teardown show'));

      const slugOnly = UserPersonalInfo(
        firstName: 'Dev',
        age: 30,
        location: 'Pune',
        goalKey: 'camera_confidence',
      );
      expect(slugOnly.displayGoal, equals('camera_confidence'));
    });
  });

  group('HiveScriptsDataSourceImpl per-user cache isolation', () {
    late Directory tempDir;
    late Box scriptsBox;
    late HiveScriptsDataSourceImpl dataSource;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cc_hive_scripts_test_');
      Hive.init(tempDir.path);
      scriptsBox = await Hive.openBox('test_scripts_box');
      dataSource = HiveScriptsDataSourceImpl(scriptsBox: scriptsBox);
    });

    tearDown(() async {
      await scriptsBox.close();
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('isolates daily and warmup scripts strictly by userId', () async {
      await dataSource.cacheScripts('userA', [
        {'day_number': 1, 'title': 'A Day 1', 'script_text': 'Alpha script'},
        // Negative day_number rows (synced warmups) must not pollute daily slots
        {'day_number': -1, 'title': 'Warmup row', 'script_text': 'Ignored'},
      ]);
      await dataSource.cacheScripts('userB', [
        {'day_number': 1, 'title': 'B Day 1', 'script_text': 'Beta script'},
      ]);

      await dataSource.cacheWarmupScripts('userA', [
        {'warmupIndex': 0, 'title': 'A Warmup 0', 'scriptText': 'Warmup A'},
      ]);
      await dataSource.cacheWarmupScripts('userB', [
        {'warmupIndex': 0, 'title': 'B Warmup 0', 'scriptText': 'Warmup B'},
      ]);

      expect((await dataSource.getScripts('userA')).length, equals(1));
      expect(
        (await dataSource.getScriptForDay('userA', 1))?['title'],
        equals('A Day 1'),
      );
      expect(
        (await dataSource.getScriptForDay('userB', 1))?['title'],
        equals('B Day 1'),
      );
      expect(
        (await dataSource.getWarmupScript('userA', 0))?['title'],
        equals('A Warmup 0'),
      );
      expect(
        (await dataSource.getWarmupScript('userB', 0))?['title'],
        equals('B Warmup 0'),
      );

      // Clearing userA leaves userB completely untouched
      await dataSource.clearScripts(userId: 'userA');

      expect(await dataSource.hasScripts('userA'), isFalse);
      expect(await dataSource.getScriptForDay('userA', 1), isNull);
      expect(await dataSource.getWarmupScript('userA', 0), isNull);

      expect(await dataSource.hasScripts('userB'), isTrue);
      expect(
        (await dataSource.getScriptForDay('userB', 1))?['title'],
        equals('B Day 1'),
      );
      expect(
        (await dataSource.getWarmupScript('userB', 0))?['title'],
        equals('B Warmup 0'),
      );
    });
  });

  group('ContentScript metadata helpers', () {
    test('reads hookAlternatives and meta cleanly from questionnaire JSONB', () {
      final now = DateTime(2026, 11, 27);
      final script = ContentScript(
        id: '11111111-1111-4111-8111-111111111111',
        userId: 'user-1',
        title: 'Eye Contact Secret',
        part1: 'Stop staring at yourself on screen.',
        part2: 'Look right into the camera lens.\n\nPut a tiny sticker next to it.',
        part3: 'Try this in your next take.',
        promptTemplate: 'tips',
        questionnaire: const {
          'hookAlternatives': [
            'Stop staring at yourself on screen.',
            'Why does your audience feel disconnected?',
            'One tiny sticker fixed my camera anxiety.',
          ],
          'wordCount': 142,
          'estimatedSeconds': 61,
          'languageCode': 'hinglish',
          'length': 'medium',
          'platform': 'youtube',
          'scriptStyle': 'romanized',
        },
        createdAt: now,
        updatedAt: now,
      );

      expect(script.hookAlternatives.length, equals(3));
      expect(script.wordCount, equals(142));
      expect(script.estimatedSeconds, equals(61));
      expect(script.languageCode, equals('hinglish'));
      expect(script.lengthKey, equals('medium'));
      expect(script.platformKey, equals('youtube'));
      expect(script.scriptStyle, equals('romanized'));
    });

    test('returns safe defaults when questionnaire is null', () {
      final now = DateTime(2026, 11, 27);
      final script = ContentScript(
        id: '22222222-2222-4222-8222-222222222222',
        userId: 'user-1',
        title: 'Manual',
        part1: 'Hook',
        part2: 'Body',
        part3: 'Close',
        createdAt: now,
        updatedAt: now,
      );

      expect(script.hookAlternatives, isEmpty);
      expect(script.wordCount, isNull);
      expect(script.estimatedSeconds, isNull);
      expect(script.languageCode, isNull);
    });
  });

  group('ContentCreatorRepositoryImpl unified Edge Function & offline cache', () {
    late Directory tempDir;
    late Box contentBox;
    late HiveContentScriptsDataSourceImpl localDataSource;
    late _MockRemoteContentScriptsDataSource remoteDataSource;
    late _MockSupabaseClient supabaseClient;
    late _MockFunctionsClient functionsClient;
    late ContentCreatorRepositoryImpl repository;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('cc_content_repo_test_');
      Hive.init(tempDir.path);
      contentBox = await Hive.openBox('test_content_scripts_box');
      localDataSource = HiveContentScriptsDataSourceImpl(
        contentScriptsBox: contentBox,
      );
      remoteDataSource = _MockRemoteContentScriptsDataSource();
      supabaseClient = _MockSupabaseClient();
      functionsClient = _MockFunctionsClient();
      when(() => supabaseClient.functions).thenReturn(functionsClient);

      repository = ContentCreatorRepositoryImpl(
        remoteDataSource: remoteDataSource,
        localDataSource: localDataSource,
        supabaseClient: supabaseClient,
      );
    });

    tearDown(() async {
      await contentBox.close();
      await Hive.close();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('generateScript calls generate-script edge fn, preserves AI title/hooks/meta, and caches locally', () async {
      Map<String, dynamic>? capturedBody;

      when(
        () => functionsClient.invoke(
          'generate-script',
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        capturedBody =
            invocation.namedArguments[#body] as Map<String, dynamic>?;
        return FunctionResponse(
          status: 200,
          data: {
            'title': 'Camera Confidence Without Awkwardness',
            'part1': 'Stop hiding behind your script.',
            'part2': 'Beat one with **energy**.\n\nBeat two with a real story.',
            'part3': 'Hit record today and share take one.',
            'hookAlternatives': [
              'Stop hiding behind your script.',
              'Why do you freeze the second the red light blinks?',
              'Two minutes a day cured my camera shyness.',
            ],
            'meta': {
              'wordCount': 148,
              'estimatedSeconds': 63,
            },
          },
        );
      });

      when(() => remoteDataSource.saveScript(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ContentScript,
      );

      final result = await repository.generateScript(
        userId: 'user-42',
        topic: 'How to beat camera anxiety with humour',
        audience: 'New YouTube creators',
        message: 'Laugh at your first awkward take',
        tone: 'humorous',
        language: 'Hindi',
        languageCode: 'hi',
        template: PromptTemplate.tips,
        length: 'long',
        platform: 'youtube',
        scriptStyle: 'romanized',
      );

      expect(result.isRight(), isTrue);
      final script = result.getOrElse(() => throw StateError('expected Right'));

      expect(capturedBody?['action'], equals('generate'));
      expect(capturedBody?['tone'], equals('humorous'));
      expect(capturedBody?['length'], equals('long'));
      expect(capturedBody?['platform'], equals('youtube'));
      expect(capturedBody?['languageCode'], equals('hi'));
      expect(capturedBody?['scriptStyle'], equals('romanized'));

      expect(script.title, equals('Camera Confidence Without Awkwardness'));
      expect(script.hookAlternatives.length, equals(3));
      expect(script.wordCount, equals(148));
      expect(script.estimatedSeconds, equals(63));

      // Verify offline cache was also populated
      final cached = await localDataSource.getScripts('user-42');
      expect(cached.length, equals(1));
      expect(cached.first.id, equals(script.id));
    });

    test('generateScript surfaces ServerFailure on edge error (never saves fake fallback script)', () async {
      when(
        () => functionsClient.invoke(
          'generate-script',
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => FunctionResponse(
          status: 502,
          data: {'error': 'Upstream model temporarily unavailable'},
        ),
      );

      final result = await repository.generateScript(
        userId: 'user-42',
        topic: 'Test failure handling',
        audience: 'Everyone',
        message: 'Should fail transparently',
        tone: 'casual',
        language: 'English',
        languageCode: 'en',
        template: PromptTemplate.educational,
      );

      expect(result.isLeft(), isTrue);
      verifyNever(() => remoteDataSource.saveScript(any()));
      expect(await localDataSource.getScripts('user-42'), isEmpty);
    });

    test('refineScript preserves script ID and updates body, hooks, and wordCount', () async {
      final now = DateTime(2026, 11, 27);
      final original = ContentScript(
        id: '33333333-3333-4333-8333-333333333333',
        userId: 'user-42',
        title: 'Original Title',
        part1: 'Original hook sentence here.',
        part2: 'Long original body paragraph one.\n\nParagraph two.',
        part3: 'Original closing call to action.',
        promptTemplate: 'educational',
        questionnaire: const {
          'languageCode': 'en',
          'scriptStyle': 'spoken_natural',
          'wordCount': 150,
          'estimatedSeconds': 64,
        },
        createdAt: now,
        updatedAt: now,
      );

      when(
        () => functionsClient.invoke(
          'generate-script',
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => FunctionResponse(
          status: 200,
          data: {
            'title': 'Tighter Title',
            'part1': 'Tighter hook.',
            'part2': 'Tighter body beat one.\n\nBeat two.',
            'part3': 'Tighter close.',
            'hookAlternatives': ['Tighter hook.', 'Alt hook 2', 'Alt hook 3'],
            'meta': {'wordCount': 102, 'estimatedSeconds': 44},
          },
        ),
      );

      when(() => remoteDataSource.saveScript(any())).thenAnswer(
        (inv) async => inv.positionalArguments.first as ContentScript,
      );

      final result = await repository.refineScript(
        script: original,
        instruction: 'shorter',
      );

      expect(result.isRight(), isTrue);
      final refined = result.getOrElse(() => throw StateError('expected Right'));
      expect(refined.id, equals(original.id));
      expect(refined.title, equals('Tighter Title'));
      expect(refined.part1, equals('Tighter hook.'));
      expect(refined.wordCount, equals(102));
      expect(refined.hookAlternatives.length, equals(3));
    });

    test('getScripts falls back to offline Hive cache when Supabase is unreachable', () async {
      final now = DateTime(2026, 11, 27);
      final cachedScript = ContentScript(
        id: '44444444-4444-4444-8444-444444444444',
        userId: 'user-offline',
        title: 'Offline Ready Script',
        part1: 'Hook',
        part2: 'Body',
        part3: 'Close',
        createdAt: now,
        updatedAt: now,
      );
      await localDataSource.saveScript(cachedScript);

      when(
        () => remoteDataSource.getScripts('user-offline'),
      ).thenThrow(Exception('SocketException: No route to host'));

      final result = await repository.getScripts('user-offline');
      expect(result.isRight(), isTrue);
      final list = result.getOrElse(() => const []);
      expect(list.length, equals(1));
      expect(list.first.title, equals('Offline Ready Script'));
    });

    test('enhanceSpokenIdea invokes enhance_idea action and parses structured brief', () async {
      Map<String, dynamic>? capturedBody;

      when(
        () => functionsClient.invoke(
          'generate-script',
          body: any(named: 'body'),
        ),
      ).thenAnswer((invocation) async {
        capturedBody =
            invocation.namedArguments[#body] as Map<String, dynamic>?;
        return FunctionResponse(
          status: 200,
          data: {
            'topic': 'Why Beginners Hate Their Recorded Voice on Camera',
            'audience': 'First-time Reels and YouTube creators',
            'coreMessage': 'Record 60-second voice notes daily until your ear adapts',
            'suggestedTemplate': 'tips',
            'suggestedTone': 'Casual',
            'suggestedLength': 'short',
            'suggestedPlatform': 'reels_shorts',
            'summaryNote': 'Tightened into a short Reels tips brief',
          },
        );
      });

      final result = await repository.enhanceSpokenIdea(
        transcript: 'uh make a quick reel about hating your own voice on camera',
        languageCode: 'en',
        languageText: 'English',
        toneHint: 'Casual',
        lengthHint: 'short',
        platformHint: 'reels_shorts',
      );

      expect(result.isRight(), isTrue);
      expect(capturedBody?['action'], equals('enhance_idea'));
      final idea = result.getOrElse(() => throw StateError('expected Right'));
      expect(idea.topic, equals('Why Beginners Hate Their Recorded Voice on Camera'));
      expect(idea.suggestedTemplate, equals(PromptTemplate.tips));
      expect(idea.suggestedLength, equals('short'));
      expect(idea.suggestedPlatform, equals('reels_shorts'));
    });
  });

  group('ContentCreatorBloc resilient state transitions', () {
    late _MockContentCreatorRepository mockRepo;
    late _MockVideoStorageService mockVideoStorage;
    late ContentScript sampleScript;
    late ContentScript refinedScript;

    setUp(() {
      mockRepo = _MockContentCreatorRepository();
      mockVideoStorage = _MockVideoStorageService();
      when(() => mockVideoStorage.getAllVideos()).thenAnswer((_) async => []);

      final now = DateTime(2026, 11, 27);
      sampleScript = ContentScript(
        id: '55555555-5555-4555-8555-555555555555',
        userId: 'user-1',
        title: 'Original',
        part1: 'Hook 1',
        part2: 'Body 1',
        part3: 'Close 1',
        createdAt: now,
        updatedAt: now,
      );
      refinedScript = sampleScript.copyWith(
        part1: 'Punchier Hook!',
        title: 'Refined',
      );
    });

    blocTest<ContentCreatorBloc, ContentCreatorState>(
      'restores previous ContentCreatorLoaded list after a failed GenerateScript so MyScriptsTab never goes blank',
      build: () {
        when(
          () => mockRepo.getScripts('user-1'),
        ).thenAnswer((_) async => Right([sampleScript]));
        when(
          () => mockRepo.generateScript(
            userId: any(named: 'userId'),
            topic: any(named: 'topic'),
            audience: any(named: 'audience'),
            message: any(named: 'message'),
            tone: any(named: 'tone'),
            language: any(named: 'language'),
            languageCode: any(named: 'languageCode'),
            template: any(named: 'template'),
            length: any(named: 'length'),
            platform: any(named: 'platform'),
            scriptStyle: any(named: 'scriptStyle'),
            ctaStyle: any(named: 'ctaStyle'),
            customPrompt: any(named: 'customPrompt'),
          ),
        ).thenAnswer(
          (_) async => const Left(ServerFailure(message: 'Network timeout')),
        );
        return ContentCreatorBloc(
          repository: mockRepo,
          videoStorageService: mockVideoStorage,
        );
      },
      act: (bloc) async {
        bloc.add(const LoadScripts('user-1'));
        await Future<void>.delayed(Duration.zero);
        bloc.add(
          const GenerateScript(
            userId: 'user-1',
            topic: 'Test',
            audience: 'All',
            message: 'Msg',
            tone: 'casual',
            language: 'English',
            languageCode: 'en',
            template: PromptTemplate.tips,
          ),
        );
      },
      expect: () => [
        isA<ContentCreatorLoading>(),
        isA<ContentCreatorLoaded>().having((s) => s.scripts.length, 'count', 1),
        isA<ScriptGenerating>(),
        isA<ContentCreatorError>().having((s) => s.message, 'msg', 'Network timeout'),
        isA<ContentCreatorLoaded>().having((s) => s.scripts.length, 'count', 1),
      ],
    );

    blocTest<ContentCreatorBloc, ContentCreatorState>(
      'emits ScriptRefining -> ScriptRefined -> ContentCreatorLoaded on RefineScript',
      build: () {
        when(
          () => mockRepo.refineScript(
            script: any(named: 'script'),
            instruction: 'punchier_hook',
          ),
        ).thenAnswer((_) async => Right(refinedScript));
        when(
          () => mockRepo.getScripts('user-1'),
        ).thenAnswer((_) async => Right([refinedScript]));
        return ContentCreatorBloc(
          repository: mockRepo,
          videoStorageService: mockVideoStorage,
        );
      },
      act: (bloc) => bloc.add(
        RefineScript(script: sampleScript, instruction: 'punchier_hook'),
      ),
      expect: () => [
        isA<ScriptRefining>(),
        isA<ScriptRefined>().having((s) => s.script.part1, 'part1', 'Punchier Hook!'),
        isA<ContentCreatorLoaded>().having(
          (s) => s.scripts.first.part1,
          'first.part1',
          'Punchier Hook!',
        ),
      ],
    );

    blocTest<ContentCreatorBloc, ContentCreatorState>(
      'EnhanceSpokenIdea(autoGenerate: true) chains detected spoken language straight into generateScript',
      build: () {
        const enhancedIdea = EnhancedScriptIdea(
          rawTranscript: 'chat GPT Kaise kam karta hai',
          topic: 'ChatGPT Kaise Kaam Karta Hai',
          audience: 'Tech-curious beginners in India',
          coreMessage: 'Samjho kaise ChatGPT patterns predict karke jawab deta hai',
          suggestedTemplate: PromptTemplate.educational,
          suggestedTone: 'Casual',
          suggestedLength: 'short',
          suggestedPlatform: 'reels_shorts',
          detectedLanguageCode: 'hinglish',
          detectedLanguageName: 'Hinglish',
          detectedScriptStyle: 'romanized',
        );
        when(
          () => mockRepo.enhanceSpokenIdea(
            transcript: any(named: 'transcript'),
            languageCode: any(named: 'languageCode'),
            languageText: any(named: 'languageText'),
            toneHint: any(named: 'toneHint'),
            lengthHint: any(named: 'lengthHint'),
            platformHint: any(named: 'platformHint'),
          ),
        ).thenAnswer((_) async => const Right(enhancedIdea));
        when(
          () => mockRepo.generateScript(
            userId: any(named: 'userId'),
            topic: any(named: 'topic'),
            audience: any(named: 'audience'),
            message: any(named: 'message'),
            tone: any(named: 'tone'),
            language: any(named: 'language'),
            languageCode: any(named: 'languageCode'),
            template: any(named: 'template'),
            length: any(named: 'length'),
            platform: any(named: 'platform'),
            scriptStyle: any(named: 'scriptStyle'),
            ctaStyle: any(named: 'ctaStyle'),
            customPrompt: any(named: 'customPrompt'),
          ),
        ).thenAnswer((_) async => Right(sampleScript));
        when(
          () => mockRepo.getScripts('user-1'),
        ).thenAnswer((_) async => Right([sampleScript]));

        return ContentCreatorBloc(
          repository: mockRepo,
          videoStorageService: mockVideoStorage,
        );
      },
      act: (bloc) => bloc.add(
        const EnhanceSpokenIdea(
          userId: 'user-1',
          transcript: 'chat GPT Kaise kam karta hai',
          language: 'Auto-Detect',
          languageCode: 'auto',
          autoGenerate: true,
        ),
      ),
      expect: () => [
        isA<IdeaEnhancing>(),
        isA<IdeaEnhanced>()
            .having((s) => s.autoGenerating, 'autoGen', isTrue)
            .having((s) => s.idea.detectedLanguageCode, 'langCode', 'hinglish'),
        isA<ScriptGenerating>(),
        isA<ScriptGenerated>(),
        isA<ContentCreatorLoaded>().having(
          (s) => s.selectedScript?.id,
          'selectedScript',
          sampleScript.id,
        ),
      ],
      verify: (_) {
        verify(
          () => mockRepo.generateScript(
            userId: 'user-1',
            topic: 'ChatGPT Kaise Kaam Karta Hai',
            audience: 'Tech-curious beginners in India',
            message: 'Samjho kaise ChatGPT patterns predict karke jawab deta hai',
            tone: 'Casual',
            language: 'Hinglish',
            languageCode: 'hinglish',
            template: PromptTemplate.educational,
            length: 'short',
            platform: 'reels_shorts',
            scriptStyle: 'romanized',
          ),
        ).called(1);
      },
    );
  });
}
