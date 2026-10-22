import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/analytics/analytics_service.dart';
import 'package:handa_peso/core/face/face_liveness_bridge.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_reply.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/permissions/permission_coordinator.dart';
import 'package:handa_peso/core/report/report_bridge.dart';
import 'package:handa_peso/core/report/report_service.dart';
import 'package:handa_peso/core/report/report_store.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/certification/bind_card_design.dart';
import 'package:handa_peso/features/certification/bind_card_models.dart';
import 'package:handa_peso/features/certification/bind_card_page.dart';

const _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

Map<String, dynamic> _field(
  String title,
  String key, {
  String control = 'txt',
  String placeholder = 'Please enter',
  List<Map<String, dynamic>> options = const <Map<String, dynamic>>[],
  int optional = 0,
  String suggestion = '',
}) {
  return <String, dynamic>{
    'canonic': title,
    'unaccepted': key,
    'preaccuses': placeholder,
    'psychosexual': control,
    'azurites': options,
    'packwaxes': optional,
    'monosyllabicity': '',
    'lysogenicity': suggestion,
    'ulterior': 0,
  };
}

Map<String, dynamic> _group(
  String label,
  String type,
  List<Map<String, dynamic>> fields,
) {
  return <String, dynamic>{
    'canonic': label,
    'trollopy': type,
    'magnificences': fields,
  };
}

