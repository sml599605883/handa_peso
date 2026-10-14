import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../theme/app_colors.dart';

/// 屏幕正中的提示浮层（设计稿 01-02 - 登录-电话号码格式无效）。
///
/// 设计稿把提示画成一块固定的深色圆角方块：151x144（375x812 画布）、
/// 圆角 8、底色 64% 黑、白色 15pt 文案居中，2 秒后自动消失、不拦截点击。
/// 不复用 `EasyLoading` 的 toast：它的盒子贴着文案、皮肤又与 loading 共用，
/// 改它会连带改到全站的 loading 与提示。
///
/// 使用方式：[AppHint.show]（已由 `AppNavigator.showHint` 转发）。
abstract final class AppHint {
  /// 设计稿画布宽度。
  static const double designWidth = 375;

  /// 设计稿量到的浮层尺寸。
  static const double boxWidth = 151;
  static const double boxMinHeight = 144;
  static const double boxRadius = 8;
  static const EdgeInsets boxPadding = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 20,
  );

  /// 文案字号与行高。
  ///
  /// 设计稿里「Invalid phone number format.」在 111 的可用宽度内断成两行
  /// （`Invalid phone` / `number format.`），行距 22；按设备字体渲染时 15pt 会
  /// 挤到三行，14pt 才能复现设计稿的断行与字形高度。
  static const double fontSize = 14;
  static const double lineHeight = 22;

  /// 展示时长与淡入淡出时长。
  static const Duration displayDuration = Duration(seconds: 2);
  static const Duration fadeDuration = Duration(milliseconds: 200);

  static OverlayEntry? _entry;
  static Completer<void>? _completion;

  /// 上一条提示播完（含淡出）后完成；当前没有提示时立即完成。
  ///
  /// 「提示播完再动界面」的动作（例如登录失败后复位输入框）靠它挂接。
  static Future<void> get dismissed =>
      _completion?.future ?? Future<void>.value();

  /// 在屏幕正中弹一条提示；空文案直接忽略。
  ///
  /// 没有 Overlay（例如纯 widget 测试里没挂 App）时返回 `false`，
  /// 调用方可以据此决定是否退回到别的提示手段。
  static bool show(String message) {
    final text = message.trim();
    if (text.isEmpty) return false;
    final context = Get.context;
    final overlay = context == null
        ? Get.key.currentState?.overlay
        : Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return false;

    final scale = context == null
        ? 1.0
        : MediaQuery.sizeOf(context).width / designWidth;
    dismiss();
    _completion = Completer<void>();
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HintOverlay(
        message: text,
        scale: scale,
        onDismissed: () {
          if (!identical(_entry, entry)) return;
          _entry = null;
          _complete();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    return true;
  }

  /// 立刻收起当前的提示（重复调用无副作用）。
  static void dismiss() {
    final entry = _entry;
    _entry = null;
    // Overlay 已经随着页面销毁时 `mounted` 为 false，直接丢引用即可。
    if (entry != null && entry.mounted) entry.remove();
    _complete();
  }

  static void _complete() {
    final pending = _completion;
    _completion = null;
    if (pending != null && !pending.isCompleted) pending.complete();
  }
}

/// 浮层本体：居中、忽略点击、淡入淡出。
class _HintOverlay extends StatefulWidget {
  const _HintOverlay({
    required this.message,
    required this.scale,
    required this.onDismissed,
  });

  final String message;
  final double scale;
  final VoidCallback onDismissed;

  @override
  State<_HintOverlay> createState() => _HintOverlayState();
}

class _HintOverlayState extends State<_HintOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppHint.fadeDuration,
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    unawaited(_controller.forward());
    _timer = Timer(AppHint.displayDuration, _dismiss);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: _controller,
        child: Center(
          child: AppHintBox(message: widget.message, scale: widget.scale),
        ),
      ),
    );
  }
}

/// 提示浮层的方块（独立出来方便直接测量与复用）。
class AppHintBox extends StatelessWidget {
  const AppHintBox({required this.message, this.scale = 1, super.key});

  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      key: const Key('app-hint'),
      constraints: BoxConstraints(
        minWidth: AppHint.boxWidth * scale,
        maxWidth: AppHint.boxWidth * scale,
        minHeight: AppHint.boxMinHeight * scale,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.hintSurface,
          borderRadius: BorderRadius.circular(AppHint.boxRadius * scale),
        ),
        child: Padding(
          padding: AppHint.boxPadding * scale,
          // 设计稿的方块固定 144 高、文案在方块里垂直居中；正文更长时
          // 由 `MainAxisSize.min` 撑高，不会裁切。
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textOnPrimary,
                  fontSize: AppHint.fontSize * scale,
                  fontWeight: FontWeight.w400,
                  height: AppHint.lineHeight / AppHint.fontSize,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
