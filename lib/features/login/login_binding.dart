import 'package:get/get.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/network/gateway_client.dart';
import 'login_controller.dart';

class LoginBinding extends Bindings {
  LoginBinding({this.apiClient, this.appDependencies});

  final GatewayClient? apiClient;
  final AppDependencies? appDependencies;

  @override
  void dependencies() {
    final client = apiClient ?? appDependencies?.apiClient ?? Get.find<GatewayClient>();
    Get.put<LoginController>(LoginController(apiClient: client, sessionStore: client.settings.sessionStore));
  }
}
