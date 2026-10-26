import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../identity_models.dart';

/// 认证项退出时的挽留弹窗。
///
/// 返回 `true` 表示继续认证（留在当前页），`false` 表示退出。
///
/// 弹窗背景（卡片、插画与标题正文）整幅由服务端下发（`tidewaters`），客户端只
/// 在背景底部叠两枚原生按钮：左侧「返回」用实底，右侧「继续」用渐变胶囊。这样
/// 文案跟着接口走，各认证项不需要为每一套文案单独出客户端切图。
Future<bool> showIdentityRetentionDialog(
  BuildContext context, {
  required IdentityRetentionPrompt prompt,
  ImageProvider<Object>? imageProvider,
}) async {
  final stay = await showGeneralDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'identity-retention',
    barrierColor: AppColors.identitySheetBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _IdentityRetentionDialog(prompt: prompt, imageProvider: imageProvider),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
  return stay ?? false;
}

class _IdentityRetentionDialog extends StatelessWidget {
  const _IdentityRetentionDialog({
    required this.prompt,
    required this.imageProvider,
  });

  final IdentityRetentionPrompt prompt;
  final ImageProvider<Object>? imageProvider;

  /// 设计稿基准宽度与弹窗背景宽度（设计稿卡片 327 宽）。
  static const double _designWidth = 375;
  static const double _backgroundWidth = 327;

  /// 按钮行：左右各让出 20、两枚 138 宽、间距 11、高 52，距背景底边 27。
  static const double _rowInset = 20;
  static const double _buttonHeight = 52;
  static const double _buttonGap = 11;
  static const double _rowBottom = 27;

  /// 背景图加载失败时的占位高度（设计稿整幅 327x379），保证按钮仍可见。
  static const double _fallbackHeight = 379;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    double px(num value) => value * scale;

    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: px(24), vertical: px(24)),
            child: SizedBox(
              width: px(_backgroundWidth),
              child: Stack(
                children: <Widget>[
                  // 整幅弹窗由服务端下发（卡片、插画、标题与正文都在图里）。
                  Image(
                    key: const Key('identity-retention-image'),
                    image: imageProvider ?? NetworkImage(prompt.imageUrl),
                    width: px(_backgroundWidth),
                    fit: BoxFit.fitWidth,
                    // 背景还没解码完时先按设计稿比例占位：否则 Stack 高度为 0，
                    // 叠在底部的按钮会被裁掉，弹窗会「先空一下再出现」。
                    frameBuilder:
                        (context, child, frame, wasSynchronouslyLoaded) {
                          if (wasSynchronouslyLoaded || frame != null) {
                            return child;
                          }
                          return SizedBox(
                            width: px(_backgroundWidth),
                            height: px(_fallbackHeight),
                          );
                        },
                    errorBuilder: (context, error, stackTrace) => SizedBox(
                      width: px(_backgroundWidth),
                      height: px(_fallbackHeight),
                    ),
                  ),
                  Positioned(
                    left: px(_rowInset),
                    right: px(_rowInset),
                    bottom: px(_rowBottom),
                    height: px(_buttonHeight),
                    child: Row(
                      children: <Widget>[
                        Expanded(
                          child: _RetentionButton(
                            key: const Key('identity-retention-exit'),
                            label: prompt.exitText,
                            scale: scale,
                            background: AppColors.identityRetentionExitSurface,
                            foreground: AppColors.textOnPrimary,
                            onTap: () => Navigator.of(context).pop(false),
                          ),
                        ),
                        SizedBox(width: px(_buttonGap)),
                        Expanded(
                          child: _RetentionButton(
                            key: const Key('identity-retention-continue'),
                            label: prompt.continueText,
                            scale: scale,
                            gradient:
                                AppColors.identityRetentionPrimaryGradient,
                            foreground: AppColors.textOnPrimary,
                            onTap: () => Navigator.of(context).pop(true),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RetentionButton extends StatelessWidget {
  const _RetentionButton({
    required this.label,
    required this.scale,
    required this.foreground,
    required this.onTap,
    this.background,
    this.gradient,
    super.key,
  });

  final String label;
  final double scale;
  final Color foreground;
  final Color? background;
  final Gradient? gradient;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          gradient: gradient,
          borderRadius: BorderRadius.circular(26 * scale),
        ),
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12 * scale),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: foreground,
                fontSize: 18 * scale,
                fontWeight: FontWeight.w600,
                height: 25 / 18,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
