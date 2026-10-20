import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/navigation/app_navigator.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/certification/face_recognition_page.dart';
import 'package:handa_peso/features/certification/identity_models.dart';
import 'package:handa_peso/features/certification/identity_type_page.dart';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

const String _homeRoute = '/stub-home';

/// 一次被记录的请求：URL 与表单字段。
class _RecordedRequest {
  const _RecordedRequest({required this.url, required this.fields});

  final String url;
  final Map<String, String> fields;
}

/// 认证项列表（`thurl`）里的一项。`uppropped` 是「是否已完成」。
Map<String, dynamic> _verifyItem(String taskType, {required int completed}) =>
    <String, dynamic>{
      'canonic': 'Informasi identitas',
      'preaccuses': 'Please complete your identity',
      'trollopy': 0,
      'uppropped': completed,
      'capaciousness': 'Sertifikasi',
      'demount': taskType,
      'gesticulating': 1,
      'incomers': 1,
      'holt': 'Silakan lengkapi sertifikasi secara berurutan',
    };

String _productDetailBody(List<Map<String, dynamic>> verify) =>
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"murdering":200,'
    '"recurs":{"dependable":"1000460","dullard":"Handa Peso",'
    '"redecorates":"ORDER-1000460"},'
    '"thurl":${_json(verify)}}}';

String _identityTypesBody() =>
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"alleviated":[{"tonsil":[{"apivorous":"SSS ID"}],"divagations":[]}]}}';

/// 极小的 JSON 序列化：只在本文件里拼固定结构，避免再加一层依赖。
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

