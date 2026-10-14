import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/navigation/h5_paths.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/session/local_session.dart';
import '../main_shell/main_controller.dart';
import 'login_cooldown.dart';
import 'phone_number.dart';

/// 手机号格式不合法时的提示（设计稿 01-02 - 登录-电话号码格式无效）。
const String invalidPhoneHint = 'Invalid phone number format.';

/// 没勾选协议时的提示。
const String agreementHint =
    'Please agree to the Privacy Policy and Terms of Service';

/// 验证码已发出的兜底文案：接口的 `unstably` 没给内容时才用它。
const String codeSentHint = 'Verification code sent.';

/// 手机号 + 短信验证码登录（设计稿 01-02 - 登录）。
///
/// 输入事件由页面通过 [onPhoneTyped] / [onCodeTyped] 送进来，控制器只负责校验、
/// 请求与登录态：`+63` 前缀固定展示，验证码填满 6 位自动提交，手机号格式不对
/// 或没勾选协议时立刻给浮层提示，而不是让主按钮点了没反应。
class LoginController extends GetxController {
  LoginController({required this.gatewayClient, required this.localSession});

  final GatewayClient gatewayClient;
  final LocalSession localSession;

  /// 输入框的文本控制器：控制器持有它们是为了回填上次的手机号、登录失败后
  /// 清空验证码；输入变化本身走 [onPhoneTyped] / [onCodeTyped]，不再挂监听。
  final phoneField = TextEditingController();
  final codeField = TextEditingController();
  final codeFocus = FocusNode();

  /// 输入内容的响应式状态，供按钮态与提示判断使用。
  final phoneDigits = ''.obs;
  final codeDigits = ''.obs;

  /// 协议勾选默认已同意（与同族 Dali / Kaibigan 端一致）；用户取消勾选后
  /// 主按钮与自动登录都会停下来提示。
  final privacyAccepted = true.obs;
  final requestingCode = false.obs;
  final signingIn = false.obs;
  final cooldown = LoginCooldown();

  /// 手机号非空即可点「Get Code」，格式是否合法交给 [requestCode] 提示。
  bool get canRequestCode =>
      phoneDigits.value.isNotEmpty &&
      !cooldown.isRunning &&
      !requestingCode.value;

  /// 主按钮的可用态只看「手机号非空 + 验证码满 6 位 + 已勾选」，不含格式校验：
  /// 设计稿「电话号码格式无效」分镜里主按钮同样是橙色可用态。
  bool get isSignInReady =>
      phoneDigits.value.isNotEmpty &&
      codeDigits.value.length == 6 &&
      privacyAccepted.value &&
      !signingIn.value;

  /// 协议地址 = 服务端下发的 H5 域名 + 文档登记的混淆段。
  String get privacyUrl =>
      H5Paths.resolve(gatewayClient.settings.webOrigin, H5Paths.privacyPolicy);

  String get termsUrl =>
      H5Paths.resolve(gatewayClient.settings.webOrigin, H5Paths.agreement);

  @override
  void onInit() {
    super.onInit();
    unawaited(_prefillRememberedPhone());
  }

  @override
  void onClose() {
    cooldown.stop();
    phoneField.dispose();
    codeField.dispose();
    codeFocus.dispose();
    super.onClose();
  }

  /// 回填上次登录成功的手机号，省去用户重复输入。
  Future<void> _prefillRememberedPhone() async {
    final remembered = await localSession.readPhone();
    if (isClosed || remembered.isEmpty || phoneField.text.isNotEmpty) return;
    phoneField.value = TextEditingValue(
      text: remembered,
      selection: TextSelection.collapsed(offset: remembered.length),
    );
    phoneDigits.value = remembered;
  }

  void onPrivacyChanged(bool accepted) => privacyAccepted.value = accepted;

  void onPhoneTyped(String value) => phoneDigits.value = value;

  /// 验证码输入变化：填满 6 位就自动提交，缺什么由 [signIn] 提示出来。
  void onCodeTyped(String value) {
    codeDigits.value = value;
    // 手机号还空着时不打扰：填验证码的过程中不该弹出「手机号格式无效」。
    if (phoneDigits.value.isEmpty) return;
    if (value.length == 6) unawaited(signIn());
  }

