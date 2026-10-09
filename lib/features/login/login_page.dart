import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import 'login_controller.dart';

class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.screenPadding,
            vertical: AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text('Welcome back', style: textTheme.headlineSmall),
              const SizedBox(height: AppSpacing.xs),
              Text(
                'Sign in with your mobile number to continue.',
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              _PhoneField(controller: controller),
              const SizedBox(height: AppSpacing.sm),
              _CodeField(controller: controller),
              const SizedBox(height: AppSpacing.xs),
              Obx(
                () => controller.errorText.value == null
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                        child: Text(
                          controller.errorText.value!,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
                        ),
                      ),
              ),
              _AgreementRow(controller: controller),
              const SizedBox(height: AppSpacing.lg),
              Obx(
                () => FilledButton(
                  key: const Key('login-submit'),
                  onPressed: controller.canSubmit ? controller.submit : null,
                  child: controller.submitting.value
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.textOnPrimary,
                          ),
                        )
                      : const Text('Sign in'),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Text(
                  'Handa Peso is a loan matchmaking platform, not a lender.',
                  style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('login-phone'),
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(12),
      ],
      onChanged: controller.onPhoneChanged,
      decoration: const InputDecoration(
        labelText: 'Mobile number',
        hintText: '9XX XXX XXXX',
        prefixIcon: Icon(Icons.phone_iphone_rounded),
      ),
    );
  }
}

class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('login-code'),
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      onChanged: controller.onCodeChanged,
      decoration: InputDecoration(
        labelText: 'Verification code',
        prefixIcon: const Icon(Icons.password_rounded),
        suffixIcon: TextButton(
          key: const Key('login-send-code'),
          onPressed: controller.canSendCode ? controller.sendCode : null,
          child: Obx(
            () => Text(
              controller.countdown.value > 0 ? '${controller.countdown.value}s' : 'Send',
            ),
          ),
        ),
      ),
    );
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Obx(
          () => Checkbox(
            key: const Key('login-agreement'),
            value: controller.agreed.value,
            onChanged: (value) => controller.onAgreementChanged(value ?? false),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.sm),
            child: Wrap(
              children: [
                const Text('I agree to the '),
                GestureDetector(
                  onTap: () => AppNavigator.toWebView(
                    url: 'https://www.handapeso.example/terms',
                    title: 'Terms of Service',
                  ),
                  child: const Text(
                    'Terms',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                const Text(' and '),
                GestureDetector(
                  onTap: () => AppNavigator.toWebView(
                    url: 'https://www.handapeso.example/privacy',
                    title: 'Privacy Policy',
                  ),
                  child: const Text(
                    'Privacy Policy',
                    style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
