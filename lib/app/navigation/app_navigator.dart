import 'dart:async';

import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/json/json_utils.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/network/gateway_reply.dart';
import '../../core/product/product_next_step.dart';
import '../../core/product/product_detail_loader.dart';
import '../../core/product/product_detail_snapshot.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';
import '../../core/session/local_session.dart';
import '../../features/certification/bind_card_models.dart';
import '../../features/certification/emergency_contact_models.dart';
import '../../features/certification/face_models.dart';
import '../../features/certification/identity_models.dart';
import '../../features/certification/personal_information_models.dart';
import '../../features/webview/payout_account_models.dart';
import '../routes/app_routes.dart';
import '../widgets/ios_permission_prompt.dart';
import 'h5_paths.dart';
import '../widgets/app_hint.dart';

typedef AdmissionHandler = Future<void> Function(
  String productId, {
  int source,
});

/// 供各业务控制器共用的导航与反馈辅助方法。
///
/// 在这里封装 `Get` 可以让业务代码不掺杂路由细节，也提供统一的位置来添加
/// 拦截（例如申请前要求资料已完善）。
abstract final class AppNavigator {
  static void Function(int index)? mainTabSelector;
  static AdmissionHandler? admissionHandler;

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

  /// H5 判定登录态失效后下发的 login 深链。
  ///
  /// 与接口返回 `-2` 的处理对齐：先清掉本地会话，回到首页 Tab，再把登录页开在
  /// 首页之上，同时移除已经失效的网页等中间页。这样登录页的返回键和登录成功
  /// 都落在首页，而不是退回那张已经失效的 H5。
  static Future<void> openLoginAfterSessionExpiry() async {
    await _localSession()?.resetSession();
    AnalyticsService.setUserId(null);
    switchMainTab(0);
    final navigator = Get.key.currentState;
    if (navigator == null) {
      await toLogin();
      return;
    }
    await navigator.pushNamedAndRemoveUntil<void>(AppRoutes.login, (candidate) {
      final name = candidate.settings.name;
      return name == null || name == AppRoutes.main;
    });
  }

  /// 返回到外壳首页（H5 的 `goHome`、二级页面无栈可退时的兜底都走这里）。
  ///
  /// 外壳还在栈里时逐级 pop 回去，不重建：保留 Tab 与页面状态，首页的刷新由
  /// `RouteObserver.didPopNext` 负责（与 dali_cash/laya_credit/fund_nexus 的
  /// 「返回首页」一致）。只有外壳真的不在栈里（例如登录页作为根页面）时才用
  /// `offAllNamed` 新建一个。
  static Future<void>? toMain() {
    final navigator = Get.key.currentState;
    if (navigator == null) return null;
    if (navigator.canPop()) {
      navigator.popUntil((candidate) {
        final name = candidate.settings.name;
        return name == AppRoutes.main || candidate.isFirst;
      });
    }
    if (Get.currentRoute == AppRoutes.main) return null;
    return Get.offAllNamed<void>(AppRoutes.main);
  }

  static void switchMainTab(int index) => mainTabSelector?.call(index);

  static Future<void>? toCalculator() =>
      Get.toNamed<void>(AppRoutes.calculator);

  /// 等待授信页；轮询器为常驻对象，离开页面后仍会继续检查结果。
  ///
  /// [clearWebViews] 为真时连同来源 WebView 一起清掉：准入从订单详情 H5 发起、
  /// 下发的是授信 loading 页时，旧详情页会留在栈底继续轮询，退出授信页还会回退
  /// 到它。
  static Future<void> toCreditReview({
    required String productId,
    bool clearWebViews = false,
  }) async {
    await _toTopLevelCertification<void>(
      AppRoutes.creditReview,
      arguments: <String, dynamic>{'productId': productId},
      clearWebViews: clearWebViews,
    );
  }

  /// 打开认证流程。[productId] 是用户申请的产品：认证过程中的风控埋点要带上它，
  /// 缺了产品维度的埋点数据无法归因到具体产品。
  static Future<void>? toCertification({String productId = ''}) =>
      Get.toNamed<void>(
        AppRoutes.certification,
        arguments: {'productId': productId},
      );

