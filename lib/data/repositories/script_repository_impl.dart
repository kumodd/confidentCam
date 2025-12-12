import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';

import '../../core/error/failures.dart';
import '../../core/network/network_info.dart';
import '../../core/utils/logger.dart';
import '../../domain/entities/daily_script.dart';
import '../../domain/repositories/script_repository.dart';
import '../datasources/local/hive_scripts_datasource.dart';
import '../datasources/remote/supabase_script_datasource.dart';
import '../models/daily_script_model.dart';

/// Implementation of ScriptRepository with caching.
class ScriptRepositoryImpl implements ScriptRepository {
  final SupabaseScriptDataSource remoteDataSource;
  final HiveScriptsDataSource localDataSource;
  final NetworkInfo networkInfo;
  final Uuid _uuid = const Uuid();

  ScriptRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<DailyScript>>> getScripts(String userId) async {
    try {
      // Try local cache first
      if (await localDataSource.hasScripts()) {
        final cached = await localDataSource.getScripts();
        if (cached.isNotEmpty) {
          return Right(
            cached.map((json) => DailyScriptModel.fromJson(json)).toList(),
          );
        }
      }

      // Fetch from remote if online
      if (await networkInfo.isConnected) {
        try {
          final data = await remoteDataSource.getScripts(userId);
          if (data.isNotEmpty) {
            await localDataSource.cacheScripts(data);
            return Right(
              data.map((json) => DailyScriptModel.fromJson(json)).toList(),
            );
          }
        } catch (e) {
          logger.w('Failed to fetch remote scripts', e);
        }
      }

      // Return empty if nothing found
      return const Right([]);
    } catch (e) {
      logger.e('Error getting scripts', e);
      return const Left(ServerFailure(message: 'Failed to load scripts'));
    }
  }

  @override
  Future<Either<Failure, DailyScript?>> getScriptForDay(
    String userId,
    int dayNumber,
  ) async {
    try {
      // Try local cache first
      final cached = await localDataSource.getScriptForDay(dayNumber);
      if (cached != null) {
        return Right(DailyScriptModel.fromJson(cached));
      }

      // Fetch from remote if online
      if (await networkInfo.isConnected) {
        final data = await remoteDataSource.getScriptForDay(userId, dayNumber);
        if (data != null) {
          return Right(DailyScriptModel.fromJson(data));
        }
      }

      return const Right(null);
    } catch (e) {
      logger.e('Error getting script for day $dayNumber', e);
      return const Right(null);
    }
  }

  @override
  Future<Either<Failure, List<DailyScript>>> generateScripts({
    required String userId,
    required String goal,
    required String niche,
    required String fear,
    required String experience,
  }) async {
    // For MVP, we use fallback scripts instead of AI generation
    // In future, this would call an Edge Function for AI generation
    logger.i('Generating scripts for user $userId');

    return loadFallbackScripts(userId);
  }

  @override
  Future<Either<Failure, List<DailyScript>>> loadFallbackScripts(
    String userId,
  ) async {
    try {
      final scripts = <Map<String, dynamic>>[];
      final now = DateTime.now();

      // Generate fallback scripts for all 30 days
      for (int day = 1; day <= 30; day++) {
        final script = _generateFallbackScript(userId, day, now);
        scripts.add(script);
      }

      // Save to remote if online
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.saveScripts(scripts);
        } catch (e) {
          logger.w('Failed to save scripts to remote', e);
        }
      }

      // Cache locally
      await localDataSource.cacheScripts(scripts);

