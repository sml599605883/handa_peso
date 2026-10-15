import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/routes/app_routes.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/session/local_session.dart';
import '../home/home_data.dart';
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

/// 管理三 Tab 外壳及共享首页信息流的状态。
///
/// 首页数据的刷新时机与 Handa Peso 其它端保持一致：
/// 首次进入、切回首页 Tab、从二级页面返回、下拉刷新、回到前台，
/// 以及登录 / 退出后重新同步。
class MainController extends GetxController with WidgetsBindingObserver {
  MainController({required this.gatewayClient, required this.localSession});

  final GatewayClient gatewayClient;
  final LocalSession localSession;

  final activeTab = 0.obs;
  final sessionPhone = ''.obs;
  final overviewData = Rxn<HomeData>();
  final overviewLoading = false.obs;
  final overviewError = RxnString();

  /// 首页是否真的露在外面。首页 Banner 的自动轮播靠它暂停。
  final homeOnScreen = true.obs;

  bool _loadedOnce = false;
  bool _openingBanner = false;
  bool _progressRequesting = false;
  bool _openingLogin = false;
  bool _leftForeground = false;
  bool _wentToBackground = false;
  bool _resumeAfterDialogConsumed = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _restoreProfile();
    unawaited(loadOverview());
  }

  @override
  void onClose() {
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
        return;
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _wentToBackground = true;
        return;
      case AppLifecycleState.resumed:
        break;
      case AppLifecycleState.detached:
        return;
    }

    final fromBackground = _wentToBackground;
    final fromDialog = _leftForeground && !_resumeAfterDialogConsumed;
    _wentToBackground = false;
    _leftForeground = false;
    if (!fromBackground && !fromDialog) return;
    if (fromDialog) _resumeAfterDialogConsumed = true;
    unawaited(_refreshVisibleTab());
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
  /// `repay` / `early_repay` 由服务端下发跳转地址，直接打开；`retry`（原卡重试）
  /// 与 `change`（更换账户）不下发地址，改为进订单详情页，由详情页内的原卡
  /// 重试与换绑入口承接。
  Future<void> tapLoanProgressAction(
    LoanProgressItem item,
    LoanProgressAction action,
  ) {
    return _runProgressRequest(() async {
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
    try {
      final response = await gatewayClient.fetchHomeOverview();
      overviewData.value = HomeData.fromJson(response.payload);
      _loadedOnce = true;
    } on GatewayFailure catch (error) {
      overviewError.value = error.message;
      CrashReporter.record(error, StackTrace.current);
      // 已有内容时保留旧数据，只用轻提示反馈本次刷新失败。
      if (overviewData.value != null) AppNavigator.showError(error.message);
    } finally {
      overviewLoading.value = false;
    }
  }

  /// 在任意页面登录成功后重新同步游客状态。
  Future<void> onSessionStarted(String phone) async {
    sessionPhone.value = phone;
    _loadedOnce = false;
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
      try {
        final id = banner.id.trim();
        if (id.isNotEmpty && (await localSession.readSessionId()).isNotEmpty) {
          await gatewayClient.recordBannerClick(bannerId: id);
        }
      } catch (_) {
        // 上报失败不影响跳转。
      }
      await AppNavigator.openTarget(target);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError('Unable to open link');
    } finally {
      _openingBanner = false;
    }
  }

  Future<void> applyNow(String productId) async {
    final appliedProductId = productId.isEmpty
        ? _homeApplyProductId
        : productId;
    AnalyticsService.logEvent(AppEvents.applyNowTapped, {
      'product_id': appliedProductId,
    });
    if (!await AppNavigator.requireSession(redirect: productId)) {
      return;
    }
    final profileComplete = await localSession.readCertified();
    if (!profileComplete) {
      await AppNavigator.toCertification(productId: appliedProductId);
      return;
    }
    await AppNavigator.toCalculator();
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

  Future<void> openAccountDeletion() async {
    await Get.toNamed<void>(AppRoutes.accountDeletion);
  }

  /// 首页只有在选中且外壳路由位于顶层时才请求得到数据。
  bool get _homeIsTopRoute {
    if (activeTab.value != 0) return false;
    final route = Get.currentRoute;
    return route.isEmpty || route == AppRoutes.main;
  }
}
