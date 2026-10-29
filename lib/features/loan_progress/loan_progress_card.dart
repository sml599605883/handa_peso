import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'loan_progress_item.dart';

/// 借款进度卡片（设计稿 02- 贷款-订单进度）。
///
/// 卡片按设计稿的 375 宽画布取样，再按可用宽度等比缩放：尺寸、缺口、徽标
/// 悬挑都写设计稿上的原始数值。票券分隔带与两枚按钮直接铺设计稿导出的切片
/// （见 [LoanProgressCard._dividerSlice] 等），底板（奶油色面板、1px 内描边、
/// 票券缺口）由代码绘制，高度随有无按钮在 128 / 174 之间切换。
class LoanProgressCard extends StatelessWidget {
  const LoanProgressCard({
    super.key,
    required this.item,
    required this.scale,
    this.onTap,
    this.onActionTap,
  });

  // 设计稿数值。
  static const double width = 347;
  static const double _heightIdle = 128;
  static const double _heightWithActions = 174;

  /// 底板圆角 14、1px 内描边（设计稿 `形状结合`）。
  static const double _radius = 14;
  static const double _stroke = 1;
  static const double _contentInset = 14;

  /// 产品行：24 高，距卡片上沿 14。
  static const double _productTop = 14;
  static const double _logoSize = 24;
  static const double _logoRadius = 4;
  static const double _logoGap = 10;

  /// 票券分隔带：设计稿导出的 347x18 切片，两端各切一个 r7 半圆缺口，1 高的
  /// 分隔线（左右各留 14）落在切片中线上；切片自带缺口边缘的描边与抗锯齿。
  /// 缺口圆心在设计稿的 48 处，因此切片上沿落在 48 - 18/2 = 39。
  static const String _dividerSlice = 'assets/loan_progress_card_divider.png';
  static const double _dividerSliceHeight = 18;
  static const double _dividerCenter = 48;
  static const double _notchRadius = 7;

  /// 数据块：52 高，距上沿 62，两侧各留 24。
  static const double _valueTop = 62;
  static const double _valueHeight = 52;
  static const double _valueInset = 24;
  static const double _valueGap = 12;
  static const double _valueRadius = 8;
  static const double _valuePadding = 8;
  static const double _valueLabelGap = 4;

  /// 按钮：32 高，距上沿 128；两枚时左右各留 28、中间间隔 19。
  static const double _actionTop = 128;
  static const double _actionHeight = 32;
  static const double _actionWidth = 136;
  static const double _actionInset = 28;
  static const double _actionGap = 19;

  /// 主按钮（暖橙渐变）与次按钮（灰）的切片，136x32、两角圆角 18。
  static const String _actionPrimarySlice =
      'assets/loan_progress_action_primary.png';
  static const String _actionMutedSlice =
      'assets/loan_progress_action_muted.png';

  /// 状态徽标：108x30，右对齐卡片，向上悬挑 6；文案 14 号，中线比徽标略高
  /// 2（设计稿给文案留了上 4 / 下 8 的内边距，给右下角的小尾巴让位）。
  static const double _badgeWidth = 108;
  static const double _badgeHeight = 30;
  static const double _badgeOverhang = 6;
  static const double _badgeFontSize = 14;
  static const double _badgeLabelRise = 4;

  final LoanProgressItem item;
  final double scale;

  /// 点击卡片主体：进订单详情页。
  final VoidCallback? onTap;

  final void Function(LoanProgressAction action)? onActionTap;

  double get _height => item.hasActions ? _heightWithActions : _heightIdle;

