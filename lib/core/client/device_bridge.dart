import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Device identity read from the native iOS layer.
///
/// [platform] is the hardware identifier (e.g. `iPhone15,2`), [deviceId] is a
/// Keychain-backed IDFV that stays stable across reinstalls, and the version
/// fields feed the app's signed public parameters.
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

/// Thin wrapper over the `handa_peso/device_bridge` method channel.
///
/// Every call degrades gracefully when the channel is unavailable (unit tests,
/// non-iOS hosts) so callers never have to guard for platform failures.
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
      // The native bridge is still registering during a cold start.
      return null;
    } on PlatformException {
      return null;
    } on UnsupportedError {
      return null;
    }
  }
}
