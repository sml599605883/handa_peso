import 'package:permission_handler/permission_handler.dart';

/// Outcome of a permission request, normalised for the UI.
enum PermissionDecision { granted, denied, permanentlyDenied, restricted }

/// Centralises permission prompts so every request has a consistent rationale
/// and complies with App Store / Google Play disclosure requirements.
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
