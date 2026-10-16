import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// 个人中心的「Our service」菜单（设计稿 07-01 `text_9` + `list_1`）。
///
/// 三行固定入口：客服中心、隐私协议、账号（设置页）。行高 52、圆角 8、白底
/// 加 1px 描边，行间距 14；图标与文案间距 6（设计稿实测 58 - 28 - 24 = 6）。
class MineServiceSection extends StatelessWidget {
  const MineServiceSection({
    required this.scale,
    required this.onCustomerService,
    required this.onPrivacy,
    required this.onAccount,
    super.key,
  });

  static const String title = 'Our service';
  static const double width = 347;
  static const double titleHeight = 30;
  static const double titleSize = 20;

  /// 标题与第一行之间的间距（设计稿标题行盒到 394、首行 398）。
  static const double titleGap = 4;
  static const double rowHeight = 52;
  static const double rowRadius = 8;
  static const double rowGap = 14;
  static const double rowPaddingLeft = 14;
  static const double iconSize = 24;
  static const double iconGap = 6;
  static const double labelSize = 16;

  final double scale;
  final VoidCallback onCustomerService;
  final VoidCallback onPrivacy;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    double px(num value) => value * scale;

    final rows = <_ServiceRow>[
      _ServiceRow(
        key: const Key('mine-service-customer-service'),
        asset: 'assets/mine_service_customer_service.png',
        label: 'Customer service',
        onTap: onCustomerService,
      ),
      _ServiceRow(
        key: const Key('mine-service-privacy'),
        asset: 'assets/mine_service_privacy.png',
        label: 'Privacy',
        onTap: onPrivacy,
      ),
      _ServiceRow(
        key: const Key('mine-service-account'),
        asset: 'assets/mine_service_account.png',
        label: 'Account',
        onTap: onAccount,
      ),
    ];

    return SizedBox(
      width: px(width),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: px(titleHeight),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: px(titleSize),
                  fontWeight: FontWeight.w700,
                  height: titleHeight / titleSize,
                ),
              ),
            ),
          ),
          SizedBox(height: px(titleGap)),
          for (var index = 0; index < rows.length; index++) ...[
            _buildRow(rows[index], px),
            if (index != rows.length - 1) SizedBox(height: px(rowGap)),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(_ServiceRow row, double Function(num) px) {
    return GestureDetector(
      key: row.key,
      behavior: HitTestBehavior.opaque,
      onTap: row.onTap,
      child: Container(
        height: px(rowHeight),
        padding: EdgeInsets.symmetric(horizontal: px(rowPaddingLeft)),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(px(rowRadius)),
          border: Border.all(color: AppColors.homeCardBorder, width: px(1)),
        ),
        child: Row(
          children: [
            SizedBox(
              width: px(iconSize),
              height: px(iconSize),
              child: Image(image: AssetImage(row.asset), fit: BoxFit.fill),
            ),
            SizedBox(width: px(iconGap)),
            Expanded(
              child: Text(
                row.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: AppColors.textStrong,
                  fontSize: px(labelSize),
                  height: 20 / labelSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceRow {
  const _ServiceRow({
    required this.key,
    required this.asset,
    required this.label,
    required this.onTap,
  });

  final Key key;
  final String asset;
  final String label;
  final VoidCallback onTap;
}
