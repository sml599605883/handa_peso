import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../identity_models.dart';

/// 证件类型页的退出挽留弹窗。
///
/// 返回 `true` 表示继续认证（留在当前页），`false` 表示退出。
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

  static const double _designWidth = 375;
  static const double _imageWidth = 330;
  static const double _buttonsWidth = 266;
  static const double _buttonHeight = 48;
  static const double _buttonGap = 10;

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
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Image(
                  key: const Key('identity-retention-image'),
                  image: imageProvider ?? NetworkImage(prompt.imageUrl),
                  width: px(_imageWidth),
                  fit: BoxFit.fitWidth,
                  errorBuilder: (context, error, stackTrace) =>
                      const SizedBox.shrink(),
                ),
                SizedBox(height: px(18)),
                SizedBox(
                  width: px(_buttonsWidth),
                  height: px(_buttonHeight),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: _RetentionButton(
                          key: const Key('identity-retention-exit'),
                          label: prompt.exitText,
                          scale: scale,
                          background: AppColors.surface,
                          foreground: AppColors.identitySheetUnselectedText,
                          onTap: () => Navigator.of(context).pop(false),
                        ),
                      ),
                      SizedBox(width: px(_buttonGap)),
                      Expanded(
                        child: _RetentionButton(
                          key: const Key('identity-retention-continue'),
                          label: prompt.continueText,
                          scale: scale,
                          gradient: AppColors.homeWarmGradient,
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
          borderRadius: BorderRadius.circular(
            _IdentityRetentionDialog._buttonHeight / 2 * scale,
          ),
          border: background == null
              ? null
              : Border.all(color: AppColors.identityCardBorder),
        ),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: foreground,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
