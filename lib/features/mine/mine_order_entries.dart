import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../orders/order_item.dart';

/// 个人中心的三个订单入口（设计稿 07-01 `box_6`）：All / Outstanding / Settled。
///
/// 三列等宽居中，点任意一列都打开订单列表，并带上对应的筛选状态。设计稿没有
/// Overdue 入口，筛选条里仍然有它。
class MineOrderEntries extends StatelessWidget {
  const MineOrderEntries({
    required this.scale,
    required this.onSelect,
    super.key,
  });

  /// 设计稿切片是 66x66，文案与图标间距 10、行高 20。
  static const double iconSize = 66;
  static const double labelGap = 10;
  static const double labelSize = 16;
  static const double labelHeight = 20;

  static const List<_OrderEntry> _entries = <_OrderEntry>[
    _OrderEntry(
      status: OrderListStatus.all,
      asset: 'assets/mine_order_all.png',
    ),
    _OrderEntry(
      status: OrderListStatus.outstanding,
      asset: 'assets/mine_order_outstanding.png',
    ),
    _OrderEntry(
      status: OrderListStatus.settled,
      asset: 'assets/mine_order_settled.png',
    ),
  ];

  final double scale;
  final ValueChanged<OrderListStatus> onSelect;

  @override
  Widget build(BuildContext context) {
    double px(num value) => value * scale;

    return Row(
      children: [
        for (final entry in _entries)
          Expanded(
            child: GestureDetector(
              key: Key('mine-order-entry-${entry.status.name}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(entry.status),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: px(iconSize),
                    height: px(iconSize),
                    child: Image(
                      image: AssetImage(entry.asset),
                      fit: BoxFit.fill,
                    ),
                  ),
                  SizedBox(height: px(labelGap)),
                  Text(
                    entry.status.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.accountEntryLabel,
                      fontSize: px(labelSize),
                      height: labelHeight / labelSize,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _OrderEntry {
  const _OrderEntry({required this.status, required this.asset});

  final OrderListStatus status;
  final String asset;
}
