import 'package:shared_preferences/shared_preferences.dart';

/// 持久化少量必须跨冷启动保留的状态。
///
/// 令牌和 PII 被有意排除在该存储之外；这里只写入不透明的会话 id、
/// 已登录的手机号以及轻量级的 UI 偏好设置。
class SessionStore {
  SessionStore(this._preferences) : _memory = null;

  SessionStore.memory() : _preferences = null, _memory = <String, Object?>{};

  static const _sessionIdKey = 'session.id';
  static const _phoneKey = 'session.phone';
  static const _profileCompleteKey = 'session.profile_complete';
  static const _deviceNameKey = 'device.name';

  final SharedPreferencesAsync? _preferences;
  final Map<String, Object?>? _memory;

  Future<String> sessionId() async => (await _string(_sessionIdKey)) ?? '';

  Future<void> saveSessionId(String value) => _setString(_sessionIdKey, value);

  Future<String> phone() async => (await _string(_phoneKey)) ?? '';

  Future<void> savePhone(String value) => _setString(_phoneKey, value);

  /// 从网关解析得到的可读设备名称（公有参数）。
  Future<String> deviceName() async => (await _string(_deviceNameKey)) ?? '';

  Future<void> saveDeviceName(String value) =>
      _setString(_deviceNameKey, value);

  Future<bool> profileComplete() async => (await _string(_profileCompleteKey)) == '1';

  Future<void> saveProfileComplete(bool value) =>
      _setString(_profileCompleteKey, value ? '1' : '0');

  Future<void> clear() async {
    final memory = _memory;
    if (memory != null) {
      memory.clear();
      return;
    }
    final prefs = _preferences!;
    await prefs.remove(_sessionIdKey);
    await prefs.remove(_phoneKey);
    await prefs.remove(_profileCompleteKey);
  }

  Future<String?> _string(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key] as String?;
    return _preferences!.getString(key);
  }

  Future<void> _setString(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    await _preferences!.setString(key, value);
  }
}
