import 'api_exception.dart';
import 'api_protocol.dart';

/// Normalised envelope returned by the gateway.
///
/// The backend wraps every payload in `{code, message, data}` where each key is
/// an app-specific opaque token (see [ApiProtocol]). [states] exposes the
/// unwrapped `data` object; when the backend sends a bare array it is nested
/// under `list` so callers always get a map.
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

  /// Unwrapped payload. Kept as `data` so feature code stays readable.
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
