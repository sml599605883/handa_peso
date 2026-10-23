import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/layout/responsive_layout.dart';
import '../../app/theme/app_colors.dart';
import '../../app/widgets/app_empty_state.dart';
import '../home/customer_service_shortcut.dart';
import '../main_shell/main_controller.dart';
import 'loan_progress_card.dart';
import 'loan_progress_item.dart';

/// 「Loan Progress」：Loan Tab 的借款进度列表（设计稿 02- 贷款-订单进度）。
///
/// 数据与首页信息流同源（`PROCESS_LIST` 模块），所以刷新时机交给
/// [MainController] 统一调度：切到本 Tab、回到前台、从二级页面返回时才请求。
/// 页面本身只负责三种状态（加载 / 失败 / 空）与卡片列表。
class LoanProgressPage extends GetView<MainController> {
  const LoanProgressPage({super.key});

  /// 标题上沿与行高（设计稿：20 号字、30 的行盒）。
  static const double _titleTop = 53;
  static const double _titleHeight = 30;

  /// 列表视口上沿：首张卡片本体落在设计稿的 102，徽标给它留出 6 的悬挑。
  static const double _listTop = _cardTop - _badgeOverhang;
  static const double _cardTop = 102;
  static const double _badgeOverhang = 6;

  /// 卡片间距（设计稿 20）：上方 6 给徽标，下方 14 收尾。
  static const double _cardGap = 20;
  static const double _listBottom = 24;

  /// 顶部点阵装饰（设计稿 375x296）。
  static const double _dotsHeight = 296;

  /// 无订单时的 Apply Now 按钮（设计稿 220x40 @ y=398）。
  static const double _emptyButtonTop = 398;
  static const double _emptyButtonWidth = 220;
  static const double _emptyButtonHeight = 40;
  static const double _emptyButtonRadius = 28;
  static const double _emptyButtonBottom = 48;

  /// 按钮上方的纸飞机插画（设计稿导出的 200x200 切片 `block_1`）：水平居中，
  /// 与按钮之间留 24，因此上沿落在设计稿的 174。
  static const String _emptyIllustration =
      'assets/loan_progress_empty_illustration.png';
  static const double _emptyIllustrationSize = 200;
  static const double _emptyIllustrationGap = 24;
  static const double _emptyIllustrationTop =
      _emptyButtonTop - _emptyIllustrationGap - _emptyIllustrationSize;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      // 先把 Rx 值取出来：`LayoutBuilder` 的 builder 在 layout 阶段执行，那里
      // 再读可观察量不会被 GetX 记进依赖，页面就不会跟着数据刷新。
      final data = controller.overviewData.value;
      final items = data?.progressItems ?? const <LoanProgressItem>[];
      final error = controller.overviewError.value;
      final loading = controller.overviewLoading.value;

