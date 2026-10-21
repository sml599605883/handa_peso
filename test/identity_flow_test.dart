import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
// `get` 也导出了一个同名的 FormData（get_connect 的 multipart），这里只认 dio 的。
import 'package:get/get.dart' hide FormData;
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/analytics/analytics_service.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/permissions/permission_coordinator.dart';
import 'package:handa_peso/core/report/report_bridge.dart';
import 'package:handa_peso/core/report/report_service.dart';
import 'package:handa_peso/core/report/report_store.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/certification/identity_photo_service.dart';
import 'package:handa_peso/features/certification/identity_result_page.dart';
import 'package:handa_peso/features/certification/identity_models.dart';
import 'package:handa_peso/features/certification/identity_type_page.dart';
import 'package:handa_peso/features/certification/identity_upload_page.dart';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

const String _homeRoute = '/stub-home';

/// 接口文档「获取用户身份信息（第一项）」的载荷：一组推荐证件 + 一组其它证件。
const String _identityTypesBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"chemistry":{"uppropped":0},'
    '"melancholies":{"uppropped":0},'
    '"pricklier":[["DRIVINGLICENSE","PRC","SSS"]],'
    '"alleviated":[{"tonsil":[{'
    '"apivorous":"SSS ID","destructs":["https://demo"],"will":["https://bad"]'
    '}],"divagations":[{"apivorous":"TIN ID"}]}],'
    '"flatfish":"Fill in the identity information truly and accurately."'
    '}}';

/// 接口文档「接口上传(face,身份证正面)（第一项）」的识别结果。
const String _uploadResultBody =
    '{"unaccepted":"0","unstably":"成功","indulgences":{'
    '"definitively":"NAVEEN TOM VARGHESE",'
    '"optically":"623099344112",'
    '"foldaway":"Male",'
    '"gleeking":"23/11/1993",'
    '"tidewaters":"https://id-front.png",'
    '"barrens":"1993","arytenoid":"11","blather":"23"}}';

/// 接口文档「获取挽留弹窗」：弹窗类型 0（身份认证）。
const String _retentionBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"revetting":{"canonic":"Please wait, it only takes ",'
    '"unstably":" for you to complete all certifications and get a loan!",'
    '"luciferins":2000,"argala":"","sleeker":"xx/xxx/xxx.xxx",'
    '"jollified":"Continuar","footrests":"Exit",'
    '"tidewaters":"https://retention.png"}}}';

/// 一次被记录的请求：只看 URL 与表单字段。
class _RecordedRequest {
  const _RecordedRequest({required this.url, required this.fields});

  final String url;
  final Map<String, String> fields;
}

/// 脚本化适配器：按路由回固定信封，并记录表单字段。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter({this.uploadBody});

  final String? uploadBody;
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
    if (url.contains('blockader')) return _json(_identityTypesBody);
    if (url.contains('unchivalrous')) return _json(_retentionBody);
    if (url.contains('sikes')) {
      return _json(uploadBody ?? _uploadResultBody);
    }
    return _json('{"unaccepted":"0","unstably":"success","indulgences":{}}');
  }

  ResponseBody _json(String body) =>
      ResponseBody.fromString(body, 200, headers: _jsonHeaders);

  @override
  void close({bool force = false}) {}
}

/// 只记录埋点参数的假上报服务；不发任何请求。
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

  final List<String> scenes = <String>[];
  final List<String> productIds = <String>[];

  @override
  Future<void> reportScene({
    required String scene,
    String productId = '',
    String orderNo = '',
    required int startedAtSeconds,
    int? endedAtSeconds,
  }) async {
    scenes.add(scene);
    productIds.add(productId);
  }
}

/// 业务失败用例会主动上报错误；测试里静默吸收，避免 debug 出口把它当成
/// 未捕获异常而让用例失败。
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

/// 假取图出口：直接回测试临时文件。
class _FakePhotoPicker implements IdentityPhotoPicker {
  _FakePhotoPicker(this.path);

