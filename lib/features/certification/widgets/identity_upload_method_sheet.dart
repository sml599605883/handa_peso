import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../identity_design.dart';
import '../identity_photo_service.dart';

/// 弹出认证方式弹层（设计稿 03-01 - 身份认证-认证方式选择）。
///
/// 设计稿给的是 Camera / Album 二选一 + 同一枚 Submit 确认。相册通过系统
/// PHPicker 读取用户选中的单张照片，不申请完整相册权限。
///
/// 返回用户确认的取图方式；点返回或遮罩关闭时返回 `null`。
Future<IdentityPhotoSource?> showIdentityUploadMethodSheet(
  BuildContext context,
) {
  return showGeneralDialog<IdentityPhotoSource>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'identity-upload-method',
    barrierColor: AppColors.identitySheetBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _IdentityUploadMethodSheet(),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

class _IdentityUploadMethodSheet extends StatefulWidget {
  const _IdentityUploadMethodSheet();

  @override
  State<_IdentityUploadMethodSheet> createState() =>
      _IdentityUploadMethodSheetState();
}

class _IdentityUploadMethodSheetState
    extends State<_IdentityUploadMethodSheet> {
  IdentityPhotoSource _selected = IdentityPhotoSource.camera;

  void _submit() => Navigator.of(context).pop(_selected);

  @override
  Widget build(BuildContext context) {
    final metrics = IdentityMetrics(
      screenWidth: MediaQuery.sizeOf(context).width,
    );

    return IdentityBottomPanel(
      panelKey: const Key('identity-upload-method-sheet'),
      height: IdentityDesign.sheetHeight,
      metrics: metrics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Align(
            alignment: Alignment.centerLeft,
            child: IdentityPanelBackButton(
              key: const Key('identity-upload-method-back'),
              metrics: metrics,
            ),
          ),
          SizedBox(height: metrics.size(IdentityDesign.sheetBackGap)),
          _MethodRow(
            key: const Key('identity-upload-method-camera'),
            label: IdentityStrings.camera,
            metrics: metrics,
            selected: _selected == IdentityPhotoSource.camera,
            onTap: () => setState(() => _selected = IdentityPhotoSource.camera),
          ),
          SizedBox(height: metrics.size(IdentityDesign.sheetRowGap)),
          _MethodRow(
            key: const Key('identity-upload-method-album'),
            label: IdentityStrings.album,
            metrics: metrics,
            selected: _selected == IdentityPhotoSource.album,
            onTap: () => setState(() => _selected = IdentityPhotoSource.album),
          ),
          SizedBox(height: metrics.size(IdentityDesign.sheetSubmitGap)),
          IdentitySubmitButton(
            key: const Key('identity-upload-method-submit'),
            metrics: metrics,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

/// 一行取图方式（设计稿 `section_8` / `text-wrapper_4`）：选中态用浅米色底 +
/// 右侧圆点，未选中态是白底 + 次要文字。
class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.label,
    required this.metrics,
    required this.selected,
    required this.onTap,
    super.key,
  });

  final String label;
  final IdentityMetrics metrics;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: metrics.size(IdentityDesign.sheetContentWidth),
        height: metrics.size(IdentityDesign.sheetRowHeight),
        child: Stack(
          // 选中圆点压在这一行的右上角、有一半在行外，必须允许越界绘制。
          clipBehavior: Clip.none,
          children: <Widget>[
            Positioned.fill(
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.identityPanelSurface
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(
                    metrics.size(IdentityDesign.sheetRowRadius),
                  ),
                  border: Border.all(
                    color: AppColors.identityCardBorder,
                    width: metrics.size(1),
                  ),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected
                        ? AppColors.identityTitle
                        : AppColors.identitySheetUnselectedText,
                    fontSize: metrics.size(IdentityDesign.sheetRowSize),
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                    height: 1.25,
                  ),
                ),
              ),
            ),
            if (selected)
              Positioned(
                right: metrics.size(IdentityDesign.sheetMarkerRight),
                top: metrics.size(IdentityDesign.sheetMarkerCenterOffset),
                child: Container(
                  width: metrics.size(IdentityDesign.sheetMarkerSize),
                  height: metrics.size(IdentityDesign.sheetMarkerSize),
                  decoration: const BoxDecoration(
                    color: AppColors.identitySheetMarker,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
