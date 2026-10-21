import '../json/json_utils.dart';
import '../network/gateway_reply.dart';

/// 产品详情里供认证页面复用的内容。
///
/// `azurites` 是接口文档登记的各认证页顶部文案容器；每个页面只认自己的字段，
/// 不能用相邻页面的文案兜底。订单号来自产品信息 `recurs.redecorates`。
class ProductDetailSnapshot {
  const ProductDetailSnapshot({required this.copy, required this.orderNo});

  factory ProductDetailSnapshot.fromReply(GatewayReply reply) {
    final payload = reply.payload;
    return ProductDetailSnapshot(
      copy: ProductStepCopy.fromJson(payload.mapOf(_copyContainer)),
      orderNo: payload.mapOf('recurs').stringValue('redecorates').trim(),
    );
  }

  final ProductStepCopy copy;
  final String orderNo;

  static const _copyContainer = 'azurites';
}

/// 产品详情下发的认证页文案。
///
/// 低版本或未灰度请求可能缺少整个容器或其中某项；缺失项保持空串，由页面使用
/// 自己的设计稿兜底文案。
class ProductStepCopy {
  const ProductStepCopy({
    this.identity = '',
    this.identityConfirmation = '',
    this.liveness = '',
    this.personal = '',
    this.work = '',
    this.emergencyContact = '',
    this.payoutAccount = '',
    this.payoutAccountBottom = '',
  });

  factory ProductStepCopy.fromJson(Map<String, dynamic> json) {
    return ProductStepCopy(
      identity: json.stringValue(identityField).trim(),
      identityConfirmation: json.stringValue(identityConfirmationField).trim(),
      liveness: json.stringValue(livenessField).trim(),
      personal: json.stringValue(personalField).trim(),
      work: json.stringValue(workField).trim(),
      emergencyContact: json.stringValue(emergencyContactField).trim(),
      payoutAccount: json.stringValue(payoutAccountField).trim(),
      payoutAccountBottom: json.stringValue(payoutAccountBottomField).trim(),
    );
  }

  factory ProductStepCopy.fromStorage(Map<String, dynamic> json) {
    String read(String key) => json[key]?.toString().trim() ?? '';
    return ProductStepCopy(
      identity: read(identityField),
      identityConfirmation: read(identityConfirmationField),
      liveness: read(livenessField),
      personal: read(personalField),
      work: read(workField),
      emergencyContact: read(emergencyContactField),
      payoutAccount: read(payoutAccountField),
      payoutAccountBottom: read(payoutAccountBottomField),
    );
  }

  final String identity;
  final String identityConfirmation;
  final String liveness;
  final String personal;
  final String work;
  final String emergencyContact;
  final String payoutAccount;
  final String payoutAccountBottom;

  Map<String, String> toStorage() => <String, String>{
    identityField: identity,
    identityConfirmationField: identityConfirmation,
    livenessField: liveness,
    personalField: personal,
    workField: work,
    emergencyContactField: emergencyContact,
    payoutAccountField: payoutAccount,
    payoutAccountBottomField: payoutAccountBottom,
  };

  static const identityField = 'neuroscientific';
  static const identityConfirmationField = 'diverticula';
  static const livenessField = 'indication';
  static const personalField = 'pinnulate';
  static const workField = 'vervet';
  static const emergencyContactField = 'songfests';
  static const payoutAccountField = 'signor';
  static const payoutAccountBottomField = 'dilatational';
}
