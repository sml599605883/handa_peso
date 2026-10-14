import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_route_observer.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../home/home_page.dart';
import '../mine/mine_page.dart';
import '../orders/orders_page.dart';
import 'main_controller.dart';

class MainShellPage extends GetView<MainController> {
  const MainShellPage({super.key});

  static const _tabs = <_ShellTab>[
    _ShellTab(
      label: 'Home',
      icon: 'assets/tab_home_active.png',
      dimIcon: 'assets/tab_home_inactive.png',
      id: 'home',
    ),
    _ShellTab(
      label: 'Loan',
      icon: 'assets/tab_loan_active.png',
      dimIcon: 'assets/tab_loan_inactive.png',
      id: 'loan',
    ),
    _ShellTab(
      label: 'Mine',
      icon: 'assets/tab_mine_active.png',
      dimIcon: 'assets/tab_mine_inactive.png',
      id: 'mine',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return _RouteReturnListener(
      child: Obx(() {
        final tabIndex = controller.selectedIndex.value;
        return Scaffold(
          body: IndexedStack(
            index: tabIndex,
            children: const [HomePage(), OrdersPage(), MinePage()],
          ),
          bottomNavigationBar: _ShellNavigationBar(
            entries: _tabs,
            activeIndex: tabIndex,
            onSelect: controller.selectTab,
          ),
        );
      }),
    );
  }
}

/// 订阅全局路由观察者：从二级页面返回外壳时，让当前 Tab 重新拉一次数据。
class _RouteReturnListener extends StatefulWidget {
  const _RouteReturnListener({required this.child});

  final Widget child;

  @override
  State<_RouteReturnListener> createState() => _RouteReturnListenerState();
}

class _RouteReturnListenerState extends State<_RouteReturnListener>
    with RouteAware {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void dispose() {
    appRouteObserver.unsubscribe(this);
    super.dispose();
  }

  @override
  void didPopNext() {
    unawaited(Get.find<MainController>().onRouteReturned());
  }

  @override
  void didPushNext() {
    Get.find<MainController>().onRouteLeft();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// 底部 Tab 的静态描述：图标、标题与埋点用的标识。
class _ShellTab {
  const _ShellTab({
    required this.label,
    required this.icon,
    required this.dimIcon,
    required this.id,
  });

  final String label;
  final String icon;
  final String dimIcon;
  final String id;
}

class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({
    required this.entries,
    required this.activeIndex,
    required this.onSelect,
  });

  /// 底部 Home 指示条安全区之上的内容高度（设计稿 block_6）。
  static const double _contentHeight = 56;

  /// Tab 图标取自 90x90 @3x 图切片，按 30dp 渲染。
  static const double _iconSize = 30;

  /// 图标行上方、顶部选中条下方的垂直留白。
  static const double _topPadding = AppSpacing.xs;
  static const double _bottomPadding = 2;

  /// 图标与文字之间的视觉间隙（设计稿使用 2px 偏移）。
  static const double _iconLabelGap = 2;

  /// 位于导航栏最顶部边缘的选中 Tab 指示条。
  static const double _indicatorWidth = 12;
  static const double _indicatorHeight = 2;

  final List<_ShellTab> entries;
  final int activeIndex;
  final ValueChanged<int> onSelect;

  /// 导航栏底板：白色圆角面板。
  static const BoxDecoration _surface = BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
  );

  @override
  Widget build(BuildContext context) {
    final safeBottom = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: _surface,
      child: Padding(
        padding: EdgeInsets.only(bottom: safeBottom),
        child: SizedBox(
          height: _contentHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final slotWidth = constraints.maxWidth / entries.length;
              final indicatorLeft =
                  slotWidth * activeIndex + (slotWidth - _indicatorWidth) / 2;
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: _topPadding,
                      bottom: _bottomPadding,
                    ),
                    child: Row(
                      children: [
                        for (var index = 0; index < entries.length; index++)
                          Expanded(
                            child: InkWell(
                              key: Key('tab-${entries[index].id}'),
                              onTap: () => onSelect(index),
                              child: _TabItem(
                                tab: entries[index],
                                lit: index == activeIndex,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: indicatorLeft,
                    child: Container(
                      width: _indicatorWidth,
                      height: _indicatorHeight,
                      decoration: const BoxDecoration(
                        color: AppColors.tabActive,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(1),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 单个 Tab：图标 + 文案，选中态换色换图。
class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.lit});

  final _ShellTab tab;
  final bool lit;

  static const double _labelSize = 10;
  static const double _labelHeight = 1.4;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          lit ? tab.icon : tab.dimIcon,
          width: _ShellNavigationBar._iconSize,
          height: _ShellNavigationBar._iconSize,
        ),
        const SizedBox(height: _ShellNavigationBar._iconLabelGap),
        Text(
          tab.label,
          style: TextStyle(
            fontSize: _labelSize,
            height: _labelHeight,
            color: lit ? AppColors.tabActive : AppColors.tabInactive,
            fontWeight: lit ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}
