import 'package:equatable/equatable.dart';

/// Base class for all failures in the application.
/// Uses Equatable for value comparison in tests and BLoC states.
abstract class Failure extends Equatable {
  final String message;
  final String? code;

  const Failure({required this.message, this.code});

  @override
  List<Object?> get props => [message, code];
}

/// Server-related failures (API errors, network issues with server)
class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.code});

  factory ServerFailure.fromStatusCode(int statusCode) {
    switch (statusCode) {
      case 400:
        return const ServerFailure(
          message: 'Bad request. Please check your input.',
          code: 'bad_request',
        );
      case 401:
        return const ServerFailure(
          message: 'Unauthorized. Please login again.',
          code: 'unauthorized',
        );
      case 403:
        return const ServerFailure(
          message: 'Access denied.',
          code: 'forbidden',
        );
      case 404:
        return const ServerFailure(
          message: 'Resource not found.',
          code: 'not_found',
        );
      case 429:
        return const ServerFailure(
          message: 'Too many requests. Please wait a moment.',
          code: 'rate_limited',
        );
      case 500:
      case 502:
      case 503:
        return const ServerFailure(
          message: 'Server error. Please try again later.',
          code: 'server_error',
        );
      default:
        return ServerFailure(
          message: 'An unexpected error occurred (Code: $statusCode).',
          code: 'unknown',
        );
    }
  }
}

/// Network-related failures (no internet, timeout)
class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'No internet connection. Please check your network.',
    super.code = 'no_connection',
  });
}

/// Cache/local storage failures
class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Failed to access local data.',
    super.code = 'cache_error',
  });
}

/// Authentication failures
class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.code});

  factory AuthFailure.invalidPhone() => const AuthFailure(
    message: 'Please enter a valid phone number.',
    code: 'auth/invalid-phone',
  );

  factory AuthFailure.otpExpired() => const AuthFailure(
    message: 'This code has expired. Please request a new one.',
    code: 'auth/otp-expired',
  );

  factory AuthFailure.invalidOtp() => const AuthFailure(
    message: 'Invalid verification code. Please try again.',
    code: 'auth/invalid-otp',
  );

  factory AuthFailure.tooManyAttempts() => const AuthFailure(
    message: 'Too many attempts. Please wait 15 minutes.',
    code: 'auth/too-many-attempts',
  );

  factory AuthFailure.sessionExpired() => const AuthFailure(
    message: 'Your session has expired. Please login again.',
    code: 'auth/session-expired',
  );
}

/// Recording-related failures
class RecordingFailure extends Failure {
  const RecordingFailure({required super.message, super.code});

  factory RecordingFailure.permissionDenied() => const RecordingFailure(
    message: 'Camera access is required. Please enable in Settings.',
    code: 'recording/permission-denied',
  );

  factory RecordingFailure.storageFull() => const RecordingFailure(
    message: 'Not enough storage. Free up space to continue.',
    code: 'recording/storage-full',
  );

  factory RecordingFailure.recordingFailed() => const RecordingFailure(
    message: 'Recording failed. Please try again.',
    code: 'recording/failed',
  );

  factory RecordingFailure.tooShort() => const RecordingFailure(
    message: 'Video too short. Record at least 5 seconds.',
    code: 'recording/too-short',
  );
}

/// Sync-related failures
class SyncFailure extends Failure {
  const SyncFailure({
    super.message = "Couldn't save to cloud. We'll try again later.",
    super.code = 'sync/failed',
  });
}

/// Premium/payment failures
class PremiumFailure extends Failure {
  const PremiumFailure({required super.message, super.code});

  factory PremiumFailure.purchaseFailed() => const PremiumFailure(
    message: "Purchase couldn't be completed. Please try again.",
    code: 'premium/purchase-failed',
  );

  factory PremiumFailure.restoreFailed() => const PremiumFailure(
    message:
        'No purchases found. Contact support if you believe this is an error.',
    code: 'premium/restore-failed',
  );
}

/// Script generation failures
class ScriptFailure extends Failure {
  const ScriptFailure({
    super.message = "Couldn't generate personalized scripts. Using defaults.",
    super.code = 'scripts/generation-failed',
  });
}

/// Validation failures
class ValidationFailure extends Failure {
  const ValidationFailure({
    required super.message,
    super.code = 'validation_error',
  });
}