  /// 打开证件认证流程（设计稿 03-01 身份认证）。
  ///
  /// 流程是「证件类型选择 -> 上传证件 -> 上传成功」三段独立页面，返回用户是否
  /// 走完（证件信息保存成功）。成功页会直接刷新产品详情并打开下一项；完成标记
  /// 仍随路由参数传递，供调用方和测试判断本次流程结果。
  static Future<IdentityFlowOutcome> toIdentityVerification({
    String productId = '',
  }) async {
    final outcome = IdentityFlowOutcome();
    await _toTopLevelCertification<void>(
      AppRoutes.certificationIdentity,
      arguments: <String, dynamic>{
        'productId': productId,
        IdentityFlowOutcome.argumentKey: outcome,
      },
    );
    return outcome;
  }

  /// 打开人脸识别流程（设计稿 03-01 - 身份认证-人脸识别）。
  static Future<bool> toFaceVerification({
    required String productId,
    String orderNo = '',
    String cardType = '',
  }) async {
    final outcome = FaceVerificationOutcome();
    await _toTopLevelCertification<void>(
      AppRoutes.certificationFace,
      arguments: <String, dynamic>{
        'productId': productId,
        'orderNo': orderNo,
        'cardType': cardType,
        FaceVerificationOutcome.argumentKey: outcome,
      },
    );
    return outcome.completed;
  }

  /// 打开个人信息（设计稿 03-03），成功保存时由页面标记完成。
  static Future<PersonalInformationFlowOutcome> toPersonalInformation({
    String productId = '',
  }) async {
    return _toInformation(
      route: AppRoutes.personalInformation,
      productId: productId,
    );
  }

  /// 打开工作信息（设计稿 03-02），保存成功时由页面标记完成。
  static Future<PersonalInformationFlowOutcome> toWorkInformation({
    String productId = '',
  }) async {
    return _toInformation(
      route: AppRoutes.workInformation,
      productId: productId,
    );
  }

  /// 打开紧急联系人（设计稿 03-04），保存成功时由页面标记完成。
  static Future<EmergencyContactFlowOutcome> toEmergencyContact({
    String productId = '',
  }) async {
    final outcome = EmergencyContactFlowOutcome();
    await _toTopLevelCertification<void>(
      AppRoutes.emergencyContact,
      arguments: <String, dynamic>{
        'productId': productId,
        EmergencyContactFlowOutcome.argumentKey: outcome,
      },
    );
    return outcome;
  }

  /// 打开放款账户绑定页（设计稿 03-05）。
  ///
  /// `changeOrderNo` 非空时复用同一页面完成换绑，调用方从结果中读取新的
  /// `bindId` 与订单跳转地址。
  static Future<BindCardFlowOutcome> toBindCard({
    String productId = '',
    String orderNo = '',
    String changeOrderNo = '',
  }) async {
    final outcome = BindCardFlowOutcome();
    await _toTopLevelCertification<void>(
      AppRoutes.bindCard,
      arguments: <String, dynamic>{
        'productId': productId,
        'orderNo': orderNo,
        'changeOrderNo': changeOrderNo,
        BindCardFlowOutcome.argumentKey: outcome,
      },
    );
    return outcome;
  }

  /// 打开更换放款账户页（设计稿 04-01）。
  ///
  /// 列表页以普通页面压在来源 H5 上；新增账户时再从列表页压入绑卡页。最终
  /// 成功结果只带回新的订单地址，由来源 WebView 替换自身并清掉旧 H5。
  static Future<PayoutAccountFlowOutcome> toPayoutAccounts({
    required PayoutAccountCatalog catalog,
    required String productId,
    required String orderNo,
  }) async {
    final outcome = PayoutAccountFlowOutcome();
    await Get.toNamed<void>(
      AppRoutes.payoutAccounts,
      arguments: <String, dynamic>{
        'catalog': catalog,
        'productId': productId,
        'orderNo': orderNo,
        PayoutAccountFlowOutcome.argumentKey: outcome,
      },
    );
    return outcome;
  }

