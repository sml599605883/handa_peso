import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import 'login_design.dart';

/// 整页主视觉：设计稿的整幅切图铺满画布。
///
/// 比设计稿更高的机型，图片下方用切图底边的同色补齐滚动区域，既不留接缝
/// 也不拉伸画面。
class LoginBackdrop extends StatelessWidget {
  const LoginBackdrop({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.loginBackgroundBottom,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: LoginDesign.canvas.width,
          height: LoginDesign.canvas.height,
          child: const Image(
            key: Key('login-background'),
            image: AssetImage(LoginDesign.backgroundAsset),
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}

/// 卡片切图：卡片本体、缎带、回形针、闪电与星芒都在图里，只做展示不接收点击。
class LoginCardArtwork extends StatelessWidget {
  const LoginCardArtwork({super.key});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Image.asset(LoginDesign.cardAsset, fit: BoxFit.fill),
    );
  }
}

/// 缎带上的应用名：缎带与回形针都在卡片切图里，只有文字由这里叠上去。
class LoginAppName extends StatelessWidget {
  const LoginAppName({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 34),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'APP NAME',
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            height: 22 / 16,
          ),
        ),
      ),
    );
  }
}
