/// Handa Peso 网关的通信契约。
///
/// 每个信封键和接口路径片段都取自本应用专属的词表，因此业务代码不必写出
/// 原始协议，发布包也不会与同系列的其他构建共享字面量字符串。
/// 请把下面的值当作不透明令牌：它们是有意选取的无意义词汇，并且必须与
/// 后端保持同步。
abstract final class ApiProtocol {
  static const code = 'unaccepted';
  static const message = 'unstably';
  static const data = 'indulgences';

  /// 绑卡流程返回 `20000` 时，表示用户必须先完成活体检测才能提交成功，
  /// 因此它算作传输层成功，由调用方负责处理。
  static const successCodes = <int>{0, 20000};

  static const authExpiredCode = -2;
}
