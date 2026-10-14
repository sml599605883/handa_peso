/// H5 页面地址（接口文档「值映射 -> Scheme -> h5页面混淆」）。
///
/// 前端路由与 H5 页面都做过混淆，原生只能用文档登记过的混淆段来拼路径；
/// 域名则来自服务端下发的 `GatewaySettings.webOrigin`（启动后会被远端配置刷新），
/// 所以这里只维护混淆段，不写死域名。
abstract final class H5Paths {
  /// 客服中心。
  static const customerService = '/#/PonderersCollotypies';

  /// 隐私协议。
  static const privacyPolicy = '/#/Pederast';

  /// 借款协议。
  static const agreement = '/#/Carbonate';

  /// 把登记的混淆段拼到 H5 域名上；域名末尾多余的 `/` 会被去掉。
  static String resolve(String baseUrl, String path) {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return base.isEmpty ? path : '$base$path';
  }
}
