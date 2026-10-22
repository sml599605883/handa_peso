import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_reply.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/product/product_detail_loader.dart';
import 'package:handa_peso/core/product/product_detail_snapshot.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/certification/face_recognition_page.dart';
import 'package:handa_peso/features/certification/identity_design.dart';
import 'package:handa_peso/features/certification/identity_result_page.dart';
import 'package:handa_peso/features/certification/identity_upload_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

const _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

Map<String, dynamic> _detailPayload() => <String, dynamic>{
  'murdering': 200,
  'recurs': <String, dynamic>{
    'dependable': '1000460',
    'redecorates': 'ORDER-1000460',
    'luciferins': '60000',
    'splashiest': '91',
    'curb': 1,
  },
  'azurites': <String, dynamic>{
    ProductStepCopy.identityField: 'Upload the new identity copy',
    ProductStepCopy.identityConfirmationField: 'Confirm the new identity copy',
    ProductStepCopy.livenessField: 'Complete the new face copy',
    ProductStepCopy.personalField: 'Complete the new personal copy',
    ProductStepCopy.workField: 'Complete the new work copy',
    ProductStepCopy.emergencyContactField: 'Add the new contact copy',
    ProductStepCopy.payoutAccountField: 'Add the new payout copy',
    ProductStepCopy.payoutAccountBottomField: 'Check the payout copy',
  },
};

String _detailBody() =>
    '{"unaccepted":"0","unstably":"success","indulgences":'
    '${_json(_detailPayload())}}';

String _json(Object? value) {
  if (value is String) return '"$value"';
  if (value is num || value is bool) return '$value';
  if (value is List) return '[${value.map(_json).join(',')}]';
  if (value is Map) {
    final entries = value.entries
        .map((entry) => '"${entry.key}":${_json(entry.value)}')
        .join(',');
    return '{$entries}';
  }
  return 'null';
}

class _DetailAdapter implements HttpClientAdapter {
  _DetailAdapter(this.body);

  final String body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(body, 200, headers: _jsonHeaders);

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.testMode = true;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  tearDown(() {
    Get.reset();
    SharedPreferencesAsyncPlatform.instance = null;
  });

  test('产品详情按 azurites 的八个独立字段解析文案', () {
    final snapshot = ProductDetailSnapshot.fromReply(
      GatewayReply.parse(<String, dynamic>{
        'unaccepted': '0',
        'unstably': 'success',
        'indulgences': _detailPayload(),
      }),
    );

    expect(snapshot.orderNo, 'ORDER-1000460');
    expect(snapshot.amount, '60000');
    expect(snapshot.term, '91');
    expect(snapshot.termUnit, '1');
    expect(snapshot.copy.identity, 'Upload the new identity copy');
    expect(snapshot.copy.identityConfirmation, 'Confirm the new identity copy');
    expect(snapshot.copy.liveness, 'Complete the new face copy');
    expect(snapshot.copy.personal, 'Complete the new personal copy');
    expect(snapshot.copy.work, 'Complete the new work copy');
    expect(snapshot.copy.emergencyContact, 'Add the new contact copy');
    expect(snapshot.copy.payoutAccount, 'Add the new payout copy');
    expect(snapshot.copy.payoutAccountBottom, 'Check the payout copy');
  });

  test('成功请求详情后缓存文案和订单号，退出会话时清除', () async {
    final writer = LocalSession(SharedPreferencesAsync());
    final client = GatewayClient(
      GatewaySettings(signSecret: 'unit-test-secret', localSession: writer),
      dio: Dio()..httpClientAdapter = _DetailAdapter(_detailBody()),
    );

    await ProductDetailLoader.load(client, productId: '1000460');

    final reader = LocalSession(SharedPreferencesAsync());
    await reader.restoreProductFlow();
    expect(reader.productFlowOrderNo, 'ORDER-1000460');
    expect(reader.productFlowCopy.liveness, 'Complete the new face copy');

    await reader.resetSession();
    final afterReset = LocalSession(SharedPreferencesAsync());
    await afterReset.restoreProductFlow();
    expect(afterReset.productFlowOrderNo, isEmpty);
    expect(afterReset.productFlowCopy.personal, isEmpty);
  });

  test('详情业务失败时保留上一次可用缓存', () async {
    final store = LocalSession.memory();
    await store.cacheProductFlow(
      const ProductStepCopy(identity: 'Keep the cached identity copy'),
      orderNo: 'ORDER-OLD',
    );
    final client = GatewayClient(
      GatewaySettings(signSecret: 'unit-test-secret', localSession: store),
      dio: Dio()
        ..httpClientAdapter = _DetailAdapter(
          '{"unaccepted":"500","unstably":"failed","indulgences":{}}',
        ),
    );

    await expectLater(
      ProductDetailLoader.load(client, productId: '1000460'),
      throwsA(anything),
    );
    expect(store.productFlowCopy.identity, 'Keep the cached identity copy');
    expect(store.productFlowOrderNo, 'ORDER-OLD');
  });

  testWidgets('证件上传页读取身份认证文案', (tester) async {
    final client = await _cachedClient();
    await _pumpPage(
      tester,
      route: AppRoutes.certificationIdentityUpload,
      page: IdentityUploadPage(apiClient: client),
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
      },
    );
    expect(find.text('Upload the new identity copy'), findsWidgets);
    expect(find.text(IdentityStrings.heroCopy), findsNothing);
  });

  testWidgets('证件确认页读取身份认证成功文案', (tester) async {
    final client = await _cachedClient();
    await _pumpPage(
      tester,
      route: AppRoutes.certificationIdentityResult,
      page: IdentityResultPage(apiClient: client, autoContinue: false),
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
        'sceneStartSeconds': 0,
        'definitively': 'BANBU',
        'optically': '3877409801987862',
        'gleeking': '23-02-1996',
        'tidewaters': '',
      },
    );
    expect(find.text('Confirm the new identity copy'), findsWidgets);
  });

  testWidgets('人脸页读取活体认证文案', (tester) async {
    final client = await _cachedClient();
    await _pumpPage(
      tester,
      route: AppRoutes.certificationFace,
      page: FaceRecognitionPage(apiClient: client, autoContinue: false),
      arguments: <String, dynamic>{
        'productId': '1000460',
        'orderNo': 'ORDER-1000460',
        'cardType': 'SSS ID',
      },
    );
    expect(find.text('Complete the new face copy'), findsWidgets);
  });
}

Future<GatewayClient> _cachedClient() async {
  final store = LocalSession.memory();
  await store.cacheProductFlow(
    ProductStepCopy.fromJson(
      _detailPayload()['azurites'] as Map<String, dynamic>,
    ),
    orderNo: 'ORDER-1000460',
  );
  return GatewayClient(
    GatewaySettings(signSecret: 'unit-test-secret', localSession: store),
    dio: Dio()..httpClientAdapter = _DetailAdapter(_detailBody()),
  );
}

Future<void> _pumpPage(
  WidgetTester tester, {
  required String route,
  required Widget page,
  required Map<String, dynamic> arguments,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/stub',
      builder: EasyLoading.init(),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(
          name: '/stub',
          page: () => const Scaffold(body: SizedBox()),
        ),
        GetPage<void>(name: route, page: () => page),
      ],
    ),
  );
  await tester.pumpAndSettle();
  Get.toNamed<void>(route, arguments: arguments);
  await tester.pumpAndSettle();
}
