import '../json/json_utils.dart';
import '../network/gateway_reply.dart';

/// 产品详情接口（`/dropcloth/shinning`）里「下一步该补哪一项认证」。
///
/// 载荷的认证项列表 `thurl`（`verify`）是按顺序排的，每项带 `demount`（`taskType`）、
/// `uppropped`（是否已完成）与 `gesticulating`（是否可点击）。这里取第一个
/// 「未完成且可点击」的项——顺序由服务端给，客户端不自己决定该走哪一步。
///
/// 字段名一律取接口文档里登记的不透明键名，改动前必须回查 MyTools 的
/// `ph_handa_peso_ios` 文档。
class ProductNextStep {
  const ProductNextStep({required this.taskType, this.orderNo = ''});

  factory ProductNextStep.fromReply(GatewayReply reply) {
    for (final item in reply.payload.listValue(_verifyField)) {
      final map = item is Map<String, dynamic>
          ? item
          : const <String, dynamic>{};
      if (map.boolValue(_completedField)) continue;
      // `gesticulating` 缺失时按「可点击」处理：不能因为服务端少下发一个字段
      // 就把整条申请链路堵死。
      if (!map.boolValue(_clickableField, fallback: true)) continue;
      final taskType = map.stringValue(_taskTypeField).trim();
      if (taskType.isEmpty) continue;
      return ProductNextStep(
        taskType: taskType,
        orderNo: reply.payload
            .mapOf('recurs')
            .stringValue('redecorates')
            .trim(),
      );
    }
    return ProductNextStep(
      taskType: '',
      orderNo: reply.payload.mapOf('recurs').stringValue('redecorates').trim(),
    );
  }

  /// 文档「值映射 -> 产品详情认证项目列表」登记的六项 `taskType`。
  ///
  /// 每一项都给了明文与混淆两套写法，两套都要认（服务端灰度时会换）。
  static const Map<String, String> _labels = <String, String>{
    'public': _identity,
    'FerrelEstray': _identity,
    'face': _face,
    'DiestocksGynecoid': _face,
    'personal': _personal,
    'CivetsEspousals': _personal,
    'work': _work,
    'Denegation': _work,
    'ext': _ext,
    'CloursConfitures': _ext,
    'bank': _bank,
    'KinesicsSaintliest': _bank,
  };

  static const String _identity = 'Identity verification';
  static const String _face = 'Face verification';
  static const String _personal = 'Personal information';
  static const String _work = 'Work information';
  static const String _ext = 'Emergency contacts';
  static const String _bank = 'Payout account';

  /// 没有可做的下一步。
  static const ProductNextStep absent = ProductNextStep(taskType: '');

  final String taskType;

  /// 产品详情 `recurs.redecorates` 下发的订单号；人脸 token 接口必填。
  final String orderNo;

  /// 下一步是不是证件（第一项）。
  bool get isIdentity => _labels[taskType] == _identity;

  /// 下一步是不是人脸（第二项）。
  bool get isFace => _labels[taskType] == _face;

  /// 这一步在提示里显示的名字；文档里没登记过的取值返回空串（服务端可能加了新步骤）。
  String get label => _labels[taskType] ?? '';

  // 接口文档里的混淆字段，只在这一处出现。
  static const String _verifyField = 'thurl';
  static const String _taskTypeField = 'demount';
  static const String _completedField = 'uppropped';
  static const String _clickableField = 'gesticulating';
}