  /// 查询账户并进入原生换卡流程。
  ///
  /// 调用方只负责拿到最终结果：来源是 H5 时替换来源 WebView；来源是首页进度
  /// 卡片时，再打开接口返回的订单页。账户为空时直接进入绑卡页。
  static Future<PayoutAccountFlowOutcome> changePayoutAccount({
    required String productId,
    required String orderNo,
  }) async {
    final product = productId.trim();
    final order = orderNo.trim();
    if (product.isEmpty || order.isEmpty) {
      throw const GatewayFailure('Missing account information');
    }
    final client = Get.isRegistered<GatewayClient>()
        ? Get.find<GatewayClient>()
        : null;
    if (client == null) {
      throw const GatewayFailure('Payout account is unavailable');
    }

    await showLoading();
    late final PayoutAccountCatalog catalog;
    try {
      final reply = await client.fetchBoundCards(productId: product);
      reply.orThrow();
      catalog = PayoutAccountCatalog.fromReply(reply);
    } finally {
      await dismissLoading();
    }

    if (catalog.isEmpty) {
      final bound = await toBindCard(productId: product, changeOrderNo: order);
      return PayoutAccountFlowOutcome()
        ..changed = bound.changed
        ..redirectUrl = bound.redirectUrl;
    }
    return toPayoutAccounts(
      catalog: catalog,
      productId: product,
      orderNo: order,
    );
  }

  static Future<PersonalInformationFlowOutcome> _toInformation({
    required String route,
    required String productId,
  }) async {
    final outcome = PersonalInformationFlowOutcome();
    await _toTopLevelCertification<void>(
      route,
      arguments: <String, dynamic>{
        'productId': productId,
        PersonalInformationFlowOutcome.argumentKey: outcome,
      },
    );
    return outcome;
  }

  /// 认证流程页面集合。打开下一项时移除这些页面，只保留首页/业务入口页。
  static const Set<String> _certificationRoutes = <String>{
    AppRoutes.certification,
    AppRoutes.certificationIdentity,
    AppRoutes.certificationIdentityUpload,
    AppRoutes.certificationIdentityResult,
    AppRoutes.certificationFace,
    AppRoutes.personalInformation,
    AppRoutes.workInformation,
    AppRoutes.emergencyContact,
    AppRoutes.bindCard,
    AppRoutes.creditReview,
  };

  /// 打开顶层认证页并移除已有认证页，对齐 Peso Shield 的认证导航。
  ///
  /// [clearWebViews] 为真时同时移除来源 WebView：准入派发到原生页（授信 loading、
  /// 订单列表）时，旧的订单详情 H5 不该留在栈底继续轮询，也不该在退出后回退到。
  static Future<T?>? _toTopLevelCertification<T>(
    String route, {
    Object? arguments,
    bool clearWebViews = false,
  }) {
    final navigator = Get.key.currentState;
    if (navigator == null) return null;
    return navigator.pushNamedAndRemoveUntil<T>(route, (candidate) {
      final name = candidate.settings.name;
      if (clearWebViews && name == AppRoutes.webView) return false;
      return name == null || !_certificationRoutes.contains(name);
    }, arguments: arguments);
  }

  /// 打开订单列表。[status] 是接口文档里的筛选状态码
  /// （4 全部 / 7 进行中 / 6 待还款 / 5 已结清），空串表示默认「全部」。
  static Future<void>? toOrders({
    String status = '',
    bool clearWebViews = false,
  }) {
    final arguments = status.trim().isEmpty
        ? null
        : <String, dynamic>{'status': status.trim()};
    if (!clearWebViews) {
      return Get.toNamed<void>(AppRoutes.orders, arguments: arguments);
    }
    final navigator = Get.key.currentState;
    if (navigator == null) {
      return Get.toNamed<void>(AppRoutes.orders, arguments: arguments);
    }
    return navigator.pushNamedAndRemoveUntil<void>(
      AppRoutes.orders,
      (candidate) => candidate.settings.name != AppRoutes.webView,
      arguments: arguments,
    );
  }

  /// 打开账号页（设计稿 07-01 - 个人中心-退出）。
  static Future<void>? toAccount() => Get.toNamed<void>(AppRoutes.account);

  static Future<void>? toSupport() => Get.toNamed<void>(AppRoutes.support);

  static Future<void>? toAnnouncements() =>
      Get.toNamed<void>(AppRoutes.announcements);

