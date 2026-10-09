import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../routes/app_routes.dart';

/// Navigation and feedback helpers shared by feature controllers.
///
/// Wrapping `Get` here keeps feature code free of routing details and gives us a
/// single place to add guards (e.g. requiring a completed profile before apply).
abstract final class AppNavigator {
  static void Function(int index)? mainTabSelector;

  static Future<void>? toLogin({String? redirect}) {
    return Get.offAllNamed<void>(AppRoutes.login, arguments: redirect);
  }

  static Future<void>? toMain() => Get.offAllNamed<void>(AppRoutes.main);

  static void switchMainTab(int index) => mainTabSelector?.call(index);

  static Future<void>? toCalculator() => Get.toNamed<void>(AppRoutes.calculator);

  static Future<void>? toCertification() => Get.toNamed<void>(AppRoutes.certification);

  static Future<void>? toOrders() => Get.toNamed<void>(AppRoutes.orders);

  static Future<void>? toSupport() => Get.toNamed<void>(AppRoutes.support);

  static Future<void>? toAnnouncements() => Get.toNamed<void>(AppRoutes.announcements);

  static Future<void>? toWebView({
    required String url,
    required String title,
  }) {
    return Get.toNamed<void>(AppRoutes.webView, arguments: {'url': url, 'title': title});
  }

  static Future<void> showLoading([String status = 'Loading...']) =>
      EasyLoading.show(status: status);

  static Future<void> dismissLoading() => EasyLoading.dismiss();

  static void showToast(String message) => EasyLoading.showToast(message);

  static void showError(String message) => EasyLoading.showError(message);
}
