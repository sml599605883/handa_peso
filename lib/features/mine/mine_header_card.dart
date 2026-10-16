import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// 个人中心头部卡片（设计稿 07-01 `矩形` 347x126）：暖橙渐变卡 + 2px 白描边，
/// 左侧是脱敏手机号与「User ID：」，右侧是头像。
class MineHeaderCard extends StatelessWidget {
  const MineHeaderCard({required this.phone, required this.scale, super.key});

  static const double width = 347;
  static const double height = 126;
  static const double radius = 24;
  static const double borderWidth = 2;
  static const double paddingH = 24;
  static const double paddingV = 20;

  /// 头像（设计稿 `蒙版` 86x86，圆角 43）。
  static const double avatarSize = 86;
  static const String avatarAsset = 'assets/mine_profile_avatar.png';

  /// 文案块相对内容区再让出 14（设计稿 `text-group_1` 的上下外边距）。
  static const double textInset = 14;
  static const double phoneSize = 24;
  static const double userIdSize = 16;
  static const double userIdGap = 10;

  /// 「User ID：」标签：设计稿里这一行的取值是空的，当前版本也没有可用的
  /// 用户 ID 数据源，因此先只画标签，取值留白与设计稿一致。
  static const String userIdLabel = 'User ID：';

  final String phone;
  final double scale;

  @override
  Widget build(BuildContext context) {
    double px(num value) => value * scale;

    return Container(
      width: px(width),
      height: px(height),
      padding: EdgeInsets.symmetric(
        horizontal: px(paddingH),
        vertical: px(paddingV),
      ),
      decoration: BoxDecoration(
        gradient: AppColors.accountWarmGradient,
        borderRadius: BorderRadius.circular(px(radius)),
        border: Border.all(color: AppColors.surface, width: px(borderWidth)),
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: px(textInset),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  maskPhone(phone),
                  key: const Key('mine-phone'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: px(phoneSize),
                    fontWeight: FontWeight.w500,
                    height: 28 / phoneSize,
                  ),
                ),
                SizedBox(height: px(userIdGap)),
                Text(
                  userIdLabel,
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: px(userIdSize),
                    height: 20 / userIdSize,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            width: px(avatarSize),
            height: px(avatarSize),
            child: const Image(
              key: Key('mine-avatar'),
              image: AssetImage(avatarAsset),
              fit: BoxFit.fill,
            ),
          ),
        ],
      ),
    );
  }
}

/// 手机号脱敏：保留前 3 位与后 4 位（设计稿 `962****1210`）。
///
/// 位数不足的号码原样返回，不做截断，避免把残缺号码显示成「已脱敏」的样子。
String maskPhone(String phone) {
  final value = phone.trim();
  if (value.length <= 7) return value;
  return '${value.substring(0, 3)}****${value.substring(value.length - 4)}';
}
