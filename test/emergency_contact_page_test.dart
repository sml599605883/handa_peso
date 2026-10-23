import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/analytics/analytics_service.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_reply.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/report/report_bridge.dart';
import 'package:handa_peso/core/report/report_service.dart';
import 'package:handa_peso/core/report/report_store.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/certification/emergency_contact_design.dart';
import 'package:handa_peso/features/certification/emergency_contact_models.dart';
import 'package:handa_peso/features/certification/emergency_contact_page.dart';

const _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

const _contactBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"redness":{"latchstrings":['
    '{"releasers":"1","definitively":"Da","silencers":"8254-000248",'
    '"nomadisms":"first","musick":['
    '{"definitively":"Parent","trollopy":"1"},'
    '{"definitively":"Spouse","trollopy":"2"},'
    '{"definitively":"Friend","trollopy":"5"}]},'
    '{"releasers":"2","definitively":"Mm","silencers":"80054 87521",'
    '"nomadisms":"second","musick":['
    '{"definitively":"Parent","trollopy":"1"},'
    '{"definitively":"Spouse","trollopy":"2"}]},'
    '{"releasers":"","definitively":"","silencers":"",'
    '"nomadisms":"third","musick":['
    '{"definitively":"Friend","trollopy":"5"}]}'
    ']},"flatfish":"Protect your emergency contact information"}}';

/// 接口文档「获取挽留弹窗」：弹窗类型 4（紧急联系人）。
const _retentionBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"revetting":{"canonic":"Please wait, it only takes ",'
    '"unstably":" for you to complete all certifications and get a loan!",'
    '"luciferins":2000,"argala":"","sleeker":"xx/xxx/xxx.xxx",'
    '"jollified":"Continuar","footrests":"Exit",'
    '"tidewaters":"https://retention.png"}}}';

class _RecordedRequest {
  const _RecordedRequest({required this.url, required this.fields});

  final String url;
  final Map<String, String> fields;
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.saveBody = '{"unaccepted":"0","unstably":"success"}'});

  final String saveBody;
  final requests = <_RecordedRequest>[];

  List<_RecordedRequest> where(String fragment) => requests
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
    requests.add(_RecordedRequest(url: options.uri.toString(), fields: fields));
    final uri = options.uri.toString();
    if (uri.contains('unchivalrous')) {
      return ResponseBody.fromString(
        _retentionBody,
        200,
        headers: _jsonHeaders,
      );
    }
    final body = uri.contains('ranulas') ? saveBody : _contactBody;
    return ResponseBody.fromString(body, 200, headers: _jsonHeaders);
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
  void setUserProperty(String name, String? value) {}

  @override
  void setUserId(String? userId) {}
}

class _SpyReportService extends ReportService {
  _SpyReportService()
    : super(
        gatewayClient: GatewayClient(
          GatewaySettings(
            signSecret: 'unit-test-secret',
            localSession: LocalSession.memory(),
          ),
        ),
        store: ReportStore.memory(),
        bridge: ReportNativeBridge(available: false),
      );

  final reports = <({String scene, String productId, int startedAtSeconds})>[];

  @override
  Future<void> reportScene({
    required String scene,
    String productId = '',
    String orderNo = '',
    required int startedAtSeconds,
    int? endedAtSeconds,
  }) async {
    reports.add((
      scene: scene,
      productId: productId,
      startedAtSeconds: startedAtSeconds,
    ));
  }
}

GatewayClient _clientFor(_StubAdapter adapter) {
  return GatewayClient(
    GatewaySettings(
      signSecret: 'unit-test-secret',
      localSession: LocalSession.memory(),
    ),
    dio: Dio()..httpClientAdapter = adapter,
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required GatewayClient client,
  required EmergencyContactPicker contactPicker,
  ReportService? reporter,
  bool autoContinue = false,
  EmergencyContactFlowOutcome? outcome,
}) async {
  tester.view.physicalSize = const Size(375, 1147);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/home',
      builder: EasyLoading.init(),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(
          name: '/home',
          page: () => const Scaffold(body: Center(child: Text('home'))),
        ),
        GetPage<void>(
          name: AppRoutes.emergencyContact,
          page: () => EmergencyContactPage(
            apiClient: client,
            reporter: reporter,
            autoContinue: autoContinue,
            contactPicker: contactPicker,
          ),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  final arguments = <String, dynamic>{'productId': '1000460'};
  if (outcome != null) {
    arguments[EmergencyContactFlowOutcome.argumentKey] = outcome;
  }
  Get.toNamed<void>(AppRoutes.emergencyContact, arguments: arguments);
  await tester.pumpAndSettle();
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var frame = 0; frame < 40 && !done(); frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  for (var frame = 0; frame < 4; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AnalyticsService.configure(_SilentTelemetrySink());
    await EasyLoading.dismiss();
  });
  tearDown(Get.reset);

  test('按 Handa 接口文档解析联系人、关系选项和页面文案', () {
    final data = EmergencyContactData.fromReply(
      GatewayReply.parse(jsonDecode(_contactBody)),
    );

    expect(data.prompt, 'Protect your emergency contact information');
    expect(data.contacts, hasLength(3));
    expect(data.contacts.first.number, 'first');
    expect(data.contacts.first.relationshipLabel, 'Parent');
    expect(data.contacts.first.name, 'Da');
    expect(data.contacts.first.phone, '8254-000248');
    expect(data.contacts.first.relationshipOptions.last.value, '5');
  });

  testWidgets('三组标题按左、右、左交替并保持设计稿位置', (tester) async {
    final adapter = _StubAdapter();
    await _pumpPage(
      tester,
      client: _clientFor(adapter),
      contactPicker: () async => null,
    );

    expect(find.byType(EmergencyContactPage), findsOneWidget);
    expect(find.text('Emergency Contacts'), findsOneWidget);
    expect(
      find.text('Protect your emergency contact information'),
      findsWidgets,
    );
    expect(adapter.where('trollopy'), hasLength(1));
    expect(adapter.where('trollopy').single.url, contains('cotype=1000460'));

    final firstBadge = tester.widget<Image>(
      find.byKey(const ValueKey<String>('emergency-contact-badge-asset-first')),
    );
    final secondBadge = tester.widget<Image>(
      find.byKey(
        const ValueKey<String>('emergency-contact-badge-asset-second'),
      ),
    );
    final thirdBadge = tester.widget<Image>(
      find.byKey(const ValueKey<String>('emergency-contact-badge-asset-third')),
    );
    expect(
      (firstBadge.image as AssetImage).assetName,
      EmergencyContactDesign.titleLeftAsset,
    );
    expect(
      (secondBadge.image as AssetImage).assetName,
      EmergencyContactDesign.titleRightAsset,
    );
    expect(
      (thirdBadge.image as AssetImage).assetName,
      EmergencyContactDesign.titleLeftAsset,
    );

    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('emergency-contact-badge-asset-first'),
            ),
          )
          .dx,
      closeTo(14, 0.01),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('emergency-contact-badge-asset-second'),
            ),
          )
          .dx,
      closeTo(93, 0.01),
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('emergency-contact-badge-asset-third'),
            ),
          )
          .dx,
      closeTo(14, 0.01),
    );

    expect(
      tester
          .getRect(
            find.byKey(
              const ValueKey<String>('emergency-contact-relationship-first'),
            ),
          )
          .width,
      closeTo(319, 0.01),
    );
    expect(
      tester
          .getRect(
            find.byKey(
              const ValueKey<String>('emergency-contact-picker-first'),
            ),
          )
          .width,
      closeTo(319, 0.01),
    );
  });

  testWidgets('更改关系、选择联系人后按文档字段保存并上报场景 7', (tester) async {
    final adapter = _StubAdapter();
    final reporter = _SpyReportService();
    final outcome = EmergencyContactFlowOutcome();
    await _pumpPage(
      tester,
      client: _clientFor(adapter),
      reporter: reporter,
      outcome: outcome,
      contactPicker: () async =>
          const EmergencyPickedContact(name: 'Ana Cruz', phone: '09171234567'),
    );

    await tester.tap(
      find.byKey(
        const ValueKey<String>('emergency-contact-relationship-first'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('certification-option-5')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('certification-single-select-submit')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Friend'), findsWidgets);

    await tester.tap(
      find.byKey(const ValueKey<String>('emergency-contact-picker-first')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ana Cruz'), findsOneWidget);
    expect(find.text('09171234567'), findsOneWidget);

    await tester.tap(find.byKey(const Key('emergency-contact-submit')));
    for (
      var frame = 0;
      frame < 30 && find.byType(EmergencyContactPage).evaluate().isNotEmpty;
      frame++
    ) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    final request = adapter.where('ranulas').single;
    final saved = jsonDecode(request.fields['indulgences']!) as List<dynamic>;
    expect(saved, hasLength(3));
    expect(saved.first, <String, dynamic>{
      'silencers': '09171234567',
      'definitively': 'Ana Cruz',
      'releasers': '5',
      'nomadisms': 'first',
    });
    expect(request.fields['cotype'], '1000460');
    expect(outcome.completed, isTrue);
    expect(reporter.reports, hasLength(1));
    expect(reporter.reports.single.scene, '7');
    expect(reporter.reports.single.productId, '1000460');
    expect(find.byType(EmergencyContactPage), findsNothing);
  });

  testWidgets('保存失败时停留当前页、不标记完成也不上报', (tester) async {
    final adapter = _StubAdapter(
      saveBody: '{"unaccepted":"500","unstably":"Save failed"}',
    );
    final reporter = _SpyReportService();
    final outcome = EmergencyContactFlowOutcome();
    await _pumpPage(
      tester,
      client: _clientFor(adapter),
      reporter: reporter,
      outcome: outcome,
      contactPicker: () async => null,
    );

    await tester.tap(find.byKey(const Key('emergency-contact-submit')));
    for (var frame = 0; frame < 80; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(adapter.where('ranulas'), hasLength(1));
    expect(outcome.completed, isFalse);
    expect(reporter.reports, isEmpty);
    expect(find.byType(EmergencyContactPage), findsOneWidget);
    await EasyLoading.dismiss();
  });

  testWidgets('紧急联系人页返回：请求 scene=4 的挽留弹窗', (tester) async {
    final adapter = _StubAdapter();
    await _pumpPage(
      tester,
      client: _clientFor(adapter),
      contactPicker: () async => null,
    );

    await tester.tap(find.byKey(const Key('identity-back')));
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('identity-retention-continue'))
          .evaluate()
          .isNotEmpty,
    );
    final retention = adapter.where('unchivalrous').single;
    expect(retention.fields['ulterior'], '4');
    expect(retention.fields['knife'], '1000460');

    await tester.tap(find.byKey(const Key('identity-retention-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(EmergencyContactPage), findsOneWidget);
  });

  testWidgets('紧急联系人页返回：挽留弹窗选择退出时回到入口页', (tester) async {
    final adapter = _StubAdapter();
    await _pumpPage(
      tester,
      client: _clientFor(adapter),
      contactPicker: () async => null,
    );

    await tester.tap(find.byKey(const Key('identity-back')));
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('identity-retention-exit'))
          .evaluate()
          .isNotEmpty,
    );
    await tester.tap(find.byKey(const Key('identity-retention-exit')));
    await _pumpUntil(
      tester,
      () => find.byType(EmergencyContactPage).evaluate().isEmpty,
    );

    expect(find.text('home'), findsOneWidget);
    expect(find.byType(EmergencyContactPage), findsNothing);
  });
}