      return LayoutBuilder(
        builder: (context, constraints) {
          final metrics = AppResponsiveMetrics(
            screenWidth: constraints.maxWidth,
            safeTop: MediaQuery.paddingOf(context).top,
            safeBottom: MediaQuery.paddingOf(context).bottom,
          );
          final scale = metrics.scale;
          double px(num value) => value * scale;

          // 安全区比设计稿的状态栏更高时，标题整体下移，避免压到刘海。
          final titleTop = math.max(_titleTop, metrics.safeTop / scale + 8);
          final listTop = math.max(titleTop + _titleHeight, _listTop);

          return Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                width: constraints.maxWidth,
                height: px(_dotsHeight),
                child: const IgnorePointer(
                  child: Image(
                    image: AssetImage('assets/loan_progress_header_dots.png'),
                    fit: BoxFit.fill,
                  ),
                ),
              ),
              Positioned(
                top: px(titleTop - 1),
                right: px(20),
                child: CustomerServiceShortcut(
                  buttonKey: const Key('loan-customer-service'),
                  onTap: controller.openCustomerService,
                ),
              ),
              Column(
                children: [
                  SizedBox(height: px(titleTop)),
                  SizedBox(
                    height: px(_titleHeight),
                    child: Center(
                      child: Text(
                        'Loan Progress',
                        style: TextStyle(
                          color: AppColors.progressValueText,
                          fontSize: 20 * scale,
                          fontWeight: FontWeight.w700,
                          height: _titleHeight / 20,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    height: px(math.max(0, listTop - titleTop - _titleHeight)),
                  ),
                  Expanded(
                    child: _ProgressBody(
                      items: items,
                      loading: loading && items.isEmpty,
                      error: items.isEmpty ? error : null,
                      scale: scale,
                      listTop: listTop,
                      onRefresh: controller.refreshProgress,
                      onCardTap: controller.openLoanProgress,
                      onActionTap: controller.tapLoanProgressAction,
                      onApply: () => controller.switchTab(0),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      );
    });
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({
    required this.items,
    required this.loading,
    required this.error,
    required this.scale,
    required this.listTop,
    required this.onRefresh,
    required this.onCardTap,
    required this.onActionTap,
    required this.onApply,
  });

  final List<LoanProgressItem> items;
  final bool loading;
  final String? error;
  final double scale;
  final double listTop;
  final Future<void> Function() onRefresh;
  final void Function(LoanProgressItem item) onCardTap;
  final void Function(LoanProgressItem item, LoanProgressAction action)
  onActionTap;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final message = error;
    if (message != null) {
      return AppEmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'We could not load your loans',
        description: message,
        action: FilledButton(
          key: const Key('loan-progress-retry'),
          onPressed: () => onRefresh(),
          child: const Text('Try again'),
        ),
      );
    }

    if (items.isEmpty) {
      return _EmptyProgress(scale: scale, listTop: listTop, onApply: onApply);
    }

    final gap = LoanProgressPage._cardGap * scale;
    final overhang = LoanProgressPage._badgeOverhang * scale;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.only(bottom: LoanProgressPage._listBottom * scale),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return Padding(
            // 上方留出徽标向上的悬挑，下方补齐设计稿的 20 间距。
            padding: EdgeInsets.only(top: overhang, bottom: gap - overhang),
            child: Center(
              child: LoanProgressCard(
                key: ValueKey<String>('loan-progress-${item.orderNo}'),
                item: item,
                scale: scale,
                onTap: () => onCardTap(item),
                onActionTap: (action) => onActionTap(item, action),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// 无订单（设计稿 02- 贷款-订单进度-无订单）：纸飞机插画 + Apply Now 按钮。
class _EmptyProgress extends StatelessWidget {
  const _EmptyProgress({
    required this.scale,
    required this.listTop,
    required this.onApply,
  });

  final double scale;
  final double listTop;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    double px(num value) => value * scale;

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          SizedBox(
            height: px(
              math.max(0, LoanProgressPage._emptyIllustrationTop - listTop),
            ),
          ),
          SizedBox(
            width: px(LoanProgressPage._emptyIllustrationSize),
            height: px(LoanProgressPage._emptyIllustrationSize),
            child: const Image(
              key: Key('loan-progress-empty-illustration'),
              image: AssetImage(LoanProgressPage._emptyIllustration),
              fit: BoxFit.fill,
            ),
          ),
          SizedBox(height: px(LoanProgressPage._emptyIllustrationGap)),
          _ApplyNowButton(scale: scale, onTap: onApply),
          SizedBox(height: px(LoanProgressPage._emptyButtonBottom)),
        ],
      ),
    );
  }
}

/// 主按钮：暖橙渐变 + 两角圆角（设计稿 220x40，圆角 28）。
class _ApplyNowButton extends StatelessWidget {
  const _ApplyNowButton({required this.scale, required this.onTap});

  final double scale;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = Radius.circular(LoanProgressPage._emptyButtonRadius * scale);
    return GestureDetector(
      key: const Key('loan-progress-apply'),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: LoanProgressPage._emptyButtonWidth * scale,
        height: LoanProgressPage._emptyButtonHeight * scale,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          gradient: AppColors.progressPrimaryGradient,
          borderRadius: BorderRadius.only(topRight: radius, bottomLeft: radius),
        ),
        child: Text(
          'Apply Now',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w400,
            height: 20 / 16,
          ),
        ),
      ),
    );
  }
}
