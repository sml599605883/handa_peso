import 'package:permission_handler/permission_handler.dart';

/// 权限请求的结果，已为 UI 归一化处理。
enum PermissionDecision { granted, denied, permanentlyDenied, restricted }

/// 集中管理权限弹窗，使每次请求都有一致的说明理由，
/// 并符合 App Store / Google Play 的信息披露要求。
class PermissionCoordinator {
  const PermissionCoordinator();

  Future<PermissionDecision> requestContacts() => _request(Permission.contacts);

  Future<PermissionDecision> requestPhotos() => _request(Permission.photos);

  Future<PermissionDecision> requestCamera() => _request(Permission.camera);

  Future<PermissionDecision> requestLocation() => _request(Permission.locationWhenInUse);

  Future<PermissionDecision> requestNotifications() => _request(Permission.notification);

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
}
