/// 风控埋点的场景编号（接口文档「数据上报 -> 上报风控埋点(新)」的 `proves`）。
///
/// 每个场景由两次取时钟夹出：一次是页面进入或点击动作，一次是提交成功。
/// 因此这里只登记编号，起止时间必须由拥有该页面的调用方在真实的进入点与成功
/// 回调里各自取一次 [DateTime.now]，不要在埋点发出时才补算开始时间。
abstract final class ReportScene {
  /// 注册：进入登录页 -> 登录成功。
  static const registration = '1';

  /// 认证选择：点击认证选择页 -> 选择结束。
  static const certificationChoice = '2';

  /// 证件信息：点击证件正面 -> 证件正面保存成功。
  static const identityDocument = '3';

  /// 人脸上传：点击开始人脸 -> 人脸照片上传成功。
  static const faceScan = '4';

  /// 个人信息：进入个人信息页 -> 个人信息保存成功。
  static const personalInfo = '5';

  /// 工作信息：进入工作信息页 -> 工作信息保存成功。
  static const jobInfo = '6';

  /// 紧急联系人：进入紧急联系人页 -> 紧急联系人保存成功。
  static const emergencyContact = '7';

  /// 银行卡信息：进入绑卡页 -> 银行卡信息保存成功。
  static const bankCard = '8';

  /// 开始申贷：订单号接口的请求时刻 -> 该接口响应成功。
  static const applyStarted = '9';

  /// 结束申贷：确认借款页点击确认 -> 确认用款接口响应成功。
  static const applyFinished = '10';
}
