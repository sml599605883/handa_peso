import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide FormData;
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/analytics/analytics_service.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/webview/app_webview_page.dart';

import 'support/fake_inappwebview_platform.dart';

/// 普通业务页（不是确认用款页），返回时不会触发 scene=5 挽留弹窗。
const String _orderUrl = 'http://host/#/SomewhereElse?redecorates=1';

/// 页面顶部那条加载条（`LinearProgressIndicator`）。缺陷 reczz28SjoGTm9vy
/// 说的是它在 H5 页面上一直挂着收不掉。
final Finder _topBar = find.byType(LinearProgressIndicator);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = FakeInAppWebViewPlatform(
    FakePlatformController(_orderUrl),
  );
  InAppWebViewPlatform.instance = platform;

  setUp(() {
    Get.testMode = true;
    AnalyticsService.configure(_SilentTelemetrySink());
    platform.controller = FakePlatformController(_orderUrl);
  });

  tearDown(() async {
    await EasyLoading.dismiss();
    Get.reset();
  });

  testWidgets('首屏加载完成后顶部加载条收起，随后的进度回落不再显示', (tester) async {
    await _pumpApp(tester);
    await _openPage(tester);

    expect(_topBar, findsNothing);

    // H5 首屏之后还会继续加载图片/接口，进度可能回落到 100 以下：这时不该
    // 再把已经收起的加载条重新挂上去。
    platform.controller.emitProgress(60);
    platform.controller.emitProgress(99);
    await tester.pump();
    await tester.pump();

    expect(_topBar, findsNothing);
  });

  testWidgets('首屏加载失败时加载条收起，改由页面自己的失败提示接管', (tester) async {
    platform.controller = FakePlatformController(_orderUrl)
      ..autoFinishLoad = false;
    await _pumpApp(tester);
    await _openPage(tester);

    expect(_topBar, findsOneWidget);

    platform.controller.emitLoadError();
    await tester.pump();

    expect(_topBar, findsNothing);
    expect(find.byKey(const Key('webview-retry')), findsOneWidget);
    expect(find.text('The page could not be loaded.'), findsOneWidget);
  });

  testWidgets('站内二次跳转：新文档开始加载时重新出现，加载完成后再次收起', (tester) async {
    await _pumpApp(tester);
    await _openPage(tester);
    expect(_topBar, findsNothing);

    platform.controller.emitLoadStart();
    await tester.pump();
    expect(_topBar, findsOneWidget);

    platform.controller.emitLoadStop();
    await tester.pump();
    expect(_topBar, findsNothing);
  });

  testWidgets('站内跳转交给原生页接管后加载条收起（导航被取消，WebView 不再回报完成）', (tester) async {
    await _pumpApp(tester);
    await _openPage(tester);

    platform.controller.emitLoadStart();
    await tester.pump();
    expect(_topBar, findsOneWidget);

    // 站内点到一个原生深链（这里是「回首页」）：页面把这次导航交给
    // `AppNavigator`，随后取消加载。WebView 不会再回调 `onLoadStop`，加载条
    // 只能由导航侧自己收。
    final policy = await platform.controller.emitNavigation(
      'ph://handa-peso/ios/SoulsClodpole',
    );
    await tester.pump();

    expect(policy, NavigationActionPolicy.CANCEL);
    expect(_topBar, findsNothing);
  });

  testWidgets('首屏既没有完成也没有失败回调时，兜底时长到点收起加载条', (tester) async {
    platform.controller = FakePlatformController(_orderUrl)
      ..autoFinishLoad = false;
    await _pumpApp(tester);
    await _openPage(tester);

    platform.controller.emitLoadStart();
    platform.controller.emitProgress(97);
    await tester.pump();
    expect(_topBar, findsOneWidget);

    await tester.pump(webViewLoadingFallback + const Duration(seconds: 1));

    expect(_topBar, findsNothing);
    // 兜底只收加载条，不能把页面判定成失败。
    expect(find.byKey(const Key('webview-retry')), findsNothing);
  });

  testWidgets('取网页标题失败不影响收起加载条', (tester) async {
    platform.controller = FakePlatformController(_orderUrl)..failGetTitle = true;
    await _pumpApp(tester);
    await _openPage(tester);

    expect(_topBar, findsNothing);
    // 标题取不到时保留兜底标题，页面本身照常可用。
    expect(find.text('Details'), findsOneWidget);
  });

  testWidgets('关闭 H5 后重复进入：首屏加载中关掉不留兜底定时器，重进后依旧正常收起', (tester) async {
    await _pumpApp(tester);
    await _openPage(tester);
    expect(_topBar, findsNothing);

    // 加载条还挂着的时候直接关页面：兜底定时器必须跟着 State 一起取消。
    platform.controller.emitLoadStart();
    await tester.pump();
    expect(_topBar, findsOneWidget);

    platform.controller.bridgeCanGoBack = false;
    await tester.tap(find.byKey(const Key('webview-back')));
    await _pumpUntil(
      tester,
      () => find.byType(AppWebViewPage).evaluate().isEmpty,
    );
    expect(find.byType(AppWebViewPage), findsNothing);

    // 再次进入：新的 State、新的控制器，首屏完成后同样收起。
    platform.controller = FakePlatformController(_orderUrl);
    await _openPage(tester);
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(AppWebViewPage), findsOneWidget);
    expect(_topBar, findsNothing);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final client = GatewayClient(
    GatewaySettings(
      signSecret: 'unit-test-secret',
      localSession: LocalSession.memory(),
    ),
    dio: Dio(),
  );
  Get.put<GatewayClient>(client, permanent: true);

  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/home',
      builder: EasyLoading.init(),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(
          name: '/home',
          page: () => const Scaffold(body: Text('home')),
        ),
        GetPage<void>(
          name: AppRoutes.webView,
          page: () => const AppWebViewPage(),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _openPage(WidgetTester tester, {String url = _orderUrl}) async {
  Get.toNamed<void>(
    AppRoutes.webView,
    arguments: <String, dynamic>{'url': url, 'title': 'Details'},
  );
  await _pumpUntil(
    tester,
    () => find.byKey(const Key('webview-back')).evaluate().isNotEmpty,
  );
  // 假 WebView 在首帧之后回调 `onLoadStop`：多走一帧让页面把加载条收掉。
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var frame = 0; frame < 40 && !done(); frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _SilentTelemetrySink implements TelemetrySink {
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {}

  @override
  void setUserId(String? userId) {}

  @override
  void setUserProperty(String name, String? value) {}
}
