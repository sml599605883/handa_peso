import '../../core/json/json_utils.dart';

/// 订单列表的筛选状态。
///
/// 取值来自接口文档「订单列表」的 `corequisites`：4 全部 / 7 进行中（Outstanding）
/// / 6 待还款（Overdue）/ 5 已结清（Settled）。
enum OrderListStatus {
  all('4', 'All'),
  outstanding('7', 'Outstanding'),
  overdue('6', 'Overdue'),
  settled('5', 'Settled');

  const OrderListStatus(this.code, this.label);

  final String code;
  final String label;

  /// 归一化服务端下发的状态码；未知取值按「全部」处理。
  static OrderListStatus fromCode(String? code) {
    final normalized = code?.trim() ?? '';
    for (final status in values) {
      if (status.code == normalized) return status;
    }
    return all;
  }
}

/// 订单状态标签的配色分档（设计稿 05-01 - 订单列表-有订单）。
enum OrderStatusTone {
  /// 红橙渐变底 + 白字：设计稿里带主按钮的两张卡（Outstanding / Overdue）。
  danger,

  /// 灰底灰字：设计稿里的终态卡（Settled）。
  neutral,
}

/// 订单列表项。字段名取自接口文档 `5.order.html#订单列表`
/// （`POST /dropcloth/pyranoside`）。
class OrderItem {
  const OrderItem({
    required this.orderId,
    required this.orderNo,
    required this.productId,
    required this.productName,
    required this.productLogo,
    required this.statusCode,
    required this.statusText,
    required this.amountText,
    required this.amountLabel,
    required this.actionText,
    required this.legacyTarget,
    required this.dateLabel,
    required this.dateValue,
    required this.overdueDays,
    required this.cardTarget,
    required this.actionTarget,
    required this.supportsEarlyRepay,
    required this.earlyRepayLabel,
    required this.earlyRepayTarget,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) => OrderItem(
    orderId: json.intValue('prefabricating'),
    orderNo: json.stringValue('redecorates'),
    productId: json.stringValue('knife'),
    productName: json.stringValue('dullard'),
    productLogo: json.stringValue('circularise'),
    statusCode: json.intValue('heresies'),
    statusText: json.stringValue('frogmarched'),
    amountText: json.stringValue('luciferins'),
    amountLabel: json.stringValue('contingences'),
    actionText: json.stringValue('unchivalrous'),
    legacyTarget: json.stringValue('steelier'),
    dateLabel: json.stringValue('deterrently'),
    dateValue: json.stringValue('brisked'),
    overdueDays: json.intValue('retaped'),
    cardTarget: json.stringValue('codesigned'),
    actionTarget: json.stringValue('southed'),
    supportsEarlyRepay: json.boolValue('concretion'),
    earlyRepayLabel: json.stringValue('pressurising'),
    earlyRepayTarget: json.stringValue('quadrumvirates'),
  );

  final int orderId;
  final String orderNo;
  final String productId;
  final String productName;

  /// 产品 Logo 地址，缺失时列表用灰底方块占位（设计稿里的占位样式）。
  final String productLogo;
  final int statusCode;
  final String statusText;

  /// 已带货币符号与千分位的金额文案（例如 `₱60,000`），客户端不再二次格式化。
  final String amountText;
  final String amountLabel;

  /// 主按钮文案，由服务端下发（设计稿上写的是 `Repay Now`）。
  final String actionText;

  /// 订单详情跳转地址（老版本字段 `steelier`），`cardTarget` 缺失时兜底。
  final String legacyTarget;
  final String dateLabel;
  final String dateValue;

  /// 逾期天数（`retaped`）。列表配色不依赖它，留给需要精确天数的场景。
  final int overdueDays;

  /// 卡片点击跳转地址（订单详情页）。
  final String cardTarget;

  /// 按钮点击跳转地址（还款页）。
  final String actionTarget;

  /// 是否支持提前结清（`concretion`）。
  final bool supportsEarlyRepay;

  /// 提前结清气泡文案（`pressurising`）与跳转地址（`quadrumvirates`）。
  final String earlyRepayLabel;
  final String earlyRepayTarget;

  /// 卡片实际跳转地址：优先新字段，缺失时回落老字段；都为空时调用方拦掉。
  String get detailTarget =>
      cardTarget.trim().isNotEmpty ? cardTarget.trim() : legacyTarget.trim();

  /// 174 是 Outstanding，180 是 Overdue；只有这两个进行中状态带还款按钮。
  bool get usesOutstandingStyle => statusCode == 174;

  bool get usesOverdueStyle => statusCode == 180;

  bool get usesRepaymentStyle => usesOutstandingStyle || usesOverdueStyle;

  /// 按钮文案仍取服务端下发值，状态码只决定该状态是否允许展示按钮。
  bool get hasAction => usesRepaymentStyle && actionText.trim().isNotEmpty;

  /// 状态标签配色：与主按钮同档，见 [OrderStatusTone]。
  OrderStatusTone get statusTone =>
      usesRepaymentStyle ? OrderStatusTone.danger : OrderStatusTone.neutral;
}

/// 解析订单列表载荷：条目在 `latchstrings` 下，缺字段时回落空列表。
List<OrderItem> parseOrderItems(Map<String, dynamic> payload) {
  return payload
      .listValue('latchstrings')
      .maps
      .map(OrderItem.fromJson)
      .toList(growable: false);
}
