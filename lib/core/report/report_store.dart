import 'package:shared_preferences/shared_preferences.dart';

/// 上报模块需要跨冷启动保留的少量事实。
///
/// 键名带 `handa_peso.report.` 前缀，与 `LocalSession` 的会话键分开：这里只存
/// 设备维度的上报进度（首开标记、上次登录时间），退出登录时**不清**，否则每次
/// 登录都会把同一台设备重复算成新设备。
///
/// 定位缓存与推送 token 不在这里：前者只在本次进程里兜底，后者由服务端按设备
/// 覆盖，落盘反而会让换 token 后不再更新。
class ReportStore {
  ReportStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences,
      _draft = null;

  /// 不落盘的实现，供单元测试使用。
  ReportStore.memory() : _preferences = null, _draft = <String, Object?>{};

  SharedPreferencesAsync? _preferences;
  final Map<String, Object?>? _draft;

  /// 落盘句柄按需创建：单元测试里只用到内存实现时不必初始化平台通道。
  SharedPreferencesAsync get _prefs =>
      _preferences ??= SharedPreferencesAsync();

  static const _firstOpen = 'handa_peso.report.first_open';
  static const _loginAt = 'handa_peso.report.login_at';

  /// 记下本次启动；返回它是否是本机的第一次启动。
  Future<bool> markLaunched() async {
    final first = !await _bool(_firstOpen);
    await _setBool(_firstOpen, true);
    return first;
  }

  Future<void> saveLoginAt(int millis) => _setInt(_loginAt, millis);

  Future<int> loginAt() => _int(_loginAt);

  Future<int> _int(String key) async {
    final draft = _draft;
    if (draft != null) return draft[key] as int? ?? 0;
    return await _prefs.getInt(key) ?? 0;
  }

  Future<bool> _bool(String key) async {
    final draft = _draft;
    if (draft != null) return draft[key] as bool? ?? false;
    return await _prefs.getBool(key) ?? false;
  }

  Future<void> _setInt(String key, int value) async {
    final draft = _draft;
    if (draft != null) {
      draft[key] = value;
      return;
    }
    await _prefs.setInt(key, value);
  }

  Future<void> _setBool(String key, bool value) async {
    final draft = _draft;
    if (draft != null) {
      draft[key] = value;
      return;
    }
    await _prefs.setBool(key, value);
  }
}