  static Future<void>? toWebView({
    required String url,
    required String title,
    bool replaceCurrent = false,
    bool removeCertificationPages = false,
  }) {
    final arguments = <String, dynamic>{'url': url, 'title': title};
    if (!replaceCurrent && !removeCertificationPages) {
      return Get.toNamed<void>(AppRoutes.webView, arguments: arguments);
    }
    final navigator = Get.key.currentState;
    if (navigator == null) return null;
    // 同一命名路由再次 offNamed 可能被 GetX 当作原地复用，参数不会换。
    // 显式移除来源 WebView 后再推入目标地址，确保只保留一个新的 H5。
    return navigator.pushNamedAndRemoveUntil<void>(AppRoutes.webView, (route) {
      final name = route.settings.name;
      return name != AppRoutes.webView &&
          !(removeCertificationPages &&
              name != null &&
              _certificationRoutes.contains(name));
    }, arguments: arguments);
  }

  /// 打开服务端下发的跳转地址：Banner 落地页、进度卡片按钮与订单详情都用它。
  ///
  /// 链接形态见接口文档「值映射 -> Scheme」：
  /// - `http` / `https`：H5 落地页，交给内置 WebView；
  /// - `/#/<混淆段>` 这类相对路径：拼上服务端下发的 H5 域名再进 WebView；
  /// - `ph://handa-peso/ios/<混淆段>`：映射到对应的原生页面；
  /// - `ph://handa-peso/ios/Sputterers?cotype=<产品id>`（产品详情）：只带产品 ID，
  ///   真正的下一步由产品详情接口决定，见 [_openProductDetail]；
  /// - 其它（包括文档里已登记、但当前版本还没有落地页的混淆段）：明确提示
  ///   打不开，而不是悄悄当成 H5 打开。
  static Future<void> openTarget(
    String target, {
    String title = 'Activity',
    bool fromPush = false,
    bool cleanWorkflowForWeb = false,
    String fallbackProductId = '',
    int source = 0,
  }) async {
    final link = target.trim();
    if (link.isEmpty) return;

    if (link.startsWith('/')) {
      final currentRoute = Get.currentRoute;
      await toWebView(
        url: H5Paths.resolve(_webOrigin(), link),
        title: title,
        replaceCurrent:
            cleanWorkflowForWeb &&
            (currentRoute == AppRoutes.webView ||
                currentRoute == AppRoutes.creditReview),
        removeCertificationPages:
            cleanWorkflowForWeb &&
            (currentRoute == AppRoutes.bindCard ||
                currentRoute == AppRoutes.creditReview),
      );
      return;
    }

    final uri = Uri.tryParse(link);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    if (scheme == 'http' || scheme == 'https') {
      if (uri == null || uri.host.isEmpty) {
        showError(_unopenableLink);
        return;
      }
      final currentRoute = Get.currentRoute;
      await toWebView(
        url: link,
        title: title,
        replaceCurrent:
            cleanWorkflowForWeb &&
            (currentRoute == AppRoutes.webView ||
                currentRoute == AppRoutes.creditReview),
        removeCertificationPages:
            cleanWorkflowForWeb &&
            (currentRoute == AppRoutes.bindCard ||
                currentRoute == AppRoutes.creditReview),
      );
      return;
    }

    final segments = uri?.pathSegments ?? const <String>[];
    final isCurrentScheme = scheme == 'ph' && uri?.host == _schemeHost;
    if (isCurrentScheme &&
        uri != null &&
        segments.length == 2 &&
        segments.first == 'ios') {
      switch (segments.last) {
        case _BannerTarget.home:
          if (cleanWorkflowForWeb) await _popWebViews();
          switchMainTab(0);
          return;
        case _BannerTarget.login:
          if (fromPush) {
            await redirectToLoginAfterSessionExpiry();
          } else {
            // H5 把 login 深链当作「登录态失效」的信号：过期页面不能留在栈里，
            // 否则登录页的返回键还会退回去。
            await openLoginAfterSessionExpiry();
          }
          return;
        case _BannerTarget.order:
          await toOrders(
            status: _orderStatusOf(uri),
            clearWebViews: cleanWorkflowForWeb,
          );
          return;
        case _BannerTarget.setting:
          await toAccount();
          return;
        case _BannerTarget.productDetail:
          await _openProductDetail(uri, fallbackProductId);
          return;
        case _BannerTarget.admission:
          await _openAdmission(uri, fallbackProductId, fallbackSource: source);
          return;
        case _BannerTarget.recredit:
          await _openRecredit(
            uri,
            fallbackProductId,
            clearWebViews: cleanWorkflowForWeb,
          );
          return;
      }
    }

    showError(_unopenableLink);
  }

