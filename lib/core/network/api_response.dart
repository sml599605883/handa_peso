import 'api_exception.dart';
import 'api_protocol.dart';

/// 网关返回的统一信封结构。
///
/// 后端会把每个载荷包装成 `{code, message, data}`，其中每个键都是应用专属的
/// 不透明令牌（见 [ApiProtocol]）。[states] 暴露解包后的 `data` 对象；当后端
/// 返回裸数组时，会将其嵌套到 `list` 下，因此调用方始终拿到一个 map。
class ApiResponse {
  const ApiResponse({
    required this.code,
    required this.message,
    required this.states,
    required this.raw,
  });

  static const invalidFormatCode = -900001;

  final int code;
  final String message;
  final Map<String, dynamic> states;
  final Map<String, dynamic> raw;

  bool get isSuccess => ApiProtocol.successCodes.contains(code);

  bool get isAuthExpired => code == ApiProtocol.authExpiredCode;

  /// 解包后的载荷。保留 `data` 这个名字，方便业务代码阅读。
  Map<String, dynamic> get data => states;

  static ApiResponse fromRaw(dynamic raw) {
    if (raw is! Map) {
      return const ApiResponse(
        code: invalidFormatCode,
        message: 'Invalid response format',
        states: <String, dynamic>{},
        raw: <String, dynamic>{},
      );
    }
    final map = Map<String, dynamic>.from(raw);
    return ApiResponse(
      code: _parseCode(map[ApiProtocol.code]),
      message: map[ApiProtocol.message]?.toString() ?? '',
      states: _parseStates(map[ApiProtocol.data]),
      raw: map,
    );
  }

  ApiResponse ensureSuccess() {
    if (isSuccess) return this;
    throw ApiException(
      message.isEmpty ? 'Request failed' : message,
      code: code,
    );
  }

  static Map<String, dynamic> _parseStates(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return <String, dynamic>{'list': value};
    return <String, dynamic>{};
  }

  static int _parseCode(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? invalidFormatCode;
    return invalidFormatCode;
  }
}
