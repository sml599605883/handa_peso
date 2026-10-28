import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// 定位受系统限制或服务关闭时的 iOS 风格说明。
///
/// 系统弹窗只会出现一次；用户拒绝后必须引导到系统设置。取消按钮使用浅灰色，
/// 主操作使用黑色，避免跟随全局主题色。
///
/// 按钮文案由调用方按场景传入，不同权限弹窗允许各自措辞（相机、定位权限、
/// 定位服务三种场景的按钮并不相同），但返回值语义固定：左侧 `false` 表示留在
/// 当前页，右侧 `true` 表示去系统设置。
Future<bool> showIosPermissionPrompt(
  BuildContext context, {
  required String title,
  required String message,
  String cancelLabel = 'Not Now',
  String confirmLabel = 'Open Settings',
}) async {
  final shouldOpenSettings = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => CupertinoTheme(
      data: const CupertinoThemeData(primaryColor: AppColors.identityTitle),
      child: CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          CupertinoDialogAction(
            textStyle: const TextStyle(color: AppColors.textMuted),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              cancelLabel,
              style: const TextStyle(color: AppColors.textMuted),
            ),
          ),
          CupertinoDialogAction(
            textStyle: const TextStyle(
              color: AppColors.identityTitle,
              fontWeight: FontWeight.w600,
            ),
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              confirmLabel,
              style: const TextStyle(
                color: AppColors.identityTitle,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    ),
  );
  return shouldOpenSettings == true;
}
