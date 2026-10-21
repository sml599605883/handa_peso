import 'package:flutter/material.dart';

/// 全应用统一的文本选择菜单。
///
/// iOS 原生 `SystemContextMenu` 在快速切换输入框时可能触发
/// `Attempted to show while another instance was still visible`；改用 Flutter
/// 自适应菜单可以避开该原生菜单实例竞争，同时保留复制、粘贴和全选等能力。
abstract final class AppTextSelectionMenu {
  static Widget build(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    return AdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }
}
