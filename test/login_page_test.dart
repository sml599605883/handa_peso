import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/app/theme/app_colors.dart';
import 'package:handa_peso/app/theme/app_theme.dart';
import 'package:handa_peso/core/network/api_client.dart';
import 'package:handa_peso/core/network/api_config.dart';
import 'package:handa_peso/core/session/session_store.dart';
import 'package:handa_peso/features/login/login_controller.dart';
import 'package:handa_peso/features/login/login_page.dart';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

const String _homeRoute = '/stub-home';

/// 整页渲染结果的抓取点（放在 [GetMaterialApp.builder] 最外层，保证浮层也在内）。
const Key _captureKey = Key('login-capture');

const Color _white = Color(0xFFFFFFFF);

/// 直接读渲染像素：样式问题（例如全局主题漏进输入框）在 widget 属性上看不出来。
Future<_Pixels> _capturePixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  late _Pixels pixels;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final data = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
    pixels = _Pixels(data, image.width);
  });
  return pixels;
}

/// 1 设计像素 = 1 像素的取色器。
class _Pixels {
  _Pixels(this._data, this._width);

  final ByteData _data;
  final int _width;

  Color at(double x, double y) {
    final offset = (y.round() * _width + x.round()) * 4;
    return Color.fromARGB(
      255,
      _data.getUint8(offset),
      _data.getUint8(offset + 1),
      _data.getUint8(offset + 2),
    );
  }
}

/// 记录请求路径的脚本化适配器；登录页只关心短信验证码与登录两个接口。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler, {this.gate});

  final Future<ResponseBody> Function(RequestOptions options) handler;

  /// 用来把响应挂起，方便断言请求进行中的 Loading 态。
  final Future<void>? gate;

  final List<String> urls = <String>[];

  int get codeRequests =>
      urls.where((url) => url.contains('fishtailed')).length;

  int get loginRequests =>
      urls.where((url) => url.contains('checkreins')).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    urls.add(options.uri.toString());
    await gate;
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

String _envelope([Map<String, dynamic>? data]) {
  return jsonEncode(<String, dynamic>{
    'unaccepted': 0,
    'unstably': 'success',
    'indulgences': data ?? <String, dynamic>{},
  });
}

ApiConfig _config(SessionStore store) {
  return ApiConfig(
    apiBaseUrl: 'http://login.test',
    signatureSecret: 'unit-test-secret',
    sessionStore: store,
    webBaseUrl: 'http://web.test',
    timestampProvider: () => 1700000000000,
    randomDigitsProvider: (length) => '1' * length,
  );
}

/// 设计稿坐标（375x812 画布）对应的 widget 矩形。
Rect _designRect(double left, double top, double width, double height) =>
    Rect.fromLTWH(left, top, width, height);

/// 触发协议文案里某一段链接的点击回调。
///
/// 测试字体每个字形都是等宽方块，协议文案的第二行会被 `maxLines` 截断，
/// 没法用 `tapOnText` 命中；真机字体下两行都能点到，所以这里直接调用链接
/// 自己的 [TapGestureRecognizer]。
void _tapAgreementSpan(WidgetTester tester, String text) {
  final richText = tester.widget<RichText>(
    find.byWidgetPredicate(
      (widget) =>
          widget is RichText && widget.text.toPlainText().contains(text),
    ),
  );
  TextSpan? target;
  void walk(InlineSpan span) {
    if (target != null || span is! TextSpan) return;
    if (span.recognizer != null && span.toPlainText() == text) {
      target = span;
      return;
    }
    for (final child in span.children ?? const <InlineSpan>[]) {
      walk(child);
    }
  }

  walk(richText.text);
  (target!.recognizer! as TapGestureRecognizer).onTap!();
}

