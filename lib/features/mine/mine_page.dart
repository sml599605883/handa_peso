import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/navigation/h5_paths.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../core/analytics/analytics_service.dart';
import '../main_shell/main_controller.dart';
import '../orders/order_item.dart';
import 'mine_header_card.dart';
import 'mine_order_entries.dart';
import 'mine_service_section.dart';

/// 个人中心（Mine Tab，设计稿 07-01 - 个人中心-默认）。
///
/// 自上而下三块：头部卡片（脱敏手机号 + 头像）、三个订单入口、Our service 菜单。
/// 整页按 375 设计宽度等比缩放，数值都写设计稿坐标；底色渐变只铺到设计稿的
/// 547 高度，以下留白由页面补白（设计稿里那块 `矩形` 就是这么切的）。
///
/// 手机号取自本地会话——个人中心接口（`/dropcloth/affluents`）按接口文档只下发
/// 签到、待绑卡 / 待还款数量与菜单列表，没有手机号字段。
class MinePage extends GetView<MainController> {
  const MinePage({super.key});

  static const double _designWidth = 375;

  /// 标题（设计稿 20 号字，行盒 30，上沿 58）。
  static const double _titleTop = 58;
  static const double _titleHeight = 30;
  static const double _titleSize = 20;

  /// 头部卡片 / 订单入口 / 服务菜单的上沿（设计稿 98 / 244 / 364）。
  static const double _headerTop = 98;
  static const double _entriesTop = 244;
  static const double _serviceTop = 364;

  /// 订单入口整块高度（图标 66 + 间距 10 + 文案 20）。
  static const double _entriesHeight = 96;

  /// 状态栏比设计稿更高时的兜底间距。
  static const double _safeGap = 8;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final phone = controller.sessionPhone.value;
      return LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / _designWidth;
          double px(num value) => value * scale;

          final safeTop = MediaQuery.paddingOf(context).top / scale;
          final shift = math.max(0, safeTop + _safeGap - _titleTop);

          // 外壳的 Tab 页拿到的是「不紧」的高度约束：Stack 跟着内容收缩时，
          // 页面底部的白色只铺到内容下沿，再往下会露出外层页面的底色。
          // 这里显式撑满视口，让白色一直铺到底部导航栏。
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    key: Key('mine-background'),
                    decoration: BoxDecoration(
                      gradient: AppColors.accountPageGradient,
                    ),
                  ),
                ),
                SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: px(_titleTop + shift)),
                      SizedBox(
                        height: px(_titleHeight),
                        child: Center(
                          child: Text(
                            'Mine',
                            style: TextStyle(
                              color: AppColors.textStrong,
                              fontSize: px(_titleSize),
                              fontWeight: FontWeight.w700,
                              height: _titleHeight / _titleSize,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        height: px(_headerTop - _titleTop - _titleHeight),
                      ),
                      MineHeaderCard(phone: phone, scale: scale),
                      SizedBox(
                        height: px(
                          _entriesTop - _headerTop - MineHeaderCard.height,
                        ),
                      ),
                      MineOrderEntries(scale: scale, onSelect: _openOrders),
                      SizedBox(
                        height: px(_serviceTop - _entriesTop - _entriesHeight),
                      ),
                      MineServiceSection(
                        scale: scale,
                        onCustomerService: () => _openH5(
                          H5Paths.customerService,
                          'Customer service',
                        ),
                        onPrivacy: () =>
                            _openH5(H5Paths.privacyPolicy, 'Privacy'),
                        onAccount: () => Get.toNamed<void>(AppRoutes.account),
                      ),
                      SizedBox(height: px(24)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );
    });
  }

  /// 点订单入口：带上筛选状态打开订单列表。
  void _openOrders(OrderListStatus status) {
    AppNavigator.toOrders(status: status.code);
  }

  /// 打开服务端下发的 H5 页面（客服中心 / 隐私协议）。
  Future<void> _openH5(String path, String title) async {
    try {
      await AppNavigator.openTarget(path, title: title);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      AppNavigator.showError('Unable to open link');
    }
  }
}
