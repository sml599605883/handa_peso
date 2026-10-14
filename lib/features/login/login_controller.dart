import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/navigation/h5_paths.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/session_store.dart';
import '../main_shell/main_controller.dart';

/// 手机号格式不合法时的提示（设计稿 01-02 - 登录-电话号码格式无效）。
const String _invalidPhoneMessage = 'Invalid phone number format.';

/// 驱动手机号 + 短信验证码登录流程（设计稿 01-02 - 登录）。
///
/// 交互与 Dali 系列登录页保持一致：输入框固定展示 `+63` 前缀，验证码按需
/// 申请、成功后进入 60 秒倒计时，填满 6 位即自动提交，必须勾选协议，
/// 格式与接口错误统一用 toast 提示（设计稿里也是浮层提示）。
class LoginController extends GetxController {
  LoginController({required this.apiClient, required this.sessionStore});

  final ApiClient apiClient;
  final SessionStore sessionStore;

  /// 输入框内容；`phone` / `code` 是它们的响应式镜像，供 UI 重建按钮状态。
  final phoneInput = TextEditingController();
  final codeInput = TextEditingController();
  final codeFocusNode = FocusNode();

  final phone = ''.obs;
  final code = ''.obs;
  final agreed = false.obs;
  final sendingCode = false.obs;
  final submitting = false.obs;
  final countdown = 0.obs;

  Timer? _timer;

  /// 与 Dali 系列一致：手机号非空即可点，格式是否合法交给 [sendCode] 打开提示。
  bool get canSendCode =>
      phone.value.isNotEmpty && countdown.value == 0 && !sendingCode.value;

  /// 与 Dali 系列一致：按钮的可用态只看「手机号非空 + 验证码满 6 位 + 已勾选」，
  /// 不校验手机号格式。设计稿「电话号码格式无效」分镜里主按钮同样是橙色可用态，
  /// 手机号是否合法由 [submit] 给出浮层提示。
  bool get canSubmit =>
      phone.value.isNotEmpty &&
      code.value.length == 6 &&
      agreed.value &&
      !submitting.value;

  /// 协议地址 = 服务端下发的 H5 域名 + 文档登记的混淆段。
  String get privacyPolicyUrl =>
      H5Paths.resolve(apiClient.config.webBaseUrl, H5Paths.privacyPolicy);

  String get termsOfServiceUrl =>
      H5Paths.resolve(apiClient.config.webBaseUrl, H5Paths.agreement);

  @override
  void onInit() {
    super.onInit();
    phoneInput.addListener(_onPhoneInputChanged);
    codeInput.addListener(_onCodeInputChanged);
    unawaited(_restorePhone());
  }

  @override
  void onClose() {
    _timer?.cancel();
    phoneInput
      ..removeListener(_onPhoneInputChanged)
      ..dispose();
    codeInput
      ..removeListener(_onCodeInputChanged)
      ..dispose();
    codeFocusNode.dispose();
    super.onClose();
  }

  /// 回填上次登录成功的手机号，省去用户重复输入。
  Future<void> _restorePhone() async {
    final remembered = await sessionStore.phone();
    if (isClosed || remembered.isEmpty || phoneInput.text.isNotEmpty) return;
    phoneInput.value = TextEditingValue(
      text: remembered,
      selection: TextSelection.collapsed(offset: remembered.length),
    );
  }

  void onAgreementChanged(bool value) => agreed.value = value;

  Future<void> sendCode() async {
    // 空输入不提示：设计稿里手机号为空时「Get Code」仍是可点样式，但确实没有
    // 可发送的内容，保持与 Dali 系列一致地安静返回；只有填了却格式不对才提示。
    if (phone.value.isEmpty) return;
    if (!_isValidPhone(phone.value)) {
      _showMessage(_invalidPhoneMessage);
      return;
    }
    if (!canSendCode) return;
    sendingCode.value = true;
    try {
      // 只等请求，不等「转圈」动画：动画没跑完时请求也应该已经发出去了。
      unawaited(AppNavigator.showLoading());
      await apiClient.sendSmsCode(fishtailed: phone.value);
      await AppNavigator.dismissLoading();
      _startCountdown();
      codeFocusNode.requestFocus();
      _showMessage('Verification code sent.');
    } on ApiException catch (error) {
      await AppNavigator.dismissLoading();
      _showMessage(error.message);
      CrashReporter.record(error, StackTrace.current);
    } catch (error) {
      await AppNavigator.dismissLoading();
      _showMessage(ApiErrorMessage.resolve(error));
      CrashReporter.record(error, StackTrace.current);
    } finally {
      sendingCode.value = false;
    }
  }

