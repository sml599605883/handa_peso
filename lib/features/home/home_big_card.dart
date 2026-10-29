import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'home_data.dart';

/// 首页主视觉区（设计稿 02-01 / 02-02）。
///
/// 覆盖 HELLO WELCOME 插画、借款卡片、认证进度票据、认证引导文案以及
/// 「Apply Now」按钮。所有元素按 375x812 设计稿画布绝对定位，再按可用宽度
/// 等比缩放，因此位图素材在任意机型上都不会变形。
///
/// 卡片底板（容器、金额面板、条款条）全部由代码绘制，素材只保留顶部的
/// 深色装饰条，因此认证进度把卡片拉长时底板可以自由延伸而不会被拉伸变形。
///
/// 卡片高度由下发的数据决定：未认证时为 262（设计稿 142~404），
/// 有认证进度时下方多出 119 的票据区（设计稿长到 523）。
class HomeBigCard extends StatelessWidget {
  const HomeBigCard({super.key, required this.card, required this.onApply});

  /// 「立即申请」按钮的稳定标识（测试 / 命中测试用）。
  static const Key applyButtonKey = Key('home-big-card-apply');

  /// 整张大卡的点击热区标识（测试 / 命中测试用）。
  static const Key cardTapKey = Key('home-big-card-tap');

  static const double _designWidth = 375;

  // 插画（设计稿 330x276 @ 22.5,20）。
  static const double _heroLeft = 22.5;
  static const double _heroTop = 20;
  static const double _heroWidth = 330;
  static const double _heroHeight = 276;

  // 顶部装饰条素材（设计稿 349x66 @ 12,110）：深色渐变 + 左侧线环 +
  // 右侧闪电贴纸。素材自带透明通道，直接叠在卡片底板上即可。
  static const double _headerLeft = 12;
  static const double _headerTop = 110;
  static const double _headerWidth = 349;
  static const double _headerHeight = 66;

  // 卡片底板（设计稿 347x262 @ 14,142）。
  static const double _frameLeft = 14;
  static const double _frameTop = 142;
  static const double _frameWidth = 347;
  static const double _frameHeight = 262;
  static const double _frameRadius = 25;
  static const double _frameStroke = 2;
  static const double _frameProgressExtra = 119;

  // 深色金额面板（设计稿 332x148 @ 20,174），2px 白色描边。
  static const double _panelLeft = 20;
  static const double _panelTop = 174;
  static const double _panelWidth = 332;
  static const double _panelHeight = 148;
  static const double _panelRadius = 16;
  static const double _panelStroke = 2;

  // 条款条（设计稿 323x58 @ 26,332）：两侧各切掉一个票券缺口。
  static const double _termsLeft = 26;
  static const double _termsTop = 332;
  static const double _termsWidth = 323;
  static const double _termsHeight = 58;
  static const double _termsRadius = 9;
  static const double _termsNotch = 12;

  // 认证进度票据（设计稿 323x108 @ 26,404）。
  static const double _ticketLeft = 26;
  static const double _ticketTop = 404;
  static const double _ticketWidth = 323;
  static const double _ticketHeight = 108;

  static const double _captionGap = 10;
  static const double _captionHeight = 32;
  static const double _applyGap = 12;
  static const double _applyLeft = 48;
  static const double _applyWidth = 278;
  static const double _applyHeight = 56;

  final HomeLoanCard card;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / _designWidth;
        double px(num value) => value * scale;

        final frameBottom =
            _frameTop +
            _frameHeight +
            (card.hasLimitSteps ? _frameProgressExtra : 0);
        final captionTop = frameBottom + _captionGap;
        final applyTop = captionTop + _captionHeight + _applyGap;

