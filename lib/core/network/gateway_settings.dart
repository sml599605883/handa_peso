import 'package:shared_preferences/shared_preferences.dart';

import '../session/local_session.dart';

/// 会话失效时执行的动作（交给导航层跳到登录页）。
typedef SessionExpiredCallback = Future<void> Function();

/// 毫秒时间戳来源；留空时使用系统时钟。
typedef EpochMillisProvider = int Function();

/// 干扰字段的数字来源；留空时使用安全随机数。
typedef NoiseDigitsProvider = String Function(int length);

/// 网关客户端的运行时配置。
///
/// 签名密钥、渠道标识与上报加密密钥都是 Handa Peso 专属的，全部可以在构建期
/// 用 `--dart-define`（`API_BASE_URL`、`API_SIGN_SECRET`、`API_AES_KEY`……）
/// 覆盖，不需要改源码。API 域名默认使用后端提供的环境，也支持服务端下发的
/// 运行时换址。
class GatewaySettings {
  GatewaySettings({
    this.apiOrigin = fallbackApiOrigin,
    this.webOrigin = fallbackWebOrigin,
    this.spareSourceUrl = fallbackSpareSourceUrl,
    this.signSecret = fallbackSignSecret,
    this.cipherSecret = fallbackCipherSecret,
    this.cipherVector = fallbackCipherVector,
    this.marketTag = defaultMarketTag,
    this.deepLinkScheme = defaultDeepLinkScheme,
    this.appVersion = '',
    this.deviceLabel = '',
    this.deviceId = '',
    this.systemVersion = '',
    LocalSession? localSession,
    this.onSessionExpired,
    this.clock,
    this.noiseDigits,
  }) {
    _localSession = localSession;
  }

  static const fallbackApiOrigin = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://8.220.176.2/deliv',
  );
  static const fallbackWebOrigin = String.fromEnvironment(
    'WEB_BASE_URL',
    defaultValue: 'http://8.220.176.2',
  );
  static const fallbackSpareSourceUrl = String.fromEnvironment(
    'API_REMOTE_CONFIG_URL',
  );
  static const fallbackSignSecret = String.fromEnvironment(
    'API_SIGN_SECRET',
    defaultValue: '713b788c33c51fb72eaab884289c8d30',
  );
  static const fallbackCipherSecret = String.fromEnvironment(
    'API_AES_KEY',
    defaultValue: 'bb0f14fd3d820b45',
  );
  static const fallbackCipherVector = String.fromEnvironment(
    'API_AES_IV',
    defaultValue: 'a61df01c554a27a0',
  );
  static const defaultMarketTag = 'appstore-ph-handa-peso-ios';
  static const defaultDeepLinkScheme = 'ph://handa-peso/ios';

  String apiOrigin;
  String webOrigin;
  String spareSourceUrl;
  String signSecret;
  String cipherSecret;
  String cipherVector;

  /// 网关为原生与 H5 路由下发的深链 scheme。
  final String deepLinkScheme;

  /// 作为公有参数发送的渠道标识；每个发布包必须保持唯一。
  final String marketTag;

  String appVersion;
  String deviceLabel;
  String deviceId;
  String systemVersion;

  /// 稳定的设备标识（IDFV）：`corkscrewed` 与 `parcener` 两个公有参数都发送
  /// 这个值，因为网关要求二者一致。
  String get pairedDeviceId => deviceId;

  LocalSession? _localSession;
  SessionExpiredCallback? onSessionExpired;
  EpochMillisProvider? clock;
  NoiseDigitsProvider? noiseDigits;

  LocalSession get localSession {
    return _localSession ??= LocalSession(SharedPreferencesAsync());
  }

  set localSession(LocalSession value) {
    _localSession = value;
  }
}
