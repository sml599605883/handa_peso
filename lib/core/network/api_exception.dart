import 'package:dio/dio.dart';

/// 网络层抛出的唯一错误类型。
///
/// 业务代码只会看到这一种类型：传输、超时和业务失败都在这里统一归一化，
/// 以便 UI 渲染一致的错误状态，并让崩溃报告可追溯。
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

  /// 当缺少必要的配置时，在请求发送前抛出。
  factory ApiException.configuration(String message) =>
      ApiException(message, code: 'configuration');

  final String message;

  /// 既可能是符号化的传输层错误码（'network'、'timeout' 等），也可能是
  /// 网关返回的原始数字业务码。
  final Object? code;
  final int? statusCode;
  final Object? cause;

  bool get isUnauthorized => code == 'unauthorized' || statusCode == 401;

  bool get isAuthExpired => code == -2 || code == '-2';

  @override
  String toString() =>
      'ApiException(code: $code, status: $statusCode, message: $message)';
}

/// 将任意被抛出的对象映射为对用户安全的提示信息。
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
