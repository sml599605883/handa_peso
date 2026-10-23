import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
// `get` 也导出 FormData；这里只使用 Dio 的 multipart 类型。
import 'package:get/get.dart' hide FormData;
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/app/theme/app_colors.dart';
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
import 'package:handa_peso/features/certification/face_models.dart';
import 'package:handa_peso/features/certification/face_recognition_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('face token contract', () {
    test('只有 result_code=200、类型 7 且 license 非空时可启动活体', () {
      final reply = GatewayReply.parse(<String, Object?>{
        'unaccepted': '00',
        'unstably': '成功',
        'indulgences': <String, Object?>{
          'beet': '200',
          'obsoletely': 'license-1',
          'esplanades': 7,
        },
      });

      final token = FaceTokenResult.fromReply(reply);

      expect(token.isReady, isTrue);
      expect(token.needsIdentityUpload, isFalse);
    });

    test('活体类型不是 7 时不得误交给 TrustDecision SDK', () {
      final reply = GatewayReply.parse(<String, Object?>{
        'unaccepted': 0,
        'indulgences': <String, Object?>{
          'beet': 200,
          'obsoletely': 'facepp-token',
          'esplanades': 5,
        },
      });

      expect(FaceTokenResult.fromReply(reply).isReady, isFalse);
    });

    test('400 表示需要重新上传身份证', () {
      final reply = GatewayReply.parse(<String, Object?>{
        'unaccepted': 0,
        'indulgences': <String, Object?>{'beet': 400},
      });

      expect(FaceTokenResult.fromReply(reply).needsIdentityUpload, isTrue);
    });
  });

  group('face liveness upload gate', () {
    test('回调带图片与 liveness_id 时允许上传，不依赖 success/code', () {
      const result = FaceLivenessResult(
        success: false,
        code: 400,
        message: '',
        image: 'base64-image',
        livenessId: 'liveness-1',
        requestId: 'request-1',
        rawJson: '{}',
      );

      expect(hasUploadableLivenessData(result), isTrue);
    });

    test('缺少图片或 liveness_id 时停止流程', () {
      const noImage = FaceLivenessResult(
        success: true,
        code: 200,
        message: '',
        image: '',
        livenessId: 'liveness-1',
        requestId: 'request-1',
        rawJson: '{}',
      );
      const noLivenessId = FaceLivenessResult(
        success: true,
        code: 200,
        message: '',
        image: 'base64-image',
        livenessId: '',
        requestId: 'request-1',
        rawJson: '{}',
      );

      expect(hasUploadableLivenessData(noImage), isFalse);
      expect(hasUploadableLivenessData(noLivenessId), isFalse);
    });
  });

  group('face verification navigation gate', () {
    late _FaceAdapter adapter;
    late _FaceSpyReportService reporter;

    setUp(() {
      Get.testMode = true;
      AnalyticsService.configure(_SilentTelemetrySink());
      adapter = _FaceAdapter();
      reporter = _FaceSpyReportService();
    });

    tearDown(Get.reset);

    testWidgets('按 MyTools 字段上传成功后才完成并上报场景 4', (tester) async {
      final outcome = FaceVerificationOutcome();
      await _pumpFacePage(
        tester,
        adapter: adapter,
        reporter: reporter,
        outcome: outcome,
      );

      await tester.tap(find.byKey(const Key('face-recognition-submit')));
      await _pumpUntil(tester, () => outcome.completed);

      final token = adapter.where('postforming').single;
      expect(token.fields['eelworm'], 'ORDER-1');
      expect(token.fields['trollopy'], '0');
      final upload = adapter.where('sikes').single;
      expect(upload.fields['trollopy'], '10');
      expect(upload.fields['sleeker'], '1');
      expect(upload.fields['scarriest'], 'SSS ID');
      expect(upload.fields['debater'], 'liveness-1');
      expect(upload.fields['wowsers'], 'license-1');
      expect(upload.fields['esplanades'], '7');
      expect(adapter.where('flaunter'), hasLength(1));
      expect(reporter.scenes, <String>['4']);
      expect(find.text('home'), findsOneWidget);
      await _drainEasyLoading(tester);
    });

    testWidgets('人脸上传业务失败时留在页面，不完成也不上报场景 4', (tester) async {
      adapter.uploadBody =
          '{"unaccepted":"500","unstably":"Upload rejected","indulgences":{}}';
      final outcome = FaceVerificationOutcome();
      await _pumpFacePage(
        tester,
        adapter: adapter,
        reporter: reporter,
        outcome: outcome,
      );

      await tester.tap(find.byKey(const Key('face-recognition-submit')));
      await _pumpUntil(tester, () => adapter.where('sikes').isNotEmpty);

      expect(outcome.completed, isFalse);
      expect(find.byType(FaceRecognitionPage), findsOneWidget);
      expect(reporter.scenes, isEmpty);
      await _drainEasyLoading(tester);
    });

    testWidgets('相机权限缺失时展示 Cupertino 弹窗，取消按钮为浅灰色', (tester) async {
      final outcome = FaceVerificationOutcome();
      await _pumpFacePage(
        tester,
        adapter: adapter,
        reporter: reporter,
        outcome: outcome,
        permissions: _DenyCamera(),
      );

      await tester.tap(find.byKey(const Key('face-recognition-submit')));
      await _pumpUntil(
        tester,
        () => find.byType(CupertinoAlertDialog).evaluate().isNotEmpty,
      );

      expect(find.byType(CupertinoAlertDialog), findsOneWidget);
      final cancel = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Not Now'),
      );
      final openSettings = tester.widget<CupertinoDialogAction>(
        find.widgetWithText(CupertinoDialogAction, 'Open Settings'),
      );
      expect(cancel.textStyle?.color, AppColors.textMuted);
      expect(openSettings.textStyle?.color, AppColors.identityTitle);

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();
      expect(find.byType(CupertinoAlertDialog), findsNothing);
      expect(outcome.completed, isFalse);
    });

    testWidgets('人脸页返回：请求 scene=1 的挽留弹窗，继续时留在当前页', (tester) async {
      final outcome = FaceVerificationOutcome();
      await _pumpFacePage(
        tester,
        adapter: adapter,
        reporter: reporter,
        outcome: outcome,
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
      expect(retention.fields['ulterior'], '1');
      expect(retention.fields['knife'], '1000460');

      await tester.tap(find.byKey(const Key('identity-retention-continue')));
      await tester.pumpAndSettle();
      expect(find.byType(FaceRecognitionPage), findsOneWidget);
      expect(outcome.completed, isFalse);
    });

    testWidgets('人脸页返回：挽留弹窗选择退出时回到入口页', (tester) async {
      final outcome = FaceVerificationOutcome();
      await _pumpFacePage(
        tester,
        adapter: adapter,
        reporter: reporter,
        outcome: outcome,
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
      await _pumpUntil(tester, () => find.text('home').evaluate().isNotEmpty);

      expect(find.text('home'), findsOneWidget);
      expect(find.byType(FaceRecognitionPage), findsNothing);
      expect(outcome.completed, isFalse);
    });
  });
}

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

