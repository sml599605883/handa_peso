import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';

/// 账号相关的退出动作：退出登录 / 注销账号。
enum AccountExitAction { logout, deleteAccount }

/// 弹出退出 / 注销的挽留弹窗，返回用户是否确认了那个破坏性动作。
///
/// 对应设计稿 `07-01 - 个人中心-注销挽留弹窗` 与
/// `个人中心-退出弹窗-退出挽留弹窗`：两版版式完全相同，只有插画里的标题、正文
/// 与按钮文案不同。整卡切图（设计稿 `编组` 335x294 @3x）里已经把面板、铃铛、
/// 标题与正文烘焙好了，代码只叠两枚按钮——标题用的是 26 号渐变字，交给设备
/// 字体渲染会换行位置不一致。
Future<bool?> showAccountRetentionDialog({
  required BuildContext context,
  required AccountExitAction action,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss account retention dialog',
    barrierColor: AppColors.accountDialogBarrier,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) =>
        _AccountRetentionDialog(action: action),
    transitionBuilder: (context, animation, secondaryAnimation, child) =>
        FadeTransition(opacity: animation, child: child),
  );
}

/// 弹窗里的固定文案（设计稿逐字照搬）。
class _RetentionCopy {
  const _RetentionCopy({
    required this.asset,
    required this.confirmLabel,
    required this.keepLabel,
  });

  /// 整卡切图（标题 / 正文已烘焙在图里）。
  final String asset;

  /// 左侧灰色按钮：真正退出 / 注销。
  final String confirmLabel;

  /// 右侧暖橙按钮：留在 App，等同于关闭弹窗。
  final String keepLabel;
}

/// 注销挽留弹窗（设计稿 `Before you continue`）。
const _deleteAccountCopy = _RetentionCopy(
  asset: 'assets/account_delete_retention_card.png',
  confirmLabel: 'Delete Account',
  keepLabel: 'Get Funds',
);

/// 退出挽留弹窗（设计稿 `Leaving already?`）。
const _logoutCopy = _RetentionCopy(
  asset: 'assets/account_logout_retention_card.png',
  confirmLabel: 'Exit',
  keepLabel: 'Stay',
);

class _AccountRetentionDialog extends StatelessWidget {
  const _AccountRetentionDialog({required this.action});

  final AccountExitAction action;

  /// 设计稿 375 基准下的尺寸。
  static const double _designWidth = 375;

  /// 整卡切图（设计稿 `编组` 335x294）。
  static const double _cardWidth = 335;
  static const double _cardHeight = 294;

  /// 两枚按钮：设计稿里按钮行宽 295、上沿在切图内 217（整卡 441 - 224）。
  static const double _buttonsTop = 217;
  static const double _buttonsWidth = 295;
  static const double _buttonsGap = 10;
  static const double _buttonHeight = 52;
  static const double _buttonRadius = 26;
  static const double _buttonLabelSize = 18;

  /// 面板在设计稿上比屏幕垂直中心高 26，弹窗整体上移同样的距离。
  static const double _lift = 26;

  _RetentionCopy get _copy => switch (action) {
    AccountExitAction.logout => _logoutCopy,
    AccountExitAction.deleteAccount => _deleteAccountCopy,
  };

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / _designWidth;
    double px(num value) => value * scale;
    final copy = _copy;

    // 必须包一层 Material：`showGeneralDialog` 的页面子树没有 Material 祖先时，
    // `Text` 会退化成 Flutter 的错误样式（红字 + 黄色双下划线）。
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: Padding(
          padding: EdgeInsets.only(bottom: px(_lift * 2)),
          child: SizedBox(
            width: px(_cardWidth),
            height: px(_cardHeight),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image(image: AssetImage(copy.asset), fit: BoxFit.fill),
                ),
                Positioned(
                  left: px((_cardWidth - _buttonsWidth) / 2),
                  top: px(_buttonsTop),
                  width: px(_buttonsWidth),
                  height: px(_buttonHeight),
                  child: Row(
                    children: [
                      Expanded(
                        child: _RetentionButton(
                          key: const Key('account-retention-confirm'),
                          label: copy.confirmLabel,
                          scale: scale,
                          surface: AppColors.accountMutedAction,
                          onTap: () => Navigator.of(context).pop(true),
                        ),
                      ),
                      SizedBox(width: px(_buttonsGap)),
                      Expanded(
                        child: _RetentionButton(
                          key: const Key('account-retention-keep'),
                          label: copy.keepLabel,
                          scale: scale,
                          gradient: AppColors.accountWarmGradient,
                          onTap: () => Navigator.of(context).pop(false),
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

/// 弹窗里的胶囊按钮：灰色底或暖橙渐变底，文案由代码叠加。
class _RetentionButton extends StatelessWidget {
  const _RetentionButton({
    required this.label,
    required this.scale,
    required this.onTap,
    this.surface,
    this.gradient,
    super.key,
  });

  final String label;
  final double scale;
  final VoidCallback onTap;
  final Color? surface;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: surface,
          gradient: gradient,
          borderRadius: BorderRadius.circular(
            _AccountRetentionDialog._buttonRadius * scale,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: _AccountRetentionDialog._buttonLabelSize * scale,
            fontWeight: FontWeight.w600,
            height: 25 / _AccountRetentionDialog._buttonLabelSize,
          ),
        ),
      ),
    );
  }
}
