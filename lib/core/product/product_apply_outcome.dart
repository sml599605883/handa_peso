import '../json/json_utils.dart';
import '../network/gateway_reply.dart';

/// 产品准入接口（接口文档「点击申请」，`/dropcloth/legongs`）的结果。
///
/// 服务端只回一份「结果码 + 跳转地址 + 提示文案」：是否跳转、跳到 H5 还是
/// 原生页面全由它决定，客户端不自行判断用户该走认证还是确认用款。
class ProductApplyOutcome {
  const ProductApplyOutcome({
    required this.code,
    required this.target,
    required this.message,
  });

  /// 解析网关载荷（信封已在传输层解包，这里拿到的是 `indulgences` 那一层）。
  factory ProductApplyOutcome.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    return ProductApplyOutcome(
      code: payload.intValue(_codeField),
      target: payload.stringValue(_targetField).trim(),
      message: payload.stringValue(_messageField).trim(),
    );
  }

  /// 准入通过的结果码，其余取值表示准入失败（风控、分期等）。
  static const admittedCode = 200;

  final int code;

  /// 服务端指定的落地页；为空表示这一次不需要跳转。
  final String target;

  /// 服务端的提示文案（准入失败时给出原因）。
  final String message;

  bool get isAdmitted => code == admittedCode;

  bool get hasTarget => target.isNotEmpty;

  // 接口文档里的混淆字段，只在这一处出现。
  static const _codeField = 'murdering';
  static const _targetField = 'tidewaters';
  static const _messageField = 'bioscope';
}