        return SizedBox(
          width: constraints.maxWidth,
          height: px(applyTop + _applyHeight),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: px(_heroLeft),
                top: px(_heroTop),
                width: px(_heroWidth),
                height: px(_heroHeight),
                child: Image.asset(
                  'assets/home_hero_hello_bg.png',
                  fit: BoxFit.fill,
                ),
              ),
              // 卡片底板：奶油色圆角容器，带认证进度时整体向下拉长。
              Positioned(
                left: px(_frameLeft),
                top: px(_frameTop),
                width: px(_frameWidth),
                height: px(frameBottom - _frameTop),
                child: _CardFrame(
                  scale: scale,
                  radius: _frameRadius,
                  stroke: _frameStroke,
                ),
              ),
              // 顶部装饰条覆盖在底板之上：深色渐变向内收进边框，
              // 线环与闪电贴纸则按设计稿溢出到卡片外。
              Positioned(
                left: px(_headerLeft),
                top: px(_headerTop),
                width: px(_headerWidth),
                height: px(_headerHeight),
                child: Image.asset(
                  'assets/home_loan_card_header.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: px(52),
                top: px(126),
                child: _AppNameBadge(
                  name: card.productName,
                  logoUrl: card.logoUrl,
                  scale: scale,
                ),
              ),
              Positioned(
                left: px(_panelLeft),
                top: px(_panelTop),
                width: px(_panelWidth),
                height: px(_panelHeight),
                child: _AmountPanel(
                  caption: card.amountCaption,
                  amount: card.amountText,
                  scale: scale,
                  radius: _panelRadius,
                  stroke: _panelStroke,
                ),
              ),
              Positioned(
                left: px(_termsLeft),
                top: px(_termsTop),
                width: px(_termsWidth),
                height: px(_termsHeight),
                child: _CouponSurface(
                  scale: scale,
                  radius: _termsRadius,
                  notch: _termsNotch,
                  child: _CardTerms(card: card, scale: scale),
                ),
              ),
              if (card.hasLimitSteps)
                Positioned(
                  left: px(_ticketLeft),
                  top: px(_ticketTop),
                  width: px(_ticketWidth),
                  height: px(_ticketHeight),
                  child: _LimitTicket(steps: card.limitSteps, scale: scale),
                ),
              Positioned(
                left: px(14),
                right: px(14),
                top: px(captionTop),
                child: Text(
                  card.processText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.heroCaption,
                    fontSize: px(12),
                    height: 16 / 12,
                  ),
                ),
              ),
              // 整张大卡都是申请入口，与其它支线一致：点卡片任意位置等价于点
              // Apply Now（按钮本身是同一回调，视觉上只是更强的引导）。
              // 热区覆盖卡片底板到按钮底部，不盖住上方的 HELLO WELCOME 插画。
              Positioned(
                left: px(_frameLeft),
                right: px(_frameLeft),
                top: px(_frameTop),
                height: px(applyTop + _applyHeight - _frameTop),
                child: GestureDetector(
                  key: cardTapKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: onApply,
                ),
              ),
              Positioned(
                left: px(_applyLeft),
                top: px(applyTop),
                width: px(_applyWidth),
                height: px(_applyHeight),
                child: _ApplyNowButton(onPressed: onApply),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 卡片底板：浅米色圆角容器 + 2px 描边，随认证进度向下延伸。
class _CardFrame extends StatelessWidget {
  const _CardFrame({
    required this.scale,
    required this.radius,
    required this.stroke,
  });

  final double scale;
  final double radius;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.homeCardSurface,
        border: Border.all(
          color: AppColors.homeCardBorder,
          width: stroke * scale,
        ),
        borderRadius: BorderRadius.circular(radius * scale),
      ),
    );
  }
}

/// 条款条底：浅色票券面，左右两侧各切掉一个半圆缺口。
class _CouponSurface extends StatelessWidget {
  const _CouponSurface({
    required this.scale,
    required this.radius,
    required this.notch,
    required this.child,
  });

  final double scale;
  final double radius;
  final double notch;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CouponClipper(radius: radius * scale, notch: notch * scale),
      child: ColoredBox(color: AppColors.homeCardRow, child: child),
    );
  }
}

/// 票券轮廓：圆角矩形减去左右两个与边缘相切的半圆。
class _CouponClipper extends CustomClipper<Path> {
  const _CouponClipper({required this.radius, required this.notch});

  final double radius;
  final double notch;

  @override
  Path getClip(Size size) {
    final body = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    final centerY = size.height / 2;
    final notches = Path()
      ..addOval(Rect.fromCircle(center: Offset(0, centerY), radius: notch))
      ..addOval(
        Rect.fromCircle(center: Offset(size.width, centerY), radius: notch),
      );
    return Path.combine(PathOperation.difference, body, notches);
  }

  @override
  bool shouldReclip(covariant _CouponClipper oldClipper) =>
      oldClipper.radius != radius || oldClipper.notch != notch;
}

