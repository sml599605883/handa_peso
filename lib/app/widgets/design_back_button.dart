import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../navigation/app_navigator.dart';

/// 二级页面左上角的返回键（设计稿 07-01 个人中心、05-01 订单列表）。
///
/// 白色圆角底与棕色箭头都在切图里（设计稿 24x24），与登录页共用同一张切片。
/// 页面把它摆在设计坐标 (14, 56)；状态栏更高的机型由页面按安全区下移。
class DesignBackButton extends StatelessWidget {
  const DesignBackButton({super.key});

  static const String asset = 'assets/login/login_back.png';

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('design-back'),
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (Get.key.currentState?.canPop() ?? false) {
          Get.back<void>();
          return;
        }
        AppNavigator.toMain();
      },
      child: const Image(image: AssetImage(asset), fit: BoxFit.fill),
    );
  }
}
