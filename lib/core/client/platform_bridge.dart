import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// 原生层回传的设备身份。
///
/// [hardwareModel] 是硬件标识（例如 `iPhone15,2`），[deviceId] 是 Keychain
/// 支撑的 IDFV（重装应用后仍稳定），版本字段用于填充签名公有参数。
class DeviceIdentity {
  const DeviceIdentity({
    required this.hardwareModel,
    required this.systemVersion,
    required this.appVersion,
    required this.buildNumber,
    required this.deviceId,
  });

  /// 键名由 Swift 侧固定，改动需同步 `DeviceBridgeRegistrar`。
  factory DeviceIdentity.fromMap(Map<Object?, Object?> map) {
    return DeviceIdentity(
      hardwareModel: _text(map['platform']),
      systemVersion: _text(map['systemVersion']),
      appVersion: _text(map['appVersion']),
      buildNumber: _text(map['buildNumber']),
      deviceId: _text(map['deviceId']),
    );
  }

  final String hardwareModel;
  final String systemVersion;
  final String appVersion;
  final String buildNumber;
  final String deviceId;

  static String _text(Object? value) => value?.toString() ?? '';
}

/// 原生层回传的系统代理设置。
///
/// 抓包工具（Proxyman/Charles）把代理写进系统网络设置，而 Dart 的 `HttpClient`
/// 默认直连、不读系统代理，所以必须由原生层把 host/port 透出来，再交给
/// `GatewayTransport.useProxy` 应用到 Dio 上。
class ProxyEndpoint {
  const ProxyEndpoint({
    required this.isEnabled,
    required this.host,
    required this.port,
  });

  factory ProxyEndpoint.fromMap(Map<Object?, Object?> map) {
    final host = _text(map['host']);
    return ProxyEndpoint(
      isEnabled: map['enabled'] == true && host.isNotEmpty,
      host: host,
      port: _port(map['port']),
    );
  }

  final bool isEnabled;
  final String host;
  final int port;

  /// 只有原生确认代理已开启、且 host/port 合法时，才真的能拿来抓包。
  bool get isUsable => isEnabled && host.isNotEmpty && port > 0;

  static String _text(Object? value) => value?.toString() ?? '';

  static int _port(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim()) ?? 0;
    return 0;
  }
}

/// `handa_peso/device_bridge` 方法通道的薄封装。
///
/// 通道不可用时（单元测试、非 iOS 宿主）每次都优雅降级返回 `null`，调用方
/// 不需要自己防范平台异常。
class PlatformBridge {
  PlatformBridge({bool? available, MethodChannel? channel})
    : _available = available ?? Platform.isIOS,
      _channel = channel ?? const MethodChannel(channelName);

  /// 与 Swift 侧注册的通道名一致。
  static const channelName = 'handa_peso/device_bridge';

  final bool _available;
  final MethodChannel _channel;

  bool get isAvailable => _available;

  /// 读取设备身份；原生不可用时返回 `null`。
  Future<DeviceIdentity?> readDeviceIdentity() async {
    final map = await _invoke('getPlatformInfo');
    return map == null ? null : DeviceIdentity.fromMap(map);
  }

  /// 读取系统 HTTP 代理；桥接不可用或系统未开启代理时返回 `null`。
  ///
  /// 抓包能力完全由系统设置驱动：没配代理时这里返回 `null`，请求照旧直连，
  /// 发布包行为与改动前一致。
  Future<ProxyEndpoint?> readProxyEndpoint() async {
    final map = await _invoke('getProxySettings');
    return map == null ? null : ProxyEndpoint.fromMap(map);
  }

  /// 方法名同样是 Swift 侧的固定契约。
  Future<Map<Object?, Object?>?> _invoke(String method) async {
    if (!_available) return null;
    try {
      return await _channel.invokeMapMethod<Object?, Object?>(method);
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