  /// 产品详情深链：首页大卡准入成功后服务端下发的就是这一段
  /// （`ph://handa-peso/ios/Sputterers?cotype=1`）。
  ///
  /// 深链只给产品 ID，究竟该走哪一步认证由产品详情接口里的认证项列表决定，
  /// 客户端不自行判断。当前版本已按服务端顺序落地证件、人脸、个人信息、工作
  /// 信息、紧急联系人与放款账户；其余步骤没有设计稿对应页面时明确提示。
  static Future<void> _openProductDetail(
    Uri uri,
    String fallbackProductId,
  ) async {
    final productId = _productIdOf(uri, fallbackProductId);
    final client = Get.isRegistered<GatewayClient>()
        ? Get.find<GatewayClient>()
        : null;
    if (productId.isEmpty || client == null) {
      showError(_unopenableLink);
      return;
    }
    await _openNextProductStep(
      productId: productId,
      client: client,
      allowIdentity: true,
    );
  }

  static Future<void> _openAdmission(
    Uri uri,
    String fallbackProductId, {
    required int fallbackSource,
  }) async {
    final productId = _productIdOf(uri, fallbackProductId);
    final starter = admissionHandler;
    if (productId.isEmpty || starter == null) {
      showError(_unopenableLink);
      return;
    }
    await starter(productId, source: _admissionSourceOf(uri, fallbackSource));
  }

  static Future<void> _openRecredit(
    Uri uri,
    String fallbackProductId, {
    bool clearWebViews = false,
  }) async {
    final productId = _productIdOf(uri, fallbackProductId);
    if (productId.isEmpty) {
      showError(_unopenableLink);
      return;
    }
    await toCreditReview(productId: productId, clearWebViews: clearWebViews);
  }

  /// 收起栈里的 WebView 回到外壳：准入派发回首页 Tab 时用。
  static Future<void> _popWebViews() async {
    if (Get.key.currentState == null) return;
    Get.until((candidate) {
      final name = candidate.settings.name;
      return name == AppRoutes.main || candidate.isFirst;
    });
  }

  /// 当前认证页保存成功后刷新产品详情并打开下一项认证。
  ///
  /// 新认证页使用顶层导航替换旧认证页，因此从当前成功页直接切到下一项，
  /// 不会先回首页或认证列表。
  static Future<void> continueProductCertification({
    required String productId,
    bool allowIdentity = false,
  }) async {
    final client = Get.isRegistered<GatewayClient>()
        ? Get.find<GatewayClient>()
        : null;
    if (productId.isEmpty || client == null) {
      showError(_unopenableLink);
      return;
    }
    await _openNextProductStep(
      productId: productId,
      client: client,
      allowIdentity: allowIdentity,
    );
  }

