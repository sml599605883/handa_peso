import 'dart:async';

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

/// 普通业务页（不是确认用款页）：返回时不触发 scene=5 挽留弹窗。
const String _orderUrl = 'http://host/#/SomewhereElse?redecorates=1';

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

  testWidgets('首屏点返回：关闭 H5 回到来源页，不是白屏也不是无反应', (tester) async {
    platform.controller.bridgeCanGoBack = false;
    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('webview-back')));
    await tester.pumpAndSettle();

    expect(find.byType(AppWebViewPage), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(platform.controller.historyBackCalls, 0);
  });

  testWidgets('站内跳转后点返回：只发起一次 history.back()，不关页面', (tester) async {
    platform.controller.bridgeCanGoBack = true;
    await _pumpPage(tester);

    await tester.tap(find.byKey(const Key('webview-back')));
    await tester.pumpAndSettle();

    expect(platform.controller.historyBackCalls, 1);
    expect(platform.controller.goBackCalls, 0);
    expect(find.byType(AppWebViewPage), findsOneWidget);
  });

  testWidgets('连点返回只退一页', (tester) async {
    final gate = Completer<void>();
    platform.controller
      ..bridgeCanGoBack = true
      ..holdEval = gate;
    await _pumpPage(tester);

    final back = find.byKey(const Key('webview-back'));
    await tester.tap(back);
    await tester.tap(back);

    gate.complete();
    await tester.pumpAndSettle();

    expect(platform.controller.historyBackCalls, 1);
    expect(find.byType(AppWebViewPage), findsOneWidget);
  });

  testWidgets('系统返回（Android 物理键 / iOS 侧滑）走同一条决策链', (tester) async {
    platform.controller.bridgeCanGoBack = true;
    await _pumpPage(tester);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(platform.controller.historyBackCalls, 1);
    expect(find.byType(AppWebViewPage), findsOneWidget);
  });
}

Future<void> _pumpPage(WidgetTester tester, {String url = _orderUrl}) async {
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
  Get.toNamed<void>(
    AppRoutes.webView,
    arguments: <String, dynamic>{'url': url, 'title': 'Details'},
  );
  await _pumpUntil(
    tester,
    () => find.byKey(const Key('webview-back')).evaluate().isNotEmpty,
  );
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
