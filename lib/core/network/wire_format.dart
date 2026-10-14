/// 网关信封使用的字段名与状态码。
///
/// 这些字符串是后端下发的**不透明令牌**：每个发布包一套，请不要按字面去猜
/// 语义，业务代码也不该直接写死它们。数值状态码同样只在这里声明一次。
abstract final class WireFormat {
  /// 业务状态码字段。
  static const statusField = 'unaccepted';

  /// 服务端提示文案字段。
  static const noteField = 'unstably';

  /// 业务载荷字段。
  static const payloadField = 'indulgences';

  /// 传输层认可的取值。
  ///
  /// `20000` 只出现在绑卡流程：它表示用户还需要先完成活体检测，属于可以继续
  /// 处理的结果，因此交给调用方决定后续动作，而不是当成失败抛出。
  static const acceptedStatuses = <int>{0, 20000};

  /// 会话失效。传输层据此触发重新登录，而不是当成普通业务错误。
  static const expiredSessionStatus = -2;
}
