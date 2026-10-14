import 'package:get/get.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/network/gateway_client.dart';
import 'main_controller.dart';

class MainBinding extends Bindings {
  MainBinding({this.apiClient, this.appDependencies});

  final GatewayClient? apiClient;
  final AppDependencies? appDependencies;

  @override
  void dependencies() {
    final client = apiClient ??
        appDependencies?.apiClient ??
        (Get.isRegistered<GatewayClient>() ? Get.find<GatewayClient>() : null);
    if (client == null) {
      throw StateError('GatewayClient is not available to MainBinding.');
    }
    if (!Get.isRegistered<GatewayClient>()) {
      Get.put<GatewayClient>(client, permanent: true);
    }
    if (!Get.isRegistered<MainController>()) {
      Get.put<MainController>(
        MainController(apiClient: client, sessionStore: client.settings.sessionStore),
      );
    }
  }
}
