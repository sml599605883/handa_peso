import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/app_colors.dart';
import 'login_controller.dart';

/// 主按钮：可提交时用暖橙渐变，否则是设计稿里的灰色不可用态。
///
/// 灰态也保持可点：手机号格式不对、协议没勾选这类问题由控制器给出具体提示，
/// 比「按钮点了没反应」更好排查。
class LoginSubmitButton extends StatelessWidget {
  const LoginSubmitButton({super.key, required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final ready = controller.isSignInReady;
      return GestureDetector(
        key: const Key('login-submit'),
        behavior: HitTestBehavior.opaque,
        onTap: controller.signIn,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: ready ? null : AppColors.loginDisabledSurface,
            gradient: ready ? AppColors.homeWarmGradient : null,
            borderRadius: BorderRadius.circular(26),
          ),
          child: Center(
            child: Text(
              'Sign up / Sign in',
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w700,
                height: 24 / 20,
              ),
            ),
          ),
        ),
      );
    });
  }
}
