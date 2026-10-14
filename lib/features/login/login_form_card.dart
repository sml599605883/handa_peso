import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import 'login_agreement_row.dart';
import 'login_controller.dart';

/// 卡片里的表单。
///
/// 卡片的圆角、底色、边框与右上角的星芒都在卡片切图里，这里只摆设计稿上的
/// 两段标签、两个输入框和协议勾选行。
class LoginFormCard extends StatelessWidget {
  const LoginFormCard({super.key, required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 50, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel('Please fill in your phone number'),
          const SizedBox(height: 16),
          _PhoneRow(controller: controller),
          const SizedBox(height: 24),
          const _FieldLabel('Send SMS verification code'),
          const SizedBox(height: 14),
          _CodeRow(controller: controller),
          const SizedBox(height: 24),
          LoginAgreementRow(controller: controller),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.loginLabelText,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 20 / 16,
      ),
    );
  }
}

/// 手机号输入框：左侧固定 `+63`，只收手机号本体的数字。
class _PhoneRow extends StatelessWidget {
  const _PhoneRow({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return _FieldSurface(
      key: const Key('login-phone-field'),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Text(
            '+63',
            style: TextStyle(
              color: AppColors.loginAccentText,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 20 / 16,
            ),
          ),
          Expanded(
            child: TextField(
              key: const Key('login-phone'),
              controller: controller.phoneField,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              // 只收数字，但不设长度上限：号码是否合法交给控制器提示（设计稿
              // 的「格式无效」分镜要求输入能长到非法长度，截断就不成立了）。
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: controller.onPhoneTyped,
              cursorColor: AppColors.loginAccentText,
              style: _inputTextStyle,
              decoration: _fieldDecoration('Cellphone number'),
            ),
          ),
        ],
      ),
    );
  }
}

/// 验证码输入框：右侧是「Get Code」/倒计时按钮。
class _CodeRow extends StatelessWidget {
  const _CodeRow({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return _FieldSurface(
      key: const Key('login-code-field'),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('login-code'),
              controller: controller.codeField,
              focusNode: controller.codeFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              onChanged: controller.onCodeTyped,
              cursorColor: AppColors.loginAccentText,
              style: _inputTextStyle,
              decoration: _fieldDecoration('Verification Code'),
            ),
          ),
          const SizedBox(width: 8),
          _GetCodeButton(controller: controller),
        ],
      ),
    );
  }
}

/// 「Get Code」按钮：请求成功后开始倒计时，倒计时期间不可再点。
class _GetCodeButton extends StatelessWidget {
  const _GetCodeButton({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final counted = controller.cooldown.remaining.value;
      final waiting = controller.cooldown.isRunning;
      return GestureDetector(
        key: const Key('login-send-code'),
        behavior: HitTestBehavior.opaque,
        onTap: waiting ? null : controller.requestCode,
        child: Container(
          width: 86,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: waiting
                ? AppColors.loginDisabledSurface
                : AppColors.loginCodeButtonSurface,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            waiting ? '${counted}s' : 'Get Code',
            style: TextStyle(
              color: waiting
                  ? AppColors.textOnPrimary
                  : AppColors.loginAccentText,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              height: 20 / 16,
            ),
          ),
        ),
      );
    });
  }
}

/// 白色输入底色 + 8 圆角，高度固定 48（设计稿）。
class _FieldSurface extends StatelessWidget {
  const _FieldSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.only(right: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

const TextStyle _inputTextStyle = TextStyle(
  color: AppColors.loginInputText,
  fontSize: 16,
  fontWeight: FontWeight.w700,
  height: 20 / 16,
);

/// 登录页的输入框独立于全局 `InputDecorationTheme`。
///
/// 全局主题给输入框配了浅灰填充（`filled + fillColor`）与「默认 1px / 聚焦 1.5px」
/// 的描边，但设计稿里的输入框只有一块白色圆角底，没有任何填充色和描边，
/// 所以这里把填充和六种边框全部显式关掉，只看页面自己的白底。
InputDecoration _fieldDecoration(String hint) {
  return InputDecoration(
    isCollapsed: true,
    filled: false,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    hintText: hint,
    hintStyle: const TextStyle(
      color: AppColors.loginLabelText,
      fontSize: 16,
      fontWeight: FontWeight.w400,
      height: 20 / 16,
    ),
  );
}
