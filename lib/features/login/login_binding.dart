import 'package:get/get.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/network/gateway_client.dart';
import '../../core/report/report_service.dart';
import 'login_controller.dart';

class LoginBinding extends Bindings {
  LoginBinding({this.gatewayClient, this.appDependencies});

  final GatewayClient? gatewayClient;
  final AppDependencies? appDependencies;

  @override
  void dependencies() {
    final client =
        gatewayClient ??
        appDependencies?.gatewayClient ??
        Get.find<GatewayClient>();
    final reporter = appDependencies?.reportService ?? _registeredReporter();
    Get.put<LoginController>(
      LoginController(
        gatewayClient: client,
        localSession: client.settings.localSession,
        reportService: reporter,
      ),
    );
  }

  /// 登录页可能在任何时机打开：上报服务由启动流程注册，这里只在容器里存在时取用。
  ReportService? _registeredReporter() {
    if (Get.isRegistered<ReportService>()) return Get.find<ReportService>();
    return null;
  }
}
