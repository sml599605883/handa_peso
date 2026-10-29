import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/navigation/app_navigator.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/analytics/analytics_service.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/main_shell/main_binding.dart';
import 'package:handa_peso/features/main_shell/main_controller.dart';
import 'package:handa_peso/features/main_shell/main_shell_page.dart';
import 'package:handa_peso/features/mine/account_page.dart';
import 'package:package_info_plus/package_info_plus.dart';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

/// 记录请求的适配器：首页信息流返回空模块，退出 / 注销返回成功。
class _StubAdapter implements HttpClientAdapter {
  final List<String> urls = <String>[];

  /// 退出登录接口（`/dropcloth/unaccepted`）的调用次数。
  int get logoutCalls => urls.where((url) => url.contains('unaccepted')).length;

  /// 注销账号接口（`/dropcloth/unstably`）的调用次数。
  int get deleteCalls => urls.where((url) => url.contains('unstably')).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    urls.add(options.uri.toString());
    return Future<ResponseBody>.value(
      ResponseBody.fromString(
        '{"unaccepted":0,"unstably":"success","indulgences":{}}',
        200,
        headers: _jsonHeaders,
      ),
    );
  }

  @override
  void close({bool force = false}) {}
}

/// 静默上报出口：退出 / 注销路径不需要把异常丢给测试框架。
class _QuietSink implements TelemetrySink {
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {}

  @override
  void setUserId(String? userId) {}

  @override
  void setUserProperty(String name, String? value) {}
}

GatewaySettings _config() {
  return GatewaySettings(
    apiOrigin: 'http://home.test',
    webOrigin: 'http://h5.test',
    signSecret: 'unit-test-secret',
    localSession: LocalSession.memory(),
    clock: () => 1700000000000,
    noiseDigits: (length) => '1' * length,
  );
}

GatewayClient _client(GatewaySettings config, HttpClientAdapter adapter) {
  return GatewayClient(config, dio: Dio()..httpClientAdapter = adapter);
}

/// 弹窗里的整卡切图（设计稿 `编组`）是否换成了对应的那一张。
Finder _retentionArtwork(String asset) => find.byWidgetPredicate(
  (widget) =>
      widget is Image && (widget.image as AssetImage).assetName == asset,
);

