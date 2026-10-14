import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/theme/app_colors.dart';
import 'login_controller.dart';

/// 登录页（设计稿 01-02 - 登录：`1-2登陆页/默认`、`01-02 - 登录-已输入`、
/// `01-02 - 登录-电话号码格式无效`）。
///
/// 设计画布为 375x812：点阵主视觉、「APP NAME」缎带、米色表单卡片和
/// 「Sign up / Sign in」主按钮都按设计稿坐标绝对摆放，外层只做等宽缩放，
/// 保证各机型上的层级与间距一致。
class LoginPage extends GetView<LoginController> {
  const LoginPage({super.key});

  static const double _designWidth = 375;
  static const double _designHeight = 812;

  /// 设计稿 375x812 画布对应的状态栏高度（iPhone 13 mini 一档）：返回键在
  /// 设计稿里就摆在状态栏下方，其余装饰是满幅出血，不需要避让。
  static const double _designTopInset = 50;

  /// 返回键在设计稿里的纵坐标（状态栏下方 8pt）。
  static const double _backTop = 58;

  /// 整页主视觉切图（点阵背景 + HELLO WELCOME + 插画），375x812 的 @3x 导出。
  static const String _backgroundAsset = 'assets/login/login_background.png';

  /// 表单卡片切图：卡片本体、缎带、回形针、闪电与星芒都在图里；缎带上的
  /// 「APP NAME」是文字层，切图里没有，由 [_AppNameLabel] 叠上去。
  static const String _cardAsset = 'assets/login/login_card.png';

  /// 卡片切图在设计稿里的位置与尺寸。
  ///
  /// 切图是 @3x 导出的，导出原点落在 682（不能被 3 整除）上；按整数设计坐标
  /// 摆放会把整块位图重采样、发虚，所以这里直接按切图的 @3x 网格给坐标，
  /// 在 375x812 的三倍屏上与设计稿逐像素对齐。
  static const double _cardLeft = 36 / 3;
  static const double _cardTop = 682 / 3;
  static const double _cardWidth = 349;
  static const double _cardHeight = 368;

  /// 卡片本体（切图里那块米色圆角矩形）在设计稿里的位置。
  static const double _cardBodyLeft = 14;
  static const double _cardBodyTop = 259;
  static const double _cardBodyWidth = 347;
  static const double _cardBodyHeight = 336;

  static const String _backAsset = 'assets/login/login_back.png';
  static const String _checkboxUnchecked =
      'assets/login/login_checkbox_unchecked.png';
  static const String _checkboxChecked =
      'assets/login/login_checkbox_checked.png';

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        body: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final scale = constraints.maxWidth / _designWidth;
              final canvasHeight = math.max(
                constraints.maxHeight,
                _designHeight * scale,
              );
              // 返回键是唯一贴着状态栏的可点元素：机型状态栏比设计稿高时
              // （例如 iPhone 16 Pro 的 62）按真实安全区下移，避免压在状态栏上；
              // 设计稿画布（50 以内）保持设计坐标不动。这里换算回设计坐标，
              // 由 `_positioned` 统一乘 scale。
              final safeTopInset = scale > 0
                  ? MediaQuery.paddingOf(context).top / scale
                  : 0.0;
              final backTop = math.max(
                _backTop,
                safeTopInset + (_backTop - _designTopInset),
              );
              return SingleChildScrollView(
                child: SizedBox(
                  width: constraints.maxWidth,
                  height: canvasHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _Background(scale: scale)),
                      _positioned(
                        _cardLeft,
                        _cardTop,
                        _cardWidth,
                        _cardHeight,
                        scale,
                        const _Decoration(
                          key: Key('login-card-artwork'),
                          asset: _cardAsset,
                        ),
                      ),
                      _positioned(
                        _cardBodyLeft,
                        _cardBodyTop,
                        _cardBodyWidth,
                        _cardBodyHeight,
                        scale,
                        _LoginForm(controller: controller, scale: scale),
                      ),
                      _positioned(
                        19,
                        236,
                        305,
                        43,
                        scale,
                        _AppNameLabel(scale: scale),
                      ),
                      _positioned(
                        50,
                        619,
                        274,
                        52,
                        scale,
                        _SubmitButton(controller: controller, scale: scale),
                      ),
                      _positioned(
                        14,
                        backTop,
                        24,
                        24,
                        scale,
                        const _BackButton(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// 按设计稿坐标（375x812 画布）摆放一个元素。
  Widget _positioned(
    double left,
    double top,
    double width,
    double height,
    double scale,
    Widget child,
  ) {
    return Positioned(
      left: left * scale,
      top: top * scale,
      width: width * scale,
      height: height * scale,
      child: child,
    );
  }
}

/// 整页背景：设计稿的整幅切图铺满 375x812 画布；比设计稿更高的机型，图片
/// 下方用切图底边的同色补齐滚动区域，既不留接缝也不拉伸画面。
class _Background extends StatelessWidget {
  const _Background({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.loginBackgroundBottom,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: LoginPage._designWidth * scale,
          height: LoginPage._designHeight * scale,
          child: const Image(
            key: Key('login-background'),
            image: AssetImage(LoginPage._backgroundAsset),
            fit: BoxFit.fill,
          ),
        ),
      ),
    );
  }
}

class _Decoration extends StatelessWidget {
  const _Decoration({super.key, required this.asset});

