import '../json/json_utils.dart';
import '../network/gateway_reply.dart';

/// 从订单类接口载荷中读取首个可用跳转地址。
///
/// 订单重试、换卡和旧版 H5 桥接共用同一组历史字段名；集中在这里可以避免
/// 不同入口对新旧字段的判断不一致。
String orderRedirectUrlFrom(GatewayReply reply) {
  for (final key in const <String>[
    'proclises',
    'url',
    'flowerpot',
    'antineoplastic',
    'redirectUrl',
  ]) {
    final value = reply.payload.stringValue(key).trim();
    if (value.isNotEmpty) return value;
  }
  final list = reply.payload.listValue('list');
  return list.isEmpty ? '' : list.first?.toString().trim() ?? '';
}
