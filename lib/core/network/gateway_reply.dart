import 'gateway_failure.dart';
import 'wire_format.dart';

/// 网关信封解包后的结果。
///
/// [payload] 是解包出来的业务载荷；后端返回裸数组时会被塞进 `list` 键下，
/// 因此调用方拿到的始终是一个 map。
class GatewayReply {
  const GatewayReply({
    required this.status,
    required this.note,
    required this.payload,
    required this.envelope,
  });

  /// 响应体不是 map 时使用的状态码。
  static const malformedStatus = -900001;

  final int status;
  final String note;
  final Map<String, dynamic> payload;
  final Map<String, dynamic> envelope;

  bool get isAccepted => WireFormat.acceptedStatuses.contains(status);

  bool get isSessionExpired => status == WireFormat.expiredSessionStatus;

  static GatewayReply parse(Object? body) {
    if (body is! Map) {
      return const GatewayReply(
        status: malformedStatus,
        note: 'Invalid response format',
        payload: <String, dynamic>{},
        envelope: <String, dynamic>{},
      );
    }
    final envelope = Map<String, dynamic>.from(body);
    return GatewayReply(
      status: _statusOf(envelope[WireFormat.statusField]),
      note: '${envelope[WireFormat.noteField] ?? ''}',
      payload: _payloadOf(envelope[WireFormat.payloadField]),
      envelope: envelope,
    );
  }

  /// 业务失败时抛出 [GatewayFailure]，成功则原样返回。
  GatewayReply orThrow() {
    if (isAccepted) return this;
    throw GatewayFailure(note.isEmpty ? 'Request failed' : note, code: status);
  }

  static Map<String, dynamic> _payloadOf(Object? value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    if (value is List) return <String, dynamic>{'list': value};
    return <String, dynamic>{};
  }

  static int _statusOf(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? malformedStatus;
    return malformedStatus;
  }
}
