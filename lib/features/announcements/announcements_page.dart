import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../main_shell/main_shell_page.dart';

/// Fraud-prevention and product guidance shown inside the app.
///
/// The gateway does not expose a public announcements feed, so this content is
/// curated locally. Keeping it in-app (rather than served) also gives each
/// release its own unique content surface.
class AnnouncementsPage extends StatelessWidget {
  const AnnouncementsPage({super.key});

  static const _items = <({IconData icon, String title, String body})>[
    (
      icon: Icons.verified_user_rounded,
      title: 'Borrow only from licensed partners',
      body:
          'Handa Peso is a matchmaking platform. Offers come from licensed '
          'lending partners, and your loan agreement is always issued by them.',
    ),
    (
      icon: Icons.price_check_rounded,
      title: 'Check the full repayment total',
      body:
          'Use the calculator to preview the total repayment before you apply. '
          'Interest and any fees are disclosed up front, never added silently.',
    ),
    (
      icon: Icons.lock_outline_rounded,
      title: 'We never ask for your PIN or OTP',
      body:
          'Support will never request your banking PIN, OTP or password. '
          'Report any such request to in-app support immediately.',
    ),
    (
      icon: Icons.sms_failed_rounded,
      title: 'Ignore off-platform loan offers',
      body:
          'Be wary of offers sent over messaging apps that ask for an advance '
          'fee. Apply only through the app so your data stays protected.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const ShellAppBar(title: 'Announcements'),
      body: ListView.separated(
        padding: const EdgeInsets.all(AppSpacing.screenPadding),
        itemCount: _items.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
        itemBuilder: (context, index) {
          final item = _items[index];
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.icon, color: AppColors.primary),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item.title, style: textTheme.titleMedium),
                        const SizedBox(height: AppSpacing.xxs),
                        Text(item.body, style: textTheme.bodyMedium),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