  final String asset;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: Image.asset(asset, fit: BoxFit.fill));
  }
}

/// 缎带上的应用名：缎带、回形针都在卡片切图里，只有文字由这里叠上去。
class _AppNameLabel extends StatelessWidget {
  const _AppNameLabel({required this.scale});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 34 * scale),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'APP NAME',
          style: TextStyle(
            color: AppColors.textOnPrimary,
            fontSize: 16 * scale,
            fontWeight: FontWeight.w500,
            height: 22 / 16,
          ),
        ),
      ),
    );
  }
}

/// 返回键：白色圆角底与棕色箭头都在切图里（设计稿 24x24）。
class _BackButton extends StatelessWidget {
  const _BackButton();

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
        image: AssetImage(LoginPage._backAsset),
        fit: BoxFit.fill,
      ),
    );
  }
}

/// 卡片里的表单：卡片的圆角、底色、边框和右上角的星芒都在卡片切图里。
class _LoginForm extends StatelessWidget {
  const _LoginForm({required this.controller, required this.scale});

  final LoginController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        18 * scale,
        50 * scale,
        18 * scale,
        30 * scale,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel('Please fill in your phone number', scale: scale),
          SizedBox(height: 16 * scale),
          _PhoneField(controller: controller, scale: scale),
          SizedBox(height: 24 * scale),
          _FieldLabel('Send SMS verification code', scale: scale),
          SizedBox(height: 14 * scale),
          _CodeField(controller: controller, scale: scale),
          SizedBox(height: 24 * scale),
          _AgreementRow(controller: controller, scale: scale),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.scale});

  final String text;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppColors.loginLabelText,
        fontSize: 16 * scale,
        fontWeight: FontWeight.w400,
        height: 20 / 16,
      ),
    );
  }
}

/// 手机号输入框：左侧固定 `+63`，只接收手机号本体的数字。
class _PhoneField extends StatelessWidget {
  const _PhoneField({required this.controller, required this.scale});

  final LoginController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return _FieldSurface(
      key: const Key('login-phone-field'),
      scale: scale,
      child: Row(
        children: [
          SizedBox(width: 14 * scale),
          Text(
            '+63',
            style: TextStyle(
              color: AppColors.loginAccentText,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w700,
              height: 20 / 16,
            ),
          ),
          // SizedBox(width: 12 * scale),
          Expanded(
            child: TextField(
              key: const Key('login-phone'),
              controller: controller.phoneInput,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              // 只收数字，但不设长度上限：合法与否交给 [_isValidPhone] 判断并给出
              // 设计稿的格式提示（截断输入会让「格式无效」这个状态不可达）。
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              cursorColor: AppColors.loginAccentText,
              style: _inputStyle(scale),
              decoration: _inputDecoration('Cellphone number', scale),
            ),
          ),
        ],
      ),
    );
  }
}

/// 验证码输入框：右侧是「Get Code」/倒计时按钮。
class _CodeField extends StatelessWidget {
  const _CodeField({required this.controller, required this.scale});

  final LoginController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return _FieldSurface(
      key: const Key('login-code-field'),
      scale: scale,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('login-code'),
              controller: controller.codeInput,
              focusNode: controller.codeFocusNode,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              cursorColor: AppColors.loginAccentText,
              style: _inputStyle(scale),
              decoration: _inputDecoration('Verification Code', scale),
            ),
          ),
          SizedBox(width: 8 * scale),
          _CodeButton(controller: controller, scale: scale),
        ],
      ),
    );
  }
}

class _CodeButton extends StatelessWidget {
  const _CodeButton({required this.controller, required this.scale});

  final LoginController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final counting = controller.countdown.value > 0;
      return GestureDetector(
        key: const Key('login-send-code'),
        behavior: HitTestBehavior.opaque,
        onTap: counting ? null : controller.sendCode,
        child: Container(
          width: 86 * scale,
          height: 28 * scale,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: counting
                ? AppColors.loginDisabledSurface
                : AppColors.loginCodeButtonSurface,
            borderRadius: BorderRadius.circular(6 * scale),
          ),
          child: Text(
            counting ? '${controller.countdown.value}s' : 'Get Code',
            style: TextStyle(
              color: counting
                  ? AppColors.textOnPrimary
                  : AppColors.loginAccentText,
              fontSize: 16 * scale,
              fontWeight: FontWeight.w500,
              height: 20 / 16,
            ),
          ),
        ),
      );
    });
  }
}

class _AgreementRow extends StatelessWidget {
  const _AgreementRow({required this.controller, required this.scale});