  Future<void> submit() async {
    if (submitting.value) return;
    // 设计稿的已输入态与提示态都没有键盘遮挡表单；提交时先收起键盘，
    // 与 Dali 系列的 `dismissKeyboard()` 保持一致。
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_isValidPhone(phone.value)) {
      _showMessage(_invalidPhoneMessage);
      return;
    }
    if (!agreed.value) {
      _showMessage('Please agree to the Privacy Policy and Terms of Service');
      return;
    }
    if (code.value.length != 6) return;

    submitting.value = true;
    AnalyticsService.logEvent(AppEvents.loginSubmit, {
      'length': phone.value.length,
    });
    try {
      unawaited(AppNavigator.showLoading());
      final response = await apiClient.smsCodeLogin(
        criminology: phone.value,
        legongs: code.value,
      );
      final sessionId = response.data['sandman']?.toString() ?? '';
      if (sessionId.isEmpty) {
        throw const ApiException('Invalid login response');
      }
      await AppNavigator.dismissLoading();
      await sessionStore.saveSessionId(sessionId);
      await sessionStore.savePhone(phone.value);
      AnalyticsService.setUserId(phone.value);
      AnalyticsService.logEvent(AppEvents.loginSuccess);
      if (Get.isRegistered<MainController>()) {
        await Get.find<MainController>().onSessionStarted(phone.value);
      }
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back<void>();
      } else {
        await AppNavigator.toMain();
      }
    } on ApiException catch (error) {
      await AppNavigator.dismissLoading();
      _showMessage(error.message);
      CrashReporter.record(error, StackTrace.current);
      // 验证码一次性失效：清空后让用户重新获取，保持与 Dali 系列一致。
      codeInput.clear();
      codeFocusNode.requestFocus();
    } catch (error) {
      await AppNavigator.dismissLoading();
      _showMessage(ApiErrorMessage.resolve(error));
      CrashReporter.record(error, StackTrace.current);
      codeInput.clear();
      codeFocusNode.requestFocus();
    } finally {
      submitting.value = false;
    }
  }

  /// 与 Dali 系列一致：登录页的提示统一走浮层（空文案直接忽略）。
  ///
  /// 浮层样式取自设计稿（屏幕正中的深色圆角方块），见 [AppNavigator.showHint]。
  void _showMessage(String message) {
    if (message.trim().isEmpty) return;
    AppNavigator.showHint(message);
  }

  void _onPhoneInputChanged() {
    final digits = phoneInput.text.replaceAll(RegExp(r'\D'), '');
    if (digits != phoneInput.text) {
      phoneInput.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
      return;
    }
    phone.value = digits;
  }

  void _onCodeInputChanged() {
    final digits = codeInput.text.replaceAll(RegExp(r'\D'), '');
    if (digits != codeInput.text) {
      codeInput.value = TextEditingValue(
        text: digits,
        selection: TextSelection.collapsed(offset: digits.length),
      );
      return;
    }
    code.value = digits;
    // 验证码填满即自动登录；协议未勾选时不打扰用户，交给主按钮提示。
    if (canSubmit) unawaited(submit());
  }

  void _startCountdown() {
    countdown.value = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      countdown.value -= 1;
      if (countdown.value <= 0) {
        countdown.value = 0;
        timer.cancel();
      }
    });
  }

  /// 校验去掉 `+63` 前缀后的菲律宾手机号：10 位 `9xxxxxxxxx`，
  /// 也兼容用户整段粘贴的 `09xxxxxxxxx` / `639xxxxxxxxx`。
  bool _isValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return digits.startsWith('9');
    if (digits.length == 11) return digits.startsWith('09');
    if (digits.length == 12) return digits.startsWith('639');
    return false;
  }
}
