import 'package:flutter/services.dart';

import '../client/device_bridge.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../session/session_store.dart';

/// Fills the gateway's device public parameters.
///
/// The native layer supplies the hardware identifier, OS version and a
/// Keychain-stable IDFV without touching the network, so [applyDeviceIdentity]
/// can run before the first frame. The human-readable device name needs a
/// gateway round-trip, so [resolveDeviceName] runs afterwards and is entirely
/// best-effort: the signed request keeps working with the hardware identifier
/// as a fallback.
class DeviceInfoSync {
  const DeviceInfoSync({
    required this.apiClient,
    required this.bridge,
    required this.store,
    this.attempts = 3,
    this.retryDelay = const Duration(milliseconds: 100),
  }) : assert(attempts > 0);

  final ApiClient apiClient;
  final DeviceBridge bridge;
  final SessionStore store;
  final int attempts;
  final Duration retryDelay;

  /// Applies the local device identity to [config] and returns the hardware
  /// identifier, or `null` when the native bridge is unavailable.
  Future<String?> applyDeviceIdentity(ApiConfig config) async {
    final info = await _platformInfo();
    if (info != null) {
      if (info.deviceId.isNotEmpty) config.deviceId = info.deviceId;
      if (info.systemVersion.isNotEmpty) config.osVersion = info.systemVersion;
      if (info.appVersion.isNotEmpty) config.appVersion = info.appVersion;
      if (info.platform.isNotEmpty) config.deviceName = info.platform;
    }
    if (config.deviceName.isEmpty) {
      config.deviceName = await store.deviceName();
    }
    return info?.platform;
  }

  /// Resolves the display device name for [modelIdentifier] via the gateway.
  ///
  /// Never throws: a failure leaves the hardware identifier in place so the
  /// next requests are still correctly signed.
  Future<void> resolveDeviceName(
    ApiConfig config,
    String modelIdentifier,
  ) async {
    if (modelIdentifier.isEmpty) return;

    final cached = await store.deviceName();
    if (cached.isNotEmpty && cached != modelIdentifier) {
      config.deviceName = cached;
      return;
    }

    try {
      final response = await apiClient.getDeviceName(
        definitively: modelIdentifier,
      );
      final name = response.states['especially']?.toString() ?? '';
      if (name.isNotEmpty && name != modelIdentifier) {
        await store.saveDeviceName(name);
        config.deviceName = name;
      }
    } catch (_) {
      // Device-name lookup is best-effort and must not affect startup.
    }
  }

  Future<ClientPlatformInfo?> _platformInfo() async {
    if (!bridge.supportsNativeBridge) return null;

    for (var attempt = 0; attempt < attempts; attempt++) {
      try {
        final info = await bridge.platformInfo();
        if (info != null && info.deviceId.isNotEmpty) {
          return info;
        }
      } on MissingPluginException {
        // The implicit Flutter engine may still be registering its channels.
      } on PlatformException {
        // Retry transient channel failures during a cold start.
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
