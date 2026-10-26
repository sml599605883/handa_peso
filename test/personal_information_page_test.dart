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
import 'package:handa_peso/core/product/product_detail_snapshot.dart';
import 'package:handa_peso/core/report/report_bridge.dart';
import 'package:handa_peso/core/report/report_service.dart';
import 'package:handa_peso/core/report/report_store.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/certification/identity_design.dart';
import 'package:handa_peso/features/certification/personal_information_models.dart';
import 'package:handa_peso/features/certification/personal_information_page.dart';
import 'package:handa_peso/features/certification/widgets/personal_address_selector.dart';
import 'package:handa_peso/features/certification/work_information_page.dart';

const _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

const _personalBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"magnificences":['
    '{"canonic":"Education","preaccuses":"Please select education",'
    '"unaccepted":"education","psychosexual":"enum","ulterior":0,'
    '"azurites":[{"definitively":"High School","trollopy":2},'
    '{"definitively":"Undergraduate","trollopy":4}],'
    '"packwaxes":0,"monosyllabicity":"Undergraduate"},'
    '{"canonic":"Marital state","preaccuses":"Please select marital state",'
    '"unaccepted":"various","psychosexual":"enum","ulterior":0,'
    '"azurites":[{"definitively":"Single","trollopy":1}],'
    '"packwaxes":0,"monosyllabicity":"Single"},'
    '{"canonic":"Number of Credit Cards",'
    '"preaccuses":"Please select numbers of your credit cards",'
    '"unaccepted":"number_of_credit_cards","psychosexual":"enum",'
    '"ulterior":0,"azurites":[{"definitively":"2","trollopy":3}],'
    '"packwaxes":0,"monosyllabicity":"2"},'
    '{"canonic":"Email","preaccuses":"Please input email",'
    '"unaccepted":"offer","psychosexual":"txt","ulterior":0,"azurites":[],'
    '"packwaxes":0,"monosyllabicity":"user@example.com"},'
    '{"canonic":"Gender","preaccuses":"Gender","unaccepted":"copies",'
    '"psychosexual":"enum","ulterior":0,'
    '"azurites":[{"definitively":"male","trollopy":1}],'
    '"packwaxes":0,"monosyllabicity":"male"},'
    '{"canonic":"Residential Address","preaccuses":"Please select address",'
    '"unaccepted":"residential_address","psychosexual":"citySelect",'
    '"ulterior":0,'
    '"azurites":[],"packwaxes":0,'
    '"monosyllabicity":"Region I-Pangasinan-Alcala"},'
    '{"canonic":"Loan Purpose","preaccuses":"Loan Purpose",'
    '"unaccepted":"use_of_funds","psychosexual":"enum","ulterior":0,'
    '"azurites":[{"definitively":"Loans","trollopy":11}],'
    '"packwaxes":0,"monosyllabicity":"Loans"},'
    '{"canonic":"Address Details",'
    '"preaccuses":"Please input company address detail",'
    '"unaccepted":"complete_address","psychosexual":"txt","ulterior":0,'
    '"azurites":[],"packwaxes":0,"monosyllabicity":"SPSS"}'
    '],"flatfish":"Fill in personal information truthfully and accurately."'
    '}}';

const _addressBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"latchstrings":[{"dependable":1,"definitively":"NCR",'
    '"latchstrings":[{"dependable":2,"definitively":"Metro Manila",'
    '"latchstrings":[{"dependable":1350,"definitively":"Manila"}]}]}]}}';

const _workBody =
    '{"unaccepted":"0","unstably":"success","indulgences":{'
    '"magnificences":['
    '{"canonic":"Company Name","preaccuses":"Please input company name",'
    '"unaccepted":"freshly","psychosexual":"onto","ulterior":0,'
    '"azurites":[],"packwaxes":0,"monosyllabicity":"SPSS"},'
    '{"canonic":"Profession","preaccuses":"Profession",'
    '"unaccepted":"profit","psychosexual":"stepped","ulterior":0,'
    '"azurites":[{"definitively":"Student","trollopy":1},'
    '{"definitively":"Ofw","trollopy":7}],'
    '"packwaxes":0,"monosyllabicity":"Ofw"},'
    '{"canonic":"Payday","preaccuses":"Please select payday",'
    '"unaccepted":"opportunities","psychosexual":"stepped","ulterior":0,'
    '"azurites":['
    '{"definitively":"Daily","trollopy":1,'
    '"azurites":[{"definitively":"Daily","trollopy":1}]},'
    '{"definitively":"Weekly","trollopy":2,'
    '"azurites":[{"definitively":"Mon","trollopy":2}]},'
    '{"definitively":"Once a Month","trollopy":4,'
    '"azurites":[{"definitively":1,"trollopy":11}]}'
    '],"packwaxes":0,"monosyllabicity":"Once a Month|1"}'
    '],"flatfish":"Complete the filling and increase the borrowing limit"}}';

/// 接口文档「获取挽留弹窗」：个人信息（2）与工作信息（3）共用同一份载荷。
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
  _StubAdapter({
    this.saveBody = '{"unaccepted":"0","unstably":"success","indulgences":{}}',
  });

  final String saveBody;
  final requests = <_RecordedRequest>[];

  List<_RecordedRequest> where(String fragment) =>
      requests.where((request) => request.url.contains(fragment)).toList();

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
    final body = uri.contains('unchivalrous')
        ? _retentionBody
        : uri.contains('endoscopes')
        ? _personalBody
        : uri.contains('counteract')
        ? _workBody
        : uri.contains('originator')
        ? _addressBody
        : saveBody;
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
  void setUserId(String? userId) {}

  @override
  void setUserProperty(String name, String? value) {}
}

/// 只记录风控埋点参数的假上报服务；不发任何请求。
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

  final reports = <({String scene, String productId, String orderNo})>[];

  @override
  Future<void> reportScene({
    required String scene,
    String productId = '',
    String orderNo = '',
    required int startedAtSeconds,
    int? endedAtSeconds,
  }) async {
    reports.add((scene: scene, productId: productId, orderNo: orderNo));
  }
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
    PersonalAddressSelector.clearCache();
    await EasyLoading.dismiss();
  });
  tearDown(Get.reset);

  test('接口文档字段映射为个人信息动态表单', () {
    final data = PersonalInformationData.fromReply(
      GatewayReply.parse(jsonDecode(_personalBody)),
    );

    expect(data.fields, hasLength(8));
    expect(data.tips, contains('truthfully'));
    expect(data.fields.first.title, 'Education');
    expect(data.fields.first.initialSubmitValue, '4');
    expect(data.fields[5].control, PersonalInformationControl.address);
    expect(data.fields[7].control, PersonalInformationControl.text);
  });

  test('接口文档的明文与混淆组件类型都映射到正确控件', () {
    for (final entry in <String, PersonalInformationControl>{
      'enum': PersonalInformationControl.selection,
      'PastramisNucleosomal': PersonalInformationControl.selection,
      'txt': PersonalInformationControl.text,
      'YokefellowComplicity': PersonalInformationControl.text,
      'citySelect': PersonalInformationControl.address,
      'Safely': PersonalInformationControl.address,
    }.entries) {
      final field = PersonalInformationField.fromJson(<String, dynamic>{
        'unaccepted': entry.key,
        'canonic': entry.key,
        'psychosexual': entry.key,
        'packwaxes': 0,
      });
      expect(field.control, entry.value, reason: entry.key);
    }
  });

  test('工作信息的二级选项与初始值使用 azurites 结构', () {
    final data = PersonalInformationData.fromReply(
      GatewayReply.parse(jsonDecode(_workBody)),
    );

    final payday = data.fields.last;
    expect(payday.title, 'Payday');
    expect(payday.options, hasLength(3));
    expect(payday.options.last.children.single.label, '1');
    expect(payday.options.last.children.single.value, '11');
    expect(payday.initialSubmitValue, '11');
    expect(payday.initialDisplayValue, 'Once a Month|1');
  });

  test('单选选项解析可选的 headway logo', () {
    final option = PersonalInformationOption.fromJson(<String, dynamic>{
      'definitively': 'GCash e-wallet',
      'trollopy': 6,
      'headway': 'https://example.com/gcash.png',
    });
    final withoutLogo = PersonalInformationOption.fromJson(<String, dynamic>{
      'definitively': 'Bank transfer',
      'trollopy': 'BANK',
      'headway': '',
    });

    expect(option.logoUrl, 'https://example.com/gcash.png');
    expect(withoutLogo.logoUrl, isEmpty);
  });

  testWidgets('顶部提示最多三行，最低 14 号并用省略号收尾', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const copy =
        'Complete every required detail carefully so we can verify your '
        'profile, understand your current situation, and continue reviewing '
        'your application without unnecessary delays or repeated steps. '
        'This intentionally long copy must stay inside three lines and use '
        'an ellipsis when even the minimum font size cannot display it all.';

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 375,
            height: 81,
            child: IdentityHeroBanner(
              text: copy,
              metrics: const IdentityMetrics(screenWidth: 375),
              maxLines: 3,
              minFontSize: 14,
              maxFontSize: 20,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final texts = tester.widgetList<Text>(find.text(copy)).toList();
    expect(texts, hasLength(2));
    for (final text in texts) {
      expect(text.maxLines, 3);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.style?.fontSize, 14);
    }
  });

  testWidgets('顶部提示超过三行时会实际缩小字号', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const copy =
        'Fill it out accurately, clean data lifts approval odds to 98%. '
        'Please review every field before you submit the form.';

    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 375,
            height: 81,
            child: IdentityHeroBanner(
              text: copy,
              metrics: const IdentityMetrics(screenWidth: 375),
              maxLines: 3,
              minFontSize: 14,
              maxFontSize: 20,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final fontSize = tester.widget<Text>(find.text(copy).first).style?.fontSize;
    expect(fontSize, isNotNull);
    expect(fontSize!, lessThan(20));
    expect(fontSize, greaterThanOrEqualTo(14));
  });

  testWidgets('个人信息页按设计坐标渲染，并原样提交动态字段', (tester) async {
    tester.view.physicalSize = const Size(375, 1107);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter();
    Get.put<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ),
      permanent: true,
    );
    await Get.find<GatewayClient>().settings.localSession.cacheProductFlow(
      const ProductStepCopy(personal: 'Use the product detail personal copy'),
      orderNo: 'ORDER-1000460',
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.personalInformation,
            page: () => const PersonalInformationPage(autoContinue: false),
          ),
        ],
      ),
    );
    final outcome = PersonalInformationFlowOutcome();
    Get.toNamed<void>(
      AppRoutes.personalInformation,
      arguments: <String, dynamic>{
        'productId': '1000460',
        PersonalInformationFlowOutcome.argumentKey: outcome,
      },
    );
    await tester.pumpAndSettle();

    expect(find.text('Identity Information'), findsOneWidget);
    expect(find.text('Use the product detail personal copy'), findsWidgets);
    expect(
      find.text('Fill in personal information truthfully and accurately.'),
      findsNothing,
    );
    expect(find.byKey(const Key('certification-progress-bar')), findsOneWidget);
    expect(find.byKey(const Key('identity-hero-banner')), findsOneWidget);
    expect(find.text('Education'), findsOneWidget);
    expect(find.text('Address Details'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('identity-back'))),
      const Size(24, 24),
    );
    expect(
      find.byKey(const ValueKey<String>('personal-select-education')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('personal-input-offer')),
      findsOneWidget,
    );
    final textField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('personal-input-offer')),
    );
    expect(textField.contextMenuBuilder, isNotNull);
    final decoration = textField.decoration!;
    expect(decoration.filled, isFalse);
    expect(decoration.border, InputBorder.none);
    expect(decoration.enabledBorder, InputBorder.none);
    expect(decoration.disabledBorder, InputBorder.none);
    expect(decoration.focusedBorder, InputBorder.none);
    expect(decoration.errorBorder, InputBorder.none);
    expect(decoration.focusedErrorBorder, InputBorder.none);
    expect(
      find.byKey(const ValueKey<String>('personal-select-residential_address')),
      findsOneWidget,
    );
    final fieldArrows = tester
        .widgetList<Image>(find.byType(Image))
        .where(
          (image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName ==
                  'assets/personal_information_chevron.png',
        );
    expect(fieldArrows, isNotEmpty);

    await tester.tap(
      find.byKey(const ValueKey<String>('personal-select-education')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('certification-option-2')),
    );
    await tester.tap(
      find.byKey(const Key('certification-single-select-submit')),
    );
    await tester.pumpAndSettle();
    expect(find.text('High School'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('personal-select-residential_address')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personal-address-sheet')), findsOneWidget);
    final addressSheet = tester.getRect(
      find.byKey(const Key('personal-address-sheet')),
    );
    expect(addressSheet.width, 375);
    expect(addressSheet.height, 521);
    expect(addressSheet.bottom, 1107);
    expect(
      tester.getRect(find.byKey(const ValueKey<String>('personal-address-1'))),
      const Rect.fromLTWH(24, 657, 327, 48),
    );
    expect(
      tester.getRect(find.byKey(const Key('personal-address-submit'))),
      const Rect.fromLTWH(78, 1001, 220, 52),
    );
    await tester.tap(find.byKey(const ValueKey<String>('personal-address-1')));
    await tester.pumpAndSettle();
    expect(find.text('Metro Manila'), findsNothing);
    await tester.tap(find.byKey(const Key('personal-address-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Metro Manila'), findsOneWidget);

    await tester.tap(find.byKey(const Key('personal-address-back')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey<String>('personal-address-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('personal-address-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey<String>('personal-address-2')));
    await tester.tap(find.byKey(const Key('personal-address-submit')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('personal-address-back')));
    await tester.pumpAndSettle();
    expect(find.text('Metro Manila'), findsOneWidget);
    await tester.tap(find.byKey(const Key('personal-address-submit')));
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('personal-address-1350')),
    );
    await tester.tap(find.byKey(const Key('personal-address-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personal-address-sheet')), findsNothing);

    await tester.tap(
      find.byKey(const ValueKey<String>('personal-select-residential_address')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('personal-address-back')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('personal-address-sheet')), findsNothing);
    expect(adapter.where('originator'), hasLength(1));

    expect(
      tester.getRect(find.byKey(const Key('personal-information-submit'))),
      const Rect.fromLTWH(77.5, 1001, 220, 52),
    );

    await tester.tap(find.byKey(const Key('personal-information-submit')));
    for (var i = 0; i < 30 && !outcome.completed; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final save = adapter.where('walleyed').single;
    expect(save.fields['cotype'], '1000460');
    expect(save.fields['education'], '2');
    expect(save.fields['various'], '1');
    expect(save.fields['offer'], 'user@example.com');
    expect(save.fields['residential_address'], 'NCR-Metro Manila-Manila');
    expect(save.fields['complete_address'], 'SPSS');
    expect(outcome.completed, isTrue);
  });

  testWidgets('保存失败时停留在当前页且不标记完成', (tester) async {
    tester.view.physicalSize = const Size(375, 1107);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter(
      saveBody:
          '{"unaccepted":"500","unstably":"Save failed","indulgences":{}}',
    );
    Get.put<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ),
      permanent: true,
    );
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.personalInformation,
            page: () => const PersonalInformationPage(),
          ),
        ],
      ),
    );
    final outcome = PersonalInformationFlowOutcome();
    Get.toNamed<void>(
      AppRoutes.personalInformation,
      arguments: <String, dynamic>{
        'productId': '1000460',
        PersonalInformationFlowOutcome.argumentKey: outcome,
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('personal-information-submit')));
    for (var i = 0; i < 30 && adapter.where('walleyed').isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(adapter.where('walleyed'), hasLength(1));
    expect(outcome.completed, isFalse);
    expect(find.byType(PersonalInformationPage), findsOneWidget);
  });

  testWidgets('保存个人信息后按场景 5 上报，并带上产品详情缓存的订单号', (tester) async {
    tester.view.physicalSize = const Size(375, 1107);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter();
    final reporter = _SpyReportService();
    final client = GatewayClient(
      GatewaySettings(
        signSecret: 'unit-test-secret',
        localSession: LocalSession.memory(),
      ),
      dio: Dio()..httpClientAdapter = adapter,
    );
    Get.put<GatewayClient>(client, permanent: true);
    // 产品详情流程会把 `recurs.redecorates` 写进会话缓存；场景 5 直接从那里取。
    await client.settings.localSession.cacheProductFlow(
      const ProductStepCopy(),
      orderNo: 'ORDER-1000460',
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.personalInformation,
            page: () => PersonalInformationPage(
              reporter: reporter,
              autoContinue: false,
            ),
          ),
        ],
      ),
    );
    final outcome = PersonalInformationFlowOutcome();
    Get.toNamed<void>(
      AppRoutes.personalInformation,
      arguments: <String, dynamic>{
        'productId': '1000460',
        PersonalInformationFlowOutcome.argumentKey: outcome,
      },
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('personal-information-submit')));
    for (var i = 0; i < 30 && !outcome.completed; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(adapter.where('walleyed'), hasLength(1));
    expect(outcome.completed, isTrue);
    expect(reporter.reports, hasLength(1));
    expect(reporter.reports.single.scene, '5');
    expect(reporter.reports.single.productId, '1000460');
    expect(reporter.reports.single.orderNo, 'ORDER-1000460');
  });

  testWidgets('保存工作信息后按场景 6 上报，并带上产品详情缓存的订单号', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter();
    final reporter = _SpyReportService();
    final client = GatewayClient(
      GatewaySettings(
        signSecret: 'unit-test-secret',
        localSession: LocalSession.memory(),
      ),
      dio: Dio()..httpClientAdapter = adapter,
    );
    Get.put<GatewayClient>(client, permanent: true);
    await client.settings.localSession.cacheProductFlow(
      const ProductStepCopy(),
      orderNo: 'ORDER-1000460',
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.workInformation,
            page: () =>
                WorkInformationPage(reporter: reporter, autoContinue: false),
          ),
        ],
      ),
    );
    final outcome = PersonalInformationFlowOutcome();
    Get.toNamed<void>(
      AppRoutes.workInformation,
      arguments: <String, dynamic>{
        'productId': '1000460',
        PersonalInformationFlowOutcome.argumentKey: outcome,
      },
    );
    for (var i = 0; i < 30 && adapter.where('counteract').isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    await tester.tap(find.byKey(const Key('work-information-submit')));
    for (var i = 0; i < 30 && !outcome.completed; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(adapter.where('latchstrings'), hasLength(1));
    expect(outcome.completed, isTrue);
    expect(reporter.reports, hasLength(1));
    expect(reporter.reports.single.scene, '6');
    expect(reporter.reports.single.productId, '1000460');
    expect(reporter.reports.single.orderNo, 'ORDER-1000460');
  });

  testWidgets('工作信息页加载工作接口并提交二级选项值', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter();
    Get.put<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ),
      permanent: true,
    );
    await Get.find<GatewayClient>().settings.localSession.cacheProductFlow(
      const ProductStepCopy(work: 'Use the product detail work copy'),
      orderNo: 'ORDER-1000460',
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.workInformation,
            page: () => const WorkInformationPage(autoContinue: false),
          ),
        ],
      ),
    );
    final outcome = PersonalInformationFlowOutcome();
    Get.toNamed<void>(
      AppRoutes.workInformation,
      arguments: <String, dynamic>{
        'productId': '1000460',
        PersonalInformationFlowOutcome.argumentKey: outcome,
      },
    );
    for (var i = 0; i < 30 && adapter.where('counteract').isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump();

    expect(adapter.where('counteract'), hasLength(1));
    expect(find.byType(WorkInformationPage), findsOneWidget);
    expect(find.text('Work Information'), findsOneWidget);
    expect(find.text('Use the product detail work copy'), findsWidgets);
    expect(
      find.text('Complete the filling and increase the borrowing limit'),
      findsNothing,
    );
    expect(find.text('Company Name'), findsOneWidget);
    expect(find.text('Once a Month|1'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('personal-select-opportunities')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('certification-option-4')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('certification-single-select-submit')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey<String>('certification-option-11')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('certification-single-select-submit')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Once a Month|1'), findsOneWidget);

    await tester.tap(find.byKey(const Key('work-information-submit')));
    for (var i = 0; i < 30 && !outcome.completed; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    final save = adapter.where('latchstrings').single;
    expect(save.fields['cotype'], '1000460');
    expect(save.fields['freshly'], 'SPSS');
    expect(save.fields['profit'], '7');
    expect(save.fields['opportunities'], '11');
    expect(adapter.where('walleyed'), isEmpty);
    expect(outcome.completed, isTrue);
  });

  testWidgets('个人信息页返回：请求 scene=2 的挽留弹窗', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter();
    Get.put<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ),
      permanent: true,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.personalInformation,
            page: () => const PersonalInformationPage(autoContinue: false),
          ),
        ],
      ),
    );
    Get.toNamed<void>(
      AppRoutes.personalInformation,
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
    expect(retention.fields['ulterior'], '2');
    expect(retention.fields['knife'], '1000460');

    await tester.tap(find.byKey(const Key('identity-retention-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(PersonalInformationPage), findsOneWidget);
  });

  testWidgets('个人信息页返回：挽留弹窗选择退出时回到入口页', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter();
    Get.put<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ),
      permanent: true,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.personalInformation,
            page: () => const PersonalInformationPage(autoContinue: false),
          ),
        ],
      ),
    );
    Get.toNamed<void>(
      AppRoutes.personalInformation,
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
    await _pumpUntil(
      tester,
      () => find.byType(PersonalInformationPage).evaluate().isEmpty,
    );

    expect(find.byType(PersonalInformationPage), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('工作信息页返回：请求 scene=3 的挽留弹窗', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter();
    Get.put<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ),
      permanent: true,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.workInformation,
            page: () => const WorkInformationPage(autoContinue: false),
          ),
        ],
      ),
    );
    Get.toNamed<void>(
      AppRoutes.workInformation,
      arguments: <String, dynamic>{'productId': '1000460'},
    );
    for (var i = 0; i < 30 && adapter.where('counteract').isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
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
    expect(retention.fields['ulterior'], '3');
    expect(retention.fields['knife'], '1000460');

    await tester.tap(find.byKey(const Key('identity-retention-continue')));
    await tester.pumpAndSettle();
    expect(find.byType(WorkInformationPage), findsOneWidget);
  });

  testWidgets('工作信息页返回：挽留弹窗选择退出时回到入口页', (tester) async {
    tester.view.physicalSize = const Size(375, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final adapter = _StubAdapter();
    Get.put<GatewayClient>(
      GatewayClient(
        GatewaySettings(
          signSecret: 'unit-test-secret',
          localSession: LocalSession.memory(),
        ),
        dio: Dio()..httpClientAdapter = adapter,
      ),
      permanent: true,
    );

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/stub',
        builder: EasyLoading.init(),
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/stub',
            page: () => const Scaffold(body: SizedBox()),
          ),
          GetPage<void>(
            name: AppRoutes.workInformation,
            page: () => const WorkInformationPage(autoContinue: false),
          ),
        ],
      ),
    );
    Get.toNamed<void>(
      AppRoutes.workInformation,
      arguments: <String, dynamic>{'productId': '1000460'},
    );
    for (var i = 0; i < 30 && adapter.where('counteract').isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
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
    await _pumpUntil(
      tester,
      () => find.byType(WorkInformationPage).evaluate().isEmpty,
    );

    expect(find.byType(WorkInformationPage), findsNothing);
    expect(find.byType(Scaffold), findsOneWidget);
  });
}
