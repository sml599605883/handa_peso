import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/report/report_bridge.dart';
import 'package:handa_peso/core/report/report_service.dart';
import 'package:handa_peso/core/report/report_store.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/certification/bind_card_models.dart';
import 'package:handa_peso/features/certification/certification_page.dart';
import 'package:handa_peso/features/certification/emergency_contact_models.dart';
import 'package:handa_peso/features/certification/face_models.dart';
import 'package:handa_peso/features/certification/identity_models.dart';
import 'package:handa_peso/features/certification/personal_information_models.dart';

/// 一次风控埋点调用。
class _SceneReport {
  const _SceneReport({
    required this.scene,
    required this.productId,
    required this.startedAtSeconds,
  });

  final String scene;
  final String productId;
  final int startedAtSeconds;
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

  final reports = <_SceneReport>[];

  @override
  Future<void> reportScene({
    required String scene,
    String productId = '',
    String orderNo = '',
    required int startedAtSeconds,
    int? endedAtSeconds,
  }) async {
    reports.add(
      _SceneReport(
        scene: scene,
        productId: productId,
        startedAtSeconds: startedAtSeconds,
      ),
    );
  }
}

const String _homeRoute = '/stub-home';
const String _certificationTestRoute = '/stub-certification';

/// 证件流程有没有被打开过（桩页面在 `initState` 里置位）。
bool identityFlowOpened = false;
bool faceFlowOpened = false;
bool workFlowOpened = false;
bool emergencyContactFlowOpened = false;
bool bindCardFlowOpened = false;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _SpyReportService spy;

  setUp(() {
    spy = _SpyReportService();
    Get.put<ReportService>(spy, permanent: true);
  });

  tearDown(Get.reset);

  Future<void> pumpCertification(
    WidgetTester tester, {
    String productId = '1000460',
  }) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: _homeRoute,
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: _homeRoute,
            page: () => const Scaffold(body: Center(child: Text('home'))),
          ),
          GetPage<void>(
            // 用不参与顶层替换的测试路由保留清单页，单独验证清单的埋点状态机。
            name: _certificationTestRoute,
            page: () => const CertificationPage(),
          ),
          // 证件流程是独立的三段页面（见 `identity_flow_test.dart`）。
          // 这里只关心「认证清单」自己的契约：它把第一步交给那条流程，并在流程
          // 返回成功后才标记完成，所以用一枚桩页面顶替。
          GetPage<void>(
            name: AppRoutes.certificationIdentity,
            page: () => const _StubIdentityFlow(),
          ),
          GetPage<void>(
            name: AppRoutes.certificationFace,
            page: () => const _StubFaceFlow(),
          ),
          GetPage<void>(
            name: AppRoutes.personalInformation,
            page: () => const _StubPersonalFlow(),
          ),
          GetPage<void>(
            name: AppRoutes.workInformation,
            page: () => const _StubWorkFlow(),
          ),
          GetPage<void>(
            name: AppRoutes.emergencyContact,
            page: () => const _StubEmergencyContactFlow(),
          ),
          GetPage<void>(
            name: AppRoutes.bindCard,
            page: () => const _StubBindCardFlow(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    Get.toNamed<void>(
      _certificationTestRoute,
      arguments: {'productId': productId},
    );
    await tester.pumpAndSettle();
  }

  /// 完成一步；等 SnackBar 播完再继续，避免它遮住列表底部的步骤。
  Future<void> complete(WidgetTester tester, String title) async {
    await tester.ensureVisible(find.text(title));
    await tester.pumpAndSettle();
    await tester.tap(find.text(title));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
  }

  /// 走完证件流程：证件成功后认证清单应立即继续进入人脸流程。
  Future<void> completeIdentity(WidgetTester tester) async {
    identityFlowOpened = false;
    faceFlowOpened = false;
    await tester.tap(find.text('Identity'));
    await tester.pumpAndSettle();
    expect(identityFlowOpened, isTrue);
    await tester.pump(const Duration(seconds: 5));
    expect(faceFlowOpened, isTrue);
  }

  testWidgets('每一步按文档场景上报，开始时长为进入该步到完成', (tester) async {
    final openedAfter = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await pumpCertification(tester);

    // 证件（场景 2、3）由证件流程自己的页面上报；这里只把它打开、等它回成功。
    await completeIdentity(tester);
    expect(spy.reports, isEmpty);

    expect(spy.reports, isEmpty);

    await complete(tester, 'Personal details');
    expect(spy.reports.map((report) => report.scene), <String>['5']);
    expect(spy.reports.first.productId, '1000460');
    expect(
      spy.reports.first.startedAtSeconds,
      greaterThanOrEqualTo(openedAfter),
    );

    await complete(tester, 'Work information');
    expect(workFlowOpened, isTrue);
    expect(spy.reports.map((report) => report.scene), <String>['5', '6']);
    // 工作信息的开始时间 = 上一步完成的时刻，因此不会早于个人信息步的开始时间。
    expect(
      spy.reports.last.startedAtSeconds,
      greaterThanOrEqualTo(spy.reports.first.startedAtSeconds),
    );

    await complete(tester, 'Emergency contacts');
    expect(emergencyContactFlowOpened, isTrue);
    expect(spy.reports.map((report) => report.scene), <String>['5', '6', '7']);

    await complete(tester, 'Payout account');
    expect(bindCardFlowOpened, isTrue);
    expect(spy.reports.map((report) => report.scene), <String>[
      '5',
      '6',
      '7',
      '8',
    ]);
    expect(
      spy.reports.every((report) => report.productId == '1000460'),
      isTrue,
    );
  });

  testWidgets('没有产品 ID 时埋点照常发出，只是产品维度为空', (tester) async {
    await pumpCertification(tester, productId: '');

    await completeIdentity(tester);
    await complete(tester, 'Personal details');

    expect(spy.reports.map((report) => report.scene), <String>['5']);
    expect(spy.reports.last.productId, '');
  });

  testWidgets('未接入上报服务时认证流程不受影响', (tester) async {
    Get.delete<ReportService>(force: true);
    expect(Get.isRegistered<ReportService>(), isFalse);
    await pumpCertification(tester);

    await completeIdentity(tester);
    await complete(tester, 'Personal details');
    await complete(tester, 'Work information');
    await complete(tester, 'Emergency contacts');
    await complete(tester, 'Payout account');

    // 六步全部完成：没有上报服务时流程照常走完。
    expect(find.byIcon(Icons.verified_rounded), findsNWidgets(6));
    expect(spy.reports, isEmpty);
  });
}

