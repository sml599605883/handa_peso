import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'home_data.dart';

/// 首页推荐列表（设计稿 02-01 多期 / 单期）。
class HomeRecommendations extends StatelessWidget {
  const HomeRecommendations({
    super.key,
    required this.offers,
    required this.scale,
    required this.onApply,
  });

  /// 推荐卡片之间的垂直间距（设计稿 14）。
  static const double _cardGap = 14;

  final List<HomeProductOffer> offers;
  final double scale;
  final ValueChanged<HomeProductOffer> onApply;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 14 * scale),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _RecommendationHeader(scale: scale),
          SizedBox(height: _cardGap * scale),
          for (var index = 0; index < offers.length; index++) ...[
            if (index > 0) SizedBox(height: _cardGap * scale),
            _OfferCard(
              offer: offers[index],
              scale: scale,
              onApply: () => onApply(offers[index]),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationHeader extends StatelessWidget {
  const _RecommendationHeader({required this.scale});

  static const double _emojiSize = 26;

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: _emojiSize * scale,
          height: _emojiSize * scale,
          child: Image.asset('assets/home_recommendation_emoji.png'),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: Text(
            'Recommendation!',
            style: TextStyle(
              color: AppColors.heroValue,
              fontSize: 20 * scale,
              fontWeight: FontWeight.w700,
              letterSpacing: -1 * scale,
              height: 30 / 20,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.homeMoreSurface,
            borderRadius: BorderRadius.circular(8 * scale),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10 * scale,
              vertical: 5 * scale,
            ),
            child: Text(
              'More',
              style: TextStyle(
                color: AppColors.heroValue,
                fontSize: 12 * scale,
                fontWeight: FontWeight.w500,
                height: 16 / 12,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({
    required this.offer,
    required this.scale,
    required this.onApply,
  });

  static const double _designHeight = 120;
  static const double _padding = 14;
  static const double _logoSize = 24;
  static const double _buttonHeight = 36;
  static const double _buttonRadius = 18;

  final HomeProductOffer offer;
  final double scale;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final enabled = offer.tone != HomeApplyTone.disabled;

    return SizedBox(
      key: Key('home-offer-card-${offer.productId}'),
      height: _designHeight * scale,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.homeCardRow,
          borderRadius: BorderRadius.circular(14 * scale),
        ),
        child: Padding(
          padding: EdgeInsets.all(_padding * scale),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  _logo(),
                  SizedBox(width: 10 * scale),
                  Expanded(
                    child: Text(
                      offer.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.heroValue,
                        fontSize: 12 * scale,
                        height: 14 / 12,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 10 * scale),
              Container(height: 1, color: AppColors.homeCardDivider),
              SizedBox(height: 13 * scale),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _amountBlock(),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _termsBlock(),
                            SizedBox(width: 17 * scale),
                            _applyButton(enabled),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _amountBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.amountText,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: AppColors.heroValue,
            fontSize: 22 * scale,
            fontWeight: FontWeight.w700,
            height: 26 / 22,
          ),
        ),
        SizedBox(height: 4 * scale),
        Text(
          offer.amountCaption,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: AppColors.homePeriodLabel,
            fontSize: 12 * scale,
            height: 14 / 12,
          ),
        ),
      ],
    );
  }

  Widget _termsBlock() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          offer.termText,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: AppColors.heroValue,
            fontSize: 14 * scale,
            height: 18 / 14,
          ),
        ),
        SizedBox(height: 8 * scale),
        Text(
          offer.rateText,
          maxLines: 1,
          softWrap: false,
          style: TextStyle(
            color: AppColors.heroValue,
            fontSize: 14 * scale,
            height: 18 / 14,
          ),
        ),
      ],
    );
  }

  Widget _logo() {
    final size = _logoSize * scale;
    final uri = Uri.tryParse(offer.logoUrl);
    final hasLogo = uri != null && uri.hasScheme;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.homeLogoPlaceholder,
        border: Border.all(color: AppColors.homeLogoPlaceholderBorder),
        borderRadius: BorderRadius.circular(4 * scale),
      ),
      clipBehavior: Clip.antiAlias,
      child: hasLogo
          ? Image.network(
              offer.logoUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
            )
          : null,
    );
  }

  Widget _applyButton(bool enabled) {
    final title = Text(
      offer.buttonText,
      maxLines: 1,
      softWrap: false,
      style: TextStyle(
        color: AppColors.textOnPrimary,
        fontSize: 16 * scale,
        fontWeight: FontWeight.w700,
        height: 20 / 16,
      ),
    );
    final padding = EdgeInsets.symmetric(
      horizontal: 13 * scale,
      vertical: 8 * scale,
    );
    final shape = BorderRadius.only(
      topRight: Radius.circular(_buttonRadius * scale),
      bottomLeft: Radius.circular(_buttonRadius * scale),
    );

    final button = switch (offer.tone) {
      HomeApplyTone.highlight => DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppColors.homeWarmGradient,
          borderRadius: shape,
        ),
        child: Padding(padding: padding, child: title),
      ),
      HomeApplyTone.normal => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.homeApplyNormal,
          borderRadius: shape,
        ),
        child: Padding(padding: padding, child: title),
      ),
      HomeApplyTone.disabled => DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.homeApplyDisabled,
          borderRadius: shape,
        ),
        child: Padding(padding: padding, child: title),
      ),
    };

    // 设计稿为 margin 上 6 / 下 2，卡片内容区恰好 44 高。
    return Padding(
      padding: EdgeInsets.only(top: 6 * scale, bottom: 2 * scale),
      child: Semantics(
        button: enabled,
        enabled: enabled,
        label: offer.buttonText,
        child: GestureDetector(
          key: Key('home-offer-${offer.productId}'),
          onTap: enabled ? onApply : null,
          behavior: HitTestBehavior.opaque,
          child: SizedBox(height: _buttonHeight * scale, child: button),
        ),
      ),
    );
  }
}
