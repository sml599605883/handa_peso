import 'package:shared_preferences/shared_preferences.dart';

import '../session/session_store.dart';

typedef AuthExpiredHandler = Future<void> Function();
typedef TimestampProvider = int Function();
typedef RandomDigitsProvider = String Function(int length);

/// Runtime configuration for the API client.
///
/// The gateway signs every request with an app-scoped secret and obfuscated
/// public parameters, so the market string, signing secret and reporting AES
/// keys are all specific to Handa Peso. Override any of them at build time with
/// `--dart-define` (e.g. `API_SIGN_SECRET=...`, `API_BASE_URL=...`) without
/// touching source.
///
/// Hosts default to the environment provided by the backend and can be
/// overridden per build; the app also supports a runtime domain switch driven
/// by the server.
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

  /// Deep-link scheme the gateway returns for native and H5 routes.
  final String scheme;

  /// App-store market string sent as a public parameter; must stay unique per
  /// shipping binary.
  final String appMarket;

  String appVersion;
  String deviceName;
  String deviceId;
  String osVersion;

  /// Stable device identifier (IDFV). Sent for both device-id public
  /// parameters because the gateway expects them to match.
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
