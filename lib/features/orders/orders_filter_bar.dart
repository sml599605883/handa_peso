import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'order_item.dart';

/// 订单列表筛选条（设计稿 05-01 `group_3`）：棕色轨道 + 白色胶囊选中项。
///
/// 设计稿里选中项是「文案 + 左右各 35」的胶囊（`All` 18 宽 + 70 = 88），
/// 未选中项只有文案，四项按 `space-evenly` 分布——按这个规则排出来的位置与
/// 设计稿实测坐标一致（Outstanding 中心 164.5、Overdue 250、Settled 319）。
class OrdersFilterBar extends StatelessWidget {
  const OrdersFilterBar({
    required this.selected,
    required this.onSelect,
    required this.scale,
    super.key,
  });

  static const double width = 347;
  static const double height = 50;
  static const double radius = 14;

  /// 轨道左侧内边距：设计稿把 4 给了左、右侧留白为 0（`padding: 4 20 4 4`
  /// 的右侧留白在实测里并没有体现，标签一直排到轨道右缘）。
  static const double trackLeftInset = 4;

  static const double pillHeight = 42;
  static const double pillRadius = 11;
  static const double pillPaddingX = 35;
  static const double labelSize = 14;

  final OrderListStatus selected;
  final ValueChanged<OrderListStatus> onSelect;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double px(num value) => value * scale;

    // 筛选条的四项按 `spaceEvenly` 分布（设计稿实测坐标就是这么排的）。文案随
    // 语言/字体变长时，整条内容等比缩小而不是溢出——量出自然宽度再决定缩比，
    // 生产字体下缩比是 1，几何与设计稿一致。
    // 量宽必须带上环境里的默认文字样式，否则与真正渲染出来的宽度对不上。
    final baseStyle = DefaultTextStyle.of(context).style;
    final labelStyles = <OrderListStatus, TextStyle>{
      for (final status in OrderListStatus.values)
        status: baseStyle.merge(_labelStyle(status == selected, px)),
    };
    final contentWidth = OrderListStatus.values.fold<double>(0, (sum, status) {
      final width = _textWidth(context, status.label, labelStyles[status]!);
      return sum + width + (status == selected ? px(pillPaddingX) * 2 : 0);
    });
    final available = px(width) - px(trackLeftInset);
    final shrink = contentWidth > available ? available / contentWidth : 1.0;

    return Container(
      width: px(width),
      height: px(height),
      padding: EdgeInsets.only(left: px(trackLeftInset)),
      decoration: BoxDecoration(
        color: AppColors.ordersFilterTrack,
        borderRadius: BorderRadius.circular(px(radius)),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SizedBox(
          width: available / shrink,
          height: px(height),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final status in OrderListStatus.values)
                _buildItem(status, px, labelStyles[status]!),
            ],
          ),
        ),
      ),
    );
  }

  /// 标签样式：选中项加粗、深色，未选中项常规、奶油色。
  TextStyle _labelStyle(bool lit, double Function(num) px) {
    return TextStyle(
      color: lit
          ? AppColors.ordersFilterActiveLabel
          : AppColors.ordersFilterLabel,
      fontSize: px(labelSize),
      fontWeight: lit ? FontWeight.w700 : FontWeight.w400,
      height: 18 / labelSize,
    );
  }

  /// 用与渲染相同的样式量一次文案宽度，误差只来自字体本身。
  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  Widget _buildItem(
    OrderListStatus status,
    double Function(num) px,
    TextStyle style,
  ) {
    final lit = status == selected;
    return GestureDetector(
      key: Key('orders-filter-${status.name}'),
      behavior: HitTestBehavior.opaque,
      onTap: () => onSelect(status),
      child: Container(
        height: px(pillHeight),
        padding: EdgeInsets.symmetric(horizontal: lit ? px(pillPaddingX) : 0),
        alignment: Alignment.center,
        decoration: lit
            ? BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(px(pillRadius)),
              )
            : null,
        child: Text(status.label, maxLines: 1, style: style),
      ),
    );
  }
}
