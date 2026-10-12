import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../main_shell/main_controller.dart';
import '../main_shell/main_shell_page.dart';
import 'home_big_card.dart';
import 'home_data.dart';

/// Analytics/session tag for the hero card call-to-action.
const String _homeApplyProductId = 'home_card';

class HomePage extends GetView<MainController> {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.transparent,
      child: Obx(() {
        final data = controller.homeData.value;
        final error = controller.homeError.value;
        if (controller.homeLoading.value && data == null) {
          return const SafeArea(child: Center(child: CircularProgressIndicator()));
        }
        if (error != null && data == null) {
          return SafeArea(
            child: AppEmptyState(
              icon: Icons.cloud_off_rounded,
              title: 'We could not load your home feed',
              description: error,
              action: FilledButton(
                onPressed: controller.refreshHome,
                child: const Text('Try again'),
              ),
            ),
          );
        }
        if (data == null) {
          return SafeArea(
            child: AppEmptyState(
              icon: Icons.inbox_rounded,
              title: 'Nothing here yet',
              description: 'Pull down to refresh your offers.',
              action: FilledButton(
                onPressed: controller.refreshHome,
                child: const Text('Refresh'),
              ),
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.refreshHome,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              // The hero artwork is designed full-bleed, with its top edge at
              // the physical top of the screen (design 02-01 y=0).
              HomeBigCard(
                creditLimit: data.creditLimit,
                onApply: () => controller.applyNow(_homeApplyProductId),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.screenPadding,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _CertificationCard(progress: data.progress),
                    const SizedBox(height: AppSpacing.sm),
                    const _QuickActions(),
                    if (data.offers.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Offers for you',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final offer in data.offers) ...[
                        _OfferCard(
                          offer: offer,
                          onApply: () => controller.applyNow(offer.productId),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                      ],
                    ],
                    if (data.announcements.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Announcements',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      for (final item in data.announcements)
                        _AnnouncementTile(announcement: item),
                    ],
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _CertificationCard extends StatelessWidget {
  const _CertificationCard({required this.progress});

  final CertificationProgress progress;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Verification progress', style: textTheme.titleMedium),
                ),
                Text(
                  '${progress.completed}/${progress.total}',
                  style: textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.pill),
              child: LinearProgressIndicator(
                value: progress.ratio,
                minHeight: 8,
                backgroundColor: AppColors.surfaceMuted,
                color: progress.isComplete ? AppColors.success : AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (!progress.isComplete)
              FilledButton(
                onPressed: () => AppNavigator.toCertification(),
                child: const Text('Continue verification'),
              )
            else
              const Row(
                children: [
                  Icon(Icons.verified_rounded, color: AppColors.success, size: 20),
                  SizedBox(width: AppSpacing.xs),
                  Text('You are fully verified', style: TextStyle(color: AppColors.success)),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _QuickAction(
            icon: Icons.calculate_rounded,
            label: 'Calculator',
            onTap: AppNavigator.toCalculator,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _QuickAction(
            icon: Icons.receipt_long_rounded,
            label: 'My orders',
            onTap: AppNavigator.toOrders,
          ),
        ),
        const SizedBox(width: AppSpacing.xs),
        Expanded(
          child: _QuickAction(
            icon: Icons.support_agent_rounded,
            label: 'Support',
            onTap: AppNavigator.toSupport,
          ),
        ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadius.md),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.primary),
            const SizedBox(height: AppSpacing.xs),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer, required this.onApply});

  final LoanOffer offer;
  final VoidCallback onApply;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(offer.title, style: textTheme.titleMedium)),
                Text('APR ${offer.aprPercent}%', style: textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              offer.amount.format(),
              style: textTheme.headlineSmall?.copyWith(color: AppColors.primary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text('Term: ${offer.termDays} days', style: textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: Key('apply-${offer.productId}'),
              onPressed: onApply,
              child: const Text('Apply now'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnouncementTile extends StatelessWidget {
  const _AnnouncementTile({required this.announcement});

  final Announcement announcement;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: ListTile(
        leading: const Icon(Icons.campaign_rounded, color: AppColors.accent),
        title: Text(announcement.title),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => AppNavigator.toWebView(
          url: announcement.url,
          title: announcement.title,
        ),
      ),
    );
  }
}
