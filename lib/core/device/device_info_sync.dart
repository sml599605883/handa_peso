import 'package:flutter/services.dart';

import '../client/platform_bridge.dart';
import '../network/gateway_client.dart';
import '../network/gateway_settings.dart';
import '../session/local_session.dart';

/// 填充网关要求的设备公有参数。
///
/// 硬件标识、系统版本与 Keychain 稳定的 IDFV 都不需要联网，因此
/// [applyDeviceIdentity] 可以在首帧之前跑完；可读设备名要多一次网关往返，
/// 所以 [resolveDeviceName] 随后执行，且完全尽力而为——失败时签名请求仍以
/// 硬件标识兜底。
class DeviceInfoSync {
  const DeviceInfoSync({
    required this.gatewayClient,
    required this.bridge,
    required this.localSession,
    this.attempts = 3,
    this.retryDelay = const Duration(milliseconds: 100),
  }) : assert(attempts > 0);

  final GatewayClient gatewayClient;
  final PlatformBridge bridge;
  final LocalSession localSession;
  final int attempts;
  final Duration retryDelay;

  /// 把本地设备身份写进 [settings]，并返回硬件标识；
  /// 原生桥接不可用时返回 `null`。
  Future<String?> applyDeviceIdentity(GatewaySettings settings) async {
    final identity = await _readIdentity();
    if (identity != null) {
      if (identity.deviceId.isNotEmpty) settings.deviceId = identity.deviceId;
      if (identity.systemVersion.isNotEmpty) {
        settings.systemVersion = identity.systemVersion;
      }
      if (identity.appVersion.isNotEmpty) {
        settings.appVersion = identity.appVersion;
      }
      if (identity.hardwareModel.isNotEmpty) {
        settings.deviceLabel = identity.hardwareModel;
      }
    }
    if (settings.deviceLabel.isEmpty) {
      settings.deviceLabel = await localSession.readDeviceLabel();
    }
    return identity?.hardwareModel;
  }

  /// 通过网关把 [modelCode]（如 `iPhone15,2`）解析成可读设备名。
  ///
  /// 永不抛异常：失败时保留硬件标识，后续请求依然能被正确签名。
  Future<void> resolveDeviceName(
    GatewaySettings settings,
    String modelCode,
  ) async {
    if (modelCode.isEmpty) return;

    final cached = await localSession.readDeviceLabel();
    if (cached.isNotEmpty && cached != modelCode) {
      settings.deviceLabel = cached;
      return;
    }

    try {
      final reply = await gatewayClient.lookupDeviceName(modelCode: modelCode);
      final name = reply.payload['especially']?.toString() ?? '';
      if (name.isNotEmpty && name != modelCode) {
        await localSession.writeDeviceLabel(name);
        settings.deviceLabel = name;
      }
    } catch (_) {
      // 设备名查询是尽力而为的，不得影响启动。
    }
  }

  Future<DeviceIdentity?> _readIdentity() async {
    if (!bridge.isAvailable) return null;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final identity = await bridge.readDeviceIdentity();
        if (identity != null && identity.deviceId.isNotEmpty) {
          return identity;
        }
      } on MissingPluginException {
        // 隐式 Flutter 引擎可能仍在注册它的通道。
      } on PlatformException {
        // 冷启动期间偶发的通道失败，重试即可。
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
