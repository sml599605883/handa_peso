import '../network/gateway_client.dart';
import '../network/gateway_reply.dart';
import 'product_detail_snapshot.dart';

/// 拉取产品详情，并把认证页文案与订单号写入会话缓存。
///
/// 只有接口业务成功才覆盖缓存；请求或业务失败时保留旧值，页面仍可使用上次的
/// 可用文案。缓存写入失败不能反过来阻断产品申请流程。
abstract final class ProductDetailLoader {
  static Future<GatewayReply> load(
    GatewayClient client, {
    required String productId,
  }) async {
    final reply = await client.fetchProductDetail(productId: productId);
    reply.orThrow();
    final snapshot = ProductDetailSnapshot.fromReply(reply);
    await client.settings.localSession.cacheProductFlow(
      snapshot.copy,
      orderNo: snapshot.orderNo,
    );
    return reply;
  }
}