/// EasyLoading 的转圈是无限动画，`pumpAndSettle` 不会停：这里按有限帧推进，
/// 直到条件成立或帧数用尽。
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var frame = 0; frame < 20 && !done(); frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  // 条件成立后页面还要跑完退回动画，多推几帧再断言。
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// EasyLoading 的提示动画与 2 秒计时器是跨用例共享的单例状态：把一次提示跑完，
/// 避免用例结束时留下未完成的 Timer。
Future<void> _drainEasyLoading(WidgetTester tester) async {
  for (var second = 0; second < 6; second++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await EasyLoading.dismiss();
  await tester.pump(const Duration(milliseconds: 300));
}

/// 以登录态启动外壳，从个人中心的 `Account` 行进入账号页。
Future<void> _pumpAccountPage(WidgetTester tester, GatewayClient client) async {
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: AppRoutes.main,
      builder: EasyLoading.init(),
      initialBinding: MainBinding(gatewayClient: client),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(name: AppRoutes.main, page: () => const MainShellPage()),
        GetPage<void>(name: AppRoutes.account, page: () => const AccountPage()),
      ],
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('tab-mine')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('mine-service-account')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    Get.reset();
    AnalyticsService.configure(_QuietSink());
    PackageInfo.setMockInitialValues(
      appName: 'Handa Peso',
      packageName: 'com.example.handa_peso',
      version: '1.1.1',
      buildNumber: '1',
      buildSignature: '',
    );
    // 真机上这段接线在 `main()` 里完成，测试里补上。
    AppNavigator.mainTabSelector = (index) {
      if (Get.isRegistered<MainController>()) {
        Get.find<MainController>().switchTab(index);
      }
    };
  });
  tearDown(() {
    AppNavigator.mainTabSelector = null;
    Get.reset();
  });

  group('账号页', () {
    testWidgets('卡片按设计稿：347 宽 @ y=118，应用名 / 版本号 / 图标齐全', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await config.localSession.writePhone('9621231210');
      await _pumpAccountPage(tester, _client(config, _StubAdapter()));

      expect(find.text(AccountPage.title), findsOneWidget);
      expect(find.text(AccountPage.appName), findsOneWidget);
      expect(find.text('V1.1.1'), findsOneWidget);
      expect(find.byKey(const Key('account-logo')), findsOneWidget);
      expect(find.byKey(const Key('account-delete')), findsOneWidget);
      expect(find.byKey(const Key('account-logout')), findsOneWidget);

      final card = find
          .ancestor(
            of: find.text(AccountPage.appName),
            matching: find.byType(Container),
          )
          .last;
      expect(tester.getSize(card).width, 347);
      expect(tester.getTopLeft(card), const Offset(14, 118));
      expect(
        tester.getSize(find.byKey(const Key('account-delete'))).height,
        52,
      );
    });

    testWidgets('注销：先弹挽留弹窗，选 Keep Offers 不发请求', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await config.localSession.writePhone('9621231210');
      final adapter = _StubAdapter();
      await _pumpAccountPage(tester, _client(config, adapter));

      await tester.tap(find.byKey(const Key('account-delete')));
      await tester.pumpAndSettle();

      expect(
        _retentionArtwork('assets/account_delete_retention_card.png'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('account-retention-confirm')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('account-retention-keep')), findsOneWidget);
      // 文案表：右橙保留 = Keep Offers，左灰动作 = Delete。
      expect(
        find.descendant(
          of: find.byKey(const Key('account-retention-keep')),
          matching: find.text('Keep Offers'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('account-retention-confirm')),
          matching: find.text('Delete'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('account-retention-keep')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('account-retention-confirm')), findsNothing);
      expect(adapter.deleteCalls, 0);
      expect(await config.localSession.readSessionId(), 'session-1');
    });

    testWidgets('注销确认后调注销接口、清会话并退回外壳', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await config.localSession.writePhone('9621231210');
      final adapter = _StubAdapter();
      await _pumpAccountPage(tester, _client(config, adapter));

      await tester.tap(find.byKey(const Key('account-delete')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-retention-confirm')));
      await _pumpUntil(tester, () => adapter.deleteCalls > 0);

      expect(adapter.deleteCalls, 1);
      expect(await config.localSession.readSessionId(), isEmpty);
      expect(find.byType(AccountPage), findsNothing);
      expect(find.byKey(const Key('tab-home')), findsOneWidget);

      await _drainEasyLoading(tester);
    });

    testWidgets('退出登录：Keep Rates 留在原地，Log Out 才真的退出', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await config.localSession.writePhone('9621231210');
      final adapter = _StubAdapter();
      await _pumpAccountPage(tester, _client(config, adapter));

      await tester.tap(find.byKey(const Key('account-logout')));
      await tester.pumpAndSettle();

      expect(
        _retentionArtwork('assets/account_logout_retention_card.png'),
        findsOneWidget,
      );
      // 文案表：右橙保留 = Keep Rates，左灰动作 = Log Out。
      expect(
        find.descendant(
          of: find.byKey(const Key('account-retention-keep')),
          matching: find.text('Keep Rates'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('account-retention-confirm')),
          matching: find.text('Log Out'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('account-retention-keep')));
      await tester.pumpAndSettle();
      expect(adapter.logoutCalls, 0);
      expect(await config.localSession.readSessionId(), 'session-1');

      await tester.tap(find.byKey(const Key('account-logout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('account-retention-confirm')));
      await _pumpUntil(tester, () => adapter.logoutCalls > 0);

      expect(adapter.logoutCalls, 1);
      expect(await config.localSession.readSessionId(), isEmpty);
      expect(find.byType(AccountPage), findsNothing);

      await _drainEasyLoading(tester);
    });
  });
}
