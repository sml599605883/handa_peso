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

// ---------------------------------------------------------------------------
// 弹窗按钮文案（四个常量，集中在这里，方便一行互换）
//
// 来源：需求文档 M20-3「退出 / 注销挽留弹窗」的按钮列，对应测试缺陷
// `reczz28SlNC3NUCI`（模块：退出/注销，问题：弹窗按钮文案）。
// 文案表要求：退出 = `Keep Rates` / `Log Out`，注销 = `Keep Offers` / `Delete`。
//
// 已定口径：按钮颜色语义不变——右侧暖橙 = 保留键（留在 App），左侧灰色 =
// 破坏性动作键（真的退出 / 注销）。所以保留词放右橙，动作词放左灰。
//
// 待确认：文案表把两个词按「保留 | 动作」的顺序书写（`Keep Rates | Log Out`），
// 与设计稿左灰（动作）右橙（保留）的视觉顺序相反，且截图里第二个词被列宽截断
// （注销那一格只看到 `Delete` 的前半段，此处参考同族 `peso_shield` 用 `Delete`）。
// 若产品复议为「左保留满、右动作」，只需把下面四行里 keep/action 两组词互换。
// ---------------------------------------------------------------------------

/// 退出弹窗 · 右侧暖橙按钮（保留键）：留在 App，维持当前利率。
const String kAccountRetentionLogoutKeepLabel = 'Keep Rates';

/// 退出弹窗 · 左侧灰色按钮（动作键）：真的退出登录。
const String kAccountRetentionLogoutActionLabel = 'Log Out';

/// 注销弹窗 · 右侧暖橙按钮（保留键）：留在 App，保住专属额度。
const String kAccountRetentionDeleteKeepLabel = 'Keep Offers';

/// 注销弹窗 · 左侧灰色按钮（动作键）：真的注销账号。
const String kAccountRetentionDeleteActionLabel = 'Delete';

/// 弹窗里的固定文案。
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

/// 注销挽留弹窗（设计稿 `Before you continue` / 文案表 `Consider this`）。
const _deleteAccountCopy = _RetentionCopy(
  asset: 'assets/account_delete_retention_card.png',
  confirmLabel: kAccountRetentionDeleteActionLabel,
  keepLabel: kAccountRetentionDeleteKeepLabel,
);

/// 退出挽留弹窗（设计稿 `Leaving already?` / 文案表 `One more thing`）。
const _logoutCopy = _RetentionCopy(
  asset: 'assets/account_logout_retention_card.png',
  confirmLabel: kAccountRetentionLogoutActionLabel,
  keepLabel: kAccountRetentionLogoutKeepLabel,
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
        // 按钮宽高是设计稿固定值（142.5 x 52），而文案改长后（`Keep Offers` /
        // `Keep Rates`）在大字号辅助设置下可能超宽：这里用 `FittedBox` 等比缩小
        // 而不是省略号裁断，既不溢出也不丢字，设计尺寸不作任何改动。
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: _AccountRetentionDialog._buttonLabelSize * scale,
              fontWeight: FontWeight.w600,
              height: 25 / _AccountRetentionDialog._buttonLabelSize,
            ),
          ),
        ),
      ),
    );
  }
}
