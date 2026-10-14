import 'package:flutter/material.dart';

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
