/// Domain-level error raised by the network layer.
///
/// The UI should never have to inspect raw [DioException]s; the client maps
/// every transport, timeout and business failure into this single type.
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

  final String message;
  final String? code;
  final int? statusCode;
  final Object? cause;

  bool get isUnauthorized => code == 'unauthorized' || statusCode == 401;

  @override
  String toString() =>
      'ApiException(code: $code, status: $statusCode, message: $message)';
}
