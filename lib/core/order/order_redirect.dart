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

/// 换绑（C-21）响应里的新订单地址。
///
/// 换绑可能返回多个候选地址，按接口约定（A.1.1）取首个非空。列表页选已有
/// 账户与绑卡页换绑模式调的是同一个接口，必须共用这一份判断：否则同一份响应
/// 会在一条路径上打开新订单、在另一条路径上被判成"取不到地址"。
String payoutRedirectUrlFrom(GatewayReply reply) {
  for (final key in const <String>[
    'url',
    'flowerpot',
    'proclises',
    'antineoplastic',
    'redirectUrl',
  ]) {
    final value = reply.payload.stringValue(key).trim();
    if (value.isNotEmpty) return value;
  }
  return '';
}
