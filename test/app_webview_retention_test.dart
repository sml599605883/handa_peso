import 'dart:convert';
import 'dart:typed_data';

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

const String _confirmationUrl = 'http://host/#/BanefullyHorse?drippier=1000460';

/// 服务端当前实际下发的确认用款地址：产品 ID 在 `knife`，`drippier` 不再出现。
const String _knifeConfirmationUrl =
    'http://8.220.176.2/#/BanefullyHorse?prefabricating=1&knife=1'
    '&changeAcount=1&redecorates=1772026101617112334539943';

const String _retentionBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"revetting":{"jollified":"Continue","footrests":"Exit",'
    '"tidewaters":"https://retention.png"}}}';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

final ImageProvider<Object> _retentionImage = MemoryImage(
  base64Decode('R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7'),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = FakeInAppWebViewPlatform(
    FakePlatformController(_confirmationUrl),
  );
  InAppWebViewPlatform.instance = platform;

  setUp(() {
    Get.testMode = true;
    AnalyticsService.configure(_SilentTelemetrySink());
    // 已接入返回桥的 H5：能不能退只问 __canGoBack()。
    platform.controller = FakePlatformController(_confirmationUrl)
      ..bridgeCanGoBack = true;
  });

  tearDown(() async {
    await EasyLoading.dismiss();
    Get.reset();
  });

  testWidgets('确认用款 H5 返回时展示 scene=5 挽留弹窗，继续后不返回网页', (tester) async {
    final adapter = _StubAdapter();
    await _pumpPage(tester, adapter);

    await tester.tap(find.byKey(const Key('webview-back')));
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('identity-retention-continue'))
          .evaluate()
          .isNotEmpty,
    );

    final retention = adapter.where('unchivalrous').single;
    expect(retention.fields['ulterior'], '5');
    expect(retention.fields['knife'], '1000460');
    expect(platform.controller.historyBackCalls, 0);

    await tester.tap(find.byKey(const Key('identity-retention-continue')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byType(AppWebViewPage), findsOneWidget);
    expect(platform.controller.historyBackCalls, 0);
  });

  testWidgets('确认用款地址改用 knife 下发产品 ID 时也触发 scene=5 挽留', (tester) async {
    platform.controller = FakePlatformController(_knifeConfirmationUrl)
      ..bridgeCanGoBack = true;
    final adapter = _StubAdapter();
    await _pumpPage(tester, adapter, url: _knifeConfirmationUrl);

    await tester.tap(find.byKey(const Key('webview-back')));
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('identity-retention-continue'))
          .evaluate()
          .isNotEmpty,
    );

    final retention = adapter.where('unchivalrous').single;
    expect(retention.fields['ulterior'], '5');
    expect(retention.fields['knife'], '1');
    expect(platform.controller.historyBackCalls, 0);
  });

  testWidgets('确认用款 H5 返回时选择退出后继续执行网页返回', (tester) async {
    final adapter = _StubAdapter();
    await _pumpPage(tester, adapter);

    await tester.tap(find.byKey(const Key('webview-back')));
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('identity-retention-exit'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('identity-retention-exit')));
    await _pumpUntil(tester, () => platform.controller.historyBackCalls == 1);

    expect(adapter.where('unchivalrous'), hasLength(1));
    expect(platform.controller.historyBackCalls, 1);
    // 回退只走 history.back()：iOS 27 的原生 goBack() 会漏计无手势 entry。
    expect(platform.controller.goBackCalls, 0);
    expect(find.byType(AppWebViewPage), findsOneWidget);
  });
}

Future<void> _pumpPage(
  WidgetTester tester,
  _StubAdapter adapter, {
  String url = _confirmationUrl,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final client = GatewayClient(
    GatewaySettings(
      signSecret: 'unit-test-secret',
      localSession: LocalSession.memory(),
    ),
    dio: Dio()..httpClientAdapter = adapter,
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
          page: () => AppWebViewPage(retentionImageProvider: _retentionImage),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  Get.toNamed<void>(
    AppRoutes.webView,
    arguments: <String, dynamic>{'url': url, 'title': 'Confirmation'},
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

class _StubAdapter implements HttpClientAdapter {
  final requests = <({String url, Map<String, String> fields})>[];

  List<({String url, Map<String, String> fields})> where(String fragment) =>
      requests
          .where((request) => request.url.contains(fragment))
          .toList(growable: false);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final fields = <String, String>{};
    final data = options.data;
    if (data is Map) {
      for (final entry in data.entries) {
        fields['${entry.key}'] = '${entry.value}';
      }
    }
    requests.add((url: options.uri.toString(), fields: fields));
    return ResponseBody.fromString(_retentionBody, 200, headers: _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
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
