import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import 'login_design.dart';

/// 返回键：白色圆角底与棕色箭头都在切图里（设计稿 24x24）。
///
/// 登录页可能是被二级页面推出来的，也可能直接是栈底；能回退就回退，否则回首页。
class LoginBackButton extends StatelessWidget {
  const LoginBackButton({super.key});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('login-back'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (Get.key.currentState?.canPop() ?? false) {
          Get.back<void>();
          return;
        }
        AppNavigator.toMain();
      },
      child: const Image(
        image: AssetImage(LoginDesign.backAsset),
        fit: BoxFit.fill,
      ),
    );
  }
}