  /// 按产品详情返回的下一步打开认证页。
  ///
  /// 每一步保存成功后由当前页面再次调用本方法，刷新产品详情并顶层替换到下一项。
  /// `allowIdentity` 防止服务端状态尚未刷新时再次进入同一个证件流程。
  static Future<void> _openNextProductStep({
    required String productId,
    required GatewayClient client,
    required bool allowIdentity,
  }) async {
    await showLoading();
    try {
      final detail = await ProductDetailLoader.load(
        client,
        productId: productId,
      );
      final step = ProductNextStep.fromReply(detail);
      await dismissLoading();
      if (step.taskType.isEmpty) {
        if (step.hasIncompleteTask) {
          showError('Complete the previous verification step first');
          return;
        }
        await _openLoanConfirmation(
          productId: productId,
          client: client,
          detail: detail,
        );
        return;
      }
      if (step.isIdentity) {
        if (!allowIdentity) return;
        unawaited(toIdentityVerification(productId: productId));
        return;
      }
      if (step.isFace) {
        unawaited(
          toFaceVerification(productId: productId, orderNo: step.orderNo),
        );
        return;
      }
      if (step.isPersonal) {
        unawaited(toPersonalInformation(productId: productId));
        return;
      }
      if (step.isWork) {
        unawaited(toWorkInformation(productId: productId));
        return;
      }
      if (step.isEmergency) {
        unawaited(toEmergencyContact(productId: productId));
        return;
      }
      if (step.isBank) {
        unawaited(toBindCard(productId: productId, orderNo: step.orderNo));
        return;
      }
      // 文档「产品详情认证项目列表」里登记过、但本版本还没有落地页的步骤，按步骤名
      // 明确提示；完全没登记过的取值说明协议对不上，退回统一的「打不开」。
      final label = step.label;
      showError(
        label.isEmpty ? _unopenableLink : '$label is not available yet.',
      );
    } on GatewayFailure catch (error) {
      await dismissLoading();
      showError(error.message);
    } catch (error) {
      await dismissLoading();
      showError(_unopenableLink);
    }
  }

  static bool _openingLoanConfirmation = false;

  /// 认证全部完成后提交订单，服务端返回确认用款页地址后再进入 H5。
  ///
  /// 订单提交成功后同时移除认证页与来源 WebView，确保退出确认页回到首页。
  static Future<void> _openLoanConfirmation({
    required String productId,
    required GatewayClient client,
    required GatewayReply detail,
  }) async {
    if (_openingLoanConfirmation) return;
    _openingLoanConfirmation = true;
    try {
      final snapshot = ProductDetailSnapshot.fromReply(detail);
      if (snapshot.orderNo.isEmpty ||
          snapshot.amount.isEmpty ||
          snapshot.term.isEmpty ||
          snapshot.termUnit.isEmpty) {
        showError('Loan information is incomplete');
        return;
      }

      final startedAt = ReportService.nowSeconds();
      await showLoading();
      final reply = await client.pushOrder(
        orderNo: snapshot.orderNo,
        amount: snapshot.amount,
        term: snapshot.term,
        termUnit: snapshot.termUnit,
      );
      reply.orThrow();
      await dismissLoading();

      final target = reply.payload.stringValue('tidewaters').trim();
      if (target.isEmpty) {
        showError('Loan confirmation link is unavailable');
        return;
      }

      final reporter = Get.isRegistered<ReportService>()
          ? Get.find<ReportService>()
          : null;
      unawaited(
        reporter?.reportScene(
              scene: ReportScene.applyStarted,
              productId: productId,
              orderNo: snapshot.orderNo,
              startedAtSeconds: startedAt,
            ) ??
            Future<void>.value(),
      );
      await toWebView(
        url: target,
        title: 'Loan confirmation',
        replaceCurrent: true,
        removeCertificationPages: true,
      );
    } on GatewayFailure catch (error) {
      await dismissLoading();
      showError(error.message);
    } catch (error) {
      await dismissLoading();
      CrashReporter.record(error, StackTrace.current);
      showError(FailureMessage.describe(error));
    } finally {
      _openingLoanConfirmation = false;
    }
  }

