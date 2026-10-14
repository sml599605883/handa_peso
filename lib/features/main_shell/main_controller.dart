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

/// 用于主卡片行动号召（CTA）的埋点/会话标签。
const String _homeApplyProductId = 'home_card';

/// 管理三 Tab 外壳及共享首页信息流的状态。
///
/// 首页数据的刷新时机与 Handa Peso 其它端保持一致：
/// 首次进入、切回首页 Tab、从二级页面返回、下拉刷新、回到前台，
/// 以及登录 / 退出后重新同步。
class MainController extends GetxController with WidgetsBindingObserver {
  MainController({required this.gatewayClient, required this.localSession});

  final GatewayClient gatewayClient;
  final LocalSession localSession;

  final selectedIndex = 0.obs;
  final phoneNumber = ''.obs;
  final homeData = Rxn<HomeData>();
  final homeLoading = false.obs;
  final homeError = RxnString();

  /// 首页是否真的露在外面。首页 Banner 的自动轮播靠它暂停。
  final homeVisible = true.obs;

  bool _loadedOnce = false;
  bool _openingBanner = false;
  bool _leftForeground = false;
  bool _wentToBackground = false;
  bool _resumeAfterDialogConsumed = false;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _restoreProfile();
    unawaited(loadHome());
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  /// 只在首页可见时刷新：接口失败会保留旧内容，避免页面闪空。
  Future<void> refreshHome() async {
    if (!_homeIsTopRoute) return;
    await loadHome(force: true);
  }

  /// 从二级页面返回外壳时同步首页数据。
  Future<void> onRouteReturned() {
    homeVisible.value = true;
    return refreshHome();
  }

  /// 二级页面覆盖首页时暂停首页上的一切定时行为。
  void onRouteLeft() => homeVisible.value = false;

  void selectTab(int index) {
    if (selectedIndex.value == index) return;
    selectedIndex.value = index;
    homeVisible.value = index == 0;
    if (index == 0) unawaited(refreshHome());
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
    unawaited(refreshHome());
  }

  Future<void> _restoreProfile() async {
    phoneNumber.value = await localSession.readPhone();
  }

  /// 拉取首页信息流；[force] 为 false 时只在首次进入时请求。
  Future<void> loadHome({bool force = false}) async {
    if (homeLoading.value) return;
    if (_loadedOnce && !force) return;

    homeLoading.value = true;
    homeError.value = null;
    try {
      final response = await gatewayClient.fetchHomeOverview();
      homeData.value = HomeData.fromJson(response.payload);
      _loadedOnce = true;
    } on GatewayFailure catch (error) {
      homeError.value = error.message;
      CrashReporter.record(error, StackTrace.current);
      // 已有内容时保留旧数据，只用轻提示反馈本次刷新失败。
      if (homeData.value != null) AppNavigator.showError(error.message);
    } finally {
      homeLoading.value = false;
    }
  }

  /// 在任意页面登录成功后重新同步游客状态。
  Future<void> onSessionStarted(String phone) async {
    phoneNumber.value = phone;
    _loadedOnce = false;
    await loadHome(force: true);
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
      await AppNavigator.openBannerTarget(target);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError('Unable to open link');
    } finally {
      _openingBanner = false;
    }
  }

  Future<void> applyNow(String productId) async {
    AnalyticsService.logEvent(AppEvents.applyNowTapped, {
      'product_id': productId.isEmpty ? _homeApplyProductId : productId,
    });
    if (!await AppNavigator.requireSession(redirect: productId)) {
      return;
    }
    final profileComplete = await localSession.readCertified();
    if (!profileComplete) {
      await AppNavigator.toCertification();
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
      homeData.value = null;
      phoneNumber.value = '';
      _loadedOnce = false;
      await loadHome(force: true);
    }
  }

  Future<void> openAccountDeletion() async {
    await Get.toNamed<void>(AppRoutes.accountDeletion);
  }

  /// 首页只有在选中且外壳路由位于顶层时才请求得到数据。
  bool get _homeIsTopRoute {
    if (selectedIndex.value != 0) return false;
    final route = Get.currentRoute;
    return route.isEmpty || route == AppRoutes.main;
  }
}