class _AppNameBadge extends StatelessWidget {
  const _AppNameBadge({
    required this.name,
    required this.logoUrl,
    required this.scale,
  });

  static const double _size = 28;

  final String name;
  final String logoUrl;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _size * scale,
          height: _size * scale,
          child: ClipOval(child: _logo()),
        ),
        SizedBox(width: 10 * scale),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w500,
            height: 22 / 16,
          ),
        ),
      ],
    );
  }

  /// 后端没有下发 Logo 时保留设计稿的白色圆形占位。
  Widget _logo() {
    final uri = Uri.tryParse(logoUrl);
    if (uri == null || !uri.hasScheme) {
      return const ColoredBox(color: AppColors.surface);
    }
    return Image.network(
      logoUrl,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => const ColoredBox(color: AppColors.surface),
    );
  }
}

/// 深色面板内的「Available up to / ₱50,000」区块。
class _AmountPanel extends StatelessWidget {
  const _AmountPanel({
    required this.caption,
    required this.amount,
    required this.scale,
    required this.radius,
    required this.stroke,
  });

  final String caption;
  final String amount;
  final double scale;
  final double radius;
  final double stroke;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppColors.homeAmountPanelGradient,
        border: Border.all(color: AppColors.surface, width: stroke * scale),
        borderRadius: BorderRadius.circular(radius * scale),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            caption,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textOnPrimary,
              fontSize: 20 * scale,
              fontWeight: FontWeight.w600,
              height: 28 / 20,
            ),
          ),
          _GradientAmount(amount: amount, scale: scale),
        ],
      ),
    );
  }
}

/// 带设计稿银色垂直渐变和 2px 硬投影的金额文本。
class _GradientAmount extends StatelessWidget {
  const _GradientAmount({required this.amount, required this.scale});

  final String amount;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontSize: 60 * scale,
      fontWeight: FontWeight.w700,
      height: 1,
    );
    return SizedBox(
      height: 75 * scale,
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 2 * scale),
                child: Text(
                  amount,
                  textAlign: TextAlign.center,
                  style: style.copyWith(color: AppColors.heroAmountShadow),
                ),
              ),
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (bounds) =>
                    AppColors.heroAmountGradient.createShader(bounds),
                child: Text(
                  amount,
                  textAlign: TextAlign.center,
                  style: style.copyWith(color: AppColors.surface),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 白色条款条：单期展示「期限 / 利率」，多期展示每期利率。
class _CardTerms extends StatelessWidget {
  const _CardTerms({required this.card, required this.scale});

  final HomeLoanCard card;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final periods = card.periodTerms;
    if (periods.isEmpty) {
      return Row(
        children: [
          Expanded(
            child: _CaptionValue(
              caption: card.termCaption,
              value: card.termText,
              scale: scale,
            ),
          ),
          Container(
            width: 2 * scale,
            height: 26 * scale,
            color: AppColors.heroDivider,
          ),
          Expanded(
            child: _CaptionValue(
              caption: card.rateCaption,
              value: card.rateText,
              scale: scale,
            ),
          ),
        ],
      );
    }

    final columns = <Widget>[
      for (var index = 0; index < periods.length; index++) ...[
        if (index > 0)
          Container(
            width: 1 * scale,
            height: 26 * scale,
            color: AppColors.heroDivider,
          ),
        // 期数与利率文案由后端下发，长度不定；超出设计宽度时整体等比缩小，
        // 避免长文案把条款条撑破。
        Flexible(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: _PeriodColumn(term: periods[index], scale: scale),
          ),
        ),
      ],
    ];

    return Center(
      child: SizedBox(
        width: periods.length > 1 ? 228 * scale : 66 * scale,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: columns,
        ),
      ),
    );
  }
}

class _CaptionValue extends StatelessWidget {
  const _CaptionValue({
    required this.caption,
    required this.value,
    required this.scale,
  });

  final String caption;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12 * scale, height: 14 / 12);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          caption,
          textAlign: TextAlign.center,
          style: style.copyWith(color: AppColors.heroLabel),
        ),
        Text(
          value,
          textAlign: TextAlign.center,
          style: style.copyWith(color: AppColors.heroValue),
        ),
      ],
    );
  }
}

/// 单期方案：期数徽标 + 「Period」+ 该期利率。
class _PeriodColumn extends StatelessWidget {
  const _PeriodColumn({required this.term, required this.scale});