  /// 深链里的产品 ID。文档「产品详情」登记的参数名是 `cotype`；另外两个是通用
  /// 写法，服务端换名时不至于整条链路打不开。
  static String _productIdOf(Uri uri, [String fallbackProductId = '']) {
    for (final key in const <String>[
      'cotype',
      'productId',
      'product_id',
      'drippier',
      'transported',
      'knife',
      'bombarder',
    ]) {
      final value = uri.queryParameters[key];
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return fallbackProductId.trim();
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

  /// 准入深链的来源字段。新接口使用 `efflorescence`，旧链接仍可能带
  /// Peso Shield 时代的 `parliament`。
  static int _admissionSourceOf(Uri uri, int fallback) {
    for (final key in const <String>['efflorescence', 'parliament']) {
      final value = int.tryParse(uri.queryParameters[key]?.trim() ?? '');
      if (value != null && value >= 0) return value;
    }
    return fallback;
  }

  /// 显示全屏 loading。
  ///
  /// 只负责把浮层挂出去，**不把动画完成当成业务时序**：EasyLoading 是单例，
  /// 并发 show 时后一个会把前一个的容器换掉，前一个的 Future 就永远不完成了。
  /// 申请/登录这些流程如果 await 它，就会卡在转圈那一步再也发不出请求。
  static Future<void> showLoading([String status = 'Loading...']) {
    unawaited(
      EasyLoading.show(
        status: status,
        dismissOnTap: false,
        maskType: EasyLoadingMaskType.clear,
      ),
    );
    return Future<void>.value();
  }

  static Future<void> dismissLoading() {
    unawaited(EasyLoading.dismiss());
    return Future<void>.value();
  }

  /// 打开二级页面前的转圈是否还挂着。
  ///
  /// 与 [showLoading] 的区别是收尾方不同：普通 loading 由发起的流程自己收，
  /// 这个由目标页在首屏就绪后收（H5 的 `onLoadStop` / 原生页压栈那一帧），
  /// 因此要记住"当前这个转圈是跳转挂的"，别把别的流程的转圈误收掉。
  static bool _navigationLoading = false;

  /// 跳转转圈的兜底定时器：目标页不回报时也要收，见 [showNavigationLoading]。
  static Timer? _navigationLoadingTimer;

  /// 打开二级页面前的转圈：一直挂到目标页首屏加载出来。
  ///
  /// [timeout] 是兜底：断网或页面卡住时 H5 不会回调 `onLoadStop`，全屏遮罩
  /// 不能一直盖在壳上，否则所有入口都被锁死。
  static Future<void> showNavigationLoading({
    Duration timeout = const Duration(seconds: 8),
  }) {
    _navigationLoading = true;
    _navigationLoadingTimer?.cancel();
    _navigationLoadingTimer = Timer(timeout, () {
      unawaited(dismissNavigationLoading());
    });
    return showLoading();
  }

  /// 目标页首屏就绪（或加载失败）后收起跳转转圈。
  ///
  /// 没有跳转转圈在挂时什么都不做：进 H5 之后的站内跳转同样会触发
  /// `onLoadStop`，不能让它把申请、重试这些流程自己的转圈收掉。
  static Future<void> dismissNavigationLoading() {
    _navigationLoadingTimer?.cancel();
    _navigationLoadingTimer = null;
    if (!_navigationLoading) return Future<void>.value();
    _navigationLoading = false;
    return dismissLoading();
  }

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

  /// 定位受系统限制或服务关闭时的说明，返回用户是否选择去系统设置。
  ///
  /// 这里承接用户仍可继续申请的分支：选择左侧按钮（权限被拒时 Back、定位服务
  /// 关闭时 Close）调用方照常继续，选择去设置则由系统设置页接管本次流程。
  ///
  /// 文案按产品给的口径原样落地，不要自行润色——用户可见的长文案是跨应用比对
  /// 时最直接的特征。
  static Future<bool> showLocationPermissionPrompt({
    required bool serviceDisabled,
  }) async {
    final context = Get.context;
    if (context == null || !context.mounted) return false;

    return showIosPermissionPrompt(
      context,
      title: serviceDisabled
          ? 'Location Is Unavailable'
          : 'Location Access Is Off',
      message: serviceDisabled
          ? 'Please turn on your device location service to make location '
                'information available for this step.'
          : 'Your location is not available for this step. Turn on access to '
                'provide the information needed for the review.',
      cancelLabel: serviceDisabled ? 'Close' : 'Back',
      confirmLabel: serviceDisabled ? 'Open Settings' : 'Enable Now',
    );
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
/// 产品详情、重新授信和准入这三类深链都只带产品 ID；进入后分别交由产品详情
/// 流程、重新授信检查或统一准入入口继续，不把它们误当成 H5 打开。
abstract final class _BannerTarget {
  static const home = 'SoulsClodpole';
  static const setting = 'HelistopSaintliest';
  static const login = 'Disaccording';
  static const order = 'Brusker';
  static const productDetail = 'Sputterers';
  static const recredit = 'Herbivory';
  static const admission = 'PeacefulnessesQuesters';
}
