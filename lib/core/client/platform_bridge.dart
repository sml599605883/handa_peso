import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 原生回传的原始字段表。
typedef _Payload = Map<Object?, Object?>;

/// 读取原生回传字段的小工具。
///
/// `invokeMapMethod` 只给出 `Object?`，而 Swift 侧回传的都是 plist 可序列化
/// 类型，因此每个字段在这里统一归一化成 Dart 侧的强类型。
class _Fields {
  const _Fields(this._raw);

  final _Payload _raw;

  String text(String key) => _raw[key]?.toString() ?? '';

  bool isTrue(String key) => _raw[key] == true;

  int number(String key) {
    final raw = _raw[key];
    return switch (raw) {
      int value => value,
      num value => value.toInt(),
      String value => int.tryParse(value.trim()) ?? 0,
      _ => 0,
    };
  }
}

/// 原生层回传的设备身份。
///
/// [hardwareModel] 是硬件标识（例如 `iPhone15,2`），[deviceId] 是 Keychain
/// 支撑的 IDFV（重装应用后仍然稳定），版本字段用于填充签名公有参数。
class DeviceIdentity {
  const DeviceIdentity({
    required this.deviceId,
    required this.hardwareModel,
    required this.systemVersion,
    required this.appVersion,
    required this.buildNumber,
  });

  /// 键名由 Swift 侧固定，改动需同步 `DeviceBridgeRegistrar`。
  factory DeviceIdentity.fromMap(Map<Object?, Object?> raw) {
    final fields = _Fields(raw);
    return DeviceIdentity(
      hardwareModel: fields.text('platform'),
      systemVersion: fields.text('systemVersion'),
      appVersion: fields.text('appVersion'),
      buildNumber: fields.text('buildNumber'),
      deviceId: fields.text('deviceId'),
    );
  }

  final String deviceId;
  final String hardwareModel;
  final String systemVersion;
  final String appVersion;
  final String buildNumber;
}

/// 原生层回传的系统代理设置。
///
/// 抓包工具（Proxyman/Charles）把代理写进系统网络设置，而 Dart 的 `HttpClient`
/// 默认直连、不读系统代理，所以必须由原生层把 host/port 透出来，再交给
/// `GatewayTransport.useProxy` 应用到 Dio 上。
class ProxyEndpoint {
  const ProxyEndpoint({
    required this.host,
    required this.port,
    required this.isEnabled,
  });

  factory ProxyEndpoint.fromMap(Map<Object?, Object?> raw) {
    final fields = _Fields(raw);
    final host = fields.text('host');
    return ProxyEndpoint(
      isEnabled: fields.isTrue('enabled') && host.isNotEmpty,
      host: host,
      port: fields.number('port'),
    );
  }

  final String host;
  final int port;
  final bool isEnabled;

  /// 只有原生确认代理已开启、且 host/port 合法时，才真的能拿来抓包。
  bool get isUsable => isEnabled && host.isNotEmpty && port > 0;
}

/// `handa_peso/device_bridge` 方法通道的薄封装。
///
/// 通道不可用时（单元测试、非 iOS 宿主）每次都优雅降级返回 `null`，调用方
/// 不需要自己防范平台异常。
class PlatformBridge {
  /// 与 Swift 侧注册的通道名保持一致。
  static const channelName = 'handa_peso/device_bridge';

  /// 只有 iOS 侧注册了这条通道，其它宿主直接走降级分支。
  static final bool _hostedOnIOS = defaultTargetPlatform == TargetPlatform.iOS;

  PlatformBridge({bool? available, MethodChannel? channel})
    : _available = available ?? _hostedOnIOS,
      _methods = channel ?? const MethodChannel(channelName);

  final bool _available;
  final MethodChannel _methods;

  bool get isAvailable => _available;

  /// 读取设备身份；原生不可用时返回 `null`。
  Future<DeviceIdentity?> readDeviceIdentity() async {
    final payload = await _call('getPlatformInfo');
    return payload == null ? null : DeviceIdentity.fromMap(payload);
  }

  /// 读取系统 HTTP 代理；桥接不可用或系统未开启代理时返回 `null`。
  ///
  /// 抓包能力完全由系统设置驱动：没配代理时这里返回 `null`，请求照旧直连，
  /// 发布包行为与改动前一致。
  Future<ProxyEndpoint?> readProxyEndpoint() async {
    final payload = await _call('getProxySettings');
    return payload == null ? null : ProxyEndpoint.fromMap(payload);
  }

  /// 由系统决定是否展示应用评分卡片；原生不可用时静默跳过。
  Future<void> requestAppReview() async {
    if (!_available) return;
    try {
      await _methods.invokeMethod<void>('requestAppReview');
    } on MissingPluginException {
      return;
    } on PlatformException {
      return;
    }
  }

  /// 方法名同样是 Swift 侧的固定契约；任何平台侧异常都收敛成 `null`。
  Future<_Payload?> _call(String method) async {
    if (!_available) return null;
    try {
      return await _methods.invokeMapMethod<Object?, Object?>(method);
    } catch (error) {
      // 冷启动期间原生桥接可能还在注册，非 iOS 宿主则会直接抛错。
      if (error is MissingPluginException ||
          error is PlatformException ||
          error is UnsupportedError) {
        return null;
      }
      rethrow;
    }
  }
}
