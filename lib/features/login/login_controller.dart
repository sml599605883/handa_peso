import 'dart:async';

import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/session/session_store.dart';
import '../main_shell/main_controller.dart';

/// 驱动手机号 + 短信验证码登录流程。
class LoginController extends GetxController {
  LoginController({required this.apiClient, required this.sessionStore});

  final ApiClient apiClient;
  final SessionStore sessionStore;

  final phone = ''.obs;
  final code = ''.obs;
  final agreed = false.obs;
  final sendingCode = false.obs;
  final submitting = false.obs;
  final countdown = 0.obs;
  final errorText = RxnString();

  Timer? _timer;

  bool get canSendCode => _isValidPhone(phone.value) && countdown.value == 0 && !sendingCode.value;

  bool get canSubmit =>
      _isValidPhone(phone.value) && code.value.length >= 4 && agreed.value && !submitting.value;

  @override
  void onClose() {
    _timer?.cancel();
    super.onClose();
  }

  void onPhoneChanged(String value) {
    phone.value = value.replaceAll(RegExp(r'\D'), '');
    errorText.value = null;
  }

  void onCodeChanged(String value) => code.value = value.replaceAll(RegExp(r'\D'), '');

  void onAgreementChanged(bool value) => agreed.value = value;

  Future<void> sendCode() async {
    if (!canSendCode) {
      if (!_isValidPhone(phone.value)) {
        errorText.value = 'Enter a valid Philippine mobile number.';
      }
      return;
    }
    sendingCode.value = true;
    errorText.value = null;
    try {
      await apiClient.sendSmsCode(fishtailed: phone.value);
      _startCountdown();
      AppNavigator.showToast('Verification code sent.');
    } on ApiException catch (error) {
      errorText.value = error.message;
      CrashReporter.record(error, StackTrace.current);
    } finally {
      sendingCode.value = false;
    }
  }

  Future<void> submit() async {
    if (!canSubmit) {
      if (!agreed.value) {
        errorText.value = 'Please agree to the Terms and Privacy Policy.';
      }
      return;
    }
    submitting.value = true;
    errorText.value = null;
    AnalyticsService.logEvent(AppEvents.loginSubmit, {'length': phone.value.length});
    try {
      final response = await apiClient.smsCodeLogin(
        criminology: phone.value,
        legongs: code.value,
      );
      final sessionId = response.data['sandman']?.toString() ?? '';
      await sessionStore.saveSessionId(sessionId);
      await sessionStore.savePhone(phone.value);
      AnalyticsService.setUserId(phone.value);
      AnalyticsService.logEvent(AppEvents.loginSuccess);
      if (Get.isRegistered<MainController>()) {
        await Get.find<MainController>().onSessionStarted(phone.value);
      }
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back<bool>(result: true);
      } else {
        await AppNavigator.toMain();
      }
    } on ApiException catch (error) {
      errorText.value = error.message;
      CrashReporter.record(error, StackTrace.current);
    } finally {
      submitting.value = false;
    }
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

  bool _isValidPhone(String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) return digits.startsWith('9');
    if (digits.length == 11) return digits.startsWith('09');
    if (digits.length == 12) return digits.startsWith('639');
    return false;
  }
}
