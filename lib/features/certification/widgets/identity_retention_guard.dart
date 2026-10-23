import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../app/navigation/app_navigator.dart';
import '../../../core/analytics/analytics_service.dart';
import '../../../core/network/gateway_client.dart';
import '../../../core/network/gateway_failure.dart';
import '../identity_models.dart';
import 'identity_retention_dialog.dart';

/// 认证流程页的退出挽留。
///
/// 弹窗类型（`ulterior`）与接口文档一致：0 证件认证、1 人脸识别、2 个人信息、
/// 3 工作信息、4 紧急联系人、5 确认用款（H5 页面自己处理）。每次返回都重新
/// 请求配置；请求失败或没有插画时直接放行，不阻塞用户退出。
///
/// 用法：页面 State 混入本 mixin 并在最外层包一层 [PopScope]，同时把顶部返回键
/// 接到 [handleRetentionExit]——顶部返回是直接 `pop`，不经过 `PopScope` 拦截。
mixin IdentityRetentionGuard<T extends StatefulWidget> on State<T> {
  /// 挽留弹窗类型（接口字段 `ulterior`）。
  String get retentionScene;

  /// 用户当前申请的产品 ID（接口字段 `knife`）。
  String get retentionProductId;

  /// 请求挽留配置的网关；由页面复用自己注入的实例，测试才能替换。
  GatewayClient get retentionApiClient;

  /// 测试时注入本地图片，避免挽留弹窗依赖网络。
  ImageProvider<Object>? get retentionImageProvider => null;

  /// 挽留接口请求中：连点返回只保留一次。
  bool _checkingRetention = false;

  /// 用户确认退出后才放行一次返回，避免再次触发挽留。
  bool _allowPop = false;

  /// 供 [PopScope.canPop] 使用。
  bool get retentionCanPop => _allowPop;

  /// 处理一次返回：请求配置、按用户选择留在当前页或退出。
  Future<void> handleRetentionExit() async {
    if (_checkingRetention || _allowPop) return;
    _checkingRetention = true;
    IdentityRetentionPrompt? prompt;
    await AppNavigator.showLoading();
    try {
      final reply = await retentionApiClient.fetchRetentionPrompt(
        scene: retentionScene,
        productId: retentionProductId,
      );
      reply.orThrow();
      prompt = IdentityRetentionPrompt.fromReply(reply);
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    } finally {
      await AppNavigator.dismissLoading();
      _checkingRetention = false;
    }
    if (!mounted) return;
    if (prompt?.shouldShow == true) {
      final stay = await showIdentityRetentionDialog(
        context,
        prompt: prompt!,
        imageProvider: retentionImageProvider,
      );
      if (!mounted || stay) return;
    }
    leaveRetentionGuardedPage();
  }

  /// 放行一次返回；`PopScope` 在下一帧才会拿到新值。
  void leaveRetentionGuardedPage() {
    if (_allowPop) return;
    setState(() => _allowPop = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.back<void>();
    });
  }
}
