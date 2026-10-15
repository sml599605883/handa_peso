import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/navigation/h5_paths.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/network/gateway_client.dart';
import '../../core/network/gateway_failure.dart';
import '../../core/report/report_service.dart';
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
  LoginController({
    required this.gatewayClient,
    required this.localSession,
    this.reportService,
    int Function()? clock,
  }) : _clock = clock ?? ReportService.nowSeconds;

  final GatewayClient gatewayClient;
  final LocalSession localSession;

  /// 登录成功后的上报入口；未接入上报时为空。
  final ReportService? reportService;

  /// 秒级时钟；只在测试里注入，用来断言注册埋点取的是哪个时刻。
  final int Function() _clock;

  /// 注册埋点的开始时间：控制器创建时取一次（= 进入登录页），之后每次成功
  /// 获取验证码都重置。
  ///
  /// 重置与参考端一致（它的 `timeStr` 同样在发码成功后重新取值）：这条埋点量的是
  /// 「最近一次拿到验证码」到登录成功之间的时长。
  late int _registeredAtSeconds = _clock();

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
    final loading = _acquireLoading();
    try {
      final reply = await gatewayClient.requestSmsCode(
        phone: phoneDigits.value,
      );
      // 提示要浮在转圈之上，所以先收起浮层再提示。
      await _releaseLoading(loading);
      cooldown.restart();
      // 验证码已发出：注册埋点的开始时间跟着挪到这一刻。
      _registeredAtSeconds = _clock();
      codeFocus.requestFocus();
      // 文案优先用接口下发的（`unstably`），服务端没给才退回本地兜底。
      _notify(reply.note.isEmpty ? codeSentHint : reply.note);
    } on GatewayFailure catch (error) {
      await _releaseLoading(loading);
      _notify(error.message);
      CrashReporter.record(error, StackTrace.current);
    } catch (error) {
      await _releaseLoading(loading);
      _notify(FailureMessage.describe(error));
      CrashReporter.record(error, StackTrace.current);
    } finally {
      // 兜底：上面任何一步抛异常，也不能把转圈留在屏幕上（重复调用是空操作）。
      await _releaseLoading(loading);
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
    final loading = _acquireLoading();
    try {
      final response = await gatewayClient.signInWithSmsCode(
        phone: phoneDigits.value,
        code: codeDigits.value,
      );
      final sessionId = response.payload['sandman']?.toString() ?? '';
      if (sessionId.isEmpty) {
        throw const GatewayFailure('Invalid login response');
      }
      // 会话已经拿到：后面都是本地收尾，先把浮层收掉。
      await _releaseLoading(loading);
      await localSession.writeSessionId(sessionId);
      await localSession.writePhone(phoneDigits.value);
      AnalyticsService.setUserId(phoneDigits.value);
      AnalyticsService.logEvent(AppEvents.loginSuccess);
      // 注册埋点的时长 = 最近一次拿到验证码（没发过码就是进入登录页）-> 登录成功。
      unawaited(
        reportService?.loginSucceeded(
          registeredAtSeconds: _registeredAtSeconds,
        ),
      );
      // 外壳的数据要跟着登录态同步一次，但这不能挡住登录页收尾：接口慢的时候
      // 用户会一直停在登录页上等（看起来就是「登录成功了页面还在 loading」）。
      // 首页 / 进度页自己会渲染 loading 与失败态，这里只把刷新发出去。
      unawaited(_syncShellAfterLogin());
      if (Get.key.currentState?.canPop() ?? false) {
        Get.back<void>();
      } else {
        await AppNavigator.toMain();
      }
    } on GatewayFailure catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await _releaseLoading(loading);
      await _notifyThenReset(error.message);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
      await _releaseLoading(loading);
      await _notifyThenReset(FailureMessage.describe(error));
    } finally {
      // 兜底：上面任何一步抛异常，也不能把转圈留在屏幕上（重复调用是空操作）。
      await _releaseLoading(loading);
      signingIn.value = false;
    }
  }

  /// 登录成功后让外壳重新同步一次数据（首页与进度页共用同一条信息流接口）。
  ///
  /// 有意不 await：这条请求的耗时不该决定登录页什么时候收尾；失败也只上报，
  /// 外壳页面自己会显示失败态。
  Future<void> _syncShellAfterLogin() async {
    if (!Get.isRegistered<MainController>()) return;
    try {
      await Get.find<MainController>().onSessionStarted(phoneDigits.value);
    } catch (error) {
      CrashReporter.record(error, StackTrace.current);
    }
  }

  /// 还在途的 Loading 凭据。`EasyLoading` 是全局单例、没有引用计数，而发码与
  /// 提交会撞在一起（验证码先到、用户直接填满自动提交）：谁最后关谁就决定浮层的
  /// 去留——前一个操作会把后一个还在跑的转圈收掉，漏关则让页面一直转圈。
  /// 每个操作拿着自己的凭据关自己那一次，浮层只在最后一个在途操作结束时收。
  final Set<int> _loadingTokens = <int>{};
  int _nextLoadingToken = 0;

  /// 开一次 Loading，返回本次操作的凭据。
  ///
  /// 有意不 await 弹出动画：动画没跑完时请求也应该已经发出去了。
  int _acquireLoading() {
    if (_loadingTokens.isEmpty) unawaited(AppNavigator.showLoading());
    final token = ++_nextLoadingToken;
    _loadingTokens.add(token);
    return token;
  }

  /// 关掉 [token] 这一次 Loading。同一凭据重复调用是空操作，兜底路径不会误伤
  /// 其它还在途操作的转圈。
  Future<void> _releaseLoading(int token) async {
    if (!_loadingTokens.remove(token)) return;
    if (_loadingTokens.isNotEmpty) return;
    await AppNavigator.dismissLoading();
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
