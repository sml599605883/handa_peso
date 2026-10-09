import 'package:get/get.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/network/api_client.dart';
import 'login_controller.dart';

class LoginBinding extends Bindings {
  LoginBinding({this.apiClient, this.appDependencies});

  final ApiClient? apiClient;
  final AppDependencies? appDependencies;

  @override
  void dependencies() {
    final client = apiClient ?? appDependencies?.apiClient ?? Get.find<ApiClient>();
    Get.put<LoginController>(LoginController(apiClient: client, sessionStore: client.config.sessionStore));
  }
}
