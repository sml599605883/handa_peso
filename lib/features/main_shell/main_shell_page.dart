import 'package:flutter/material.dart';
import 'package:get/get.dart';

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
      id: 'home',
      label: 'Home',
      activeIcon: 'assets/tab_home_active.png',
      inactiveIcon: 'assets/tab_home_inactive.png',
    ),
    _ShellTab(
      id: 'loan',
      label: 'Loan',
      activeIcon: 'assets/tab_loan_active.png',
      inactiveIcon: 'assets/tab_loan_inactive.png',
    ),
    _ShellTab(
      id: 'mine',
      label: 'Mine',
      activeIcon: 'assets/tab_mine_active.png',
      inactiveIcon: 'assets/tab_mine_inactive.png',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Scaffold(
        body: IndexedStack(
          index: controller.selectedIndex.value,
          children: const [HomePage(), OrdersPage(), MinePage()],
        ),
        bottomNavigationBar: _ShellNavigationBar(
          tabs: _tabs,
          selectedIndex: controller.selectedIndex.value,
          onSelected: controller.selectTab,
        ),
      ),
    );
  }
}

class _ShellTab {
  const _ShellTab({
    required this.id,
    required this.label,
    required this.activeIcon,
    required this.inactiveIcon,
  });

  final String id;
  final String label;
  final String activeIcon;
  final String inactiveIcon;
}

class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
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

  final List<_ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: _contentHeight,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tabWidth = constraints.maxWidth / tabs.length;
              final indicatorLeft =
                  tabWidth * selectedIndex + (tabWidth - _indicatorWidth) / 2;
              return Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: _topPadding, bottom: _bottomPadding),
                    child: Row(
                      children: [
                        for (var index = 0; index < tabs.length; index++)
                          Expanded(
                            child: InkWell(
                              key: Key('tab-${tabs[index].id}'),
                              onTap: () => onSelected(index),
                              child: _TabItem(
                                tab: tabs[index],
                                selected: index == selectedIndex,
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
                        borderRadius: BorderRadius.vertical(top: Radius.circular(1)),
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

class _TabItem extends StatelessWidget {
  const _TabItem({required this.tab, required this.selected});

  final _ShellTab tab;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.tabActive : AppColors.tabInactive;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Image.asset(
          selected ? tab.activeIcon : tab.inactiveIcon,
          width: _ShellNavigationBar._iconSize,
          height: _ShellNavigationBar._iconSize,
        ),
        const SizedBox(height: _ShellNavigationBar._iconLabelGap),
        Text(
          tab.label,
          style: TextStyle(
            fontSize: 10,
            height: 1.4,
            color: color,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// 供二级页面复用的页面标题栏。
class ShellAppBar extends StatelessWidget implements PreferredSizeWidget {
  const ShellAppBar({required this.title, this.actions, super.key});

  final String title;
  final List<Widget>? actions;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(title: Text(title), actions: actions);
  }
}

/// 采用 8dp 网格布局的共享空状态 widget。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    required this.icon,
    required this.title,
    this.description,
    this.action,
    super.key,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: AppColors.textMuted),
            const SizedBox(height: AppSpacing.sm),
            Text(title, style: textTheme.titleMedium, textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                description!,
                style: textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.md),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
