import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/layout/design_canvas.dart';
import 'login_back_button.dart';
import 'login_backdrop.dart';
import 'login_controller.dart';
import 'login_design.dart';
import 'login_form_card.dart';
import 'login_submit_button.dart';

/// 登录页（设计稿 01-02 - 登录：`1-2登陆页/默认`、`01-02 - 登录-已输入`、
/// `01-02 - 登录-电话号码格式无效`）。
///
/// 页面只负责把各层按设计稿坐标摆到 375x812 画布上，坐标与切图见 [LoginDesign]，
/// 缩放交给 [DesignCanvas]；表单逻辑在 [LoginController]。
class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DesignCanvas(
      designSize: LoginDesign.canvas,
      builder: (context, metrics) => Stack(
        children: [
          const Positioned.fill(child: LoginBackdrop()),
          LoginDesign.place(
            LoginDesign.cardArtLeft,
            LoginDesign.cardArtTop,
            LoginDesign.cardArtWidth,
            LoginDesign.cardArtHeight,
            const LoginCardArtwork(key: Key('login-card-artwork')),
          ),
          LoginDesign.place(
            LoginDesign.cardBodyLeft,
            LoginDesign.cardBodyTop,
            LoginDesign.cardBodyWidth,
            LoginDesign.cardBodyHeight,
            LoginFormCard(controller: controller),
          ),
          LoginDesign.place(
            LoginDesign.appNameLeft,
            LoginDesign.appNameTop,
            LoginDesign.appNameWidth,
            LoginDesign.appNameHeight,
            const LoginAppName(),
          ),
          LoginDesign.place(
            LoginDesign.submitLeft,
            LoginDesign.submitTop,
            LoginDesign.submitWidth,
            LoginDesign.submitHeight,
            LoginSubmitButton(controller: controller),
          ),
          // 返回键是唯一贴着状态栏的可点元素：机型状态栏比设计稿高时（例如
          // iPhone 16 Pro 的 62）按真实安全区下移，避免压在状态栏上；设计稿
          // 画布（50 以内）保持设计坐标不动。
          LoginDesign.place(
            LoginDesign.backLeft,
            math.max(
              LoginDesign.backTop,
              metrics.safeTop + LoginDesign.backInset,
            ),
            LoginDesign.backSize,
            LoginDesign.backSize,
            const LoginBackButton(),
          ),
        ],
      ),
    );
  }
}
