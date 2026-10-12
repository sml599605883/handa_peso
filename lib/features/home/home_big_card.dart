import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../core/money/money.dart';

/// The hero "big card" region from design 02-01 (首页-未认证-默认).
///
/// Covers everything from the top of the feed down to (and including) the
/// Apply Now button: the HELLO WELCOME artwork, the dark loan card and the CTA.
///
/// Positions are authored against the 375x812 design canvas and scaled to the
/// available width, so the bitmap artwork keeps its proportions on any device.
class HomeBigCard extends StatelessWidget {
  const HomeBigCard({
    super.key,
    required this.creditLimit,
    required this.onApply,
    this.appName = 'Handa Peso',
    this.termDays = 180,
    this.interestRateLabel = '≤0.5% / Day',
  });

  static const double _designWidth = 375;
  static const double _designHeight = 514;

  /// Stable handle for the Apply Now call-to-action (tests / hit-testing).
  static const Key applyButtonKey = Key('home-big-card-apply');

  final Money creditLimit;
  final VoidCallback onApply;
  final String appName;
  final int termDays;
  final String interestRateLabel;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / _designWidth;
        double px(num value) => value * scale;

        return SizedBox(
          width: constraints.maxWidth,
          height: px(_designHeight),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // HELLO WELCOME halftone header artwork (design: 330x276 @ 22.5,20).
              Positioned(
                left: px(22.5),
                top: px(20),
                width: px(330),
                height: px(276),
                child: Image.asset(
                  'assets/home_hero_hello_bg.png',
                  fit: BoxFit.fill,
                ),
              ),
              // Card frame: APP NAME banner, dark amount panel, terms strip.
              Positioned(
                left: px(12),
                top: px(110),
                width: px(349),
                height: px(294),
                child: Image.asset(
                  'assets/home_loan_card_bg.png',
                  fit: BoxFit.fill,
                ),
              ),
              Positioned(
                left: px(52),
                top: px(126),
                child: _AppNameBadge(name: appName, scale: scale),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: px(178),
                child: Text(
                  'Available up to',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textOnPrimary,
                    fontSize: px(20),
                    fontWeight: FontWeight.w500,
                    height: 28 / 20,
                  ),
                ),
              ),
              Positioned(
                left: px(30),
                right: px(30),
                top: px(222),
                child: _GradientAmount(amount: creditLimit.format(), scale: scale),
              ),
              Positioned(
                left: px(26),
                top: px(332),
                width: px(323),
                height: px(58),
                child: _LoanTerms(
                  termDays: termDays,
                  interestRateLabel: interestRateLabel,
                  scale: scale,
                ),
              ),
              Positioned(
                left: px(14),
                right: px(14),
                top: px(414),
                child: Text(
                  'Complete the authentication in just 3 minutes and get ₱60,000',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.heroCaption,
                    fontSize: px(12),
                    height: 16 / 12,
                  ),
                ),
              ),
              Positioned(
                left: px(48),
                top: px(458),
                width: px(278),
                height: px(56),
                child: _ApplyNowButton(onPressed: onApply),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppNameBadge extends StatelessWidget {
  const _AppNameBadge({required this.name, required this.scale});

  final String name;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28 * scale,
          height: 28 * scale,
          decoration: const BoxDecoration(
            color: AppColors.surface,
            shape: BoxShape.circle,
          ),
        ),
        SizedBox(width: 6 * scale),
        Text(
          name.toUpperCase(),
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Amount with the design's silver vertical gradient and 2px hard drop shadow.
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

class _LoanTerms extends StatelessWidget {
  const _LoanTerms({
    required this.termDays,
    required this.interestRateLabel,
    required this.scale,
  });

  final int termDays;
  final String interestRateLabel;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _TermColumn(
            label: 'Loan terms',
            value: '$termDays Days',
            scale: scale,
          ),
        ),
        Container(
          width: 1 * scale,
          height: 26 * scale,
          color: AppColors.heroDivider,
        ),
        Expanded(
          child: _TermColumn(
            label: 'Interest rate',
            value: interestRateLabel,
            scale: scale,
          ),
        ),
      ],
    );
  }
}

class _TermColumn extends StatelessWidget {
  const _TermColumn({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontSize: 12 * scale, height: 14 / 12);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, textAlign: TextAlign.center, style: style.copyWith(color: AppColors.heroLabel)),
        Text(value, textAlign: TextAlign.center, style: style.copyWith(color: AppColors.heroValue)),
      ],
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