  @override
  Widget build(BuildContext context) {
    double px(num value) => value * scale;
    final actions = item.visibleActions;

    // 整张卡片是一个热区，热区必须包在内容外面。
    //
    // 之前热区是 `Stack` 的最底层兄弟节点：`RenderParagraph.hitTestSelf` 恒为
    // true，Stack 命中子节点后就不再往下测，于是卡片上的文案（产品名、日期 /
    // 金额的标签与数值、徽标文案）会把点击吞掉，只剩文案之间的空白窄条能进
    // 订单详情（缺陷：只有右侧一小块能触发）。
    //
    // 改成祖先节点后，点击无论落在文案还是空白处都会经过它；按钮是它的子节点，
    // 命中按钮时由更深一层的识别器赢得手势竞技场，仍然走 `onActionTap`。
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: px(width),
        height: px(_height),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _CardBodyPainter(
                  radius: px(_radius),
                  stroke: px(_stroke),
                  notchRadius: px(_notchRadius),
                  notchCenterY: px(_dividerCenter),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: px(_dividerCenter - _dividerSliceHeight / 2),
              height: px(_dividerSliceHeight),
              child: const IgnorePointer(
                child: Image(
                  image: AssetImage(_dividerSlice),
                  fit: BoxFit.fill,
                ),
              ),
            ),
            Positioned(
              left: px(_contentInset),
              right: px(_contentInset),
              top: px(_productTop),
              height: px(_logoSize),
              child: _ProductRow(item: item, scale: scale, size: px(_logoSize)),
            ),
            Positioned(
              left: px(_valueInset),
              right: px(_valueInset),
              top: px(_valueTop),
              height: px(_valueHeight),
              child: Row(
                children: [
                  Expanded(
                    child: _ValueBlock(
                      label: item.dateLabel,
                      value: item.date,
                      scale: scale,
                    ),
                  ),
                  SizedBox(width: px(_valueGap)),
                  Expanded(
                    child: _ValueBlock(
                      label: item.amountLabel,
                      value: item.amount,
                      scale: scale,
                    ),
                  ),
                ],
              ),
            ),
            if (actions.isNotEmpty)
              Positioned(
                left: px(_actionInset),
                right: px(_actionInset),
                top: px(_actionTop),
                height: px(_actionHeight),
                child: _ActionStrip(
                  actions: actions,
                  scale: scale,
                  onActionTap: onActionTap,
                ),
              ),
            if (item.statusLabel.isNotEmpty)
              Positioned(
                right: 0,
                top: px(-_badgeOverhang),
                width: px(_badgeWidth),
                height: px(_badgeHeight),
                child: _StatusBadge(item: item, scale: scale),
              ),
          ],
        ),
      ),
    );
  }
}

/// 卡片底板：奶油色圆角面板 + 1px 内描边，左右各切一个票券缺口。
///
/// 描边画在外形与「向内缩 [stroke] 的同形路径」之间，因此始终落在面板以内，
/// 和设计稿的 `border: 1px inside` 一致，不会在卡片外侧糊出半个像素。
class _CardBodyPainter extends CustomPainter {
  const _CardBodyPainter({
    required this.radius,
    required this.stroke,
    required this.notchRadius,
    required this.notchCenterY,
  });

  final double radius;
  final double stroke;
  final double notchRadius;
  final double notchCenterY;

  /// [inset] 为 0 时是面板外形；为 [stroke] 时是同形内框。
  Path _shape(Size size, double inset) {
    final frame = Rect.fromLTWH(
      inset,
      inset,
      math.max(0, size.width - inset * 2),
      math.max(0, size.height - inset * 2),
    );
    final panel = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          frame,
          Radius.circular(math.max(0, radius - inset)),
        ),
      );
    // 缺口圆心落在分隔带中线上，两条边各切半个圆。
    final cut = Path()
      ..addOval(
        Rect.fromCircle(
          center: Offset(0, notchCenterY),
          radius: notchRadius + inset,
        ),
      )
      ..addOval(
        Rect.fromCircle(
          center: Offset(size.width, notchCenterY),
          radius: notchRadius + inset,
        ),
      );
    return Path.combine(PathOperation.difference, panel, cut);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = _shape(size, 0);
    canvas.drawPath(outer, Paint()..color = AppColors.progressCardSurface);
    if (stroke <= 0) return;
    final inner = _shape(size, stroke);
    canvas.drawPath(
      Path.combine(PathOperation.difference, outer, inner),
      Paint()..color = AppColors.progressCardBorder,
    );
  }

  @override
  bool shouldRepaint(_CardBodyPainter oldDelegate) =>
      radius != oldDelegate.radius ||
      stroke != oldDelegate.stroke ||
      notchRadius != oldDelegate.notchRadius ||
      notchCenterY != oldDelegate.notchCenterY;
}

