import 'package:get/get.dart';

import '../../core/bootstrap/app_bootstrap.dart';
import '../../core/network/gateway_client.dart';
import '../../core/permissions/permission_coordinator.dart';
import 'main_controller.dart';

/// 外壳页的依赖装配。
///
/// 网关客户端按「调用方注入 → 启动阶段注册」的次序取用；两者都不存在时
/// 直接抛错，宁可启动即失败，也不要让页面在没有网络层的情况下运行。
class MainBinding extends Bindings {
  MainBinding({
    this.gatewayClient,
    this.appDependencies,
    this.permissionCoordinator,
  });

  final GatewayClient? gatewayClient;
  final AppDependencies? appDependencies;

  /// 申请前的定位权限走这里；不传就用真实实现（测试注入替身）。
  final PermissionCoordinator? permissionCoordinator;

  @override
  void dependencies() {
    final gateway = _resolveGateway();
    _install<GatewayClient>(() => gateway, permanent: true);
    _install<MainController>(
      () => MainController(
        gatewayClient: gateway,
        localSession: gateway.settings.localSession,
        permissionCoordinator: permissionCoordinator,
      ),
    );
  }

  GatewayClient _resolveGateway() {
    final provided = gatewayClient ?? appDependencies?.gatewayClient;
    if (provided != null) return provided;
    if (Get.isRegistered<GatewayClient>()) return Get.find<GatewayClient>();
    throw StateError('GatewayClient is not available to MainBinding.');
  }
}

/// 容器中还没有该类型时才注册，避免重复 put 覆盖已有实例。
void _install<T>(T Function() create, {bool permanent = false}) {
  if (Get.isRegistered<T>()) return;
  Get.put<T>(create(), permanent: permanent);
}
