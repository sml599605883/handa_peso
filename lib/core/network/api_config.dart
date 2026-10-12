import 'package:shared_preferences/shared_preferences.dart';

import '../session/session_store.dart';

typedef AuthExpiredHandler = Future<void> Function();
typedef TimestampProvider = int Function();
typedef RandomDigitsProvider = String Function(int length);

/// API 客户端的运行时配置。
///
/// 网关会用应用专属密钥和混淆后的公有参数对每个请求签名，因此市场标识、
/// 签名密钥以及上报用的 AES 密钥都是 Handa Peso 专属的。可在构建时通过
/// `--dart-define`（例如 `API_SIGN_SECRET=...`、`API_BASE_URL=...`）覆盖
/// 其中任意一项，而无需改动源码。
///
/// 域名默认使用后端提供的环境，也可按构建覆盖；应用同时支持由服务端
/// 下发的运行时域名切换。
class ApiConfig {
  ApiConfig({
    this.apiBaseUrl = defaultApiBaseUrl,
    this.webBaseUrl = defaultWebBaseUrl,
    this.remoteConfigUrl = defaultRemoteConfigUrl,
    this.signatureSecret = defaultSignatureSecret,
    this.encryptKey = defaultEncryptKey,
    this.encryptIv = defaultEncryptIv,
    this.appMarket = defaultAppMarket,
    this.scheme = defaultScheme,
    this.appVersion = '',
    this.deviceName = '',
    this.deviceId = '',
    this.osVersion = '',
    SessionStore? sessionStore,
    this.authExpiredHandler,
    this.timestampProvider,
    this.randomDigitsProvider,
  }) {
    _sessionStore = sessionStore;
  }

  static const defaultApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://8.220.176.2/deliv',
  );
  static const defaultWebBaseUrl = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'http://8.220.176.2',
  );
  static const defaultRemoteConfigUrl = String.fromEnvironment(
    'API_REMOTE_CONFIG_URL',
  );
  static const defaultSignatureSecret = String.fromEnvironment(
    'API_SIGN_SECRET',
    defaultValue: '713b788c33c51fb72eaab884289c8d30',
  );
  static const defaultEncryptKey = String.fromEnvironment(
    'API_AES_KEY',
    defaultValue: 'bb0f14fd3d820b45',
  );
  static const defaultEncryptIv = String.fromEnvironment(
    'API_AES_IV',
    defaultValue: 'a61df01c554a27a0',
  );
  static const defaultAppMarket = 'appstore-ph-handa-peso-ios';
  static const defaultScheme = 'ph://handa-peso/ios';

  String apiBaseUrl;
  String webBaseUrl;
  String remoteConfigUrl;
  String signatureSecret;
  String encryptKey;
  String encryptIv;

  /// 网关为原生与 H5 路由返回的深链 scheme。
  final String scheme;

  /// 作为公有参数发送的应用市场标识；每个发布包必须保持唯一。
  final String appMarket;

  String appVersion;
  String deviceName;
  String deviceId;
  String osVersion;

  /// 稳定的设备标识（IDFV）。两个设备 ID 公有参数都会发送该值，
  /// 因为网关要求二者一致。
  String get gpsAdId => deviceId;

  SessionStore? _sessionStore;
  AuthExpiredHandler? authExpiredHandler;
  TimestampProvider? timestampProvider;
  RandomDigitsProvider? randomDigitsProvider;

  SessionStore get sessionStore {
    return _sessionStore ??= SessionStore(SharedPreferencesAsync());
  }

  set sessionStore(SessionStore value) {
    _sessionStore = value;
  }
}
