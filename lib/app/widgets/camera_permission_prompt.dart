import 'package:flutter/cupertino.dart';

import '../theme/app_colors.dart';

/// 相机权限被拒绝后的 iOS 风格二次说明。
///
/// 系统弹窗只会出现一次；用户拒绝后必须引导到系统设置。取消按钮使用浅灰色，
/// 主操作沿用项目品牌棕色。
Future<void> showCameraPermissionPrompt(
  BuildContext context, {
  required VoidCallback openSettings,
  required String title,
  required String message,
}) async {
  final shouldOpenSettings = await showCupertinoDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        CupertinoDialogAction(
          textStyle: const TextStyle(color: AppColors.textMuted),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Not Now'),
        ),
        CupertinoDialogAction(
          textStyle: const TextStyle(color: AppColors.identitySheetMarker),
          isDefaultAction: true,
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Open Settings'),
        ),
      ],
    ),
  );
  if (shouldOpenSettings == true) openSettings();
}
