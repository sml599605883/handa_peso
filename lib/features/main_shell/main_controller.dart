import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/navigation/h5_paths.dart';
import '../../app/routes/app_routes.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/order/order_redirect.dart';
import '../../core/permissions/permission_coordinator.dart';
import '../../core/product/product_apply_outcome.dart';
import '../../core/report/report_service.dart';
import '../../core/session/local_session.dart';
import '../home/home_data.dart';
import '../home/home_popup_dialog.dart';
import '../home/home_popup_models.dart';
import '../loan_progress/loan_progress_item.dart';

/// 用于主卡片行动号召（CTA）的埋点/会话标签。
const String _homeApplyProductId = 'home_card';

/// 游客也能停留的 Tab：首页允许未登录浏览，其余 Tab 都要先登录。
const int _guestTabIndex = 0;

/// 借款进度所在的 Tab（设计稿 02- 贷款-订单进度）。
const int _loanTabIndex = 1;

/// 进度卡片按钮打开的 H5 页面标题。
const String _repaymentTitle = 'Repayment';

/// 订单详情页标题。
const String _loanDetailTitle = 'Loan detail';

/// 准入失败且服务端没有下发文案时的兜底提示。
const String _applyFailedHint = 'You are not eligible right now';

/// 管理三 Tab 外壳及共享首页信息流的状态。
///
/// 首页数据的刷新时机与 Handa Peso 其它端保持一致：
/// 首次进入、切回首页 Tab、从二级页面返回、下拉刷新、回到前台，
/// 以及登录 / 退出后重新同步。
class MainController extends GetxController with WidgetsBindingObserver {
  MainController({
    required this.gatewayClient,
    required this.localSession,
    PermissionCoordinator? permissionCoordinator,
  }) : permissionCoordinator =
           permissionCoordinator ?? PermissionCoordinator() {
    AppNavigator.admissionHandler = (productId, {int source = 0}) =>
        applyNow(productId, source: source);
  }

  final GatewayClient gatewayClient;
  final LocalSession localSession;
  final PermissionCoordinator permissionCoordinator;

  final activeTab = 0.obs;
  final sessionPhone = ''.obs;
  final overviewData = Rxn<HomeData>();
  final overviewLoading = false.obs;
  final overviewError = RxnString();

  /// 首页是否真的露在外面。首页 Banner 的自动轮播靠它暂停。
  final homeOnScreen = true.obs;

  bool _loadedOnce = false;
  bool _openingBanner = false;
  bool _openingCustomerService = false;
  bool _showingPopup = false;
  bool _applying = false;
  bool _progressRequesting = false;
  bool _openingLogin = false;
  bool _leftForeground = false;
  bool _wentToBackground = false;
  bool _resumeAfterDialogConsumed = false;

  /// 正在等待系统定位授权弹窗；用户把应用切走就放弃这次等待，避免申请入口被
  /// 一个不会再返回的原生回调长期锁住。
  Completer<void>? _locationPromptInterrupt;

  /// 定位授权弹窗结束后紧跟的那次 `resumed` 已经处理过（见
  /// [didChangeAppLifecycleState]）。
  bool _ignoreLocationPromptResume = false;

