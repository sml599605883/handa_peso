import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../main_shell/main_controller.dart';
import '../../app/widgets/app_empty_state.dart';
import 'home_banner.dart';
import 'home_big_card.dart';
import 'home_recommendations.dart';

/// 首页信息流：设计稿 02-01（未认证-默认 / 单期 / 多期）与 02-02（认证进行中）。
///
/// 顶部主视觉按满幅出血设计，因此不套 SafeArea；页面背景渐变由
/// `HandaPesoApp` 统一提供。
class HomePage extends GetView<MainController> {
  const HomePage({super.key});

  static const double _designWidth = 375;

  /// 主视觉与宣传条之间的间距（设计稿 18）。
  static const double _bannerGap = 18;

  /// 各内容块之间的间距（设计稿 20）。
  static const double _sectionGap = 20;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.homeData.value;
      final error = controller.homeError.value;

      if (controller.homeLoading.value && data == null) {
        return const Center(child: CircularProgressIndicator());
      }
      if (data == null || data.isEmpty) {
        return SafeArea(
          child: AppEmptyState(
            icon: error == null ? Icons.inbox_rounded : Icons.cloud_off_rounded,
            title: error == null
                ? 'Nothing here yet'
                : 'We could not load your home feed',
            description: error ?? 'Pull down to refresh your offers.',
            action: FilledButton(
              onPressed: controller.refreshHome,
              child: Text(error == null ? 'Refresh' : 'Try again'),
            ),
          ),
        );
      }

      final card = data.loanCard;
      return LayoutBuilder(
        builder: (context, constraints) {
          final scale = constraints.maxWidth / _designWidth;
          return RefreshIndicator(
            onRefresh: controller.refreshHome,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                if (card != null) ...[
                  HomeBigCard(
                    card: card,
                    onApply: () => controller.applyNow(card.productId),
                  ),
                  SizedBox(height: _bannerGap * scale),
                ],
                HomeBanner(
                  banners: data.banners,
                  scale: scale,
                  isActive: controller.homeVisible.value,
                  onTap: controller.openBanner,
                ),
                if (data.offers.isNotEmpty) ...[
                  SizedBox(height: _sectionGap * scale),
                  HomeRecommendations(
                    offers: data.offers,
                    scale: scale,
                    onApply: (offer) => controller.applyNow(offer.productId),
                  ),
                ],
                SizedBox(height: _sectionGap * scale),
              ],
            ),
          );
        },
      );
    });
  }
}
