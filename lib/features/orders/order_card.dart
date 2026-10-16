import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'order_item.dart';

/// 订单卡片（设计稿 05-01 - 订单列表-有订单）：产品行 + 状态标签 + 分隔线 +
/// 「日期 / 金额」两列 + 主按钮。
///
/// 数值都写设计稿坐标，缩放系数由列表页传入。
class OrderCard extends StatelessWidget {
  const OrderCard({
    required this.item,
    required this.scale,
    this.onTap,
    this.onActionTap,
    super.key,
  });

  static const double width = 347;
  static const double radius = 14;
  static const double paddingLeft = 14;

  /// 卡片描边是 1px 内部描边（设计稿 `border: 1px inside`），因此上下留白各减 1，
  /// 卡片整体高度与设计稿的 158 对齐。
  static const double paddingTop = 8;
  static const double paddingBottom = 13;

  /// 产品行（Logo / 产品名 / 状态标签）。Logo 与产品名顶部再让出 5，
  /// 这样状态标签比它们高 5（设计稿 `矩形` 在产品行顶部 9、Logo 在 14）。
  static const double headerHeight = 31;
  static const double headerInset = 5;
  static const double logoSize = 24;
  static const double logoRadius = 4;
  static const double logoGap = 6;
  static const double productNameSize = 12;

  /// 状态标签（设计稿 94x22，只圆左侧两角，右侧与卡片边缘齐平）。
  static const double statusWidth = 94;
  static const double statusHeight = 22;
  static const double statusLabelSize = 12;

  static const double dividerTopGap = 7;
  static const double dividerInset = 14;
  static const double dataTopGap = 13;
  static const double dataWidth = 313;
  static const double dataLabelSize = 12;
  static const double dataValueSize = 14;
  static const double dataValueGap = 4;

  static const double actionTopGap = 11;
  static const double actionWidth = 188;
  static const double actionHeight = 36;
  static const double actionRadius = 16;
  static const double actionLabelSize = 16;

  final OrderItem item;
  final double scale;

  /// 卡片点击：进订单详情。
  final VoidCallback? onTap;

  /// 主按钮点击：进还款页。
  final VoidCallback? onActionTap;

  @override
  Widget build(BuildContext context) {
    double px(num value) => value * scale;
    final divider = px(1);

    return GestureDetector(
      key: Key('order-card-${item.orderNo}'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: px(width),
        padding: EdgeInsets.only(
          left: px(paddingLeft),
          top: px(paddingTop),
          bottom: px(paddingBottom),
        ),
        decoration: BoxDecoration(
          color: AppColors.ordersCardSurface,
          borderRadius: BorderRadius.circular(px(radius)),
          border: Border.all(color: AppColors.ordersCardBorder, width: divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: px(headerHeight), child: _buildHeader(px)),
            SizedBox(height: px(dividerTopGap)),
            Padding(
              padding: EdgeInsets.only(right: px(dividerInset)),
              child: SizedBox(
                height: divider,
                child: const ColoredBox(color: AppColors.ordersCardDivider),
              ),
            ),
            SizedBox(height: px(dataTopGap)),
            Center(child: _buildDataColumns(px)),
            if (item.hasAction) ...[
              SizedBox(height: px(actionTopGap)),
              Center(child: _buildAction(px)),
            ],
          ],
        ),
      ),
    );
  }

  /// 产品行：Logo + 产品名 + 右上角状态标签。
  Widget _buildHeader(double Function(num) px) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: px(headerInset)),
          child: _buildLogo(px),
        ),
        SizedBox(width: px(logoGap)),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: px(headerInset)),
            child: Text(
              item.productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.textStrong,
                fontSize: px(productNameSize),
                height: 14 / productNameSize,
              ),
            ),
          ),
        ),
        _buildStatusTag(px),
      ],
    );
  }

  /// 产品 Logo：服务端下发地址时用网络图，缺失或加载失败回落到设计稿的灰方块。
  Widget _buildLogo(double Function(num) px) {
    final placeholder = Container(
      width: px(logoSize),
      height: px(logoSize),
      decoration: BoxDecoration(
        color: AppColors.ordersLogoSurface,
        borderRadius: BorderRadius.circular(px(logoRadius)),
        border: Border.all(color: AppColors.ordersLogoBorder, width: px(1)),
      ),
    );
    final url = item.productLogo.trim();
    if (url.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(px(logoRadius)),
      child: Image.network(
        url,
        width: px(logoSize),
        height: px(logoSize),
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }

  /// 状态标签：设计稿里红橙渐变只圆左侧两角，右边缘与卡片边缘齐平。
  Widget _buildStatusTag(double Function(num) px) {
    final danger = item.statusTone == OrderStatusTone.danger;
    return Container(
      width: px(statusWidth),
      height: px(statusHeight),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: danger ? null : AppColors.ordersStatusNeutralSurface,
        gradient: danger ? AppColors.ordersStatusDangerGradient : null,
        borderRadius: BorderRadius.horizontal(left: Radius.circular(px(100))),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: px(4)),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            item.statusText,
            maxLines: 1,
            style: TextStyle(
              color: danger
                  ? AppColors.textOnPrimary
                  : AppColors.ordersStatusNeutralLabel,
              fontSize: px(statusLabelSize),
              height: 18 / statusLabelSize,
            ),
          ),
        ),
      ),
    );
  }

  /// 日期与金额两列：与页面中线各偏移 78.25（设计稿两列中心 109.25 / 265.75）。
  Widget _buildDataColumns(double Function(num) px) {
    return SizedBox(
      width: px(dataWidth),
      child: Row(
        children: [
          Expanded(child: _buildDataColumn(px, item.dateLabel, item.dateValue)),
          Expanded(
            child: _buildDataColumn(px, item.amountLabel, item.amountText),
          ),
        ],
      ),
    );
  }

  Widget _buildDataColumn(double Function(num) px, String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textSecondary,
            fontSize: px(dataLabelSize),
            height: 14 / dataLabelSize,
          ),
        ),
        SizedBox(height: px(dataValueGap)),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textStrong,
            fontSize: px(dataValueSize),
            fontWeight: FontWeight.w700,
            height: 18 / dataValueSize,
          ),
        ),
      ],
    );
  }

  /// 主按钮：暖橙渐变、两角全圆（设计稿 188x36，圆角 16）。
  Widget _buildAction(double Function(num) px) {
    return GestureDetector(
      key: Key('order-action-${item.orderNo}'),
      behavior: HitTestBehavior.opaque,
      onTap: onActionTap,
      child: Container(
        width: px(actionWidth),
        height: px(actionHeight),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.ordersActionGradient,
          borderRadius: BorderRadius.circular(px(actionRadius)),
        ),
        child: Text(
          item.actionText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: px(actionLabelSize),
            height: 20 / actionLabelSize,
          ),
        ),
      ),
    );
  }
}
