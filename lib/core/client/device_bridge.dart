import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// 从原生 iOS 层读取的设备身份信息。
///
/// [platform] 是硬件标识（例如 `iPhone15,2`），[deviceId] 是 Keychain 支撑的
/// IDFV，在重装应用后仍保持稳定，版本字段则用于填充应用的签名公有参数。
class ClientPlatformInfo {
  const ClientPlatformInfo({
    required this.platform,
    required this.systemVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.deviceId,
  });

  factory ClientPlatformInfo.fromMap(Map<Object?, Object?> map) {
    return ClientPlatformInfo(
      platform: _stringValue(map['platform']),
      systemVersion: _stringValue(map['systemVersion']),
      appVersion: _stringValue(map['appVersion']),
      buildNumber: _stringValue(map['buildNumber']),
      deviceId: _stringValue(map['deviceId']),
    );
  }

  final String platform;
  final String systemVersion;
  final String appVersion;
  final String buildNumber;
  final String deviceId;

  static String _stringValue(Object? value) => value?.toString() ?? '';
}

/// 对 `handa_peso/device_bridge` 方法通道的轻量封装。
///
/// 当通道不可用时（单元测试、非 iOS 宿主环境），每次调用都会优雅降级，
/// 因此调用方无需自行防范平台层面的失败。
class DeviceBridge {
  DeviceBridge({bool? supported, MethodChannel? channel})
    : _supported = supported ?? Platform.isIOS,
      _channel = channel ?? const MethodChannel(channelName);

  static const channelName = 'handa_peso/device_bridge';

  final bool _supported;
  final MethodChannel _channel;

  bool get supportsNativeBridge => _supported;

  Future<ClientPlatformInfo?> platformInfo() async {
    if (!_supported) return null;
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getPlatformInfo',
      );
      if (result == null) return null;
      return ClientPlatformInfo.fromMap(result);
    } on MissingPluginException {
      // 冷启动期间原生桥接仍在注册中。
      return null;
    } on PlatformException {
      return null;
    } on UnsupportedError {
      return null;
    }
  }
}
