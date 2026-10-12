import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import 'app/app.dart';
import 'app/navigation/app_navigator.dart';
import 'app/startup/startup_network_gate.dart';
import 'core/analytics/analytics_service.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'core/network/api_client.dart';
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
    CrashReporter.record(details.exception, details.stack ?? StackTrace.current);
  };

  await lockOrientation();
  final dependencies = await bootstrap();

  Get.put<AppDependencies>(dependencies, permanent: true);
  Get.put<ApiClient>(dependencies.apiClient, permanent: true);
  AppNavigator.mainTabSelector = (index) {
    if (Get.isRegistered<MainController>()) {
      Get.find<MainController>().selectTab(index);
    }
  };

  AnalyticsService.logEvent(AppEvents.appOpen);
  runApplication(
    StartupNetworkGate(
      probe: () => _probeStartupTransport(dependencies),
      readyBuilder: () => HandaPesoApp(dependencies: dependencies),
    ),
  );
}

/// 在外壳挂载之前确认网关可达。
///
/// 与 fund_nexus 的启动门禁保持一致：探测运行期间由启动图占住屏幕，
/// 设备名称查询仅在网关响应后触发，因此探测失败时可以给出重试入口，
/// 而不是停留在一个卡死的外壳上。
Future<bool> _probeStartupTransport(AppDependencies dependencies) async {
  final available = await dependencies.apiClient.probeTransport();
  if (available) {
    await dependencies.syncDeviceName();
  }
  return available;
}

Future<void> _lockPortrait() {
  return SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
}
