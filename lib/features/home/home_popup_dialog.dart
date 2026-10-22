import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'home_popup_models.dart';

bool _popupVisible = false;

/// 返回 true 表示用户触发了弹窗配置里的跳转。
Future<bool> showHomePopup(BuildContext context, HomePopupConfig config) async {
  if (_popupVisible || !config.shouldShow) return false;
  _popupVisible = true;
  try {
    final action = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppColors.accountDialogBarrier,
      builder: (context) => switch (config.kind) {
        HomePopupKind.marketing => _MarketingPopup(config: config),
        HomePopupKind.appUpgrade => _UpgradePopup(config: config),
        HomePopupKind.membershipUpgrade => _MembershipPopup(config: config),
        HomePopupKind.none => const SizedBox.shrink(),
      },
    );
    return action == true;
  } finally {
    _popupVisible = false;
  }
}

class _MarketingPopup extends StatelessWidget {
  const _MarketingPopup({required this.config});

  final HomePopupConfig config;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Center(
          child: GestureDetector(
            key: const Key('home-popup-marketing'),
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.of(context).pop(true),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 343),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(28),
                  child: Image.network(
                    config.imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, loading) =>
                        loading == null ? child : _PopupLoading(),
                    errorBuilder: (_, _, _) => const _PopupImageFallback(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UpgradePopup extends StatelessWidget {
  const _UpgradePopup({required this.config});

  final HomePopupConfig config;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('home-popup-upgrade'),
      backgroundColor: AppColors.homeCardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      title: const Text('New version released'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (config.version.isNotEmpty)
            Text(
              'Version ${config.version}',
              style: const TextStyle(
                color: AppColors.homeChipText,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (config.message.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(config.message),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          key: const Key('home-popup-update'),
          onPressed: config.targetUrl.isEmpty
              ? null
              : () => Navigator.of(context).pop(true),
          child: const Text('Update'),
        ),
      ],
    );
  }
}

class _MembershipPopup extends StatelessWidget {
  const _MembershipPopup({required this.config});

  final HomePopupConfig config;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      key: const Key('home-popup-membership'),
      backgroundColor: AppColors.homeCardSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.md),
      ),
      title: const Text('Membership Upgrade'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (config.previousLevelImage.isNotEmpty)
                  _LevelAvatar(
                    imageUrl: config.previousLevelImage,
                    label: config.previousLevel,
                  ),
                if (config.previousLevel.isNotEmpty &&
                    config.currentLevel.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.textMuted,
                    ),
                  ),
                if (config.currentLevelImage.isNotEmpty)
                  _LevelAvatar(
                    imageUrl: config.currentLevelImage,
                    label: config.currentLevel,
                  ),
              ],
            ),
            if (config.benefits.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              for (final benefit in config.benefits)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                  child: Row(
                    children: [
                      if (benefit.imageUrl.isEmpty)
                        const Icon(
                          Icons.check_circle_rounded,
                          size: 18,
                          color: AppColors.success,
                        )
                      else
                        Image.network(
                          benefit.imageUrl,
                          width: 18,
                          height: 18,
                          errorBuilder: (_, _, _) => const Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: AppColors.success,
                          ),
                        ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(child: Text(benefit.title)),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _LevelAvatar extends StatelessWidget {
  const _LevelAvatar({required this.imageUrl, required this.label});

  final String imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipOval(
          child: Image.network(
            imageUrl,
            width: 64,
            height: 64,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => const SizedBox.square(dimension: 64),
          ),
        ),
        if (label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(label),
          ),
      ],
    );
  }
}

class _PopupLoading extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 320,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _PopupImageFallback extends StatelessWidget {
  const _PopupImageFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 240,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: const Icon(
        Icons.local_offer_rounded,
        size: 48,
        color: AppColors.textMuted,
      ),
    );
  }
}
