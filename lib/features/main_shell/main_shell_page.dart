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
    _ShellTab(id: 'home', label: 'Home', icon: Icons.home_rounded),
    _ShellTab(id: 'orders', label: 'Orders', icon: Icons.receipt_long_rounded),
    _ShellTab(id: 'mine', label: 'Account', icon: Icons.person_rounded),
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
  const _ShellTab({required this.id, required this.label, required this.icon});

  final String id;
  final String label;
  final IconData icon;
}

class _ShellNavigationBar extends StatelessWidget {
  const _ShellNavigationBar({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_ShellTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              for (var index = 0; index < tabs.length; index++)
                Expanded(
                  child: InkWell(
                    key: Key('tab-${tabs[index].id}'),
                    onTap: () => onSelected(index),
                    child: _TabItem(tab: tabs[index], selected: index == selectedIndex),
                  ),
                ),
            ],
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
    final color = selected ? AppColors.primary : AppColors.textMuted;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(tab.icon, size: 24, color: color),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          tab.label,
          style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

/// Reusable page header used by secondary screens.
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

/// Shared empty-state widget with an 8dp-grid layout.
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