  final LoginController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          key: const Key('login-agreement'),
          behavior: HitTestBehavior.opaque,
          onTap: () => controller.onAgreementChanged(!controller.agreed.value),
          child: Padding(
            padding: EdgeInsets.only(top: 3 * scale),
            child: Obx(
              () => Image.asset(
                controller.agreed.value
                    ? LoginPage._checkboxChecked
                    : LoginPage._checkboxUnchecked,
                key: const Key('login-agreement-checkbox'),
                width: 16 * scale,
                height: 16 * scale,
              ),
            ),
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: _AgreementText(
            scale: scale,
            onPolicyTap: () => AppNavigator.toWebView(
              url: controller.privacyPolicyUrl,
              title: 'Privacy Policy',
            ),
            onTermsTap: () => AppNavigator.toWebView(
              url: controller.termsOfServiceUrl,
              title: 'Terms of Service',
            ),
          ),
        ),
      ],
    );
  }
}

/// 「I have read and agree to the Privacy Policy and Terms of Service」。
///
/// 设计稿把两个协议名做成更深的字色，这里保持同样的视觉，同时让它们可点。
class _AgreementText extends StatefulWidget {
  const _AgreementText({
    required this.scale,
    required this.onPolicyTap,
    required this.onTermsTap,
  });

  final double scale;
  final VoidCallback onPolicyTap;
  final VoidCallback onTermsTap;

  @override
  State<_AgreementText> createState() => _AgreementTextState();
}

class _AgreementTextState extends State<_AgreementText> {
  late final TapGestureRecognizer _policyRecognizer;
  late final TapGestureRecognizer _termsRecognizer;

  @override
  void initState() {
    super.initState();
    _policyRecognizer = TapGestureRecognizer()..onTap = widget.onPolicyTap;
    _termsRecognizer = TapGestureRecognizer()..onTap = widget.onTermsTap;
  }

  @override
  void didUpdateWidget(covariant _AgreementText oldWidget) {
    super.didUpdateWidget(oldWidget);
    _policyRecognizer.onTap = widget.onPolicyTap;
    _termsRecognizer.onTap = widget.onTermsTap;
  }

  @override
  void dispose() {
    _policyRecognizer.dispose();
    _termsRecognizer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      color: AppColors.loginLabelText,
      fontSize: 14 * widget.scale,
      fontWeight: FontWeight.w400,
      height: 20 / 14,
    );
    final link = base.copyWith(color: AppColors.loginInputText);
    return Text.rich(
      TextSpan(
        children: [
          const TextSpan(text: 'I have read and agree to the '),
          TextSpan(
            text: 'Privacy Policy',
            style: link,
            recognizer: _policyRecognizer,
          ),
          const TextSpan(text: ' and '),
          TextSpan(
            text: 'Terms of Service',
            style: link,
            recognizer: _termsRecognizer,
          ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: base,
    );
  }
}

/// 主按钮：可提交时用暖橙渐变，否则是设计稿里的灰色不可用态。
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({required this.controller, required this.scale});

  final LoginController controller;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final enabled = controller.canSubmit;
      return GestureDetector(
        key: const Key('login-submit'),
        behavior: HitTestBehavior.opaque,
        // 即使还不可提交也保持可点：由控制器给出「手机号格式」「先勾选协议」
        // 这类具体提示，而不是让按钮毫无反馈。
        onTap: controller.submit,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: enabled ? null : AppColors.loginDisabledSurface,
            gradient: enabled ? AppColors.homeWarmGradient : null,
            borderRadius: BorderRadius.circular(26 * scale),
          ),
          child: Center(
            child: Text(
              'Sign up / Sign in',
              style: TextStyle(
                color: AppColors.textOnPrimary,
                fontSize: 20 * scale,
                fontWeight: FontWeight.w700,
                height: 24 / 20,
              ),
            ),
          ),
        ),
      );
    });
  }
}

/// 白色输入底色 + 8 圆角，高度固定 48（设计稿）。
class _FieldSurface extends StatelessWidget {
  const _FieldSurface({super.key, required this.child, required this.scale});

  final Widget child;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48 * scale,
      padding: EdgeInsets.only(right: 14 * scale),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8 * scale),
      ),
      child: child,
    );
  }
}

TextStyle _inputStyle(double scale) => TextStyle(
  color: AppColors.loginInputText,
  fontSize: 16 * scale,
  fontWeight: FontWeight.w700,
  height: 20 / 16,
);

/// 登录页的输入框独立于全局 `InputDecorationTheme`。
///
/// 全局主题给输入框配了浅灰填充（`filled + fillColor`）与「默认 1px / 聚焦 1.5px」
/// 的描边，但设计稿里的输入框只有一块白色圆角底，没有任何填充色和描边，
/// 所以这里把填充和六种边框全部显式关掉，只看页面自己的白底。
InputDecoration _inputDecoration(String hint, double scale) => InputDecoration(
  isCollapsed: true,
  filled: false,
  border: InputBorder.none,
  enabledBorder: InputBorder.none,
  disabledBorder: InputBorder.none,
  focusedBorder: InputBorder.none,
  errorBorder: InputBorder.none,
  focusedErrorBorder: InputBorder.none,
  hintText: hint,
  hintStyle: TextStyle(
    color: AppColors.loginLabelText,
    fontSize: 16 * scale,
    fontWeight: FontWeight.w400,
    height: 20 / 16,
  ),
);
