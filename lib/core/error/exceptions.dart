/// Base class for all custom exceptions in the application.
abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException({required this.message, this.code, this.originalError});

  @override
  String toString() => 'AppException: $message (code: $code)';
}

/// Server-related exceptions
class ServerException extends AppException {
  final int? statusCode;

  const ServerException({
    required super.message,
    super.code,
    super.originalError,
    this.statusCode,
  });

  @override
  String toString() =>
      'ServerException: $message (status: $statusCode, code: $code)';
}

/// Network exceptions (no internet, timeout)
class NetworkException extends AppException {
  const NetworkException({
    super.message = 'No internet connection.',
    super.code = 'no_connection',
    super.originalError,
  });
}

/// Timeout exception
class TimeoutException extends AppException {
  const TimeoutException({
    super.message = 'Request timed out. Please try again.',
    super.code = 'timeout',
    super.originalError,
  });
}

/// Cache/local storage exceptions
class CacheException extends AppException {
  const CacheException({
    super.message = 'Failed to access local data.',
    super.code = 'cache_error',
    super.originalError,
  });
}

/// Authentication exceptions
class AuthException extends AppException {
  const AuthException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Recording exceptions
class RecordingException extends AppException {
  const RecordingException({
    required super.message,
    super.code,
    super.originalError,
  });
}

/// Permission exceptions
class PermissionException extends AppException {
  const PermissionException({
    required super.message,
    super.code = 'permission_denied',
    super.originalError,
  });
}

/// Storage exceptions
class StorageException extends AppException {
  const StorageException({
    required super.message,
    super.code = 'storage_error',
    super.originalError,
  });
}

/// Validation exceptions
class ValidationException extends AppException {
  const ValidationException({
    required super.message,
    super.code = 'validation_error',
    super.originalError,
  });
}
