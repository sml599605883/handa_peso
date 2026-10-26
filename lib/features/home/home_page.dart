import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/layout/responsive_layout.dart';
import '../../app/widgets/app_empty_state.dart';
import '../main_shell/main_controller.dart';
import 'home_banner.dart';
import 'home_big_card.dart';
import 'home_recommendations.dart';
import 'customer_service_shortcut.dart';

/// 首页信息流：设计稿 02-01（未认证-默认 / 单期 / 多期）与 02-02（认证进行中）。
///
/// 顶部主视觉按满幅出血设计，因此不套 SafeArea；页面背景渐变由
/// `HandaPesoApp` 统一提供。
class HomePage extends GetView<MainController> {
  const HomePage({super.key});

  /// 主视觉与宣传条之间的间距（设计稿 18）。
  static const double _bannerGap = 18;

  /// 各内容块之间的间距（设计稿 20）。
  static const double _sectionGap = 20;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final data = controller.overviewData.value;
      final error = controller.overviewError.value;

      if (controller.overviewLoading.value && data == null) {
        return _withCustomerService(
          context,
          const Center(child: CircularProgressIndicator()),
        );
      }
      if (data == null || data.isEmpty) {
        return _withCustomerService(
          context,
          SafeArea(
            child: AppEmptyState(
              icon: error == null
                  ? Icons.inbox_rounded
                  : Icons.cloud_off_rounded,
              title: error == null
                  ? 'Nothing here yet'
                  : 'We could not load your home feed',
              description: error ?? 'Pull down to refresh your offers.',
              action: FilledButton(
                onPressed: controller.refreshOverview,
                child: Text(error == null ? 'Refresh' : 'Try again'),
              ),
            ),
          ),
        );
      }

      final card = data.loanCard;
      return LayoutBuilder(
        builder: (context, constraints) {
          final metrics = AppResponsiveMetrics(
            screenWidth: constraints.maxWidth,
            safeTop: MediaQuery.paddingOf(context).top,
            safeBottom: MediaQuery.paddingOf(context).bottom,
          );
          final scale = metrics.scale;
          return _withCustomerService(
            context,
            RefreshIndicator(
              onRefresh: controller.refreshOverview,
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
                    isActive: controller.homeOnScreen.value,
                    onTap: controller.openBanner,
                  ),
                  if (data.offers.isNotEmpty) ...[
                    SizedBox(height: _sectionGap * scale),
                    HomeRecommendations(
                      offers: data.offers,
                      scale: scale,
                      onApply: (offer) =>
                          controller.applyNow(offer.productId, source: 7),
                    ),
                  ],
                  SizedBox(height: _sectionGap * scale),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Widget _withCustomerService(BuildContext context, Widget content) {
    return Stack(
      children: [
        Positioned.fill(child: content),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          right: 20,
          child: CustomerServiceShortcut(
            buttonKey: const Key('home-customer-service'),
            onTap: controller.openCustomerService,
          ),
        ),
      ],
    );
  }
}
