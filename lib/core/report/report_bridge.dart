import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'report_models.dart';

/// 原生上报通道的薄封装。
///
/// 方法名与返回结构是 Swift 侧 `ReportBridgeRegistrar` 的固定契约；通道不可用时
/// （单元测试、非 iOS 宿主、冷启动期间原生尚未注册）一律优雅降级成空值，
/// 调用方不需要自己防范平台异常。
class ReportNativeBridge {
  ReportNativeBridge({
    bool? available,
    MethodChannel? methods,
    EventChannel? events,
  }) : _available = available ?? _hostedOnIOS,
       _methods = methods ?? const MethodChannel(channelName),
       _events = events ?? const EventChannel(eventChannelName);

  /// 与 Swift 侧注册的通道名保持一致。
  static const channelName = 'handa_peso/report_bridge';
  static const eventChannelName = 'handa_peso/report_events';

  static final bool _hostedOnIOS = defaultTargetPlatform == TargetPlatform.iOS;

  /// 跟踪授权未决；此时不应把 IDFA 之外的信息当成已授权状态上报。
  static const trackingNotDetermined = 'not_determined';

  final bool _available;
  final MethodChannel _methods;
  final EventChannel _events;

  Stream<Map<String, dynamic>>? _stream;

  bool get isAvailable => _available;

  /// 原生推送 token 与跟踪授权变化的事件流（广播，可被多处订阅）。
  Stream<Map<String, dynamic>> events() {
    return _stream ??= _events
        .receiveBroadcastStream()
        .map(_asMap)
        .where((event) => event.isNotEmpty)
        .asBroadcastStream();
  }

  /// 设备快照；原生不可用时返回 `null`。
  Future<DeviceSnapshot?> deviceSnapshot() async {
    final payload = await _map('getDeviceSnapshot');
    return payload == null ? null : DeviceSnapshot.fromMap(payload);
  }

  /// 一次定位；未授权或定位服务关闭时返回 `null`（权限状态仍可从
  /// [ReportLocation.permissionStatus] 读到，用于排查）。
  Future<ReportLocation?> location() async {
    final payload = await _map('getLocation');
    if (payload == null) return null;
    final location = ReportLocation.fromMap(payload);
    return location.isValid ? location : null;
  }

  /// 读取本机通讯录；未授权时返回空列表。
  Future<List<ContactRecord>> contacts() async {
    if (!_available) return const <ContactRecord>[];
    try {
      final rows =
          await _methods.invokeListMethod<Object?>('getContacts') ??
          const <Object?>[];
      return rows
          .whereType<Map<Object?, Object?>>()
          .map(ContactRecord.fromMap)
          .where((contact) => contact.isUsable)
          .toList(growable: false);
    } catch (error) {
      _swallow(error);
      return const <ContactRecord>[];
    }
  }

  Future<String> pushToken() => _text('getPushToken');

  /// ATT 授权状态：`authorized` / `denied` / `restricted` / `not_determined`。
  Future<String> trackingStatus() => _text('getTrackingStatus');

  /// 弹一次系统定位授权弹窗，等用户做完选择后返回权限状态。
  ///
  /// 埋点1 的时机由这个结果决定：弹窗结束（给不给权限都算）之后才上报。
  /// 原生不可用时返回空串，调用方据此按“无需等待”处理。
  Future<String> requestLocationPermission() =>
      _text('requestLocationPermission');

  Future<void> requestNotificationPermission() =>
      _invoke('requestNotificationPermission');

  Future<void> requestTrackingPermission() =>
      _invoke('requestTrackingPermission');

  Future<void> registerForRemoteNotifications() =>
      _invoke('registerForRemoteNotifications');

  Future<Map<Object?, Object?>?> _map(String method) async {
    if (!_available) return null;
    try {
      return await _methods.invokeMapMethod<Object?, Object?>(method);
    } catch (error) {
      _swallow(error);
      return null;
    }
  }

  Future<String> _text(String method) async {
    if (!_available) return '';
    try {
      final value = await _methods.invokeMethod<Object?>(method);
      return reportText(value);
    } catch (error) {
      _swallow(error);
      return '';
    }
  }

  Future<void> _invoke(String method) async {
    if (!_available) return;
    try {
      await _methods.invokeMethod<void>(method);
    } catch (error) {
      _swallow(error);
    }
  }

  Map<String, dynamic> _asMap(Object? event) {
    if (event is Map) return Map<String, dynamic>.from(event);
    return const <String, dynamic>{};
  }

  /// 原生侧尚未注册或本次调用失败都不该影响业务：上报本身是尽力而为的。
  void _swallow(Object error) {
    if (error is MissingPluginException ||
        error is PlatformException ||
        error is UnsupportedError) {
      return;
    }
    throw error;
  }
}
