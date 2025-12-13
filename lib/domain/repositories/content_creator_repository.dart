import 'package:dartz/dartz.dart';

import '../../core/error/failures.dart';
import '../entities/content_script.dart';

/// Repository interface for Content Creator operations.
/// This is completely standalone from the existing ScriptRepository.
abstract class ContentCreatorRepository {
  /// Get all content scripts for a user.
  Future<Either<Failure, List<ContentScript>>> getScripts(String userId);

  /// Get a specific script by ID.
  Future<Either<Failure, ContentScript?>> getScriptById(String scriptId);

  /// Save a new script or update existing one.
  Future<Either<Failure, ContentScript>> saveScript(ContentScript script);

  /// Delete a script by ID.
  Future<Either<Failure, void>> deleteScript(String scriptId);

  /// Generate a new script using OpenAI based on questionnaire and template.
  Future<Either<Failure, ContentScript>> generateScript({
    required String userId,
    required String topic,
    required String audience,
    required String message,
    required String tone,
    required String language,
    required PromptTemplate template,
    String? customPrompt,
  });

  /// Mark a script as recorded.
  Future<Either<Failure, void>> markAsRecorded(String scriptId);

  /// Get videos recorded for content creator (filtered by 'content' type).
  Future<Either<Failure, List<String>>> getContentVideoPaths(String userId);
}
