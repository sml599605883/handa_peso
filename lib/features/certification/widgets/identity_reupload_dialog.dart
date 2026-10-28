import 'package:flutter/material.dart';

import '../../../app/navigation/app_navigator.dart';

/// 服务端要求重新上传证件时的说明。
///
/// 人脸核身（`livenessType=0`）与绑卡前的人脸（`livenessType=1`）调用同一个
/// token 接口，`resultCode == 400` 的业务含义都是「证件不合格、需要重拍」，
/// 因此两处共用这一份弹窗，避免文案与跳转逻辑分叉。
///
/// 是否为 400 由调用方判定，这里只负责展示与跳转证件流程。
Future<void> showIdentityReuploadDialog(
  BuildContext context, {
  required String productId,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text(IdentityReuploadStrings.title),
      content: const Text(IdentityReuploadStrings.body),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(IdentityReuploadStrings.maybeLater),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(IdentityReuploadStrings.takePhoto),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;
  await AppNavigator.toIdentityVerification(productId: productId);
}

abstract final class IdentityReuploadStrings {
  static const title = 'ID Photo Not Accepted';
  static const body =
      'This ID photo wasn\'t accepted. Please take another one or upload a '
      'readable image with all details visible.';
  static const maybeLater = 'Maybe Later';
  static const takePhoto = 'Take Photo';
}