String _cardBody({int groupCount = 3}) {
  final groups = <Map<String, dynamic>>[
    _group('E-wallet', '1', <Map<String, dynamic>>[
      _field(
        'Select your recipient E-wallet',
        'channelCode',
        control: 'enum',
        placeholder: 'Please select',
        options: <Map<String, dynamic>>[
          <String, dynamic>{
            'trollopy': 6,
            'definitively': 'GCash e-wallet',
            'headway': '',
            'uppropped': 1,
          },
          <String, dynamic>{
            'trollopy': 8,
            'definitively': 'PayMaya e-wallet',
            'headway': '',
            'uppropped': 0,
          },
        ],
      ),
      _field('E-wallet Account', 'cardNo', suggestion: '09171234567'),
      _field(
        'Repeat E-wallet Account',
        'confirmCardNo',
        placeholder: 'Ensure the account number is correct',
      ),
    ]),
    _group('Bank', '2', <Map<String, dynamic>>[
      _field(
        'Select your recipient Bank',
        'channelCode',
        control: 'enum',
        placeholder: 'Please select',
      ),
      _field('Bank Account', 'cardNo'),
      _field('Repeat Bank Account', 'confirmCardNo'),
    ]),
    _group('Cash Pickup', '3', <Map<String, dynamic>>[
      _field(
        'Select your recipient Cash Pickup',
        'channelCode',
        control: 'enum',
        placeholder: 'Please select',
      ),
      _field('First name', 'firstName', suggestion: 'Anna'),
      _field('Middle name', 'middleName', optional: 1),
      _field('Last name', 'lastName'),
    ]),
  ];
  for (var index = groups.length; index < groupCount; index++) {
    groups.add(
      _group('Voucher ${index + 1}', '${index + 1}', <Map<String, dynamic>>[
        _field('Voucher account', 'cardNo'),
      ]),
    );
  }
  return jsonEncode(<String, dynamic>{
    'unaccepted': '0',
    'unstably': 'success',
    'indulgences': <String, dynamic>{
      'magnificences': groups,
      'flatfish': 'Choose where you want to receive funds.',
      'dilatational': 'Double-check your account details.',
    },
  });
}

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({required this.cardBody, this.requireLiveness = false});

  final String cardBody;
  final bool requireLiveness;
  final List<Map<String, String>> bindBodies = <Map<String, String>>[];
  final List<Map<String, String>> switchBodies = <Map<String, String>>[];
  final List<String> paths = <String>[];

  int _bindCount = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.uri.path;
    paths.add(path);
    if (path.endsWith('/dependable')) {
      return _json(cardBody);
    }
    if (path.endsWith('/tidewaters')) {
      _bindCount += 1;
      bindBodies.add(_formFields(options.data));
      if (requireLiveness && _bindCount == 1) {
        return _json('{"unaccepted":"20000","unstably":"","indulgences":{}}');
      }
      return _json(
        '{"unaccepted":"0","unstably":"success",'
        '"indulgences":{"eyeglasses":5326}}',
      );
    }
    if (path.endsWith('/postforming')) {
      return _json(
        '{"unaccepted":"0","unstably":"success","indulgences":'
        '{"beet":200,"districts":"","obsoletely":"license-1",'
        '"genomes":"","esplanades":7}}',
      );
    }
    if (path.endsWith('/circularise')) {
      switchBodies.add(_formFields(options.data));
      return _json(
        '{"unaccepted":"0","unstably":"success","indulgences":'
        '{"proclises":"https://example.com/order"}}',
      );
    }
    return _json('{"unaccepted":"0","unstably":"success"}');
  }

  Map<String, String> _formFields(Object? data) {
    final fields = <String, String>{};
    if (data is Map) {
      for (final entry in data.entries) {
        fields['${entry.key}'] = '${entry.value}';
      }
    }
    return fields;
  }

  ResponseBody _json(String body) =>
      ResponseBody.fromString(body, 200, headers: _jsonHeaders);

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

  final scenes = <String>[];

  @override
  Future<void> reportScene({
    required String scene,
    String productId = '',
    String orderNo = '',
    required int startedAtSeconds,
    int? endedAtSeconds,
  }) async {
    scenes.add(scene);
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
  required BindCardFlowOutcome outcome,
  ReportService? reporter,
  BindCardCameraPermission? camera,
  BindCardLivenessStart? liveness,
  String changeOrderNo = '',
}) async {
  tester.view.physicalSize = const Size(375, 1000);
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
          name: AppRoutes.bindCard,
          page: () => BindCardPage(
            apiClient: client,
            reporter: reporter,
            autoContinue: false,
            orderNo: 'order-1',
            changeOrderNo: changeOrderNo,
            requestCameraPermission: camera,
            startLiveness: liveness,
            confirmLiveness: (_) async => true,
          ),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  Get.toNamed<void>(
    AppRoutes.bindCard,
    arguments: <String, dynamic>{
      'productId': '1000460',
      BindCardFlowOutcome.argumentKey: outcome,
    },
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    AnalyticsService.configure(_SilentTelemetrySink());
    await EasyLoading.dismiss();
  });

  tearDown(() async {
    await EasyLoading.dismiss();
    Get.reset();
  });

  test('按 Handa 字段解析绑卡分组、字段和选项', () {
    final data = BindCardData.fromReply(
      GatewayReply.parse(jsonDecode(_cardBody())),
    );

    expect(data.groups, hasLength(3));
    expect(data.prompt, 'Choose where you want to receive funds.');
    expect(data.bottomPrompt, 'Double-check your account details.');
    expect(data.groups.first.label, 'E-wallet');
    expect(data.groups.first.type, '1');
    expect(
      data.groups.first.fields.first.control,
      BindCardFieldControl.selection,
    );
    expect(data.groups.first.fields[1].suggestedValue, '09171234567');
    expect(data.groups[1].fields.first.key, 'channelCode');
  });

  testWidgets('绑卡页关键元素落在设计稿坐标', (tester) async {
    final adapter = _StubAdapter(cardBody: _cardBody());
    final outcome = BindCardFlowOutcome();
    await _pumpPage(tester, client: _clientFor(adapter), outcome: outcome);

    expect(
      tester.getTopLeft(find.byKey(const Key('bind-card-type-0'))),
      const Offset(14, 219),
    );
    expect(
      tester.getSize(find.byKey(const Key('bind-card-type-0'))),
      const Size(112, 58),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('bind-card-form'))),
      const Offset(14, 291),
    );
    expect(
      tester.getSize(find.byKey(const Key('bind-card-form'))),
      const Size(347, 302),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('bind-card-bottom-prompt'))),
      const Offset(14, 613),
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('bind-card-submit'))),
      const Offset(78, 681),
    );
  });

  testWidgets('类型卡使用三套图标并循环，选中态切换对应图标', (tester) async {
    final adapter = _StubAdapter(cardBody: _cardBody(groupCount: 4));
    final outcome = BindCardFlowOutcome();
    await _pumpPage(tester, client: _clientFor(adapter), outcome: outcome);

    Image icon(int index) =>
        tester.widget<Image>(find.byKey(Key('bind-card-type-icon-$index')));

    expect(
      (icon(0).image as AssetImage).assetName,
      BindCardAssets.typeArtwork[0].selected,
    );
    expect(
      (icon(1).image as AssetImage).assetName,
      BindCardAssets.typeArtwork[1].unselected,
    );

    await tester.tap(find.byKey(const Key('bind-card-type-1')));
    await tester.pumpAndSettle();
    expect(
      (icon(0).image as AssetImage).assetName,
      BindCardAssets.typeArtwork[0].unselected,
    );
    expect(
      (icon(1).image as AssetImage).assetName,
      BindCardAssets.typeArtwork[1].selected,
    );

    await tester.drag(find.byType(ListView).first, const Offset(-240, 0));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('bind-card-type-3')), findsOneWidget);
    expect(
      (icon(3).image as AssetImage).assetName,
      BindCardAssets.typeArtwork[0].unselected,
    );

    await tester.tap(find.byKey(const Key('bind-card-type-3')));
    await tester.pumpAndSettle();
    expect(
      (icon(3).image as AssetImage).assetName,
      BindCardAssets.typeArtwork[0].selected,
    );
  });

  testWidgets('气泡只在文本框聚焦且为空时显示', (tester) async {
    final adapter = _StubAdapter(cardBody: _cardBody());
    final outcome = BindCardFlowOutcome();
    await _pumpPage(tester, client: _clientFor(adapter), outcome: outcome);

    final field = find.byKey(const Key('bind-card-input-1:cardNo'));
    final bubble = find.byKey(const Key('bind-card-suggestion-1:cardNo'));
    expect(bubble, findsNothing);

    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(bubble, findsOneWidget);

    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(bubble, findsNothing);

    await tester.tap(field);
    await tester.pumpAndSettle();
    expect(bubble, findsOneWidget);
    await tester.enterText(field, '09170001');
    await tester.pumpAndSettle();
    expect(bubble, findsNothing);
  });

  testWidgets('两次账号输入不一致时不提交', (tester) async {
    final adapter = _StubAdapter(cardBody: _cardBody());
    final outcome = BindCardFlowOutcome();
    await _pumpPage(tester, client: _clientFor(adapter), outcome: outcome);

    await tester.enterText(
      find.byKey(const Key('bind-card-input-1:cardNo')),
      '09170001',
    );
    await tester.enterText(
      find.byKey(const Key('bind-card-input-1:confirmCardNo')),
      '09170002',
    );
    await tester.tap(find.byKey(const Key('bind-card-submit')));
    await tester.pump();

    expect(adapter.bindBodies, isEmpty);
    expect(outcome.completed, isFalse);
  });

  testWidgets('提交按 Handa 字段映射并回传绑卡 id', (tester) async {
    final adapter = _StubAdapter(cardBody: _cardBody());
    final reporter = _SpyReportService();
    final outcome = BindCardFlowOutcome();
    await _pumpPage(
      tester,
      client: _clientFor(adapter),
      reporter: reporter,
      outcome: outcome,
    );

    await tester.enterText(
      find.byKey(const Key('bind-card-input-1:cardNo')),
      '09171234567',
    );
    await tester.enterText(
      find.byKey(const Key('bind-card-input-1:confirmCardNo')),
      '09171234567',
    );
    await tester.tap(find.byKey(const Key('bind-card-submit')));
    await tester.pumpAndSettle();

    expect(adapter.bindBodies, hasLength(1));
    final body = adapter.bindBodies.single;
    expect(body['cotype'], '1000460');
    expect(body['scarriest'], '1');
    expect(body['voraciousness'], '');
    expect(body['thermographs'], '09171234567');
    expect(body['lander'], '09171234567');
    expect(body['fatheadedly'], isNotEmpty);
    expect(outcome.completed, isTrue);
    expect(outcome.bindId, '5326');
    expect(reporter.scenes, <String>['8']);
  });

  testWidgets('20000 时只要求 livenessId 并完成二次提交', (tester) async {
    final adapter = _StubAdapter(cardBody: _cardBody(), requireLiveness: true);
    final outcome = BindCardFlowOutcome();
    await _pumpPage(
      tester,
      client: _clientFor(adapter),
      outcome: outcome,
      camera: () async => PermissionDecision.granted,
      liveness: (license) async {
        expect(license, 'license-1');
        return const FaceLivenessResult(
          success: false,
          code: 500,
          message: '',
          image: '',
          livenessId: 'live-1',
          requestId: 'request-1',
          rawJson: '{}',
        );
      },
    );

    await tester.enterText(
      find.byKey(const Key('bind-card-input-1:cardNo')),
      '09171234567',
    );
    await tester.enterText(
      find.byKey(const Key('bind-card-input-1:confirmCardNo')),
      '09171234567',
    );
    await tester.tap(find.byKey(const Key('bind-card-submit')));
    await tester.pumpAndSettle();

    expect(adapter.bindBodies, hasLength(2));
    expect(adapter.bindBodies.first['esplanades'], '');
    expect(adapter.bindBodies.last['esplanades'], '7');
    expect(adapter.bindBodies.last['debater'], 'live-1');
    expect(adapter.bindBodies.last['wowsers'], 'license-1');
    expect(adapter.bindBodies.last['attach'], '');
    expect(outcome.completed, isTrue);
  });

  testWidgets('换绑模式提交后调用更换账户并回传跳转地址', (tester) async {
    final adapter = _StubAdapter(cardBody: _cardBody());
    final reporter = _SpyReportService();
    final outcome = BindCardFlowOutcome();
    await _pumpPage(
      tester,
      client: _clientFor(adapter),
      reporter: reporter,
      outcome: outcome,
      changeOrderNo: 'order-old',
    );

    await tester.enterText(
      find.byKey(const Key('bind-card-input-1:cardNo')),
      '09171234567',
    );
    await tester.enterText(
      find.byKey(const Key('bind-card-input-1:confirmCardNo')),
      '09171234567',
    );
    await tester.tap(find.byKey(const Key('bind-card-submit')));
    await tester.pumpAndSettle();

    expect(outcome.changed, isTrue);
    expect(outcome.bindId, '5326');
    expect(outcome.redirectUrl, 'https://example.com/order');
    expect(adapter.switchBodies, hasLength(1));
    expect(adapter.switchBodies.single['eelworm'], 'order-old');
    expect(adapter.switchBodies.single['eyeglasses'], '5326');
    expect(adapter.switchBodies.single['guaiocums'], isNotEmpty);
    expect(reporter.scenes, isEmpty);
  });
}
