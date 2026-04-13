import 'dart:async';
import 'dart:io';

import 'package:confident_cam/core/utils/logger.dart';

/// Helper utility for robust network requests.
class NetworkHelper {
  /// Executes a Future with a timeout and exponential backoff retry logic.
  ///
  /// [operation] The async operation to perform.
  /// [timeout] The maximum time a single attempt should take.
  /// [maxAttempts] The total number of attempts (including the first try).
  /// [baseDelay] The initial delay before retrying.
  static Future<T> withRetryAndTimeout<T>(
    Future<T> Function() operation, {
    required Duration timeout,
    int maxAttempts = 3,
    Duration baseDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    while (true) {
      attempts++;
      try {
        return await operation().timeout(timeout);
      } catch (e) {
        if (attempts >= maxAttempts || !_isRetryable(e)) {
          logger.w(
            'Network operation failed after $attempts attempts. Error: $e',
          );
          rethrow;
        }

        final delay = baseDelay * attempts;
        logger.d(
          'Network operation failed, retrying in ${delay.inSeconds}s... (Attempt $attempts/$maxAttempts) Error: $e',
        );
        await Future.delayed(delay);
      }
    }
  }

  /// Determines if an exception represents a transient network error that should be retried.
  static bool _isRetryable(dynamic error) {
    if (error is TimeoutException) return true;
    if (error is SocketException) return true;
    if (error is HttpException) return true;

    // Attempt string-based matching for un-casted third-party exceptions
    final errorString = error.toString().toLowerCase();
    return errorString.contains('timeout') ||
        errorString.contains('socket') ||
        errorString.contains('handshake') ||
        errorString.contains('connection');
  }
}