/// 人脸流程的桩页面：真实上传与 SDK 见 `face_verification_test.dart`。
class _StubFaceFlow extends StatefulWidget {
  const _StubFaceFlow();

  @override
  State<_StubFaceFlow> createState() => _StubFaceFlowState();
}

class _StubFaceFlowState extends State<_StubFaceFlow> {
  @override
  void initState() {
    super.initState();
    faceFlowOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FaceVerificationOutcome.of(Get.arguments)?.completed = true;
      Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('face flow')));
}

/// 个人信息页在真实实现里负责场景 5；这里用同样契约的桩页验证清单只在成功
/// 回传后才把第三步标成完成。
class _StubPersonalFlow extends StatefulWidget {
  const _StubPersonalFlow();

  @override
  State<_StubPersonalFlow> createState() => _StubPersonalFlowState();
}

class _StubPersonalFlowState extends State<_StubPersonalFlow> {
  @override
  void initState() {
    super.initState();
    final startedAt = ReportService.nowSeconds();
    final arguments = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : const <String, dynamic>{};
    final productId = arguments['productId']?.toString() ?? '';
    final reporter = Get.isRegistered<ReportService>()
        ? Get.find<ReportService>()
        : null;
    reporter?.reportScene(
      scene: '5',
      productId: productId,
      startedAtSeconds: startedAt,
    );
    PersonalInformationFlowOutcome.of(Get.arguments)?.completed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// 工作信息页复用动态表单实现，真实页面自行上报场景 6；这里只验证清单是否
/// 正确等待它成功回传，再推进到下一步。
class _StubWorkFlow extends StatefulWidget {
  const _StubWorkFlow();

  @override
  State<_StubWorkFlow> createState() => _StubWorkFlowState();
}

class _StubWorkFlowState extends State<_StubWorkFlow> {
  @override
  void initState() {
    super.initState();
    workFlowOpened = true;
    final startedAt = ReportService.nowSeconds();
    final arguments = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : const <String, dynamic>{};
    final productId = arguments['productId']?.toString() ?? '';
    final reporter = Get.isRegistered<ReportService>()
        ? Get.find<ReportService>()
        : null;
    reporter?.reportScene(
      scene: '6',
      productId: productId,
      startedAtSeconds: startedAt,
    );
    PersonalInformationFlowOutcome.of(Get.arguments)?.completed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// 紧急联系人真实页面自行上报场景 7；这里只验证清单等待它成功回传后推进。
class _StubEmergencyContactFlow extends StatefulWidget {
  const _StubEmergencyContactFlow();

  @override
  State<_StubEmergencyContactFlow> createState() =>
      _StubEmergencyContactFlowState();
}

class _StubEmergencyContactFlowState extends State<_StubEmergencyContactFlow> {
  @override
  void initState() {
    super.initState();
    emergencyContactFlowOpened = true;
    final startedAt = ReportService.nowSeconds();
    final arguments = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : const <String, dynamic>{};
    final productId = arguments['productId']?.toString() ?? '';
    final reporter = Get.isRegistered<ReportService>()
        ? Get.find<ReportService>()
        : null;
    reporter?.reportScene(
      scene: '7',
      productId: productId,
      startedAtSeconds: startedAt,
    );
    EmergencyContactFlowOutcome.of(Get.arguments)?.completed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// 绑卡真实页面自行上报场景 8；这里验证清单等待成功回传后完成最后一步。
class _StubBindCardFlow extends StatefulWidget {
  const _StubBindCardFlow();

  @override
  State<_StubBindCardFlow> createState() => _StubBindCardFlowState();
}

class _StubBindCardFlowState extends State<_StubBindCardFlow> {
  @override
  void initState() {
    super.initState();
    bindCardFlowOpened = true;
    final startedAt = ReportService.nowSeconds();
    final arguments = Get.arguments is Map
        ? Map<String, dynamic>.from(Get.arguments as Map)
        : const <String, dynamic>{};
    final productId = arguments['productId']?.toString() ?? '';
    final reporter = Get.isRegistered<ReportService>()
        ? Get.find<ReportService>()
        : null;
    reporter?.reportScene(
      scene: '8',
      productId: productId,
      startedAtSeconds: startedAt,
    );
    BindCardFlowOutcome.of(Get.arguments)?.completed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// 证件流程的桩页面：真实流程见 `identity_flow_test.dart`。
///
/// 这里只模拟它对认证清单的契约——打开后立刻把「证件信息已保存」写进随参数带进来
/// 的完成标记，然后退回清单。
class _StubIdentityFlow extends StatefulWidget {
  const _StubIdentityFlow();

  @override
  State<_StubIdentityFlow> createState() => _StubIdentityFlowState();
}

class _StubIdentityFlowState extends State<_StubIdentityFlow> {
  @override
  void initState() {
    super.initState();
    identityFlowOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      IdentityFlowOutcome.of(Get.arguments)?.completed = true;
      Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: Text('identity flow')));
}
