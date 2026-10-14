import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import 'login_controller.dart';
import 'login_design.dart';

/// 协议勾选行：左边是设计稿的方框（默认空心），右边两个协议名可以点开 H5。
class LoginAgreementRow extends StatelessWidget {
  const LoginAgreementRow({super.key, required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const Key('login-agreement'),
          behavior: HitTestBehavior.opaque,
          onTap: () =>
              controller.onPrivacyChanged(!controller.privacyAccepted.value),
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Obx(
              () => Image.asset(
                controller.privacyAccepted.value
                    ? LoginDesign.checkboxOn
                    : LoginDesign.checkboxOff,
                key: const Key('login-agreement-checkbox'),
                width: 16,
                height: 16,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _AgreementLinkText(
            onPrivacyTap: () => AppNavigator.toWebView(
              url: controller.privacyUrl,
              title: 'Privacy Policy',
            ),
            onTermsTap: () => AppNavigator.toWebView(
              url: controller.termsUrl,
              title: 'Terms of Service',
            ),
          ),
        ),
      ],
    );
  }
}

/// 「I have read and agree to the Privacy Policy and Terms of Service」。
///
/// 设计稿把两个协议名做成更深的字色，这里保持同样的视觉，同时让它们可点。
class _AgreementLinkText extends StatefulWidget {
  const _AgreementLinkText({
    required this.onPrivacyTap,
    required this.onTermsTap,
  });

  final VoidCallback onPrivacyTap;
  final VoidCallback onTermsTap;

  @override
  State<_AgreementLinkText> createState() => _AgreementLinkTextState();
}

class _AgreementLinkTextState extends State<_AgreementLinkText> {
  late final TapGestureRecognizer _privacyRecognizer;
  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _privacyRecognizer = TapGestureRecognizer()..onTap = widget.onPrivacyTap;
    _termsRecognizer = TapGestureRecognizer()..onTap = widget.onTermsTap;
  }

  @override
  void didUpdateWidget(covariant _AgreementLinkText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _privacyRecognizer.onTap = widget.onPrivacyTap;
    _termsRecognizer.onTap = widget.onTermsTap;
  }

  @override
  void dispose() {
    _privacyRecognizer.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(
      color: AppColors.loginLabelText,
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
    );
    final link = base.copyWith(color: AppColors.loginInputText);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'I have read and agree to the '),
          TextSpan(
            text: 'Privacy Policy',
            style: link,
            recognizer: _privacyRecognizer,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Terms of Service',
            style: link,
            recognizer: _termsRecognizer,
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}
