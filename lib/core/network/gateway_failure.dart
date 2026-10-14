import 'package:dio/dio.dart';

/// 网络层对外的唯一错误类型。
///
/// 传输失败、超时与业务失败都会先归一化成这一种类型，UI 因此只需要处理一套
/// 错误状态；[cause] 保留原始异常，便于崩溃上报里回溯。
class GatewayFailure implements Exception {
  const GatewayFailure(this.message, {this.code, this.statusCode, this.cause});

  /// 完全连不上网关：DNS 解析失败、连接被拒绝、设备无网络。
  factory GatewayFailure.unreachable([Object? cause]) => GatewayFailure(
    'Network is unavailable. Please check your connection and try again.',
    code: 'network',
    cause: cause,
  );

  /// 超时：连接、发送与接收都归到这里。
  factory GatewayFailure.timedOut([Object? cause]) => GatewayFailure(
    'The request timed out. Please try again.',
    code: 'timeout',
    cause: cause,
  );

  factory GatewayFailure.aborted() =>
      const GatewayFailure('Request cancelled.', code: 'cancelled');

  factory GatewayFailure.sessionExpired() => const GatewayFailure(
    'Your session has expired. Please sign in again.',
    code: 'unauthorized',
    statusCode: 401,
  );

  /// 请求还没发出去就发现配置缺失（例如没有签名密钥）。
  factory GatewayFailure.misconfigured(String message) =>
      GatewayFailure(message, code: 'configuration');

  final String message;

  /// 既可能是符号化的传输层标记（`network`、`timeout`……），也可能是网关
  /// 返回的原始数字状态码。
  final Object? code;
  final int? statusCode;
  final Object? cause;

  bool get isUnauthorized => code == 'unauthorized' || statusCode == 401;

  bool get isSessionExpired => code == -2 || code == '-2';

  @override
  String toString() =>
      'GatewayFailure(code: $code, status: $statusCode, message: $message)';
}

/// 把任意被抛出的对象翻译成可以直接展示给用户的文案。
abstract final class FailureMessage {
  static const _timedOut = 'The request timed out. Please try again.';
  static const _unreachable =
      'Network is unavailable. Please check your connection and try again.';

  static String describe(Object? error) {
    if (error == null) return 'Network error';
    if (error is GatewayFailure) return error.message;
    if (error is DioException) return _fromDio(error);
    return error.toString();
  }

  static String _fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return _timedOut;
      case DioExceptionType.connectionError:
        return _unreachable;
      default:
        return error.message ?? 'Network error';
    }
  }
}