      return Right(
        scripts.map((json) => DailyScriptModel.fromJson(json)).toList(),
      );
    } catch (e) {
      logger.e('Error loading fallback scripts', e);
      return const Left(ScriptFailure());
    }
  }

  Map<String, dynamic> _generateFallbackScript(
    String userId,
    int day,
    DateTime now,
  ) {
    final id = _uuid.v4();

    if (day <= 5) {
      // Segmented scripts for days 1-5
      return {
        'id': id,
        'user_id': userId,
        'day_number': day,
        'script_type': 'segmented',
        'script_json': _getSegmentedScript(day),
        'created_at': now.toIso8601String(),
      };
    } else {
      // Full scripts for days 6-30
      return {
        'id': id,
        'user_id': userId,
        'day_number': day,
        'script_type': 'full',
        'script_json': _getFullScript(day),
        'created_at': now.toIso8601String(),
      };
    }
  }

  Map<String, dynamic> _getSegmentedScript(int day) {
    final scripts = {
      1: {
        'title': 'Your First Step',
        'segments': [
          {
            'part': 1,
            'text':
                "Hi, I'm starting my 30-day camera confidence journey today.",
            'focus': 'Eye contact with lens',
          },
          {
            'part': 2,
            'text': "I've always wanted to be more comfortable on camera.",
            'focus': 'Natural expression',
          },
          {
            'part': 3,
            'text':
                "This is my first step, and I'm proud of myself for showing up.",
            'focus': 'Confident delivery',
          },
          {
            'part': 4,
            'text': 'See you tomorrow for Day 2!',
            'focus': 'Energetic closing',
          },
        ],
      },
      2: {
        'title': 'Building Momentum',
        'segments': [
          {
            'part': 1,
            'text': 'Day 2! I showed up again.',
            'focus': 'Enthusiasm',
          },
          {
            'part': 2,
            'text': 'Yesterday was a little awkward, but that\'s okay.',
            'focus': 'Self-compassion',
          },
          {
            'part': 3,
            'text':
                'Today I\'m focusing on looking at the lens like it\'s a friend.',
            'focus': 'Connection',
          },
          {
            'part': 4,
            'text': 'One day at a time!',
            'focus': 'Positive mindset',
          },
        ],
      },
      3: {
        'title': 'Finding Your Voice',
        'segments': [
          {
            'part': 1,
            'text': 'Welcome to Day 3 of my journey.',
            'focus': 'Clear introduction',
          },
          {
            'part': 2,
            'text': 'I\'m starting to feel a little more natural on camera.',
            'focus': 'Progress awareness',
          },
          {
            'part': 3,
            'text':
                'Today, I\'m working on projecting my voice with confidence.',
            'focus': 'Voice projection',
          },
          {
            'part': 4,
            'text': 'Every day I\'m getting stronger!',
            'focus': 'Motivation',
          },
        ],
      },
      4: {
        'title': 'Embracing Imperfection',
        'segments': [
          {
            'part': 1,
            'text': 'Day 4, and I\'m still here!',
            'focus': 'Consistency',
          },
          {
            'part': 2,
            'text':
                'I\'ve learned that perfection isn\'t the goal—progress is.',
            'focus': 'Growth mindset',
          },
          {
            'part': 3,
            'text': 'Today I\'m practicing being okay with making mistakes.',
            'focus': 'Self-acceptance',
          },
          {'part': 4, 'text': 'See you tomorrow!', 'focus': 'Friendly closing'},
        ],
      },
      5: {
        'title': 'Week One Complete',
        'segments': [
          {
            'part': 1,
            'text': 'I can\'t believe I\'ve made it to Day 5!',
            'focus': 'Celebration',
          },
          {
            'part': 2,
            'text': 'Looking back, I\'ve already improved so much.',
            'focus': 'Reflection',
          },
          {
            'part': 3,
            'text': 'I\'m committed to completing this 30-day challenge.',
            'focus': 'Commitment',
          },
          {
            'part': 4,
            'text': 'Let\'s keep this momentum going!',
            'focus': 'Energy',
          },
        ],
      },
    };

    return scripts[day] ?? scripts[1]!;
  }

  Map<String, dynamic> _getFullScript(int day) {
    final scripts = {
      6: {
        'title': 'Speaking From The Heart',
        'script':
            'Today is Day 6, and I\'m starting to find my rhythm on camera. What I\'ve realized is that being authentic matters more than being perfect. When I speak from the heart, the words flow more naturally. If you\'re watching this, I want you to know that you can do this too. This is me, showing up authentically. See you tomorrow!',
        'word_count': 65,
        'estimated_duration': '30-45 seconds',
      },
      7: {
        'title': 'One Week Strong',
        'script':
            'Day 7! I\'ve officially completed one full week of this challenge. I remember how nervous I was on Day 1, and while I\'m not completely comfortable yet, I can already see the difference. Consistency is key, and showing up every day is building my confidence. Here\'s to the next three weeks!',
        'word_count': 58,
        'estimated_duration': '25-35 seconds',
      },
    };

    // Generate generic scripts for remaining days
    if (!scripts.containsKey(day)) {
      return {
        'title': 'Day $day Journey',
        'script':
            'Welcome to Day $day of my camera confidence journey. Each day I show up, I\'m proving to myself that I can do this. Today I\'m focusing on being present and authentic. Remember, progress over perfection. Let\'s keep going!',
        'word_count': 42,
        'estimated_duration': '20-30 seconds',
      };
    }

    return scripts[day]!;
  }

  @override
  Future<bool> hasLocalScripts(String userId) async {
    return await localDataSource.hasScripts();
  }

  @override
  Future<Either<Failure, void>> saveGeneratedScripts({
    required String userId,
    required List<Map<String, dynamic>> scripts,
  }) async {
    try {
      logger.i('Saving ${scripts.length} generated scripts for user $userId');

      final formattedScripts =
          scripts.map((script) {
            final dayNumber = script['dayNumber'] as int;
            return {
              'id': _uuid.v4(),
              'user_id': userId,
              'day_number': dayNumber,
              'script_type':
                  script['scriptType'] ??
                  (dayNumber <= 5 ? 'segmented' : 'full'),
              'script_json': script,
              'created_at': DateTime.now().toIso8601String(),
            };
          }).toList();

      // Save to remote if online
      if (await networkInfo.isConnected) {
        try {
          await remoteDataSource.saveScripts(formattedScripts);
        } catch (e) {
          logger.w('Failed to save scripts to remote', e);
        }
      }

      // Cache locally
      await localDataSource.cacheScripts(formattedScripts);

      return const Right(null);
    } catch (e) {
      logger.e('Error saving generated scripts', e);
      return const Left(ScriptFailure(message: 'Failed to save scripts'));
    }
  }

  @override
  Future<void> clearCache() async {
    await localDataSource.clearScripts();
  }
}
