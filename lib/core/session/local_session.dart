import 'package:shared_preferences/shared_preferences.dart';

/// 跨冷启动保留的少量会话状态。
///
/// 令牌与 PII 有意排除在外：这里只放不透明的会话 id、已登录手机号、认证完成
/// 标记，以及网关下发的可读设备名。下面四个键名是**已发布数据的契约**——老用户
/// 设备上已经按这些字符串写过值，改键名等于让他们掉登录，所以只允许改 Dart 侧
/// 的名字。
class LocalSession {
  LocalSession(SharedPreferencesAsync devicePrefs)
    : _devicePrefs = devicePrefs,
      _draft = null;

  /// 不落盘的实现，供单元测试使用。
  LocalSession.memory() : _devicePrefs = null, _draft = <String, String>{};

  static const _sessionIdCell = 'session.id';
  static const _phoneCell = 'session.phone';
  static const _certifiedCell = 'session.profile_complete';
  static const _identityCardTypeCell = 'session.identity_card_type';
  static const _deviceLabelCell = 'device.name';

  /// 退出登录/注销时要抹掉的账号事实；设备名与账号无关，保留。
  static const _accountCells = <String>[
    _sessionIdCell,
    _phoneCell,
    _certifiedCell,
    _identityCardTypeCell,
  ];

  final SharedPreferencesAsync? _devicePrefs;
  final Map<String, String>? _draft;

  Future<String> readSessionId() => _text(_sessionIdCell);

  Future<void> writeSessionId(String value) => _put(_sessionIdCell, value);

  Future<String> readPhone() => _text(_phoneCell);

  Future<void> writePhone(String value) => _put(_phoneCell, value);

  /// 网关按硬件标识解析出来的可读设备名（公有参数 `especially`）。
  Future<String> readDeviceLabel() => _text(_deviceLabelCell);

  Future<void> writeDeviceLabel(String value) => _put(_deviceLabelCell, value);

  /// 认证资料是否已提交完成；落库形态是 `'1'` / `'0'`。
  Future<bool> readCertified() async => await _text(_certifiedCell) == '1';

  Future<void> writeCertified(bool value) =>
      _put(_certifiedCell, value ? '1' : '0');

  /// 证件流程选中的卡种；人脸上传接口的必填字段 `scarriest` 从这里取。
  Future<String> readIdentityCardType() => _text(_identityCardTypeCell);

  Future<void> writeIdentityCardType(String value) =>
      _put(_identityCardTypeCell, value);

  /// 清掉本次账号留下的状态。
  Future<void> resetSession() async {
    final draft = _draft;
    if (draft != null) {
      draft.clear();
      return;
    }
    for (final cell in _accountCells) {
      await _devicePrefs!.remove(cell);
    }
  }

  Future<String> _text(String cell) async {
    final draft = _draft;
    if (draft != null) return draft[cell] ?? '';
    final prefs = _devicePrefs;
    if (prefs == null) return '';
    return await prefs.getString(cell) ?? '';
  }

  Future<void> _put(String cell, String value) async {
    final draft = _draft;
    if (draft != null) {
      draft[cell] = value;
      return;
    }
    await _devicePrefs!.setString(cell, value);
  }
}
