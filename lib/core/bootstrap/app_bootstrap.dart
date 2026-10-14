import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/navigation/app_navigator.dart';
import '../client/platform_bridge.dart';
import '../device/device_info_sync.dart';
import '../network/gateway_client.dart';
import '../network/gateway_settings.dart';
import '../session/session_store.dart';

/// 承载首帧渲染之前就已创建好的各项依赖。
class AppDependencies {
  AppDependencies({
    required this.apiClient,
    required this.sessionStore,
    Future<void> Function()? syncDeviceName,
  }) : syncDeviceName = syncDeviceName ?? _noop;

  final GatewayClient apiClient;
  final SessionStore sessionStore;

  /// 尽力而为地向网关查询可读的设备名称。
  ///
  /// 会延迟到启动门禁确认网关可达之后才执行，让可达性探测与名称查询共用
  /// 同一个判断结果。该方法永不抛异常。
  final Future<void> Function() syncDeviceName;

  static Future<void> _noop() async {}
}

/// 应用的组合根（Composition Root）。
///
/// 自身不进行任何网络 I/O：设备身份取自原生层，可读设备名称则延迟到
/// [AppDependencies.syncDeviceName]，由启动门禁在确认网关可达后才执行。
/// 各页面仍各自加载数据，并渲染 loading/error/empty 状态。
abstract final class AppBootstrap {
  static Future<AppDependencies> initialize({
    SessionStore Function()? sessionStoreFactory,
    String? apiBaseUrl,
    String? webBaseUrl,
    String? signatureSecret,
    SessionExpiredCallback? onSessionExpired,
    PlatformBridge? platformBridge,
  }) async {
    final sessionStore =
        sessionStoreFactory?.call() ?? SessionStore(SharedPreferencesAsync());

    final settings = GatewaySettings(
      apiOrigin: apiBaseUrl ?? GatewaySettings.fallbackApiOrigin,
      webOrigin: webBaseUrl ?? GatewaySettings.fallbackWebOrigin,
      signSecret: signatureSecret ?? GatewaySettings.fallbackSignSecret,
      sessionStore: sessionStore,
    )..appVersion = await _appVersion();

    settings.onSessionExpired ??=
        AppNavigator.redirectToLoginAfterSessionExpiry;

    final bridge = platformBridge ?? PlatformBridge();
    final apiClient = GatewayClient(settings);

    // 抓包：代理地址由 iOS 系统网络设置决定，未配置代理时保持直连。
    // 必须在首个请求（启动门禁探测）之前完成。
    await _applyNativeProxy(apiClient, bridge);

    final deviceSync = DeviceInfoSync(
      apiClient: apiClient,
      bridge: bridge,
      store: sessionStore,
    );

    // 用原生设备身份填充需要签名的公有参数。此过程不涉及网络；
    // 可读设备名称会在启动门禁确认网关可达后解析。
    final model = await deviceSync.applyDeviceIdentity(settings);

    return AppDependencies(
      apiClient: apiClient,
      sessionStore: sessionStore,
      syncDeviceName: model == null || model.isEmpty
          ? null
          : () => deviceSync.resolveDeviceName(settings, model),
    );
  }

  static Future<String> _appVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      return info.version;
    } catch (_) {
      // 版本查询是尽力而为的，不得阻塞启动。
      return '';
    }
  }

  /// 从原生层读取系统代理并应用到 Dio，让设备上的抓包工具能收到请求。
  ///
  /// 尽力而为：桥接不可用、原生未开启代理或读取失败时都保持直连启动。
  static Future<void> _applyNativeProxy(
    GatewayClient apiClient,
    PlatformBridge bridge,
  ) async {
    try {
      final proxy = await bridge.readProxyEndpoint();
      if (proxy != null && proxy.isUsable) {
        apiClient.useProxy(host: proxy.host, port: proxy.port);
      }
    } catch (_) {
      // 代理发现不得阻塞启动。
    }
  }
}
