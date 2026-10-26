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
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/report/report_bridge.dart';
import 'package:handa_peso/core/report/report_service.dart';
import 'package:handa_peso/core/report/report_store.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/core/analytics/analytics_service.dart';
import 'package:handa_peso/features/login/login_controller.dart';
import 'package:handa_peso/features/login/login_page.dart';
import 'package:handa_peso/features/main_shell/main_controller.dart';

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

/// 只记录调用参数的假上报服务：用于断言登录页把“进入登录页的时间”交给了注册埋点。
class _SpyReportService extends ReportService {
  _SpyReportService(GatewayClient client)
    : super(
        gatewayClient: client,
        store: ReportStore.memory(),
        bridge: ReportNativeBridge(available: false),
      );

  int? registrationStartedAtSeconds;

  @override
  Future<void> loginSucceeded({int? registeredAtSeconds}) async {
    registrationStartedAtSeconds = registeredAtSeconds;
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

  int get homeRequests =>
      urls.where((url) => url.contains('indulgences')).length;

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

String _envelope({Map<String, dynamic>? data, String note = 'success'}) {
  return jsonEncode(<String, dynamic>{
    'unaccepted': 0,
    'unstably': note,
    'indulgences': data ?? <String, dynamic>{},
  });
}

/// 短信接口下发的「验证码已发出」文案（信封的 `unstably`）。
///
/// 端上不写死这句话：参考端也是把接口文案直接丢给 HUD。
const String _codeSentNote = 'Code sent to your cellphone';

GatewaySettings _config(LocalSession store) {
  return GatewaySettings(
    apiOrigin: 'http://login.test',
    signSecret: 'unit-test-secret',
    localSession: store,
    webOrigin: 'http://web.test',
    clock: () => 1700000000000,
    noiseDigits: (length) => '1' * length,
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
  late LocalSession store;
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
    store = LocalSession.memory();
    webViewUrls = <String>[];
    webViewTitles = <String>[];
    adapter = _StubAdapter(
      (options) async => ResponseBody.fromString(
        _envelope(
          data: options.uri.path.contains('checkreins')
              ? <String, dynamic>{'sandman': 'session-123'}
              : null,
          // 验证码已发出的提示由接口下发，端上只负责展示。
          note: options.uri.path.contains('fishtailed')
              ? _codeSentNote
              : 'success',
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
  Future<GatewayClient> pumpLogin(
    WidgetTester tester, {
    Size canvas = const Size(375, 812),
    double topInset = 0,
    ReportService Function(GatewayClient client)? reporter,
    int Function()? clock,
  }) async {
    tester.view.physicalSize = canvas;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final client = GatewayClient(
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
                LoginController(
                  gatewayClient: client,
                  localSession: store,
                  reportService: reporter?.call(client),
                  clock: clock,
                ),
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
    return client;
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

  testWidgets('默认态：协议已同意，点击协议可取消勾选', (tester) async {
    await pumpLogin(tester);

    Image checkbox() =>
        tester.widget<Image>(find.byKey(const Key('login-agreement-checkbox')));

    expect(
      checkbox().image,
      const AssetImage('assets/login/login_checkbox_checked.png'),
    );

    await tester.tap(find.byKey(const Key('login-agreement')));
    await tester.pump();

    expect(
      checkbox().image,
      const AssetImage('assets/login/login_checkbox_unchecked.png'),
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

  testWidgets('手机号格式无效时只提示不打登录接口，并复位验证码', (tester) async {
    await pumpLogin(tester);
    final controller = Get.find<LoginController>();

    await tester.enterText(
      find.byKey(const Key('login-phone')),
      '737478847391000',
    );
    await tester.pump();
    // 直接写状态：第 6 位验证码会触发自动提交，先量主按钮的可用态。
    controller.codeDigits.value = '111111';
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

    // 提交：格式不合法时不会打登录接口，只给出格式提示。提示还在屏上时输入框
    // 保持原样——复位要等提示播完（展示 2 秒 + 淡出）再做。
    await tester.tap(find.byKey(const Key('login-submit')));
    await tester.pump(const Duration(milliseconds: 10));

    expect(adapter.loginRequests, 0);
    await expectToast(tester, 'Invalid phone number format.');
    expect(controller.codeDigits.value, '111111');
    expect(controller.codeFocus.hasFocus, isFalse);

    // 提示播完再复位（清空 + 光标回到验证码框），手机号保留。
    await drainToast(tester);
    expect(controller.codeField.text, isEmpty);
    expect(controller.codeDigits.value, isEmpty);
    expect(controller.codeFocus.hasFocus, isTrue);
    expect(controller.phoneField.text, '737478847391000');
    expect(find.text('111111'), findsNothing);
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
    await expectToast(tester, _codeSentNote);

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
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(adapter.loginRequests, 1);
    expect(await store.readSessionId(), 'session-123');
    expect(await store.readPhone(), '9171234567');
    expect(Get.currentRoute, _homeRoute);
  });

  testWidgets('登录成功先收尾登录页，外壳刷新等回到外壳再做', (tester) async {
    adapter = _StubAdapter((options) async {
      final path = options.uri.path;
      if (path.contains('checkreins')) {
        return ResponseBody.fromString(
          _envelope(data: <String, dynamic>{'sandman': 'session-123'}),
          200,
          headers: _jsonHeaders,
        );
      }
      if (path.contains('indulgences')) {
        return ResponseBody.fromString(_envelope(), 200, headers: _jsonHeaders);
      }
      return ResponseBody.fromString(
        _envelope(note: _codeSentNote),
        200,
        headers: _jsonHeaders,
      );
    });

    final client = await pumpLogin(tester);
    final shell = MainController(gatewayClient: client, localSession: store);
    Get.put<MainController>(shell);
    addTearDown(() {
      if (Get.isRegistered<MainController>()) {
        Get.delete<MainController>(force: true);
      }
    });
    await tester.pumpAndSettle();
    expect(adapter.homeRequests, 1);
    expect(shell.overviewLoading.value, isFalse);

    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 250));
    }

    // 登录页收尾不等外壳刷新：登录成功当场离开登录页。
    expect(find.text('Loading...'), findsNothing);
    expect(Get.currentRoute, _homeRoute);
    expect(await store.readSessionId(), 'session-123');
    expect(shell.sessionPhone.value, '9171234567');

    // 首页刷新交给「回到外壳」那一次（见 home_page_test 的登录用例），登录页上
    // 不再重复请求首页+弹窗接口。
    expect(adapter.homeRequests, 1);
    expect(shell.overviewLoading.value, isFalse);
  });

  testWidgets('发码还没回来就自动登录，转圈要留到登录请求回来才收', (tester) async {
    final codeGate = Completer<void>();
    final loginGate = Completer<void>();
    adapter = _StubAdapter((options) async {
      final path = options.uri.path;
      if (path.contains('fishtailed')) {
        await codeGate.future;
        return ResponseBody.fromString(
          _envelope(note: _codeSentNote),
          200,
          headers: _jsonHeaders,
        );
      }
      if (path.contains('checkreins')) {
        await loginGate.future;
        return ResponseBody.fromString(
          _envelope(data: <String, dynamic>{'sandman': 'session-123'}),
          200,
          headers: _jsonHeaders,
        );
      }
      return ResponseBody.fromString(_envelope(), 200, headers: _jsonHeaders);
    });
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.text('Loading...'), findsOneWidget);

    // 验证码还没到，用户直接把 6 位码填进去触发自动登录。
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();

    // 发码先回来：登录还在路上，转圈不能被发码那次收掉。
    codeGate.complete();
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(adapter.loginRequests, 1);
    expect(find.text('Loading...'), findsOneWidget);

    loginGate.complete();
    for (var frame = 0; frame < 6; frame++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.text('Loading...'), findsNothing);
    expect(Get.currentRoute, _homeRoute);
    expect(await store.readSessionId(), 'session-123');

    // 倒计时与提示跑完，避免留下未完成的 Timer。
    await tester.pump(const Duration(seconds: 65));
    await drainToast(tester);
  });

  testWidgets('重新获取验证码后，注册埋点的开始时间跟着刷新', (tester) async {
    var nowSeconds = 1700000000;
    late _SpyReportService spy;
    await pumpLogin(
      tester,
      clock: () => nowSeconds,
      reporter: (client) => spy = _SpyReportService(client),
    );

    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();

    // 发码前把时钟推后：注册埋点要用「最近一次拿到验证码」的时刻。
    nowSeconds = 1700000060;
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump(const Duration(milliseconds: 250));
    await drainToast(tester);

    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    expect(spy.registrationStartedAtSeconds, 1700000060);
  });

  testWidgets('登录成功把进入登录页的时间交给上报服务做注册埋点', (tester) async {
    final openedAfter = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    late _SpyReportService spy;
    await pumpLogin(
      tester,
      reporter: (client) => spy = _SpyReportService(client),
    );

    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 10));

    // 注册埋点的开始时间 = 打开登录页的时刻，必须早于提交时刻且不为空。
    expect(spy.registrationStartedAtSeconds, isNotNull);
    expect(spy.registrationStartedAtSeconds, greaterThanOrEqualTo(openedAfter));
    expect(
      spy.registrationStartedAtSeconds,
      lessThanOrEqualTo(DateTime.now().millisecondsSinceEpoch ~/ 1000 + 1),
    );
  });

  testWidgets('登录失败后提示错误、清空验证码，重试仍可登录成功', (tester) async {
    // 失败会被上报给 Crashlytics 适配器；此处拦截上报，只断言页面表现
    // （与首页的失败用例一致）。
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    var attempts = 0;
    adapter = _StubAdapter((options) async {
      attempts++;
      return ResponseBody.fromString(
        attempts == 1
            ? jsonEncode(<String, dynamic>{
                'unaccepted': 1,
                'unstably': 'Verification code is incorrect',
                'indulgences': <String, dynamic>{},
              })
            : _envelope(data: <String, dynamic>{'sandman': 'session-123'}),
        200,
        headers: _jsonHeaders,
      );
    });
    await pumpLogin(tester);

    final controller = Get.find<LoginController>();
    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // 失败：只发一次请求，先播服务端文案；播放期间输入框原样保留，等它播完
    // 才把验证码清空、把光标拽回验证码框。
    expect(adapter.loginRequests, 1);
    expect(reported, isNotEmpty);
    await expectToast(tester, 'Verification code is incorrect');
    expect(controller.codeField.text, '111111');
    expect(controller.codeFocus.hasFocus, isFalse);

    await drainToast(tester);
    expect(controller.codeField.text, isEmpty);
    expect(controller.codeDigits.value, isEmpty);
    expect(find.text('111111'), findsNothing);
    expect(controller.codeFocus.hasFocus, isTrue);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('login-code')))
          .focusNode!
          .hasFocus,
      isTrue,
    );
    expect(controller.signingIn.value, isFalse);
    expect(controller.isSignInReady, isFalse);
    expect(Get.currentRoute, AppRoutes.login);
    expect(await store.readSessionId(), isEmpty);

    // 失败后重试：重新输入验证码即登录成功。
    await tester.enterText(find.byKey(const Key('login-code')), '222222');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(adapter.loginRequests, 2);
    expect(await store.readSessionId(), 'session-123');
    expect(Get.currentRoute, _homeRoute);
  });

  testWidgets('取消勾选协议后填满验证码立刻提示，且不调用登录接口', (tester) async {
    await pumpLogin(tester);

    // 协议默认已同意，这里主动取消勾选。
    await tester.tap(find.byKey(const Key('login-agreement')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();

    // 不需要再点主按钮：填满第 6 位就给出「先勾选协议」的提示（与 Dali 系列一致）。
    await expectToast(
      tester,
      'Please agree to the Privacy Policy and Terms of Service',
    );
    final controller = Get.find<LoginController>();
    expect(adapter.loginRequests, 0);
    expect(controller.isSignInReady, isFalse);
    // 提示还在屏上时不动输入框；播完再复位（清空 + 光标回到验证码框），手机号保留。
    expect(controller.codeField.text, '111111');
    expect(controller.codeFocus.hasFocus, isFalse);

    await drainToast(tester);
    expect(controller.codeField.text, isEmpty);
    expect(controller.codeFocus.hasFocus, isTrue);
    expect(controller.phoneField.text, '9171234567');

    // 重新勾选协议并重新输入验证码：第 6 位触发自动登录。
    await tester.tap(find.byKey(const Key('login-agreement')));
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '222222');
    await tester.pump();
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
      (options) async => ResponseBody.fromString(
        _envelope(note: _codeSentNote),
        200,
        headers: _jsonHeaders,
      ),
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
    await expectToast(tester, _codeSentNote);
    // 倒计时与提示都跑完，避免留下未完成的 Timer。
    await tester.pump(const Duration(seconds: 65));
    await drainToast(tester);
  });

  testWidgets('接口没下发文案时，验证码提示退回本地兜底文案', (tester) async {
    adapter = _StubAdapter(
      (options) async => ResponseBody.fromString(
        _envelope(note: ''),
        200,
        headers: _jsonHeaders,
      ),
    );
    await pumpLogin(tester);

    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.tap(find.byKey(const Key('login-send-code')));
    await tester.pump(const Duration(milliseconds: 250));

    expect(adapter.codeRequests, 1);
    await expectToast(tester, codeSentHint);
    await tester.pump(const Duration(seconds: 65));
    await drainToast(tester);
  });

  testWidgets('HTTP 状态码 >= 400 时展示接口下发的错误文案，并复位验证码', (tester) async {
    final reported = <FlutterErrorDetails>[];
    final previous = FlutterError.onError;
    FlutterError.onError = reported.add;
    addTearDown(() => FlutterError.onError = previous);

    adapter = _StubAdapter(
      (options) async => ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'unaccepted': 500,
          'unstably': 'The service is busy, please try again later',
          'indulgences': <String, dynamic>{},
        }),
        500,
        headers: _jsonHeaders,
      ),
    );
    await pumpLogin(tester);

    final controller = Get.find<LoginController>();
    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    // 500 的响应体里带着接口文案，优先展示它，而不是本地拼的「Request failed (500).」。
    expect(adapter.loginRequests, 1);
    expect(reported, isNotEmpty);
    await expectToast(tester, 'The service is busy, please try again later');
    expect(find.text('Request failed (500).'), findsNothing);

    await drainToast(tester);
    expect(controller.codeField.text, isEmpty);
    expect(controller.codeFocus.hasFocus, isTrue);
  });