  Future<void> requestCode() async {
    // 空输入不提示：设计稿里手机号为空时按钮仍是可点样式，但确实没有可发送
    // 的内容；只有填了却格式不对才提示。
    if (phoneDigits.value.isEmpty) return;
    if (!PhoneNumber.parse(phoneDigits.value).isMobile) {
      _notify(invalidPhoneHint);
      return;
    }
    if (!canRequestCode) return;
    requestingCode.value = true;
    try {
      // 只等请求，不等「转圈」动画：动画没跑完时请求也应该已经发出去了。
      unawaited(AppNavigator.showLoading());
      final reply = await gatewayClient.requestSmsCode(
        phone: phoneDigits.value,
      );
      await AppNavigator.dismissLoading();
      cooldown.restart();
      codeFocus.requestFocus();
      // 文案优先用接口下发的（`unstably`），服务端没给才退回本地兜底。
      _notify(reply.note.isEmpty ? codeSentHint : reply.note);
    } on GatewayFailure catch (error) {
      await AppNavigator.dismissLoading();
      _notify(error.message);
      CrashReporter.record(error, StackTrace.current);
    } catch (error) {
      await AppNavigator.dismissLoading();
      _notify(FailureMessage.describe(error));
      CrashReporter.record(error, StackTrace.current);
    } finally {
      requestingCode.value = false;
    }
  }

  Future<void> signIn() async {
    if (signingIn.value) return;
    // 设计稿的已输入态与提示态都没有键盘遮挡表单；提交时先收起键盘。
    FocusManager.instance.primaryFocus?.unfocus();

    // 这一轮没能走到服务端的提交，同样要复位验证码：只给提示、把填满的验证码
    // 留在框里，用户改完手机号或勾上协议后会以为能直接再提交一次。
    if (!PhoneNumber.parse(phoneDigits.value).isMobile) {
      await _notifyThenReset(invalidPhoneHint);
      return;
    }
    if (!privacyAccepted.value) {
      await _notifyThenReset(agreementHint);
      return;
    }
    if (codeDigits.value.length != 6) {
      // 位数不够只是还没填完：不清空已输入的数字，但光标要回到验证码框
      // （提交时刚收起了键盘）。
      codeFocus.requestFocus();
      return;
    }

    signingIn.value = true;
    AnalyticsService.logEvent(AppEvents.loginSubmit, {
      'length': phoneDigits.value.length,
    });
    try {
      unawaited(AppNavigator.showLoading());
      final response = await gatewayClient.signInWithSmsCode(
        phone: phoneDigits.value,
        code: codeDigits.value,
      );
      final sessionId = response.payload['sandman']?.toString() ?? '';
      if (sessionId.isEmpty) {
        throw const GatewayFailure('Invalid login response');
      }
      await AppNavigator.dismissLoading();
      await localSession.writeSessionId(sessionId);
      await localSession.writePhone(phoneDigits.value);
      AnalyticsService.setUserId(phoneDigits.value);
      AnalyticsService.logEvent(AppEvents.loginSuccess);
      if (Get.isRegistered<MainController>()) {
        await Get.find<MainController>().onSessionStarted(phoneDigits.value);
      }
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back<void>();
      } else {
        await AppNavigator.toMain();
      }
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await AppNavigator.dismissLoading();
      await _notifyThenReset(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await AppNavigator.dismissLoading();
      await _notifyThenReset(FailureMessage.describe(error));
    } finally {
      signingIn.value = false;
    }
  }

  /// 先提示、等提示播完再复位。
  ///
  /// 服务端下发的错误文案要完整给用户看完；提示还在屏上就把验证码清掉、把光标
  /// 拽回输入框，用户会以为提示说的是别的事（参考端也是在提示的完成回调里复位）。
  Future<void> _notifyThenReset(String message) async {
    if (message.trim().isEmpty) {
      _resetCodeEntry();
      return;
    }
    await AppNavigator.showHintAndWait(message);
    _resetCodeEntry();
  }

  /// 提交走不通时的复位：验证码是一次性的，一律清空并让光标回到验证码框，
  /// 让用户重新获取。手机号保留——那是用户接下来要改的东西。
  ///
  /// 提示播完才调用，期间用户可能已经离开登录页，所以先看控制器是否已关闭。
  void _resetCodeEntry() {
    if (isClosed) return;
    codeField.clear();
    codeDigits.value = '';
    codeFocus.requestFocus();
  }

  /// 登录页的提示统一走浮层（空文案直接忽略），样式见 [AppNavigator.showHint]。
  void _notify(String message) {
    if (message.trim().isEmpty) return;
    AppNavigator.showHint(message);
  }
}