  final String path;
  int cameraCalls = 0;
  int albumCalls = 0;

  @override
  Future<String?> pickFromCamera() async {
    cameraCalls += 1;
    return path;
  }

  @override
  Future<String?> pickFromAlbum() async {
    albumCalls += 1;
    return path;
  }
}

/// 假压缩出口：记录入参，返回一个可上传的文件。
class _FakePhotoCompressor implements IdentityPhotoCompressor {
  _FakePhotoCompressor(this.path);

  final String path;
  final List<String> inputs = <String>[];

  @override
  Future<String?> compressToLimit(String filePath) async {
    inputs.add(filePath);
    return path;
  }
}

/// 假相机权限出口：直接给「已授权」，测试里不碰 permission_handler 的平台通道。
class _FakePermissions extends PermissionCoordinator {
  int cameraRequests = 0;

  @override
  Future<PermissionDecision> requestCamera() async {
    cameraRequests += 1;
    return PermissionDecision.granted;
  }
}

/// EasyLoading 的转圈是无限动画，`pumpAndSettle` 不会停：按有限帧推进到条件成立。
Future<void> _pumpUntil(WidgetTester tester, bool Function() done) async {
  for (var frame = 0; frame < 30 && !done(); frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
  for (var frame = 0; frame < 6; frame++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// EasyLoading 的提示动画与计时器是单例状态：跑完再收下一个用例。
Future<void> _drainEasyLoading(WidgetTester tester) async {
  for (var second = 0; second < 6; second++) {
    await tester.pump(const Duration(seconds: 1));
  }
  await EasyLoading.dismiss();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _StubAdapter adapter;
  late _SpyReportService spy;
  late _FakePhotoPicker picker;
  late _FakePhotoCompressor compressor;
  late _FakePermissions permissions;
  late Directory tempDir;

  setUp(() async {
    AnalyticsService.configure(_SilentTelemetrySink());
    adapter = _StubAdapter();
    final client = GatewayClient(
      GatewaySettings(
        signSecret: 'unit-test-secret',
        localSession: LocalSession.memory(),
      ),
      dio: Dio()..httpClientAdapter = adapter,
    );
    Get.put<GatewayClient>(client, permanent: true);
    spy = _SpyReportService();
    Get.put<ReportService>(spy, permanent: true);

    tempDir = await Directory.systemTemp.createTemp('handa-identity-flow');
    final photo = File('${tempDir.path}/id-front.jpg');
    await photo.writeAsBytes(Uint8List.fromList(List<int>.filled(64, 7)));
    picker = _FakePhotoPicker(photo.path);
    compressor = _FakePhotoCompressor(photo.path);
    permissions = _FakePermissions();
  });

  tearDown(() async {
    Get.reset();
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  Future<void> pumpFlow(WidgetTester tester) async {
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
            page: () => const IdentityTypePage(),
          ),
          GetPage<void>(
            name: AppRoutes.certificationIdentityUpload,
            page: () => IdentityUploadPage(
              photoPicker: picker,
              photoCompressor: compressor,
              permissions: permissions,
            ),
          ),
          GetPage<void>(
            name: AppRoutes.certificationIdentityResult,
            page: () => const IdentityResultPage(autoContinue: false),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('证件类型按接口分组展示，选中后上报场景 2 并进入上传页', (tester) async {
    await pumpFlow(tester);
    final outcome = IdentityFlowOutcome();
    Get.toNamed<void>(
      AppRoutes.certificationIdentity,
      arguments: <String, dynamic>{
        'productId': '1000460',
        IdentityFlowOutcome.argumentKey: outcome,
      },
    );
    await tester.pumpAndSettle();

    // 推荐证件与其它证件两组来自 `alleviated` 的 tonsil / divagations。
    expect(find.text('RECOMMENDED ID TYPE!'), findsOneWidget);
    expect(find.text('OTHER OPTIONS!'), findsOneWidget);
    expect(find.text('SSS ID'), findsOneWidget);
    expect(find.text('TIN ID'), findsOneWidget);
    expect(adapter.where('blockader').single.url, contains('cotype=1000460'));

    await tester.tap(find.text('SSS ID'));
    await tester.pumpAndSettle();

    // 场景 2 的结束时间 = 用户选中证件；随后进入上传页。
    expect(spy.scenes, <String>['2']);
    expect(spy.productIds.single, '1000460');
    expect(find.text('Demonstration!'), findsOneWidget);
    // 流程还没走到保存成功，认证清单不该认为这一步完成。
    expect(outcome.completed, isFalse);
  });

  testWidgets('证件类型页返回：挽留弹窗选择继续时留在当前页', (tester) async {
    await pumpFlow(tester);
    Get.toNamed<void>(
      AppRoutes.certificationIdentity,
      arguments: <String, dynamic>{'productId': '1000460'},
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('identity-back')));
    await _pumpUntil(
      tester,
      () => find
          .byKey(const Key('identity-retention-continue'))
          .evaluate()
          .isNotEmpty,
    );
    final retention = adapter.where('unchivalrous').single;
    expect(retention.fields['ulterior'], '0');
    expect(retention.fields['knife'], '1000460');

    await tester.tap(find.byKey(const Key('identity-retention-continue')));
    await tester.pumpAndSettle();
    expect(find.text('RECOMMENDED ID TYPE!'), findsOneWidget);
    expect(adapter.where('unchivalrous'), hasLength(1));
  });

  testWidgets('证件类型页返回：挽留弹窗选择退出时回到入口页', (tester) async {
    await pumpFlow(tester);
    Get.toNamed<void>(
      AppRoutes.certificationIdentity,
      arguments: <String, dynamic>{'productId': '1000460'},
    );
    await tester.pumpAndSettle();

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
    expect(adapter.where('unchivalrous'), hasLength(1));
  });

  testWidgets('上传页只压缩所选图片，上传接口仍用项目自己的证件类型字段', (tester) async {
    await pumpFlow(tester);
    Get.toNamed<void>(
      AppRoutes.certificationIdentityUpload,
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('identity-upload-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('identity-upload-method-album')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('identity-upload-method-submit')));
    await _pumpUntil(
      tester,
      () => find.text('Successfully!').evaluate().isNotEmpty,
    );

    expect(compressor.inputs, <String>[picker.path]);
    final upload = adapter.where('sikes').single;
    expect(upload.fields['trollopy'], '11');
    expect(upload.fields['sleeker'], '1');
    expect(upload.fields['scarriest'], 'SSS ID');
    expect(upload.fields.containsKey('misapprehend'), isFalse);
    await _drainEasyLoading(tester);
  });

  testWidgets('上传接口业务失败时停留在上传页，不进入结果页', (tester) async {
    adapter = _StubAdapter(
      uploadBody:
          '{"unaccepted":"500","unstably":"Unable to read this ID",'
          '"indulgences":{}}',
    );
    Get.replace<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ),
    );

    await pumpFlow(tester);
    Get.toNamed<void>(
      AppRoutes.certificationIdentityUpload,
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('identity-upload-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('identity-upload-method-album')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('identity-upload-method-submit')));
    await _pumpUntil(tester, () => adapter.where('sikes').isNotEmpty);

    expect(find.text('Successfully!'), findsNothing);
    expect(find.text('Demonstration!'), findsOneWidget);
    expect(compressor.inputs, hasLength(1));
    await _drainEasyLoading(tester);
  });

  testWidgets('拍照上传：按文档字段提交，成功页能改正识别结果再保存', (tester) async {
    await pumpFlow(tester);
    final outcome = IdentityFlowOutcome();
    Get.toNamed<void>(
      AppRoutes.certificationIdentityUpload,
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
        IdentityFlowOutcome.argumentKey: outcome,
      },
    );
    await tester.pumpAndSettle();
    expect(find.text('Demonstration!'), findsOneWidget);

    // 页面 Submit -> 认证方式弹层：Camera / Album 二选一，默认拍照。
    await tester.tap(find.byKey(const Key('identity-upload-submit')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('identity-upload-method-camera')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('identity-upload-method-album')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('identity-upload-method-submit')));
    await _pumpUntil(
      tester,
      () => find.text('Successfully!').evaluate().isNotEmpty,
    );

    // 默认拍照：只请求相机权限，接口按文档传 `sleeker=2`。
    expect(picker.cameraCalls, 1);
    expect(permissions.cameraRequests, 1);
    final upload = adapter.where('sikes').single;
    expect(upload.fields['trollopy'], '11');
    expect(upload.fields['sleeker'], '2');
    expect(upload.fields['scarriest'], 'SSS ID');

    // 成功页把识别结果放进可编辑的三行：生日从 `23/11/1993` 归一成 `d-m-Y`。
    expect(find.text('NAVEEN TOM VARGHESE'), findsOneWidget);
    expect(find.text('623099344112'), findsOneWidget);
    expect(find.text('23-11-1993'), findsOneWidget);

    // 识别错的名字与证件号就地改正。
    await tester.enterText(
      find.byKey(const Key('identity-result-name')),
      'NAVEEN T VARGHESE',
    );
    await tester.enterText(
      find.byKey(const Key('identity-result-id')),
      '623099344113',
    );
    await tester.pump();

    // 生日走设计稿 03-02 的滚轮：向下滚一行（加一天）。
    await tester.tap(find.byKey(const Key('identity-result-row-2')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('identity-birthday-panel')), findsOneWidget);
    await tester.drag(
      find.byKey(const Key('identity-birthday-day')),
      const Offset(0, -60),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('identity-birthday-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('identity-result-submit')));
    await _pumpUntil(
      tester,
      () =>
          adapter.where('polybutadiene').isNotEmpty &&
          adapter.where('phellem').isNotEmpty,
    );

    final save = adapter.where('polybutadiene').single;
    expect(save.fields['definitively'], 'NAVEEN T VARGHESE');
    expect(save.fields['optically'], '623099344113');
    expect(save.fields['gleeking'], '24-11-1993');
    expect(save.fields['trollopy'], '11');
    expect(save.fields['scarriest'], 'SSS ID');
    // 文档登记的混淆字段要在同一次请求里带上。
    expect(save.fields.containsKey('wrencher'), isTrue);
    expect(adapter.where('phellem').single.fields['cotype'], '1000460');

    // 场景 3 的结束时间 = 证件正面保存成功。
    expect(spy.scenes, <String>['3']);
    expect(spy.productIds.single, '1000460');

    await _pumpUntil(tester, () => outcome.completed);
    expect(outcome.completed, isTrue);
    // 保存成功后流程逐层退出，回到入口页。
    await _pumpUntil(tester, () => find.text('home').evaluate().isNotEmpty);
    expect(find.text('home'), findsOneWidget);
    await _drainEasyLoading(tester);
  });

  testWidgets('相册上传：不请求相机权限，按文档提交 sleeker=1', (tester) async {
    await pumpFlow(tester);
    Get.toNamed<void>(
      AppRoutes.certificationIdentityUpload,
      arguments: <String, dynamic>{
        'productId': '1000460',
        'cardType': 'SSS ID',
      },
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('identity-upload-submit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('identity-upload-method-album')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('identity-upload-method-submit')));
    await _pumpUntil(
      tester,
      () => find.text('Successfully!').evaluate().isNotEmpty,
    );

    expect(picker.cameraCalls, 0);
    expect(picker.albumCalls, 1);
    expect(permissions.cameraRequests, 0);
    final upload = adapter.where('sikes').single;
    expect(upload.fields['trollopy'], '11');
    expect(upload.fields['sleeker'], '1');
    expect(upload.fields['scarriest'], 'SSS ID');
    await _drainEasyLoading(tester);
  });
}
