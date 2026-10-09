import 'package:get/get.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/network/api_client.dart';
import 'main_controller.dart';

class MainBinding extends Bindings {
  MainBinding({this.apiClient, this.appDependencies});

  final ApiClient? apiClient;
  final AppDependencies? appDependencies;

  @override
  void dependencies() {
    final client = apiClient ??
        appDependencies?.apiClient ??
        (Get.isRegistered<ApiClient>() ? Get.find<ApiClient>() : null);
    if (client == null) {
      throw StateError('ApiClient is not available to MainBinding.');
    }
    if (!Get.isRegistered<ApiClient>()) {
      Get.put<ApiClient>(client, permanent: true);
    }
    if (!Get.isRegistered<MainController>()) {
      Get.put<MainController>(
        MainController(apiClient: client, sessionStore: client.config.sessionStore),
      );
    }
  }
}
