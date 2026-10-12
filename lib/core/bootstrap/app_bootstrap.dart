import 'dart:async';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/navigation/app_navigator.dart';
import '../client/device_bridge.dart';
import '../device/device_info_sync.dart';
import '../network/api_client.dart';
import '../network/api_config.dart';
import '../session/session_store.dart';

/// Container for the dependencies created before the first frame.
class AppDependencies {
  AppDependencies({required this.apiClient, required this.sessionStore});

  final ApiClient apiClient;
  final SessionStore sessionStore;
}

/// Composition root for the app.
///
/// Deliberately performs no network I/O: the first frame should never be gated
/// behind a slow or unreachable backend. Screens load their own data and render
/// loading/error/empty states.
abstract final class AppBootstrap {
  static Future<AppDependencies> initialize({
    SessionStore Function()? sessionStoreFactory,
    String? apiBaseUrl,
    String? webBaseUrl,
    String? signatureSecret,
    AuthExpiredHandler? authExpiredHandler,
  }) async {
    final sessionStore =
        sessionStoreFactory?.call() ?? SessionStore(SharedPreferencesAsync());

    final config = ApiConfig(
      apiBaseUrl: apiBaseUrl ?? ApiConfig.defaultApiBaseUrl,
      webBaseUrl: webBaseUrl ?? ApiConfig.defaultWebBaseUrl,
      signatureSecret: signatureSecret ?? ApiConfig.defaultSignatureSecret,
      sessionStore: sessionStore,
    )..appVersion = await _appVersion();

    config.authExpiredHandler ??=
        AppNavigator.redirectToLoginAfterSessionExpiry;

    final apiClient = ApiClient(config);
    final deviceSync = DeviceInfoSync(
      apiClient: apiClient,
      bridge: DeviceBridge(),
      store: sessionStore,
    );

    // Fill the signed public parameters from the native device identity. This
    // touches no network; the human-readable device name is resolved in the
    // background so startup is never blocked on the gateway.
    final model = await deviceSync.applyDeviceIdentity(config);
    if (model != null && model.isNotEmpty) {
      unawaited(deviceSync.resolveDeviceName(config, model));
    }

    return AppDependencies(apiClient: apiClient, sessionStore: sessionStore);
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      // Version lookup is best-effort and must not block startup.
      return '';
    }
  }
}
