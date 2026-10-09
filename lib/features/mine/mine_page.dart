import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/routes/app_routes.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../main_shell/main_controller.dart';

class MinePage extends GetView<MainController> {
  const MinePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final signedIn = controller.phoneNumber.value.isNotEmpty;
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: ListView(
          padding: const EdgeInsets.all(AppSpacing.screenPadding),
          children: [
            _ProfileHeader(phone: controller.phoneNumber.value, signedIn: signedIn),
            if (!signedIn) ...[
              const SizedBox(height: AppSpacing.sm),
              const _SignInCard(),
            ],
            const SizedBox(height: AppSpacing.md),
          _MenuGroup(
            items: [
              _MenuItem(
                icon: Icons.receipt_long_rounded,
                label: 'My orders',
                onTap: AppNavigator.toOrders,
              ),
              _MenuItem(
                icon: Icons.calculate_rounded,
                label: 'Repayment calculator',
                onTap: AppNavigator.toCalculator,
              ),
              _MenuItem(
                icon: Icons.verified_user_rounded,
                label: 'Verification',
                onTap: AppNavigator.toCertification,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _MenuGroup(
            items: [
              _MenuItem(
                icon: Icons.campaign_rounded,
                label: 'Announcements',
                onTap: AppNavigator.toAnnouncements,
              ),
              _MenuItem(
                icon: Icons.support_agent_rounded,
                label: 'Support centre',
                onTap: AppNavigator.toSupport,
              ),
              _MenuItem(
                icon: Icons.privacy_tip_rounded,
                label: 'Privacy policy',
                onTap: () => AppNavigator.toWebView(
                  url: 'https://www.handapeso.example/privacy',
                  title: 'Privacy Policy',
                ),
              ),
            ],
          ),
            if (signedIn) ...[
              const SizedBox(height: AppSpacing.sm),
              _MenuGroup(
                items: [
                  _MenuItem(
                    icon: Icons.delete_outline_rounded,
                    label: 'Delete account',
                    onTap: () => Get.toNamed<void>(AppRoutes.accountDeletion),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(
                key: const Key('mine-sign-out'),
                onPressed: controller.logout,
                child: const Text('Sign out'),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            const Center(child: _VersionLabel()),
          ],
        ),
      );
    });
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.phone, required this.signedIn});

  final String phone;
  final bool signedIn;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 28,
            backgroundColor: AppColors.onPrimaryOverlay,
            child: Icon(Icons.person_rounded, color: AppColors.textOnPrimary, size: 30),
          ),
          const SizedBox(width: AppSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Handa Peso',
                style: TextStyle(color: AppColors.textOnPrimary, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                signedIn ? phone : 'Browsing as guest',
                style: const TextStyle(color: AppColors.onPrimaryMuted, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignInCard extends StatelessWidget {
  const _SignInCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.cardPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Sign in for the full experience', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'View your orders, track repayment and manage your account.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              key: const Key('mine-sign-in'),
              onPressed: () => AppNavigator.toLogin(),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          for (var index = 0; index < items.length; index++) ...[
            items[index],
            if (index != items.length - 1)
              const Divider(height: 1, indent: AppSpacing.xxl),
          ],
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
      onTap: onTap,
    );
  }
}

class _VersionLabel extends StatelessWidget {
  const _VersionLabel();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<PackageInfo>(
      future: PackageInfo.fromPlatform(),
      builder: (context, snapshot) {
        final info = snapshot.data;
        final label = info == null ? 'Handa Peso' : 'Handa Peso v${info.version} (${info.buildNumber})';
        return Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
        );
      },
    );
  }
}
