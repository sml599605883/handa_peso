import 'package:dio/dio.dart';

/// Single error type raised by the network layer.
///
/// Feature code only ever sees this type: transport, timeout and business
/// failures are all normalised here so the UI can render one consistent error
/// state and crash reports stay attributable.
class ApiException implements Exception {
  const ApiException(this.message, {this.code, this.statusCode, this.cause});

  factory ApiException.network([Object? cause]) => ApiException(
    'Network is unavailable. Please check your connection and try again.',
    code: 'network',
    cause: cause,
  );

  factory ApiException.timeout([Object? cause]) => ApiException(
    'The request timed out. Please try again.',
    code: 'timeout',
    cause: cause,
  );

  factory ApiException.cancelled() =>
      const ApiException('Request cancelled.', code: 'cancelled');

  factory ApiException.unauthorized() => const ApiException(
    'Your session has expired. Please sign in again.',
    code: 'unauthorized',
    statusCode: 401,
  );

  /// Raised before a request is sent when required configuration is missing.
  factory ApiException.configuration(String message) =>
      ApiException(message, code: 'configuration');

  final String message;

  /// Either a symbolic transport code ('network', 'timeout', ...) or the raw
  /// numeric business code returned by the gateway.
  final Object? code;
  final int? statusCode;
  final Object? cause;

  bool get isUnauthorized => code == 'unauthorized' || statusCode == 401;

  bool get isAuthExpired => code == -2 || code == '-2';

  @override
  String toString() =>
      'ApiException(code: $code, status: $statusCode, message: $message)';
}

/// Maps any thrown object to a user-safe message.
abstract final class ApiErrorMessage {
  static String resolve(Object? error) {
    if (error == null) return 'Network error';
    if (error is ApiException) return error.message;
    if (error is DioException) {
      return switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          'The request timed out. Please try again.',
        DioExceptionType.connectionError =>
          'Network is unavailable. Please check your connection and try again.',
        _ => error.message ?? 'Network error',
      };
    }
    return error.toString();
  }
}
