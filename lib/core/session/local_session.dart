import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../product/product_detail_snapshot.dart';

/// 跨冷启动保留的少量会话状态。
///
/// 令牌与 PII 有意排除在外：这里只放不透明的会话 id、已登录手机号、认证完成
/// 标记，以及网关下发的可读设备名。下面这些键名是**已发布数据的契约**——老用户
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
  static const _productFlowCell = 'product.detail.copy';

  /// 退出登录/注销时要抹掉的账号事实；设备名与账号无关，保留。
  ///
  /// 手机号也不在这里：它只用于下次打开登录页时预填，不属于登录态。参考端
  /// `peso_shield` 的 `SessionStore.clear()` 同样只清 token / 用户 id，手机号
  /// 始终保留；清掉它会让用户每次退出后都要重新输入号码。
  static const _accountCells = <String>[
    _sessionIdCell,
    _certifiedCell,
    _identityCardTypeCell,
    _productFlowCell,
  ];

  final SharedPreferencesAsync? _devicePrefs;
  final Map<String, String>? _draft;
  ProductStepCopy _productFlowCopy = const ProductStepCopy();
  String _productFlowOrderNo = '';

  /// 最近一次成功请求产品详情得到的认证页文案。
  ProductStepCopy get productFlowCopy => _productFlowCopy;

  /// 最近一次成功请求产品详情得到的订单号。
  String get productFlowOrderNo => _productFlowOrderNo;

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

  /// 冷启动时恢复产品详情缓存。损坏或旧格式数据直接丢弃。
  Future<void> restoreProductFlow() async {
    try {
      final raw = await _text(_productFlowCell);
      if (raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final data = Map<String, dynamic>.from(decoded);
      final copy = data['copy'];
      _productFlowCopy = copy is Map
          ? ProductStepCopy.fromStorage(Map<String, dynamic>.from(copy))
          : const ProductStepCopy();
      _productFlowOrderNo = data['orderNo']?.toString().trim() ?? '';
    } catch (_) {
      _productFlowCopy = const ProductStepCopy();
      _productFlowOrderNo = '';
    }
  }

  /// 保存最近一次产品详情的认证页文案与订单号。
  ///
  /// 先更新内存，保证详情请求返回后立即打开的页面能同步读到；落盘失败只影响
  /// 下次冷启动，不回滚本次流程。
  Future<void> cacheProductFlow(
    ProductStepCopy copy, {
    required String orderNo,
  }) async {
    _productFlowCopy = copy;
    _productFlowOrderNo = orderNo.trim();
    try {
      await _put(
        _productFlowCell,
        jsonEncode(<String, Object?>{
          'copy': copy.toStorage(),
          'orderNo': _productFlowOrderNo,
        }),
      );
    } catch (_) {
      // 内存缓存仍然有效，本次认证流程不受影响。
    }
  }

  /// 清掉本次账号留下的状态，保留手机号供下次登录预填。
  Future<void> resetSession() async {
    _productFlowCopy = const ProductStepCopy();
    _productFlowOrderNo = '';
    final draft = _draft;
    if (draft != null) {
      for (final cell in _accountCells) {
        draft.remove(cell);
      }
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
