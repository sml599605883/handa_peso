import 'package:flutter/cupertino.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../core/network/gateway_client.dart';
import '../../core/session/local_session.dart';
import '../routes/app_routes.dart';
import 'h5_paths.dart';
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
    final store = _localSession();
    await Get.toNamed<void>(AppRoutes.login, arguments: redirect);
    return store != null && (await store.readSessionId()).isNotEmpty;
  }

  /// 确保存在会话，必要时打开登录页。
  ///
  /// 当调用方可以继续执行需要登录的操作时返回 `true`。
  static Future<bool> requireSession({String? redirect}) async {
    final store = _localSession();
    if (store != null && (await store.readSessionId()).isNotEmpty) {
      return true;
    }
    return toLogin(redirect: redirect);
  }

  /// 清除已过期的会话并将用户带回登录页。
  ///
  /// 在启动时注册为 [GatewaySettings.onSessionExpired]，使网络层在收到 `-2`
  /// 响应时能够自行恢复，而无需引入路由模块。
  static Future<void> redirectToLoginAfterSessionExpiry() async {
    await _localSession()?.resetSession();
    await Get.offAllNamed<void>(AppRoutes.login);
  }

  static Future<void>? toMain() => Get.offAllNamed<void>(AppRoutes.main);

  static void switchMainTab(int index) => mainTabSelector?.call(index);

  static Future<void>? toCalculator() =>
      Get.toNamed<void>(AppRoutes.calculator);

  /// 打开认证流程。[productId] 是用户申请的产品：认证过程中的风控埋点要带上它，
  /// 缺了产品维度的埋点数据无法归因到具体产品。
  static Future<void>? toCertification({String productId = ''}) =>
      Get.toNamed<void>(
        AppRoutes.certification,
        arguments: {'productId': productId},
      );

  /// 打开订单列表。[status] 是接口文档里的筛选状态码
  /// （4 全部 / 7 进行中 / 6 待还款 / 5 已结清），空串表示默认「全部」。
  static Future<void>? toOrders({String status = ''}) => Get.toNamed<void>(
    AppRoutes.orders,
    arguments: status.trim().isEmpty
        ? null
        : <String, dynamic>{'status': status.trim()},
  );

  /// 打开账号页（设计稿 07-01 - 个人中心-退出）。
  static Future<void>? toAccount() => Get.toNamed<void>(AppRoutes.account);

  static Future<void>? toSupport() => Get.toNamed<void>(AppRoutes.support);

  static Future<void>? toAnnouncements() =>
      Get.toNamed<void>(AppRoutes.announcements);

  static Future<void>? toWebView({required String url, required String title}) {
    return Get.toNamed<void>(
      AppRoutes.webView,
      arguments: {'url': url, 'title': title},
    );
  }

  /// 打开服务端下发的跳转地址：Banner 落地页、进度卡片按钮与订单详情都用它。
  ///
  /// 链接形态见接口文档「值映射 -> Scheme」：
  /// - `http` / `https`：H5 落地页，交给内置 WebView；
  /// - `/#/<混淆段>` 这类相对路径：拼上服务端下发的 H5 域名再进 WebView；
  /// - `ph://handa-peso/ios/<混淆段>`：映射到对应的原生页面；
  /// - 其它（包括文档里已登记、但当前版本还没有落地页的混淆段）：明确提示
  ///   打不开，而不是悄悄当成 H5 打开。
  static Future<void> openTarget(
    String target, {
    String title = 'Activity',
  }) async {
    final link = target.trim();
    if (link.isEmpty) return;

    if (link.startsWith('/')) {
      await toWebView(url: H5Paths.resolve(_webOrigin(), link), title: title);
      return;
    }

    final uri = Uri.tryParse(link);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    if (scheme == 'http' || scheme == 'https') {
      if (uri == null || uri.host.isEmpty) {
        showError(_unopenableLink);
        return;
      }
      await toWebView(url: link, title: title);
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
          await toOrders(status: _orderStatusOf(uri));
          return;
        case _BannerTarget.setting:
          await toAccount();
          return;
      }
    }

    showError(_unopenableLink);
  }

  static const String _schemeHost = 'handa-peso';
  static const String _unopenableLink = 'Unable to open link';

  /// 订单列表深链携带筛选状态的参数名。
  ///
  /// 文档只登记了「订单列表页」这个别名，没有写状态参数；这里同时认业务字段
  /// 名 `corequisites`（接口文档「订单列表」的筛选字段）与通用的 `status`。
  static String _orderStatusOf(Uri? uri) {
    if (uri == null) return '';
    for (final key in const <String>['corequisites', 'status']) {
      final value = uri.queryParameters[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

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

  /// 弹一条提示，并在它播完（展示 2 秒 + 淡出）后返回。
  ///
  /// 复位输入框之类的界面动作要等提示播完再做：提示还在屏上就把输入框清掉，
  /// 用户会以为提示说的是别的事。
  static Future<void> showHintAndWait(String message) async {
    if (!AppHint.show(message)) {
      showToast(message);
      return;
    }
    await AppHint.dismissed;
  }

  static void showError(String message) => EasyLoading.showError(message);

  /// 位置权限被系统挡下时的二次说明，返回用户是否选择去系统设置。
  ///
  /// 系统弹窗只会出现一次，之后拒绝过的用户在设置里才能改回来，因此这里补一条
  /// 说明并提供入口。选择「Not Now」不算拒绝：调用方照常继续申请。
  ///
  /// 文案按本应用自己的口径写，不要从别的工程整段搬运——用户可见的长文案是
  /// 跨应用比对时最直接的特征。
  static Future<bool> showLocationPermissionPrompt({
    required bool serviceDisabled,
  }) async {
    final context = Get.context;
    if (context == null || !context.mounted) return false;

    final toSettings = await showCupertinoDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(
          serviceDisabled
              ? 'Location Services Are Off'
              : 'Location Access Is Off',
        ),
        content: Text(
          serviceDisabled
              ? 'Location Services is switched off on this device. Turn it on '
                    'in Settings to finish the location check, or continue '
                    'without it.'
              : 'Your location is collected once during review to confirm '
                    'your address and protect your account. Allow it in '
                    'Settings, or continue without it.',
        ),
        actions: <Widget>[
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Not Now'),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
    return toSettings ?? false;
  }

  /// H5 域名（服务端可在启动后换址），拼相对跳转路径时使用。
  static String _webOrigin() {
    if (Get.isRegistered<GatewayClient>()) {
      return Get.find<GatewayClient>().settings.webOrigin;
    }
    return '';
  }

  static LocalSession? _localSession() {
    if (Get.isRegistered<GatewayClient>()) {
      return Get.find<GatewayClient>().settings.localSession;
    }
    return null;
  }
}

/// Banner 深链里的应用页面混淆段（接口文档「值映射 -> Scheme」）。
///
/// 这里只登记当前版本真正有落地页的段。文档中同样登记过的产品详情
/// （`Sputterers`）、重新授信（`Herbivory`）与准入（`PeacefulnessesQuesters`）
/// 还没有对应的原生页面，命中时会走「打不开」提示，不会被误当成 H5 打开。
abstract final class _BannerTarget {
  static const home = 'SoulsClodpole';
  static const setting = 'HelistopSaintliest';
  static const login = 'Disaccording';
  static const order = 'Brusker';
}