  final HomePeriodTerm term;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 设计稿的 52 只是「徽标 + 最短说明」的宽度。`coaxing` 下发的分期名
        // 长度不定（例如 `Installment`），写死 52 会让文案在 39 像素里被硬裁
        // 成 `Installr`；因此这里只把它当最小宽度，文案按内容撑开，整条超出
        // 条款条宽度时再由外层 `FittedBox` 等比缩小。
        ConstrainedBox(
          constraints: BoxConstraints(minWidth: 52 * scale),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(
                  3 * scale,
                  0,
                  3 * scale,
                  2 * scale,
                ),
                decoration: BoxDecoration(
                  color: AppColors.homePeriodBadge,
                  borderRadius: BorderRadius.circular(4 * scale),
                ),
                child: Text(
                  term.period,
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: 10 * scale,
                    fontWeight: FontWeight.w700,
                    height: 12 / 10,
                  ),
                ),
              ),
              // 徽标与说明之间的固定间隙：内容撑开最小宽度后，`spaceBetween`
              // 已经没有可分配的余量，两个元素会贴在一起。
              SizedBox(width: 4 * scale),
              Text(
                term.caption,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  color: AppColors.homePeriodLabel,
                  fontSize: 12 * scale,
                  height: 14 / 12,
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          term.rateText,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: AppColors.heroValue,
            fontSize: 12 * scale,
            height: 14 / 12,
          ),
        ),
      ],
    );
  }
}

/// 「My unlocked limit」票据：已解锁额度、当前额度与未解锁额度。
///
/// 下发的筹码只带一个 `selected` 标记，因此以最后一个已达成筹码为「当前」，
/// 其右侧的筹码按未解锁（置灰）处理，与设计稿一致。
class _LimitTicket extends StatelessWidget {
  const _LimitTicket({required this.steps, required this.scale});

  static const double _chipsTop = 53;
  static const double _chipHeight = 28;
  static const double _titleTop = 18;

  final List<HomeLimitStep> steps;
  final double scale;

  @override
  Widget build(BuildContext context) {
    var currentIndex = -1;
    for (var index = 0; index < steps.length; index++) {
      if (steps[index].reached) currentIndex = index;
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/home_limit_ticket.png', fit: BoxFit.fill),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _titleTop * scale,
          child: Text(
            'My unlocked limit',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.heroCaption,
              fontSize: 12 * scale,
              height: 16 / 12,
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: _chipsTop * scale,
          height: _chipHeight * scale,
          child: Center(
            // 额度筹码由后端下发，数量与长度都不固定；超出票据宽度时整体
            // 等比缩小，保证长额度也不会把票据撑破。
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < steps.length; index++) ...[
                    if (index > 0)
                      SizedBox(width: (index == 1 ? 5 : 6) * scale),
                    _LimitChip(
                      step: steps[index],
                      selected: index == currentIndex,
                      locked: index > currentIndex,
                      scale: scale,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LimitChip extends StatelessWidget {
  const _LimitChip({
    required this.step,
    required this.selected,
    required this.locked,
    required this.scale,
  });

  final HomeLimitStep step;
  final bool selected;
  final bool locked;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final textColor = selected
        ? AppColors.textOnPrimary
        : (locked ? AppColors.homeChipLockedText : AppColors.homeChipText);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected
            ? null
            : (locked
                  ? AppColors.homeChipLockedSurface
                  : AppColors.homeChipSurface),
        gradient: selected ? AppColors.homeWarmGradient : null,
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              10 * scale,
              6 * scale,
              9 * scale,
              6 * scale,
            ),
            child: Text(
              step.amountText,
              style: TextStyle(
                color: textColor,
                fontSize: 12 * scale,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                height: 16 / 12,
              ),
            ),
          ),
          if (selected)
            Positioned(
              right: -1 * scale,
              top: 0,
              child: Container(
                width: 6 * scale,
                height: 6 * scale,
                decoration: const BoxDecoration(
                  color: AppColors.homeChipText,
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ApplyNowButton extends StatelessWidget {
  const _ApplyNowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Apply Now',
      child: GestureDetector(
        key: HomeBigCard.applyButtonKey,
        onTap: onPressed,
        behavior: HitTestBehavior.opaque,
        child: Image.asset('assets/apply_now_button.png', fit: BoxFit.fill),
      ),
    );
  }
}