class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.productDetailBody, {List<String>? productDetailSequence})
    : productDetailSequence = productDetailSequence ?? <String>[];

  final String productDetailBody;
  final List<String> productDetailSequence;
  final List<_RecordedRequest> requests = <_RecordedRequest>[];

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

    final url = options.uri.toString();
    final body = url.contains('blockader')
        ? _identityTypesBody()
        : url.contains('shinning') && productDetailSequence.isNotEmpty
        ? productDetailSequence.removeAt(0)
        : productDetailBody;
    return ResponseBody.fromString(body, 200, headers: _jsonHeaders);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubAdapter adapter;
  var completeIdentityOnOpen = false;

  setUp(() {
    Get.testMode = true;
    completeIdentityOnOpen = false;
  });
  tearDown(Get.reset);

  GatewayClient clientFor(_StubAdapter stub) => GatewayClient(
    GatewaySettings(
      signSecret: 'unit-test-secret',
      localSession: LocalSession.memory(),
    ),
    dio: Dio()..httpClientAdapter = stub,
  );

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: _homeRoute,
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: _homeRoute,
            page: () => const Scaffold(body: Center(child: Text('home'))),
          ),
          GetPage<void>(
            name: AppRoutes.certificationIdentity,
            page: () => completeIdentityOnOpen
                ? const _CompletingIdentityPage()
                : const IdentityTypePage(),
          ),
          GetPage<void>(
            name: AppRoutes.certificationFace,
            page: () => const FaceRecognitionPage(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  /// EasyLoading 的转圈是无限动画，`pumpAndSettle` 不会停：按有限帧推进。
  Future<void> pumpUntil(WidgetTester tester, bool Function() done) async {
    for (var frame = 0; frame < 25 && !done(); frame++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// 等提示的 2 秒计时器跑完，避免用例结束时留下未完成的 Timer。
  Future<void> drainToast(WidgetTester tester) async {
    for (var second = 0; second < 6; second++) {
      await tester.pump(const Duration(seconds: 1));
    }
  }

  testWidgets('产品详情深链：跳过已完成项，落到下一步的证件流程', (tester) async {
    adapter = _StubAdapter(
      _productDetailBody(<Map<String, dynamic>>[
        // 活体已完成 -> 跳过，证件才是下一步。
        _verifyItem('face', completed: 1),
        _verifyItem('public', completed: 0),
      ]),
    );
    Get.put<GatewayClient>(clientFor(adapter), permanent: true);
    await pumpApp(tester);

    // 命名路由的 Future 要等目标页被弹出才结束，这里只关心「有没有到证件页」，
    // 因此不等它返回。
    unawaited(
      AppNavigator.openTarget('ph://handa-peso/ios/Sputterers?cotype=1000460'),
    );
    await pumpUntil(
      tester,
      () => find.byType(IdentityTypePage).evaluate().isNotEmpty,
    );

    // 产品详情按文档要求带 `cotype`；证件页随后用它拉身份信息接口。
    expect(adapter.where('shinning').single.fields['cotype'], '1000460');
    expect(find.byType(IdentityTypePage), findsOneWidget);
    expect(adapter.where('blockader').single.url, contains('cotype=1000460'));
  });

  testWidgets('产品详情深链：混淆写法的证件项也认，照样进证件流程', (tester) async {
    // 文档「产品详情认证项目列表」里 `public` 的混淆写法是 `FerrelEstray`。
    adapter = _StubAdapter(
      _productDetailBody(<Map<String, dynamic>>[
        _verifyItem('FerrelEstray', completed: 0),
      ]),
    );
    Get.put<GatewayClient>(clientFor(adapter), permanent: true);
    await pumpApp(tester);

    unawaited(
      AppNavigator.openTarget('ph://handa-peso/ios/Sputterers?cotype=1000460'),
    );
    await pumpUntil(
      tester,
      () => find.byType(IdentityTypePage).evaluate().isNotEmpty,
    );

    expect(find.byType(IdentityTypePage), findsOneWidget);
  });

  testWidgets('产品详情深链：下一步为人脸时进入人脸识别页', (tester) async {
    adapter = _StubAdapter(
      _productDetailBody(<Map<String, dynamic>>[
        _verifyItem('face', completed: 0),
      ]),
    );
    Get.put<GatewayClient>(clientFor(adapter), permanent: true);
    await pumpApp(tester);

    // `openTarget` 里收 Loading 的那一步要等动画帧，先不管它的返回值。
    unawaited(
      AppNavigator.openTarget('ph://handa-peso/ios/Sputterers?cotype=1000460'),
    );
    await pumpUntil(
      tester,
      () => find.byType(FaceRecognitionPage).evaluate().isNotEmpty,
    );

    expect(find.byType(FaceRecognitionPage), findsOneWidget);
    expect(find.text('Document verification'), findsOneWidget);
    expect(find.byType(IdentityTypePage), findsNothing);
  });

  testWidgets('产品详情深链：证件保存成功后刷新下一步并自动进入人脸页', (tester) async {
    completeIdentityOnOpen = true;
    adapter = _StubAdapter(
      _productDetailBody(const <Map<String, dynamic>>[]),
      productDetailSequence: <String>[
        _productDetailBody(<Map<String, dynamic>>[
          _verifyItem('public', completed: 0),
        ]),
        _productDetailBody(<Map<String, dynamic>>[
          _verifyItem('public', completed: 1),
          _verifyItem('face', completed: 0),
        ]),
      ],
    );
    Get.put<GatewayClient>(clientFor(adapter), permanent: true);
    await pumpApp(tester);

    unawaited(
      AppNavigator.openTarget('ph://handa-peso/ios/Sputterers?cotype=1000460'),
    );
    await pumpUntil(
      tester,
      () => find.byType(FaceRecognitionPage).evaluate().isNotEmpty,
    );

    expect(find.byType(FaceRecognitionPage), findsOneWidget);
    expect(find.text('home'), findsNothing);
    expect(adapter.where('shinning'), hasLength(2));
  });

  testWidgets('产品详情深链缺产品 ID 时不发请求、提示打不开', (tester) async {
    adapter = _StubAdapter(_productDetailBody(const <Map<String, dynamic>>[]));
    Get.put<GatewayClient>(clientFor(adapter), permanent: true);
    await pumpApp(tester);

    unawaited(AppNavigator.openTarget('ph://handa-peso/ios/Sputterers'));
    await pumpUntil(
      tester,
      () => find.text('Unable to open link').evaluate().isNotEmpty,
    );

    expect(find.text('Unable to open link'), findsOneWidget);
    expect(adapter.where('shinning'), isEmpty);
    await drainToast(tester);
  });
}

class _CompletingIdentityPage extends StatefulWidget {
  const _CompletingIdentityPage();

  @override
  State<_CompletingIdentityPage> createState() =>
      _CompletingIdentityPageState();
}

class _CompletingIdentityPageState extends State<_CompletingIdentityPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final outcome = IdentityFlowOutcome.of(Get.arguments);
      outcome?.completed = true;
      outcome?.cardType = 'SSS ID';
      Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}
