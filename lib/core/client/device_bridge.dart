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

/// 从原生 iOS 层读取的系统代理配置。
///
/// 抓包工具（Proxyman/Charles）把代理写进系统网络设置，而 Dart 的
/// `HttpClient` 默认直连、不读取系统代理，因此必须由原生层把 host/port
/// 透出来，再交给 `ApiClient.setProxy` 应用到 Dio 上。
class ClientProxySettings {
  const ClientProxySettings({
    required this.enabled,
    required this.host,
    required this.port,
  });

  factory ClientProxySettings.fromMap(Map<Object?, Object?> map) {
    final host = _stringValue(map['host']);
    return ClientProxySettings(
      enabled: map['enabled'] == true && host.isNotEmpty,
      host: host,
      port: _intValue(map['port']),
    );
  }

  final bool enabled;
  final String host;
  final int port;

  /// 仅当原生层确认代理已启用、且 host/port 合法时才可用于抓包。
  bool get canApply => enabled && host.isNotEmpty && port > 0;

  static String _stringValue(Object? value) => value?.toString() ?? '';

  static int _intValue(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value.trim()) ?? 0;
    }
    return 0;
  }
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

  /// 读取系统 HTTP 代理；桥接不可用或原生未开启代理时返回 `null`。
  ///
  /// 抓包能力完全由系统设置驱动：设备没配代理时这里返回 `null`，
  /// 请求依旧直连，发布包的行为与未改动前一致。
  Future<ClientProxySettings?> proxySettings() async {
    if (!_supported) return null;
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'getProxySettings',
      );
      if (result == null) return null;
      return ClientProxySettings.fromMap(result);
    } on MissingPluginException {
      // 冷启动期间原生桥接仍在注册中。
      return null;
    } on PlatformException {
      return null;
    } on UnsupportedError {
      return null;
    }
  }

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
