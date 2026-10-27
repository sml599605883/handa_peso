import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'app/navigation/app_navigator.dart';
import 'app/routes/app_routes.dart';
import 'app/startup/startup_network_gate.dart';
import 'core/analytics/analytics_service.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/network/gateway_client.dart';
import 'core/push/push_route_coordinator.dart';
import 'core/report/report_lifecycle.dart';
import 'core/report/report_service.dart';
import 'features/main_shell/main_controller.dart';
import 'features/credit_review/credit_review_poller.dart';

typedef DependencyBootstrapper = Future<AppDependencies> Function();
typedef AppRunner = void Function(Widget app);
typedef OrientationLocker = Future<void> Function();

Future<void> main() => startHandaPeso();

Future<void> startHandaPeso({
  DependencyBootstrapper bootstrap = AppBootstrap.initialize,
  AppRunner runApplication = runApp,
  OrientationLocker lockOrientation = _lockPortrait,
}) async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    CrashReporter.record(
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  await lockOrientation();
  final dependencies = await bootstrap();

  Get.put<AppDependencies>(dependencies, permanent: true);
  Get.put<GatewayClient>(dependencies.gatewayClient, permanent: true);
  Get.put<CreditReviewPoller>(
    CreditReviewPoller(
      request: dependencies.gatewayClient.fetchRecreditInfo,
      currentRoute: () => Get.currentRoute,
      homeVisible: () {
        if (!Get.isRegistered<MainController>()) return false;
        return Get.find<MainController>().activeTab.value == 0 &&
            Get.currentRoute == AppRoutes.main;
      },
      refreshHome: () async {
        if (!Get.isRegistered<MainController>()) return;
        await Get.find<MainController>().loadOverview(force: true);
      },
      runAdmission: (productId) async {
        if (!Get.isRegistered<MainController>()) return;
        // 授信完成后由轮询器自动续跑准入：这是同一次申请的后续步骤，不是新的
        // 用户点击，不能再记一次「点击申请」埋点。
        await Get.find<MainController>().applyNow(
          productId,
          requestLocation: false,
          reportApplyTap: false,
        );
      },
    ),
    permanent: true,
  );

  // 上报服务只先登记：启动埋点与系统授权弹窗要等启动门禁确认网关可达、真实
  // 界面首帧渲染之后再跑（与 peso_shield 一致），否则通知与 ATT 弹窗会盖在
  // 启动图/网络错误页上。推送路由必须现在开始监听，通知点击才不会被丢掉。
  final reportService = dependencies.reportService;
  if (reportService != null) {
    final pushRoutes = PushRouteCoordinator(reportService.bridge.events)
      ..start();
    Get.put<PushRouteCoordinator>(pushRoutes, permanent: true);
    Get.put<ReportService>(reportService, permanent: true);
    WidgetsBinding.instance.addObserver(ReportLifecycleObserver(reportService));
  }
  AppNavigator.mainTabSelector = (index) {
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().switchTab(index);
    }
  };

  AnalyticsService.logEvent(AppEvents.appOpen);
  runApplication(
    StartupNetworkGate(
      probe: () => probeStartupTransport(
        dependencies.gatewayClient,
        onReachable: dependencies.syncDeviceName,
        reportSwitch: dependencies.gatewayClient.reportEndpointSwitch,
      ),
      readyBuilder: () => HandaPesoApp(dependencies: dependencies),
      // 授权弹窗与启动上报都等到这里：门禁已放行且真实界面首帧已绘制。
      onReady: reportService == null
          ? null
          : () => unawaited(reportService.start()),
    ),
  );
}

Future<void> _lockPortrait() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}
