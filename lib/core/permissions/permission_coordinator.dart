import 'package:permission_handler/permission_handler.dart';

import '../report/report_bridge.dart';

/// 权限请求的结果，已为 UI 归一化处理。
enum PermissionDecision { granted, denied, permanentlyDenied, restricted }

/// 「点击申请」前的定位准入结果。
///
/// 只表达调用方接下来要做什么：继续申请、引导用户去系统设置，还是这条链路
/// 根本拿不到授权状态。
enum LocationAccessDecision {
  /// 授权弹窗已经结束，且拿到了定位权限。
  granted,

  /// 权限被拒绝，或被系统限制（家长控制等）：只能去系统设置里改。
  denied,

  /// 系统「定位服务」总开关没打开：同样要去系统设置，说明文案不同。
  serviceDisabled,

  /// 拿不到授权状态（非 iOS 宿主、原生尚未注册、弹窗被系统打断）。
  unavailable,
}

/// 定位授权请求函数；默认复用上报模块的原生通道，返回原生状态字符串。
typedef LocationPermissionRequester = Future<String> Function();

/// 集中管理权限弹窗，使每次请求都有一致的说明理由，
/// 并符合 App Store / Google Play 的信息披露要求。
class PermissionCoordinator {
  PermissionCoordinator({
    LocationPermissionRequester? requestLocationPermission,
  }) : _requestLocationPermission =
           requestLocationPermission ??
           ReportNativeBridge().requestLocationPermission;

  final LocationPermissionRequester _requestLocationPermission;

  Future<PermissionDecision> requestPhotos() => _request(Permission.photos);

  Future<PermissionDecision> requestCamera() => _request(Permission.camera);

  Future<PermissionDecision> requestLocation() =>
      _request(Permission.locationWhenInUse);

  Future<PermissionDecision> requestNotifications() =>
      _request(Permission.notification);

  Future<PermissionDecision> _request(Permission permission) async {
    var status = await permission.status;
    if (!status.isGranted) {
      status = await permission.request();
    }
    if (status.isGranted || status.isLimited) {
      return PermissionDecision.granted;
    }
    if (status.isPermanentlyDenied) {
      return PermissionDecision.permanentlyDenied;
    }
    if (status.isRestricted) {
      return PermissionDecision.restricted;
    }
    return PermissionDecision.denied;
  }

  Future<bool> openSettings() => openAppSettings();

  /// 「点击申请」前的定位准入：弹一次系统弹窗，等用户做完选择再回结果。
  ///
  /// iOS 的系统弹窗只有原生侧能可靠地等到用户选择，因此这里复用上报模块的原生
  /// 通道：权限已经决定过时原生直接回当前状态，不会再弹第二次。请求本身出错时
  /// 按 [LocationAccessDecision.unavailable] 放行——定位只补全风控数据，不允许
  /// 它挡住申请主流程。
  Future<LocationAccessDecision> requestLocationAccess() async {
    final String status;
    try {
      status = await _requestLocationPermission();
    } catch (_) {
      return LocationAccessDecision.unavailable;
    }

    return switch (status.trim()) {
      'authorized' ||
      'authorized_always' ||
      'authorized_when_in_use' => LocationAccessDecision.granted,
      'service_disabled' => LocationAccessDecision.serviceDisabled,
      'denied' || 'restricted' => LocationAccessDecision.denied,
      // `not_determined`：弹窗还没结论（被切到后台等情况）；空串：原生不可用。
      // 两种都不拦申请。
      _ => LocationAccessDecision.unavailable,
    };
  }
}