/// 产品行：Logo + 产品名。
class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.item,
    required this.scale,
    required this.size,
  });

  final LoanProgressItem item;
  final double scale;
  final double size;

  @override
  Widget build(BuildContext context) {
    final logo = item.productLogo.trim();
    return Row(
      children: [
        SizedBox(
          width: size,
          height: size,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(
              LoanProgressCard._logoRadius * scale,
            ),
            child: logo.isEmpty
                ? const _LogoPlaceholder()
                : Image.network(
                    logo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const _LogoPlaceholder(),
                  ),
          ),
        ),
        SizedBox(width: LoanProgressCard._logoGap * scale),
        Expanded(
          child: Text(
            item.productName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: AppColors.progressValueText,
              fontSize: 12 * scale,
              fontWeight: FontWeight.w400,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

/// Logo 缺失时的占位方块（设计稿里就是灰底 + 灰描边）。
class _LogoPlaceholder extends StatelessWidget {
  const _LogoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.progressLogoSurface,
        border: Border.all(color: AppColors.progressLogoBorder),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// 日期 / 金额数据块：白底圆角，上方标签 12、下方数值 14 加粗。
class _ValueBlock extends StatelessWidget {
  const _ValueBlock({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.progressValueSurface,
        borderRadius: BorderRadius.circular(
          LoanProgressCard._valueRadius * scale,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: LoanProgressCard._valuePadding * scale,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.progressValueLabel,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w400,
                height: 14 / 12,
              ),
            ),
            SizedBox(height: LoanProgressCard._valueLabelGap * scale),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: AppColors.progressValueText,
                fontSize: 14 * scale,
                fontWeight: FontWeight.w700,
                height: 18 / 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 按钮行：一枚时居中，两枚时按设计稿的间距并排。
///
/// 网关下发的按钮最多四枚（原卡重试 / 更换账户 / 还款 / 提前结清），设计稿只
/// 画得下两枚，因此超出部分由 [LoanProgressItem.visibleActions] 截断。
class _ActionStrip extends StatelessWidget {
  const _ActionStrip({
    required this.actions,
    required this.scale,
    required this.onActionTap,
  });

  final List<LoanProgressAction> actions;
  final double scale;
  final void Function(LoanProgressAction action)? onActionTap;

  @override
  Widget build(BuildContext context) {
    final buttons = <Widget>[
      for (var index = 0; index < actions.length; index++)
        SizedBox(
          key: ValueKey<String>('loan-progress-action-${actions[index].type}'),
          width: LoanProgressCard._actionWidth * scale,
          height: LoanProgressCard._actionHeight * scale,
          child: _ActionButton(
            action: actions[index],
            scale: scale,
            // 前置按钮用次要样式，末位按钮用主色（设计稿 Try Again + Change）。
            muted: index < actions.length - 1,
            onTap: onActionTap,
          ),
        ),
    ];

    if (buttons.length == 1) {
      return Center(child: buttons.single);
    }
    // 两枚按钮按设计稿固定间隔并排，超过两枚的部分已经在上面截断。
    return Row(
      children: [
        for (final button in buttons) ...[
          if (button != buttons.first)
            SizedBox(width: LoanProgressCard._actionGap * scale),
          button,
        ],
      ],
    );
  }
}

/// 卡片上的操作按钮：设计稿导出的 136x32 切片（两角圆角 18、对角直角），
/// 文案由网关下发后压在切片上，因此换语言不需要重新出图。
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.action,
    required this.scale,
    required this.muted,
    required this.onTap,
  });

  final LoanProgressAction action;
  final double scale;
  final bool muted;
  final void Function(LoanProgressAction action)? onTap;

  @override
  Widget build(BuildContext context) {
    final onPressed = onTap == null ? null : () => onTap!(action);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image(
            image: AssetImage(
              muted
                  ? LoanProgressCard._actionMutedSlice
                  : LoanProgressCard._actionPrimarySlice,
            ),
            fit: BoxFit.fill,
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6 * scale),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  action.label,
                  maxLines: 1,
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 16 * scale,
                    fontWeight: FontWeight.w400,
                    height: 20 / 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 状态徽标：深棕（审核中 / 放款中 / 放款失败）或红色（待还款 / 已逾期）。
///
/// 形状（含右下角的小尾巴）直接用设计稿导出的 @3x 切片，文案由网关下发后
/// 居中压在切片上，因此换语言不需要重新出图。
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.item, required this.scale});

  static const String _darkShape = 'assets/loan_progress_status_dark.png';
  static const String _alertShape = 'assets/loan_progress_status_alert.png';

  final LoanProgressItem item;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Image.asset(
          item.status.isAlert ? _alertShape : _darkShape,
          fit: BoxFit.fill,
          width: LoanProgressCard._badgeWidth * scale,
          height: LoanProgressCard._badgeHeight * scale,
        ),
        Padding(
          padding: EdgeInsets.only(
            left: 8 * scale,
            right: 8 * scale,
            bottom: LoanProgressCard._badgeLabelRise * scale,
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              item.statusLabel,
              maxLines: 1,
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: LoanProgressCard._badgeFontSize * scale,
                fontWeight: FontWeight.w400,
                height: 17 / 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