  testWidgets('业务码 -1 的验证码错误：框架错误上报不得吃掉接口文案', (tester) async {
    // 真机上 `main()` 把 `FlutterError.onError` 接到了崩溃上报上，而上报出口
    // （debug 出口是 `FlutterError.reportError`）会再绕回 onError。这里按同样
    // 的接法跑：上报一旦递归，栈溢出会把下面这段「弹提示 + 复位验证码」掀掉，
    // 用户就只看到接口报错、页面上什么都没有。
    final previous = FlutterError.onError;
    var onErrorCalls = 0;
    FlutterError.onError = (details) {
      onErrorCalls += 1;
      expect(onErrorCalls, lessThan(5));
      CrashReporter.record(
        details.exception,
        details.stack ?? StackTrace.current,
      );
    };
    addTearDown(() => FlutterError.onError = previous);

    // 抓包实测：HTTP 200，业务码是字符串 "-1"。
    adapter = _StubAdapter(
      (options) async => ResponseBody.fromString(
        jsonEncode(<String, dynamic>{
          'unaccepted': '-1',
          'unstably': 'Verification code is invalid, please try again',
          'indulgences': <String, dynamic>{
            'EGE6xy': 'ltZZ680',
            'f5SIV7Zy2o': null,
            'lqo5': 'false',
            'ufY1ixe0RQ8V': 94766762,
            'ranulas': <String, dynamic>{},
          },
        }),
        200,
        headers: _jsonHeaders,
      ),
    );
    await pumpLogin(tester);

    final controller = Get.find<LoginController>();
    await tester.enterText(find.byKey(const Key('login-phone')), '9171234567');
    await tester.pump();
    await tester.enterText(find.byKey(const Key('login-code')), '111111');
    await tester.pump();

    expect(adapter.loginRequests, 1);
    await expectToast(tester, 'Verification code is invalid, please try again');
    expect(await store.readSessionId(), isEmpty);
    expect(Get.currentRoute, AppRoutes.login);

    // 提示播完才复位：验证码清空、光标回到验证码框。
    await drainToast(tester);
    expect(controller.codeField.text, isEmpty);
    expect(controller.codeFocus.hasFocus, isTrue);
    expect(controller.signingIn.value, isFalse);
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
    await store.writePhone('9179998888');

    await pumpLogin(tester);

    expect(find.text('9179998888'), findsOneWidget);
    expect(Get.find<LoginController>().phoneDigits.value, '9179998888');
  });
}
