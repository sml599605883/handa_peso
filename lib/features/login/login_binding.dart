import 'package:get/get.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/network/gateway_client.dart';
import 'login_controller.dart';

class LoginBinding extends Bindings {
  LoginBinding({this.gatewayClient, this.appDependencies});

  final GatewayClient? gatewayClient;
  final AppDependencies? appDependencies;

  @override
  void dependencies() {
    final client = gatewayClient ?? appDependencies?.gatewayClient ?? Get.find<GatewayClient>();
    Get.put<LoginController>(LoginController(gatewayClient: client, localSession: client.settings.localSession));
  }
}
