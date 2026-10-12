import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';

import '../../core/network/api_client.dart';
import '../../core/session/session_store.dart';
import '../routes/app_routes.dart';

/// Navigation and feedback helpers shared by feature controllers.
///
/// Wrapping `Get` here keeps feature code free of routing details and gives us a
/// single place to add guards (e.g. requiring a completed profile before apply).
abstract final class AppNavigator {
  static void Function(int index)? mainTabSelector;

  /// Pushes the login route on top of the current screen.
  ///
  /// Login is demand-driven: guests can browse the shell and are only asked to
  /// authenticate when an action needs a session. Resolves to `true` when the
  /// user completes sign-in.
  static Future<bool> toLogin({String? redirect}) async {
    final result = await Get.toNamed<bool>(AppRoutes.login, arguments: redirect);
    return result ?? false;
  }

  /// Ensures a session exists, opening login if needed.
  ///
  /// Returns `true` when the caller may proceed with an authenticated action.
  static Future<bool> requireSession({String? redirect}) async {
    final store = _sessionStore();
    if (store != null && (await store.sessionId()).isNotEmpty) {
      return true;
    }
    return toLogin(redirect: redirect);
  }

  /// Clears the expired session and returns the user to the login screen.
  ///
  /// Registered as the [ApiConfig.authExpiredHandler] at bootstrap so the
  /// network layer can recover from a `-2` response without importing routing.
  static Future<void> redirectToLoginAfterSessionExpiry() async {
    await _sessionStore()?.clear();
    await Get.offAllNamed<void>(AppRoutes.login);
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

  static SessionStore? _sessionStore() {
    if (Get.isRegistered<ApiClient>()) {
      return Get.find<ApiClient>().config.sessionStore;
    }
    return null;
  }
}
