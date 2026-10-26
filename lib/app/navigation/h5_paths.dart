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

  /// 待确认用款页；返回前需要按该页面识别挽留弹窗。
  static const loanConfirmationSegment = 'BanefullyHorse';
  static const loanConfirmation = '/#/$loanConfirmationSegment';

  /// 订单相关 H5。
  static const loanDetail = '/#/FiggingJuncture';
  static const admissionFailure = '/#/Poolside';
  static const repayment = '/#/Peerie';

  /// 其他服务页。
  static const recommendList = '/#/IncardinationSternutations';
  static const prepayment = '/#/YodellerSurpriser';
  static const pushGuide = '/#/Demographers';
  static const faceLivenessReturn = '/facelite.html';

  /// 早期发布包使用过的确认页别名，仅用于兼容已打开或已缓存的地址。
  static const legacyLoanConfirmationSegments = <String>{
    'OIUCatrionaMonodrame',
    'AmalgamatorsMarqueterie',
  };

  static bool isLoanConfirmation(Uri uri) {
    final fragment = Uri.tryParse(uri.fragment);
    return _containsConfirmationSegment(uri.pathSegments) ||
        (fragment != null &&
            _containsConfirmationSegment(fragment.pathSegments));
  }

  static bool _containsConfirmationSegment(List<String> segments) {
    return segments.contains(loanConfirmationSegment) ||
        segments.any(legacyLoanConfirmationSegments.contains);
  }

  /// 把登记的混淆段拼到 H5 域名上；域名末尾多余的 `/` 会被去掉。
  static String resolve(String baseUrl, String path) {
    final base = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    return base.isEmpty ? path : '$base$path';
  }
}