/// 接口文档「获取挽留弹窗」：弹窗类型 1（人脸识别）。
const String _retentionBody =
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

class _FaceAdapter implements HttpClientAdapter {
  String uploadBody =
      '{"unaccepted":"0","unstably":"成功","indulgences":{"waded":99}}';
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
    if (data is FormData) {
      for (final entry in data.fields) {
        fields[entry.key] = entry.value;
      }
    } else if (data is Map) {
      for (final entry in data.entries) {
        fields['${entry.key}'] = '${entry.value}';
      }
    }
    requests.add(_RecordedRequest(url: options.uri.toString(), fields: fields));

    final url = options.uri.toString();
    if (url.contains('unchivalrous')) return _json(_retentionBody);
    if (url.contains('postforming')) {
      return _json(
        '{"unaccepted":"00","unstably":"成功","indulgences":{'
        '"beet":"200","districts":"","obsoletely":"license-1",'
        '"genomes":"","esplanades":7}}',
      );
    }
    if (url.contains('sikes')) return _json(uploadBody);
    return _json('{"unaccepted":"0","unstably":"success","indulgences":{}}');
  }

  ResponseBody _json(String body) =>
      ResponseBody.fromString(body, 200, headers: _jsonHeaders);

  @override
  void close({bool force = false}) {}
}

class _FaceLivenessStub implements FaceLivenessLauncher {
  @override
  Future<FaceLivenessResult> start(String license) async {
    // Deliberately use a non-success code: upload must be gated on returned data.
    return const FaceLivenessResult(
      success: false,
      code: 400,
      message: '',
      image: 'image-data',
      livenessId: 'liveness-1',
      requestId: 'request-1',
      rawJson: '{"code":400}',
    );
  }
}

class _GrantCamera extends PermissionCoordinator {
  @override
  Future<PermissionDecision> requestCamera() async =>
      PermissionDecision.granted;
}

class _DenyCamera extends PermissionCoordinator {
  @override
  Future<PermissionDecision> requestCamera() async =>
      PermissionDecision.permanentlyDenied;
}

class _FaceSpyReportService extends ReportService {
  _FaceSpyReportService()
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

Future<void> _pumpFacePage(
  WidgetTester tester, {
  required _FaceAdapter adapter,
  required _FaceSpyReportService reporter,
  required FaceVerificationOutcome outcome,
  PermissionCoordinator? permissions,
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
  final imageBytes = File('assets/face_recognition_demo_card.png')
      .readAsBytesSync();
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/stub-home',
      builder: EasyLoading.init(),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(
          name: '/stub-home',
          page: () => const Scaffold(body: Center(child: Text('home'))),
        ),
        GetPage<void>(
          name: AppRoutes.certificationFace,
          page: () => FaceRecognitionPage(
            apiClient: client,
            liveness: _FaceLivenessStub(),
            permissions: permissions ?? _GrantCamera(),
            reporter: reporter,
            autoContinue: false,
            imageWriter: (_) {
              final file = File(
                '${Directory.systemTemp.path}/handa-face-test-'
                '${DateTime.now().microsecondsSinceEpoch}.png',
              );
              file.writeAsBytesSync(imageBytes, flush: true);
              return Future<String>.value(file.path);
            },
          ),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
  Get.toNamed<void>(
    AppRoutes.certificationFace,
    arguments: <String, dynamic>{
      'productId': '1000460',
      'orderNo': 'ORDER-1',
      'cardType': 'SSS ID',
      FaceVerificationOutcome.argumentKey: outcome,
    },
  );
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

Future<void> _drainEasyLoading(WidgetTester tester) async {
  for (var second = 0; second < 4; second++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await EasyLoading.dismiss();
}