  /// 定位授权等待上限：超过就按「拿不到授权状态」放行。
  ///
  /// 原生回调丢失时不能让 `_applying` 永远为真，否则申请入口会静默失效。
  static const Duration _locationDecisionTimeout = Duration(seconds: 15);

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _restoreProfile();
    unawaited(loadOverview());
  }

  @override
  void onClose() {
    AppNavigator.admissionHandler = null;
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// 只在首页可见时刷新：接口失败会保留旧内容，避免页面闪空。
  Future<void> refreshOverview() async {
    if (!_homeIsTopRoute) return;
    await loadOverview(force: true);
  }

  /// 从二级页面返回外壳时同步当前 Tab 的数据。
  Future<void> onRouteReturned() {
    homeOnScreen.value = activeTab.value == _guestTabIndex;
    return _refreshVisibleTab();
  }

  /// 外壳被重新推入栈顶时同步当前 Tab 的数据。
  ///
  /// [AppNavigator.toMain] 只在外壳不在栈里时（登录页作为根页面等）才重建
  /// 外壳；重建不是 pop，`didPopNext` 不会触发，而外壳控制器由启动阶段的
  /// `MainBinding` 常驻，重建外壳也不会再走一次 `onInit`。两边都不刷新时
  /// 首页会一直停在旧数据上。
  ///
  /// 首次启动时 `onInit` 已经在拉数据，[loadOverview] 的请求中守卫会挡掉这次
  /// 重复请求。
  Future<void> onShellShown() {
    homeOnScreen.value = activeTab.value == _guestTabIndex;
    return _refreshVisibleTab();
  }

  /// 二级页面覆盖首页时暂停首页上的一切定时行为。
  void onRouteLeft() => homeOnScreen.value = false;

  /// 切换 Tab：受保护的 Tab 在未登录时先弹登录页，且不改变当前 Tab。
  ///
  /// 门禁语义与 Salmon Loan 的 tabbar 一致——登录页关闭后不补切 Tab，用户
  /// 需要重新点击；因此这里有意不看登录结果，只看点击发生时有没有会话。
  Future<void> switchTab(int index) async {
    if (activeTab.value == index) return;
    if (index != _guestTabIndex && !await _hasSession()) {
      await _promptLogin();
      return;
    }
    activeTab.value = index;
    homeOnScreen.value = index == _guestTabIndex;
    unawaited(_refreshVisibleTab());
    if (index == 2) unawaited(_showScenePopup(2));
  }

  Future<bool> _hasSession() async =>
      (await localSession.readSessionId()).isNotEmpty;

  /// 打开登录页；连点只保留一个登录路由，避免叠加。
  Future<void> _promptLogin() async {
    if (_openingLogin) return;
    _openingLogin = true;
    try {
      await AppNavigator.toLogin();
    } finally {
      _openingLogin = false;
    }
  }

  /// 应用生命周期：回到前台后补一次首页刷新。
  ///
  /// 与 Dali 系列一致，`inactive -> resumed`（系统权限弹窗、控制中心）
  /// 只刷新首次，避免弹窗关闭时反复打接口；真正的后台返回则每次都刷新。
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        _leftForeground = true;
        // 系统定位授权弹窗也会让应用先 inactive 再 resumed：那次恢复不是用户
        // 离开页面又回来，标记掉，免得白刷一次首页。
        if (_locationPromptInterrupt != null) {
          _ignoreLocationPromptResume = true;
        }
        return;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _wentToBackground = true;
        _interruptLocationPrompt();
        return;
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
        _interruptLocationPrompt();
        return;
    }

    final fromBackground = _wentToBackground;
    final fromDialog = _leftForeground && !_resumeAfterDialogConsumed;
    _wentToBackground = false;
    _leftForeground = false;

    // 定位弹窗带来的恢复既不刷新，也不消耗「弹窗恢复」的那次刷新机会；用户真
    // 的从后台回来（fromBackground）时不在此列。
    final fromLocationPrompt = _ignoreLocationPromptResume && !fromBackground;
    _ignoreLocationPromptResume = false;
    if (fromLocationPrompt) return;

    if (!fromBackground && !fromDialog) return;
    if (fromDialog) _resumeAfterDialogConsumed = true;
    unawaited(_refreshVisibleTab());
  }

  /// 放弃正在等待的定位授权弹窗（用户把应用切到后台或关掉）。
  void _interruptLocationPrompt() {
    final pending = _locationPromptInterrupt;
    if (pending != null && !pending.isCompleted) pending.complete();
  }

  Future<void> _restoreProfile() async {
    sessionPhone.value = await localSession.readPhone();
  }

  /// 按当前可见的 Tab 决定刷新哪一份数据。
  ///
  /// 首页与进度页共用同一条信息流接口（`/dropcloth/indulgences`，进度卡片在
  /// `PROCESS_LIST` 模块里），因此两边的刷新时机收敛到这一个入口，避免切 Tab
  /// 时对同一份数据发两次请求。
  Future<void> _refreshVisibleTab() {
    return activeTab.value == _loanTabIndex
        ? refreshProgress()
        : refreshOverview();
  }

  /// 拉取进度卡片数据；只有 Loan Tab 露在外面时才会真正请求。
  Future<void> refreshProgress() async {
    if (activeTab.value != _loanTabIndex) return;
    await loadOverview(force: true);
  }

  /// 点击进度卡片：优先按服务端下发的订单详情地址跳转，没有地址时回到产品
  /// 申请流程（与其它支线的进度卡片保持一致）。
  Future<void> openLoanProgress(LoanProgressItem item) {
    return _runProgressRequest(() => _openLoanProgressTarget(item));
  }

  /// 点击进度卡片上的按钮。
  ///
  /// `repay` / `early_repay` 由服务端下发跳转地址，直接打开；`change`（更换
  /// 账户）由原生直接查询账户列表；`retry`（原卡重试）直接调用服务端并打开
  /// 返回的订单详情地址。
  Future<void> tapLoanProgressAction(
    LoanProgressItem item,
    LoanProgressAction action,
  ) {
    return _runProgressRequest(() async {
      if (action.isChange) {
        try {
          final result = await AppNavigator.changePayoutAccount(
            productId: item.productId,
            orderNo: item.orderNo,
          );
          if (result.changed && result.redirectUrl.isNotEmpty) {
            await AppNavigator.openTarget(
              result.redirectUrl,
              title: _loanDetailTitle,
              cleanWorkflowForWeb: true,
            );
          }
        } on GatewayFailure catch (error) {
          AppNavigator.showError(error.message);
        }
        return;
      }
      if (action.isRetry) {
        final orderNo = item.orderNo.trim();
        if (orderNo.isEmpty) {
          throw const GatewayFailure('Missing order number');
        }

        late final String target;
        await AppNavigator.showLoading();
        try {
          final reply = await gatewayClient.reorderExistingLoan(
            orderNo: orderNo,
          );
          reply.orThrow();
          target = orderRedirectUrlFrom(reply);
          if (target.isEmpty) {
            throw const GatewayFailure('Retry link is unavailable');
          }
        } finally {
          await AppNavigator.dismissLoading();
        }
        await AppNavigator.openTarget(
          target,
          title: _loanDetailTitle,
          cleanWorkflowForWeb: true,
        );
        return;
      }
      final target = action.route.trim();
      if (target.isNotEmpty) {
        await AppNavigator.openTarget(target, title: _repaymentTitle);
        return;
      }
      await _openLoanProgressTarget(item);
    });
  }

  Future<void> _openLoanProgressTarget(LoanProgressItem item) async {
    final target = item.detailRoute.trim();
    if (target.isNotEmpty) {
      await AppNavigator.openTarget(target, title: _loanDetailTitle);
      return;
    }
    final productId = item.productId.trim();
    if (productId.isEmpty) return;
    await applyNow(productId);
  }

  /// 进度卡片只允许一次跳转在途，避免连点叠出多个落地页。
  Future<void> _runProgressRequest(Future<void> Function() action) async {
    if (_progressRequesting) return;
    _progressRequesting = true;
    try {
      await action();
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError('Unable to open link');
    } finally {
      _progressRequesting = false;
    }
  }

  /// 拉取首页信息流；[force] 为 false 时只在首次进入时请求。
  Future<void> loadOverview({bool force = false}) async {
    if (overviewLoading.value) return;
    if (_loadedOnce && !force) return;

    overviewLoading.value = true;
    overviewError.value = null;
    var ownsLoading = false;
    var requestFinished = false;
    Future<void>? loadingShown;
    final mainIsTopRoute =
        Get.currentRoute.isEmpty || Get.currentRoute == AppRoutes.main;
    // 已有内容的后台刷新不盖全屏 loading：EasyLoading 是单例，和申请/登录的
    // loading 抢同一次 show 会把对方的 Future 顶掉，业务就一直等在那里。
    if (mainIsTopRoute && overviewData.value == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (requestFinished || isClosed) return;
        ownsLoading = true;
        loadingShown = AppNavigator.showLoading();
      });
      WidgetsBinding.instance.scheduleFrame();
    }
    try {
      final response = await gatewayClient.fetchHomeOverview();
      requestFinished = true;
      overviewData.value = HomeData.fromJson(response.payload);
      _loadedOnce = true;
      if (ownsLoading) {
        await loadingShown;
        await AppNavigator.dismissLoading();
        ownsLoading = false;
      }
      unawaited(_showScenePopup(1));
    } on GatewayFailure catch (error) {
      requestFinished = true;
      if (ownsLoading) {
        await loadingShown;
        await AppNavigator.dismissLoading();
        ownsLoading = false;
      }
      overviewError.value = error.message;
      CrashReporter.record(error, StackTrace.current);
      // 已有内容时保留旧数据，只用轻提示反馈本次刷新失败。
      if (overviewData.value != null) AppNavigator.showError(error.message);
    } finally {
      requestFinished = true;
      if (ownsLoading) {
        await loadingShown;
        await AppNavigator.dismissLoading();
      }
      overviewLoading.value = false;
    }
  }

  /// 在任意页面登录成功后重新同步游客状态。
  ///
  /// 只有外壳正露在登录页下面时才在这里拉数据；其余情况交给外壳自己：
  /// 登录页关闭会触发 `didPopNext` 刷新，登录页作为根页面时则由重建的外壳走
  /// [onShellShown] 拉一次（控制器常驻，重建外壳不会再走 `onInit`）。
  /// 两边都拉会让首页+弹窗接口连着请求两次。
  Future<void> onSessionStarted(String phone) async {
    sessionPhone.value = phone;
    _loadedOnce = false;
    if (!_homeIsTopRoute) return;
    await loadOverview(force: true);
  }

  /// 打开首页 Banner：先补记一次点击，再按链接跳转。
  ///
  /// 点击上报是可选的分析数据（接口文档要求登录态 + 链接非空），失败不能挡住
  /// 跳转；真正打开失败时才提示用户。同一时刻只处理一次点击，避免连点叠加
  /// 多个落地页。
  Future<void> openBanner(HomeBannerData banner) async {
    final target = banner.targetUrl.trim();
    if (target.isEmpty || _openingBanner) return;
    _openingBanner = true;
    try {
      // 点击上报是可选的分析数据（接口文档要求登录态 + 链接非空），失败不能挡住
      // 跳转。这里发出去就不等它：上报慢的时候用户点 banner 不能没有反应。
      unawaited(_reportBannerClick(banner.id));
      await AppNavigator.openTarget(target, source: 1);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError('Unable to open link');
    } finally {
      _openingBanner = false;
    }
  }

  Future<void> _reportBannerClick(String bannerId) async {
    final id = bannerId.trim();
    if (id.isEmpty) return;
    try {
      if ((await localSession.readSessionId()).isEmpty) return;
      await gatewayClient.recordBannerClick(bannerId: id);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    }
  }

  /// 首页与 Loan Tab 右上角的客服入口，统一打开 H5 客服中心。
  Future<void> openCustomerService() async {
    if (_openingCustomerService) return;
    _openingCustomerService = true;
    try {
      await AppNavigator.openTarget(
        H5Paths.customerService,
        title: 'Customer service',
      );
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError('Unable to open customer service');
    } finally {
      _openingCustomerService = false;
    }
  }

  /// 场景 1=首页，2=个人中心；接口失败或没有弹窗时直接跳过。
  Future<void> _showScenePopup(int scene) async {
    if (_showingPopup || !await _hasSession()) return;
    if (Get.currentRoute != AppRoutes.main ||
        activeTab.value != (scene == 1 ? 0 : 2)) {
      return;
    }

    _showingPopup = true;
    try {
      final reply = await gatewayClient.fetchDialogConfig(scene: scene);
      reply.orThrow();
      final config = HomePopupConfig.fromReply(reply);
      if (!config.shouldShow ||
          isClosed ||
          Get.currentRoute != AppRoutes.main ||
          activeTab.value != (scene == 1 ? 0 : 2)) {
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      final context = Get.context;
      if (context == null || !context.mounted) return;
      final shouldOpen = await showHomePopup(context, config);
      if (!shouldOpen || config.targetUrl.isEmpty) return;
      await _openPopupTarget(config);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    } finally {
      _showingPopup = false;
    }
  }

  Future<void> _openPopupTarget(HomePopupConfig config) async {
    final target = config.targetUrl.trim();
    if (target.isEmpty) return;
    if (config.kind == HomePopupKind.appUpgrade) {
      final uri = Uri.tryParse(target);
      if (uri != null) {
        try {
          if (await launchUrl(uri, mode: LaunchMode.externalApplication)) {
            return;
          }
        } catch (_) {
          // HTTP 更新链接退回内置 WebView。
        }
      }
    }
    await AppNavigator.openTarget(target, title: 'Offer', source: 2);
  }

  /// 点击首页大卡 / 推荐卡：先过登录门禁，再走准入接口（文档「点击申请」）。
  ///
  /// 与其它支线一致——跳转目标由服务端决定：准入失败会下发 H5 错误页，需要
  /// 授信或借款详情时下发 H5 或原生深链。只有当服务端只回结果码、不给地址时，
  /// 才按本地认证状态继续（未认证进认证流程，已认证进借款计算页），避免服务端
  /// 配置缺省时点击毫无反应。
  ///
  /// 游客点击时只负责把用户带到登录页，登录成功后**不续跑**这次申请：定位授权
  /// 必须由用户明确点击申请来发起，不能在登录页刚关闭时紧接着弹系统定位弹窗
  /// （参考端 kaibigan_loan 的 `applyProductWithFlow` 同样在跳登录后直接 return）。
  /// 用户回到首页重新点击，才会依次走「定位准入 → 准入接口」。
  ///
  /// 走准入之前先要一次定位权限：风控要看这一次申请发生时的位置。拒绝授权、
  /// 系统限制或定位服务关闭时说明原因，取消说明后仍可继续。
  ///
  /// [reportApplyTap] 为假时不记「点击申请」埋点：重新授信轮询器在授信完成后
  /// 自动续跑准入，这不是一次新的用户点击，不能把同一次申请算成两次点击。
  Future<void> applyNow(
    String productId, {
    bool requestLocation = true,
    int source = 0,
    bool reportApplyTap = true,
  }) async {
    final appliedProductId = productId.trim().isEmpty
        ? _homeApplyProductId
        : productId.trim();
    // 连点只走一次：准入会在服务端留痕，重复请求既脏数据也会叠出多个落地页。
    if (_applying) return;
    _applying = true;
    if (reportApplyTap) {
      AnalyticsService.logEvent(AppEvents.applyNowTapped, {
        'product_id': appliedProductId,
      });
    }
    try {
      // 登录门禁只负责跳转，不等登录结果：登录页关闭后这次点击就结束。
      // 否则登录成功的瞬间会紧跟一个系统定位弹窗，用户会以为定位权限是登录
      // 流程的一部分；也与「点击申请才要定位」的产品时机不符。
      if (!await _hasSession()) {
        await _promptLogin();
        return;
      }
      if (requestLocation && !await _ensureLocationAccess()) return;
      // 转圈只罩住这次请求：提示与转圈共用同一个浮层，请求一结束就收起，
      // 后面的提示与跳转才不会被它关掉。
      final ProductApplyOutcome outcome;
      await AppNavigator.showLoading();
      try {
        // 用户可能刚在这次定位弹窗里放开权限：先把最新定位补报一次再走准入。
        // 上报是尽力而为，失败不影响申请。
        unawaited(_reportLocationBeforeApply());
        outcome = ProductApplyOutcome.fromReply(
          await gatewayClient.startProductApplication(
            productId: appliedProductId,
            source: '$source',
          ),
        );
      } finally {
        await AppNavigator.dismissLoading();
      }

      if (outcome.hasTarget) {
        unawaited(_dispatchApplyTarget(outcome.target, appliedProductId));
        return;
      }
      if (!outcome.isAdmitted) {
        AppNavigator.showToast(
          outcome.message.isEmpty ? _applyFailedHint : outcome.message,
        );
        return;
      }
      await _continueApply(appliedProductId);
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError(FailureMessage.describe(error));
    } finally {
      _applying = false;
    }
  }

  Future<void> _dispatchApplyTarget(String target, String productId) async {
    try {
      await AppNavigator.openTarget(
        target,
        cleanWorkflowForWeb: true,
        fallbackProductId: productId,
      );
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError(FailureMessage.describe(error));
    }
  }

  /// 服务端没下发跳转地址时的兜底入口。
  Future<void> _continueApply(String productId) async {
    await AppNavigator.continueProductCertification(
      productId: productId,
      allowIdentity: true,
    );
  }

  /// 申请前的定位准入：拿到授权就继续，拿不到权限也不硬拦。
  ///
  /// 拒绝授权、系统受限或定位服务关闭时，都给出一次去设置的说明——与
  /// peso_shield 一致，即使用户刚在系统弹窗里点了「不允许」也说明一次，不能
  /// 让申请入口看起来没反应。取消说明就照常申请，选择「Settings」则由系统
  /// 设置页接管本次流程。等待弹窗期间被切到后台时本次申请直接作废（用户再点
  /// 一次即可），不能把入口挂在一个不再返回的原生回调上。
  Future<bool> _ensureLocationAccess() async {
    final decision = await _awaitLocationDecision();
    switch (decision) {
      case null:
        return false;
      case LocationAccessDecision.granted:
      case LocationAccessDecision.unavailable:
        return true;
      case LocationAccessDecision.denied:
      case LocationAccessDecision.restricted:
      case LocationAccessDecision.serviceDisabled:
        break;
    }

    final toSettings = await AppNavigator.showLocationPermissionPrompt(
      serviceDisabled: decision == LocationAccessDecision.serviceDisabled,
    );
    if (!toSettings) return true;
    await permissionCoordinator.openSettings();
    return false;
  }

  /// 等一次定位授权弹窗的结果；被切到后台时返回 `null`（本次申请作废）。
  ///
  /// 原生回调在极少数情况下会丢（系统弹窗被系统自己收掉、宿主切前台时结果
  /// 没回传）：没有超时的话 `_applying` 会一直为真，用户再点大卡就毫无反应。
  /// 超时按「拿不到授权状态」放行——定位只补全风控数据，不能反过来锁死入口。
  Future<LocationAccessDecision?> _awaitLocationDecision() async {
    final interrupted = Completer<void>();
    _locationPromptInterrupt = interrupted;
    try {
      return await Future.any<LocationAccessDecision?>(
        <Future<LocationAccessDecision?>>[
          permissionCoordinator.requestLocationAccess(),
          interrupted.future.then<LocationAccessDecision?>((_) => null),
        ],
      ).timeout(
        _locationDecisionTimeout,
        onTimeout: () {
          return LocationAccessDecision.unavailable;
        },
      );
    } finally {
      _locationPromptInterrupt = null;
    }
  }

  /// 申请前补报一次定位与设备详情。
  Future<void> _reportLocationBeforeApply() async {
    final reporter = Get.isRegistered<ReportService>()
        ? Get.find<ReportService>()
        : null;
    try {
      await reporter?.reportLocationAndDevice();
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    }
  }

  Future<void> logout() async {
    try {
      await gatewayClient.signOut();
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
    } finally {
      await localSession.resetSession();
      AnalyticsService.setUserId(null);
      overviewData.value = null;
      sessionPhone.value = '';
      _loadedOnce = false;
      await loadOverview(force: true);
    }
  }

  /// 注销账号：服务端受理成功后才清本地会话，与退出登录共用同一套收尾。
  ///
  /// 接口失败时直接把异常抛给调用方——账号并没有注销，界面不能显示成已退出。
  Future<void> deleteAccount() async {
    await gatewayClient.closeAccount();
    AnalyticsService.logEvent(AppEvents.accountDeleted);
    await localSession.resetSession();
    AnalyticsService.setUserId(null);
    overviewData.value = null;
    sessionPhone.value = '';
    _loadedOnce = false;
    await loadOverview(force: true);
  }

  /// 首页只有在选中且外壳路由位于顶层时才请求得到数据。
  bool get _homeIsTopRoute {
    if (activeTab.value != 0) return false;
    final route = Get.currentRoute;
    return route.isEmpty || route == AppRoutes.main;
  }
}