void main() {
  late SessionStore store;
  late _StubAdapter adapter;
  late List<String> webViewUrls;
  late List<String> webViewTitles;

  /// 断言 EasyLoading 浮层上的提示文案（设计稿的提示也是浮层，不是内联文案）。
  ///
  /// 提示要等 Loading 收起动画跑完才出现，所以这里在有限帧内等到它出现。
  Future<void> expectToast(WidgetTester tester, String message) async {
    for (var frame = 0; frame < 8; frame++) {
      if (find.text(message).evaluate().isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text(message), findsOneWidget);
  }

  /// EasyLoading 的提示动画与 2 秒展示计时器是跨用例共享的单例状态：把一次提示
  /// 完整跑完，避免它以未完成的 Timer 收尾（“A Timer is still pending”）。
  Future<void> drainToast(WidgetTester tester) async {
    for (var second = 0; second < 6; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  setUp(() {
    Get.testMode = true;
    store = SessionStore.memory();
    webViewUrls = <String>[];
    webViewTitles = <String>[];
    adapter = _StubAdapter(
      (options) async => ResponseBody.fromString(
        _envelope(
          options.uri.path.contains('checkreins')
              ? <String, dynamic>{'sandman': 'session-123'}
              : null,
        ),
        200,
        headers: _jsonHeaders,
      ),
    );
  });

  tearDown(() => Get.reset());

  /// 以 375x812 的设计画布渲染登录页。
  ///
  /// [canvas] / [topInset] 用来模拟其它机型：设计稿画布假设状态栏 50。
  Future<void> pumpLogin(
    WidgetTester tester, {
    Size canvas = const Size(375, 812),
    double topInset = 0,
  }) async {
    tester.view.physicalSize = canvas;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = ApiClient(
      _config(store),
      dio: Dio()..httpClientAdapter = adapter,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        // 用真实主题跑：登录页必须自己扛住全局 InputDecorationTheme 的影响。
        theme: AppTheme.light(),
        builder: (context, child) => RepaintBoundary(
          key: _captureKey,
          child: EasyLoading.init()(
            context,
            MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(padding: EdgeInsets.only(top: topInset)),
              child: child!,
            ),
          ),
        ),
        initialRoute: _homeRoute,
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: _homeRoute,
            page: () => const Scaffold(body: Center(child: Text('home'))),
          ),
          GetPage<void>(
            name: AppRoutes.login,
            page: () => const LoginPage(),
            binding: BindingsBuilder<void>(
              () => Get.put<LoginController>(
                LoginController(apiClient: client, sessionStore: store),
              ),
            ),
          ),
          GetPage<void>(
            name: AppRoutes.webView,
            page: () {
              final arguments = Get.arguments;
              if (arguments is Map) {
                webViewUrls.add(arguments['url']?.toString() ?? '');
                webViewTitles.add(arguments['title']?.toString() ?? '');
              }
              return const Scaffold(body: Center(child: Text('webview')));
            },
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    Get.toNamed<void>(AppRoutes.login);
    await tester.pumpAndSettle();
  }

  testWidgets('按设计稿坐标渲染登录页各层', (tester) async {
    await pumpLogin(tester);

    expect(find.text('APP NAME'), findsOneWidget);
    expect(find.text('+63'), findsOneWidget);
    expect(find.text('Please fill in your phone number'), findsOneWidget);
    expect(find.text('Send SMS verification code'), findsOneWidget);
    expect(find.text('Get Code'), findsOneWidget);
    expect(find.text('Sign up / Sign in'), findsOneWidget);
    expect(find.text('Cellphone number'), findsOneWidget);
    expect(find.text('Verification Code'), findsOneWidget);

    expect(
      tester.getRect(find.byKey(const Key('login-phone-field'))),
      _designRect(32, 345, 311, 48),
    );
    expect(
      tester.getRect(find.byKey(const Key('login-code-field'))),
      _designRect(32, 451, 311, 48),
    );
    expect(
      tester.getRect(find.byKey(const Key('login-send-code'))),
      _designRect(243, 461, 86, 28),
    );
    expect(
      tester.getRect(find.byKey(const Key('login-submit'))),
      _designRect(50, 619, 274, 52),
    );
    expect(
      tester.getRect(find.byKey(const Key('login-back'))),
      _designRect(14, 58, 24, 24),
    );

    // 背景与卡片都是设计稿导出的切图：背景铺满 375x812 画布，卡片切图按它自己
    // 的 @3x 网格摆放（导出原点 682 不能被 3 整除，按整数摆会让整块位图重采样）。
    expect(
      tester.getRect(find.byKey(const Key('login-background'))),
      _designRect(0, 0, 375, 812),
    );
    expect(
      tester.getRect(find.byKey(const Key('login-card-artwork'))),
      Rect.fromLTWH(12, 682 / 3, 349, 368),
    );
    expect(
      tester
          .widget<Image>(
            find.descendant(
              of: find.byKey(const Key('login-card-artwork')),
              matching: find.byType(Image),
            ),
          )
          .image,
      const AssetImage('assets/login/login_card.png'),
    );
    // 返回键的白色圆角底与箭头都在切图里，页面不再自己画底。
    expect(
      tester
          .widget<Image>(
            find.descendant(
              of: find.byKey(const Key('login-back')),
              matching: find.byType(Image),
            ),
          )
          .image,
      const AssetImage('assets/login/login_back.png'),
    );
  });

  testWidgets('状态栏更高的机型上返回键避开状态栏', (tester) async {
    // iPhone 16 Pro：393x852、状态栏 62；设计稿画布是 375x812 / 50。
    const canvas = Size(393, 852);
    await pumpLogin(tester, canvas: canvas, topInset: 62);

    final scale = canvas.width / 375;
    final back = tester.getRect(find.byKey(const Key('login-back')));
    expect(back.top, closeTo(62 + 8 * scale, 0.01));

    // 其余元素仍按设计稿坐标等比放大（纵向位置由文本行高累加而来，
    // 会跟着字体度量取整，所以只校验到 1px）。
    final field = tester.getRect(find.byKey(const Key('login-phone-field')));
    expect(field.left, closeTo(32 * scale, 0.01));
    expect(field.top, closeTo(345 * scale, 1));
    expect(field.width, closeTo(311 * scale, 0.01));
    expect(field.height, closeTo(48 * scale, 0.01));
  });

  testWidgets('默认态：协议未勾选，点击协议可切换勾选', (tester) async {
    await pumpLogin(tester);

    Image checkbox() =>
        tester.widget<Image>(find.byKey(const Key('login-agreement-checkbox')));

    expect(
      checkbox().image,
      const AssetImage('assets/login/login_checkbox_unchecked.png'),
    );

    await tester.tap(find.byKey(const Key('login-agreement')));
    await tester.pump();

    expect(
      checkbox().image,
      const AssetImage('assets/login/login_checkbox_checked.png'),
    );
  });

  testWidgets('手机号格式无效时不请求验证码', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.byKey(const Key('login-phone')),
      '737478847391000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(adapter.codeRequests, 0);
    await expectToast(tester, 'Invalid phone number format.');
    await drainToast(tester);
  });

  testWidgets('格式无效但表单填满时主按钮仍是可用态，且只提示不打登录接口', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.byKey(const Key('login-phone')),
      '737478847391000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-agreement')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();

    // 设计稿 01-02 - 登录-电话号码格式无效：验证码填满时主按钮已经是橙色，
    // 说明可用态只看「手机号非空 + 验证码满 6 位 + 已勾选」，不含格式校验。
    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(
                    of: find.byKey(const Key('login-submit')),
                    matching: find.byType(DecoratedBox),
                  ),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.gradient, AppColors.homeWarmGradient);

    // 但格式不合法时不会打登录接口，只给出格式提示。
    await tester.pump(const Duration(milliseconds: 10));
    expect(adapter.loginRequests, 0);
    await expectToast(tester, 'Invalid phone number format.');
    await drainToast(tester);
  });

  testWidgets('提示浮层按设计稿尺寸居中', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(
      find.byKey(const Key('login-phone')),
      '737478847391000',
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump(const Duration(milliseconds: 250));

    // 设计稿 01-02 - 登录-电话号码格式无效：151x144 的方块居中在 375x812 画布上。
    final box = find.byKey(const Key('app-hint'));
    expect(box, findsOneWidget);
    expect(tester.getRect(box), _designRect(112, 334, 151, 144));

    final decoration =
        tester
                .widget<DecoratedBox>(
                  find.descendant(of: box, matching: find.byType(DecoratedBox)),
                )
                .decoration
            as BoxDecoration;
    expect(decoration.color, AppColors.hintSurface);
    expect(decoration.borderRadius, BorderRadius.circular(8));
    await drainToast(tester);
  });

  testWidgets('输入框不受全局 InputDecorationTheme 影响：纯白底、无描边', (tester) async {
    await pumpLogin(tester);

    // 全局主题给输入框配了浅灰填充（filled + fillColor）和「默认 1px / 聚焦 1.5px」
    // 的描边；设计稿里的输入框只有一块白色圆角底，所以两种状态下四条边都得是白的。
    for (final focus in <bool>[false, true]) {
      if (focus) {
        await tester.tap(find.byKey(const Key('login-phone')));
        await tester.pumpAndSettle();
      }
      final pixels = await _capturePixels(tester);
      final field = tester.getRect(find.byKey(const Key('login-phone')));
      final top = field.top + 3;
      for (final ratio in <double>[0.3, 0.5, 0.7]) {
        final x = field.left + field.width * ratio;
        expect(pixels.at(x, field.top), _white, reason: '聚焦=$focus 上边$ratio');
        expect(
          pixels.at(x, field.bottom - 1),
          _white,
          reason: '聚焦=$focus 下边$ratio',
        );
      }
      expect(pixels.at(field.left, top), _white, reason: '聚焦=$focus 左边');
      expect(pixels.at(field.right - 1, top), _white, reason: '聚焦=$focus 右边');
    }
  });

  testWidgets('手机号为空时点击 Get Code 既不请求也不提示', (tester) async {
    await pumpLogin(tester);

    await tester.tap(find.byKey(const Key('login-send-code')));
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // 空输入没有「格式不对」可言，保持安静；填了但格式不对才提示（设计稿 3）。
    expect(adapter.codeRequests, 0);
    expect(find.text('Invalid phone number format.'), findsNothing);
  });

  testWidgets('提交时收起键盘，表单不被键盘遮挡', (tester) async {
    await pumpLogin(tester);

    final codeField = find.byKey(const Key('login-code'));
    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-agreement')));
    await tester.pump();

    // 还没填满 6 位时焦点在验证码输入框上（键盘是弹出的）。
    await tester.enterText(codeField, '11111');
    await tester.pump();
    final controller = Get.find<LoginController>();
    expect(controller.codeFocus.hasFocus, isTrue);

    // 第 6 位触发自动登录，提交时收起键盘（设计稿的已输入态没有键盘）。
    await tester.enterText(codeField, '111111');
    await tester.pump(const Duration(milliseconds: 10));

    expect(adapter.loginRequests, 1);
    expect(controller.codeFocus.hasFocus, isFalse);
  });

  testWidgets('合法手机号可获取验证码并进入 60 秒倒计时', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(adapter.codeRequests, 1);
    expect(find.text('60s'), findsOneWidget);
    await expectToast(tester, 'Verification code sent.');

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('59s'), findsOneWidget);

    // 倒计时结束后按钮回到可再次获取验证码的状态。
    await tester.pump(const Duration(seconds: 60));
    expect(find.text('Get Code'), findsOneWidget);
    await drainToast(tester);
  });

  testWidgets('验证码满 6 位且已同意协议时自动登录并回传登录结果', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-agreement')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(adapter.loginRequests, 1);
    expect(await store.sessionId(), 'session-123');
    expect(await store.phone(), '9171234567');
    expect(Get.currentRoute, _homeRoute);
  });

  testWidgets('未勾选协议时填满验证码立刻提示，且不调用登录接口', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();

    // 不需要再点主按钮：填满第 6 位就给出「先勾选协议」的提示（与 Dali 系列一致）。
    await expectToast(
      tester,
      'Please agree to the Privacy Policy and Terms of Service',
    );
    expect(adapter.loginRequests, 0);
    expect(Get.find<LoginController>().isSignInReady, isFalse);
    await drainToast(tester);

    // 勾选协议后主按钮转为可用态，点击即登录。
    await tester.tap(find.byKey(const Key('login-agreement')));
    await tester.pump();
    expect(Get.find<LoginController>().isSignInReady, isTrue);
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump(const Duration(milliseconds: 10));
    expect(adapter.loginRequests, 1);
    expect(Get.currentRoute, _homeRoute);
    await drainToast(tester);
  });

  testWidgets('手机号为空时填满验证码既不提示也不登录', (tester) async {
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // 还没填手机号就先把验证码填满时，不该冒出「手机号格式无效」。
    expect(adapter.loginRequests, 0);
    expect(find.text('Invalid phone number format.'), findsNothing);
    expect(
      find.text('Please agree to the Privacy Policy and Terms of Service'),
      findsNothing,
    );
  });

  testWidgets('请求进行中展示 Loading，回来后收起再提示', (tester) async {
    final release = Completer<void>();
    adapter = _StubAdapter(
      (options) async =>
          ResponseBody.fromString(_envelope(), 200, headers: _jsonHeaders),
      gate: release.future,
    );

    await pumpLogin(tester);
    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump(const Duration(milliseconds: 250));

    // 请求还没回来时页面处于 Loading 态，而不是「点了没反应」。
    expect(adapter.codeRequests, 1);
    expect(find.text('Loading...'), findsOneWidget);

    release.complete();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (find.text('Loading...').evaluate().isEmpty) break;
    }

    expect(find.text('Loading...'), findsNothing);
    await expectToast(tester, 'Verification code sent.');
    // 倒计时与提示都跑完，避免留下未完成的 Timer。
    await tester.pump(const Duration(seconds: 65));
    await drainToast(tester);
  });

  testWidgets('协议链接按文档登记的 H5 混淆段打开', (tester) async {
    await pumpLogin(tester);

    // 接口文档「值映射 -> Scheme -> h5页面混淆」：域名取服务端下发，路径用混淆段。
    final controller = Get.find<LoginController>();
    expect(controller.privacyUrl, 'http://web.test/#/Pederast');
    expect(controller.termsUrl, 'http://web.test/#/Carbonate');

    await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
    await tester.pumpAndSettle();

    expect(webViewUrls, <String>['http://web.test/#/Pederast']);
    expect(webViewTitles, <String>['Privacy Policy']);

    Get.back<void>();
    await tester.pumpAndSettle();

    _tapAgreementSpan(tester, 'Terms of Service');
    await tester.pumpAndSettle();

    expect(webViewUrls.last, 'http://web.test/#/Carbonate');
    expect(webViewTitles.last, 'Terms of Service');
  });

  testWidgets('已登录过的手机号会自动回填', (tester) async {
    await store.savePhone('9179998888');

    await pumpLogin(tester);

    expect(find.text('9179998888'), findsOneWidget);
    expect(Get.find<LoginController>().phoneDigits.value, '9179998888');
  });
}
