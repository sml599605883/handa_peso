import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'app/navigation/app_navigator.dart';
import 'app/startup/startup_network_gate.dart';
import 'core/analytics/analytics_service.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/network/gateway_client.dart';
import 'core/report/report_lifecycle.dart';
import 'core/report/report_service.dart';
import 'features/main_shell/main_controller.dart';

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

  // 上报在首帧之前就开始跑：启动埋点、授权弹窗、APNs 注册与补报都要抢在
  // 用户真正进入业务之前完成，页面随后只是往里追加业务埋点。
  final reportService = dependencies.reportService;
  if (reportService != null) {
    Get.put<ReportService>(reportService, permanent: true);
    WidgetsBinding.instance.addObserver(ReportLifecycleObserver(reportService));
    unawaited(reportService.start());
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
    ),
  );
}

Future<void> _lockPortrait() {
  return SystemChrome.setPreferredOrientations(const [
    DeviceOrientation.portraitUp,
  ]);
}
