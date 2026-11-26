import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/content_script.dart';

/// Repository interface for Content Creator operations.
abstract class ContentCreatorRepository {
  /// Get all content scripts for a user (remote with offline cache fallback).
  Future<Either<Failure, List<ContentScript>>> getScripts(String userId);

  /// Get a specific script by ID.
  Future<Either<Failure, ContentScript?>> getScriptById(String scriptId);

  /// Save a new script or update existing one.
  Future<Either<Failure, ContentScript>> saveScript(ContentScript script);

  /// Delete a script by ID.
  Future<Either<Failure, void>> deleteScript(String scriptId);

  /// Generate a new script via the Supabase `generate-script` Edge Function.
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
  });

  /// Refine an existing script (`punchier_hook`, `shorter`, `more_casual`,
  /// `add_example`, or custom instruction) and persist the updated version.
  Future<Either<Failure, ContentScript>> refineScript({
    required ContentScript script,
    required String instruction,
  });

  /// Analyze & expand a raw spoken Speech-to-Text idea transcript into a
  /// structured video content brief ready for script generation.
  Future<Either<Failure, EnhancedScriptIdea>> enhanceSpokenIdea({
    required String transcript,
    String? languageCode,
    String? languageText,
    String? toneHint,
    String? lengthHint,
    String? platformHint,
  });

  /// Mark a script as recorded.
  Future<Either<Failure, void>> markAsRecorded(String scriptId);

  /// Get videos recorded for content creator (filtered by 'content' type).
  Future<Either<Failure, List<String>>> getContentVideoPaths(String userId);
}
