import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_store.dart';
import '../routes/app_routes.dart';
import '../widgets/app_hint.dart';

/// 供各业务控制器共用的导航与反馈辅助方法。
///
/// 在这里封装 `Get` 可以让业务代码不掺杂路由细节，也提供统一的位置来添加
/// 拦截（例如申请前要求资料已完善）。
abstract final class AppNavigator {
  static void Function(int index)? mainTabSelector;

  /// 在当前页面之上推入登录路由，返回用户离开登录页时是否已有会话。
  ///
  /// 登录是按需触发的：游客可以浏览外壳，只有当某个操作需要会话时才要求
  /// 登录。GetX 的命名路由会按 `Route<dynamic>` 生成，无法承载泛型回传值，
  /// 因此这里的判断以登录页关闭后的会话状态为准。
  static Future<bool> toLogin({String? redirect}) async {
    final store = _sessionStore();
    await Get.toNamed<void>(AppRoutes.login, arguments: redirect);
    return store != null && (await store.sessionId()).isNotEmpty;
  }

  /// 确保存在会话，必要时打开登录页。
  ///
  /// 当调用方可以继续执行需要登录的操作时返回 `true`。
  static Future<bool> requireSession({String? redirect}) async {
    final store = _sessionStore();
    if (store != null && (await store.sessionId()).isNotEmpty) {
      return true;
    }
    return toLogin(redirect: redirect);
  }

  /// 清除已过期的会话并将用户带回登录页。
  ///
  /// 在启动时注册为 [ApiConfig.authExpiredHandler]，使网络层在收到 `-2`
  /// 响应时能够自行恢复，而无需引入路由模块。
  static Future<void> redirectToLoginAfterSessionExpiry() async {
    await _sessionStore()?.clear();
    await Get.offAllNamed<void>(AppRoutes.login);
  }

  static Future<void>? toMain() => Get.offAllNamed<void>(AppRoutes.main);

  static void switchMainTab(int index) => mainTabSelector?.call(index);

  static Future<void>? toCalculator() => Get.toNamed<void>(AppRoutes.calculator);

  static Future<void>? toCertification() => Get.toNamed<void>(AppRoutes.certification);

  static Future<void>? toOrders() => Get.toNamed<void>(AppRoutes.orders);

  static Future<void>? toSupport() => Get.toNamed<void>(AppRoutes.support);

  static Future<void>? toAnnouncements() => Get.toNamed<void>(AppRoutes.announcements);

  static Future<void>? toWebView({
    required String url,
    required String title,
  }) {
    return Get.toNamed<void>(AppRoutes.webView, arguments: {'url': url, 'title': title});
  }

  /// 打开首页 Banner（以及后续的弹窗）下发的跳转链接。
  ///
  /// 链接形态见接口文档「值映射 -> Scheme」：
  /// - `http` / `https`：H5 落地页，交给内置 WebView；
  /// - `ph://handa-peso/ios/<混淆段>`：映射到对应的原生页面；
  /// - 其它（包括文档里已登记、但当前版本还没有落地页的混淆段）：明确提示
  ///   打不开，而不是悄悄当成 H5 打开。
  static Future<void> openBannerTarget(String target) async {
    final link = target.trim();
    if (link.isEmpty) return;

    final uri = Uri.tryParse(link);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    if (scheme == 'http' || scheme == 'https') {
      if (uri == null || uri.host.isEmpty) {
        showError(_unopenableLink);
        return;
      }
      await toWebView(url: link, title: 'Activity');
      return;
    }

    final segments = uri?.pathSegments ?? const <String>[];
    if (scheme == 'ph' &&
        uri?.host == _schemeHost &&
        segments.length == 2 &&
        segments.first == 'ios') {
      switch (segments.last) {
        case _BannerTarget.home:
          switchMainTab(0);
          return;
        case _BannerTarget.login:
          await toLogin();
          return;
        case _BannerTarget.order:
          await toOrders();
          return;
      }
    }

    showError(_unopenableLink);
  }

  static const String _schemeHost = 'handa-peso';
  static const String _unopenableLink = 'Unable to open link';

  static Future<void> showLoading([String status = 'Loading...']) =>
      EasyLoading.show(status: status);

  static Future<void> dismissLoading() => EasyLoading.dismiss();

  static void showToast(String message) => EasyLoading.showToast(message);

  /// 屏幕正中的提示浮层（设计稿 01-02 - 登录 的提示样式）。
  ///
  /// 没有可用的 Overlay 时退回 EasyLoading，保证提示不会静默丢失。
  static void showHint(String message) {
    if (AppHint.show(message)) return;
    showToast(message);
  }

  static void showError(String message) => EasyLoading.showError(message);

  static SessionStore? _sessionStore() {
    if (Get.isRegistered<ApiClient>()) {
      return Get.find<ApiClient>().config.sessionStore;
    }
    return null;
  }
}

/// Banner 深链里的应用页面混淆段（接口文档「值映射 -> Scheme」）。
///
/// 这里只登记当前版本真正有落地页的段。文档中同样登记过的设置页
/// （`HelistopSaintliest`）、产品详情（`Sputterers`）、重新授信（`Herbivory`）
/// 与准入（`PeacefulnessesQuesters`）还没有对应的原生页面，命中时会走
/// 「打不开」提示，不会被误当成 H5 打开。
abstract final class _BannerTarget {
  static const home = 'SoulsClodpole';
  static const login = 'Disaccording';
  static const order = 'Brusker';
}
