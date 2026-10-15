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
import 'package:handa_peso/features/certification/certification_page.dart';

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

  /// 通讯录上报次数；个人信息这一步应该带上它。
  int contactUploads = 0;

  @override
  Future<void> reportDeviceContacts() async {
    contactUploads += 1;
  }

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
            name: AppRoutes.certification,
            page: () => const CertificationPage(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    Get.toNamed<void>(
      AppRoutes.certification,
      arguments: {'productId': productId},
    );
    await tester.pumpAndSettle();
  }

  /// 完成一步；等 SnackBar 播完再继续，避免它遮住列表底部的步骤。
  Future<void> complete(WidgetTester tester, String title) async {
    await tester.tap(find.text(title));
    await tester.pump();
    await tester.pump(const Duration(seconds: 5));
  }

  testWidgets('每一步按文档场景上报，开始时长为进入该步到完成', (tester) async {
    final openedAfter = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await pumpCertification(tester);

    // 列表同时是「认证选择页」：第一次点击就是选择结束，只报一次场景 2。
    await complete(tester, 'Identity');
    expect(spy.reports.map((report) => report.scene), <String>['2']);

    // 证件与人脸在文档里的开始时间是「点击证件正面 / 点击开始人脸」，
    // 骨架里没有对应的子页面与提交动作，因此不上报。
    await complete(tester, 'Face scan');
    expect(spy.reports.map((report) => report.scene), <String>['2']);

    await complete(tester, 'Personal details');
    expect(spy.reports.map((report) => report.scene), <String>['2', '5']);
    // 个人信息这一步包含联系人：完成时顺带把本机通讯录交出去。
    expect(spy.contactUploads, 1);
    expect(spy.reports.first.productId, '1000460');
    expect(
      spy.reports.first.startedAtSeconds,
      greaterThanOrEqualTo(openedAfter),
    );
    // 场景 5 的开始时间取自上一步完成，因此不会早于场景 2（页面打开）的时刻。
    expect(
      spy.reports[1].startedAtSeconds,
      greaterThanOrEqualTo(spy.reports.first.startedAtSeconds),
    );

    await complete(tester, 'Work information');
    expect(spy.reports.map((report) => report.scene), <String>['2', '5', '6']);
    // 工作信息的开始时间 = 上一步完成的时刻，因此不会早于个人信息步的开始时间。
    expect(
      spy.reports.last.startedAtSeconds,
      greaterThanOrEqualTo(spy.reports.first.startedAtSeconds),
    );

    await complete(tester, 'Payout account');
    expect(spy.reports.map((report) => report.scene), <String>[
      '2',
      '5',
      '6',
      '8',
    ]);
    expect(
      spy.reports.every((report) => report.productId == '1000460'),
      isTrue,
    );
  });

  testWidgets('没有产品 ID 时埋点照常发出，只是产品维度为空', (tester) async {
    await pumpCertification(tester, productId: '');

    await complete(tester, 'Identity');
    await complete(tester, 'Face scan');
    await complete(tester, 'Personal details');

    expect(spy.reports.map((report) => report.scene), <String>['2', '5']);
    expect(spy.reports.last.productId, '');
  });

  testWidgets('未接入上报服务时认证流程不受影响', (tester) async {
    Get.delete<ReportService>(force: true);
    expect(Get.isRegistered<ReportService>(), isFalse);
    await pumpCertification(tester);

    await complete(tester, 'Identity');
    await complete(tester, 'Face scan');
    await complete(tester, 'Personal details');
    await complete(tester, 'Work information');
    await complete(tester, 'Payout account');

    // 五步全部完成：没有上报服务时流程照常走完。
    expect(find.byIcon(Icons.verified_rounded), findsNWidgets(5));
    expect(spy.reports, isEmpty);
  });
}
