import 'package:flutter/services.dart';

import '../client/device_bridge.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../session/session_store.dart';

/// 填充网关所需的设备公有参数。
///
/// 原生层无需联网即可提供硬件标识、系统版本以及 Keychain 稳定的 IDFV，
/// 因此 [applyDeviceIdentity] 可以在首帧之前执行。可读设备名称需要一次
/// 网关往返，所以 [resolveDeviceName] 随后执行且完全尽力而为：即使失败，
/// 签名请求仍会以硬件标识作为兜底继续工作。
class DeviceInfoSync {
  const DeviceInfoSync({
    required this.apiClient,
    required this.bridge,
    required this.store,
    this.attempts = 3,
    this.retryDelay = const Duration(milliseconds: 100),
  }) : assert(attempts > 0);

  final ApiClient apiClient;
  final DeviceBridge bridge;
  final SessionStore store;
  final int attempts;
  final Duration retryDelay;

  /// 将本地设备身份写入 [config] 并返回硬件标识；
  /// 当原生桥接不可用时返回 `null`。
  Future<String?> applyDeviceIdentity(ApiConfig config) async {
    final info = await _platformInfo();
    if (info != null) {
      if (info.deviceId.isNotEmpty) config.deviceId = info.deviceId;
      if (info.systemVersion.isNotEmpty) config.osVersion = info.systemVersion;
      if (info.appVersion.isNotEmpty) config.appVersion = info.appVersion;
      if (info.platform.isNotEmpty) config.deviceName = info.platform;
    }
    if (config.deviceName.isEmpty) {
      config.deviceName = await store.deviceName();
    }
    return info?.platform;
  }

  /// 通过网关解析 [modelIdentifier] 对应的显示设备名称。
  ///
  /// 永不抛异常：失败时保留硬件标识，从而保证后续请求仍能被正确签名。
  Future<void> resolveDeviceName(
    ApiConfig config,
    String modelIdentifier,
  ) async {
    if (modelIdentifier.isEmpty) return;

    final cached = await store.deviceName();
    if (cached.isNotEmpty && cached != modelIdentifier) {
      config.deviceName = cached;
      return;
    }

    try {
      final response = await apiClient.getDeviceName(
        definitively: modelIdentifier,
      );
      final name = response.states['especially']?.toString() ?? '';
      if (name.isNotEmpty && name != modelIdentifier) {
        await store.saveDeviceName(name);
        config.deviceName = name;
      }
    } catch (_) {
      // 设备名称查询是尽力而为的，不得影响启动。
    }
  }

  Future<ClientPlatformInfo?> _platformInfo() async {
    if (!bridge.supportsNativeBridge) return null;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final info = await bridge.platformInfo();
        if (info != null && info.deviceId.isNotEmpty) {
          return info;
        }
      } on MissingPluginException {
        // 隐式 Flutter 引擎可能仍在注册其通道。
      } on PlatformException {
        // 冷启动期间重试偶发的通道失败。
      } on UnsupportedError {
        return null;
      }

      if (attempt + 1 < attempts) {
        await Future<void>.delayed(retryDelay);
      }
    }
    return null;
  }
}
