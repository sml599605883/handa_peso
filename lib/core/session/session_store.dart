import 'package:shared_preferences/shared_preferences.dart';

/// Persists the small amount of state that must survive a cold start.
///
/// Tokens and PII are intentionally kept out of this store; only the opaque
/// session id, the signed-in phone number and lightweight UI preferences are
/// written here.
class SessionStore {
  SessionStore(this._preferences) : _memory = null;

  SessionStore.memory() : _preferences = null, _memory = <String, Object?>{};

  static const _sessionIdKey = 'session.id';
  static const _phoneKey = 'session.phone';
  static const _profileCompleteKey = 'session.profile_complete';

  final SharedPreferencesAsync? _preferences;
  final Map<String, Object?>? _memory;

  Future<String> sessionId() async => (await _string(_sessionIdKey)) ?? '';

  Future<void> saveSessionId(String value) => _setString(_sessionIdKey, value);

  Future<String> phone() async => (await _string(_phoneKey)) ?? '';

  Future<void> savePhone(String value) => _setString(_phoneKey, value);

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
