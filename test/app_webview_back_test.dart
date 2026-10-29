import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide FormData;
import 'package:handa_peso/app/navigation/app_navigator.dart';
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

  testWidgets('换卡塌回根后点返回：一次就退出到首页，不回退到账户列表', (tester) async {
    // reczz28Sjm17GWSd：换卡成功后栈里还留着账户列表和旧 H5 时，返回会在
    // 「确定用款页 ↔ Loan details」之间打转。换成「只留根」的替换后，新 H5
    // 之上没有任何原生中间页，返回一次就该落回首页。
    platform.controller.bridgeCanGoBack = false;
    await _pumpPage(tester, withPayoutAccounts: true);
    // 账户列表压在来源 H5 下面，屏上不可见但确实在栈里（skipOffstage: false）。
    expect(find.text('payout-accounts', skipOffstage: false), findsOneWidget);

    // 新 H5 是一个新页面：让测试替身再走一次首屏完成，避免加载动画把
    // pumpAndSettle 拖住。
    platform.controller.created = false;
    // 这个 Future 要等新 H5 被关掉才完成，不能在用例里 await。
    unawaited(
      AppNavigator.toWebViewResettingFlow(url: _orderUrl, title: 'Details'),
    );
    await _pumpUntil(
      tester,
      () => find.byKey(const Key('webview-back')).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppWebViewPage), findsOneWidget);
    // 中间页被替换链路带走，不留残骸（skipOffstage: false：还留在栈里的
    // 路由只是不在屏上，默认断言会假通过）。
    expect(find.text('payout-accounts', skipOffstage: false), findsNothing);

    await tester.tap(find.byKey(const Key('webview-back')));
    await tester.pumpAndSettle();

    expect(find.byType(AppWebViewPage), findsNothing);
    expect(find.text('home'), findsOneWidget);
    expect(find.text('payout-accounts', skipOffstage: false), findsNothing);
    expect(platform.controller.historyBackCalls, 0);
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

Future<void> _pumpPage(
  WidgetTester tester, {
  String url = _orderUrl,
  bool withPayoutAccounts = false,
}) async {
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
        GetPage<void>(
          name: AppRoutes.payoutAccounts,
          page: () => const Scaffold(body: Text('payout-accounts')),
        ),
        GetPage<void>(
          name: AppRoutes.bindCard,
          page: () => const Scaffold(body: Text('bind-card')),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  if (withPayoutAccounts) {
    // 换卡链路：来源 H5 → 账户列表 → （替换）新 H5。
    Get.toNamed<void>(AppRoutes.payoutAccounts);
    await tester.pumpAndSettle();
  }
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
