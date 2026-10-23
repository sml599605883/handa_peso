import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/layout/responsive_layout.dart';
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
/// 页面按 iPhone 实际宽度组织纵向内容，卡片保持设计比例；底部通过安全区留白，
/// 避免内容贴到 Home Indicator。
///
/// 手机号取自本地会话——个人中心接口（`/dropcloth/affluents`）按接口文档只下发
/// 签到、待绑卡 / 待还款数量与菜单列表，没有手机号字段。
class MinePage extends GetView<MainController> {
  const MinePage({super.key});

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

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final phone = controller.sessionPhone.value;
      return LayoutBuilder(
        builder: (context, constraints) {
          final metrics = AppResponsiveMetrics(
            screenWidth: constraints.maxWidth,
            safeTop: MediaQuery.paddingOf(context).top,
            safeBottom: MediaQuery.paddingOf(context).bottom,
          );
          final scale = metrics.scale;
          double px(num value) => value * scale;
          final shift = metrics.headerShift;

          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: DecoratedBox(
              key: const Key('mine-background'),
              decoration: const BoxDecoration(
                gradient: AppColors.accountPageGradient,
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: metrics.safeBottom + px(24)),
                child: Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: constraints.maxWidth,
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
                          height: px(
                            _serviceTop - _entriesTop - _entriesHeight,
                          ),
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
                ),
              ),
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
