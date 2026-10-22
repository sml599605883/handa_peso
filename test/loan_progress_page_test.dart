import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/navigation/app_route_observer.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/app/widgets/app_empty_state.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/permissions/permission_coordinator.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/loan_progress/loan_progress_card.dart';
import 'package:handa_peso/features/loan_progress/loan_progress_item.dart';
import 'package:handa_peso/features/main_shell/main_binding.dart';
import 'package:handa_peso/features/main_shell/main_controller.dart';
import 'package:handa_peso/features/main_shell/main_shell_page.dart';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

const String _webOrigin = 'http://h5.test';

/// 记录请求的脚本化适配器：按 URL 统计首页（含进度卡片）接口的调用次数。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<String> urls = <String>[];

  int get homeCalls => urls.where((url) => url.contains('indulgences')).length;

  /// 准入接口（`/dropcloth/legongs`，文档「点击申请」）的调用次数。
  int get applyCalls => urls.where((url) => url.contains('legongs')).length;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    urls.add(options.uri.toString());
    return handler(options);
  }

  @override
  void close({bool force = false}) {}
}

/// 内置 WebView 的替身：把拿到的地址渲染出来，便于断言跳转目标。
class _WebViewStub extends StatelessWidget {
  const _WebViewStub();

  @override
  Widget build(BuildContext context) {
    final arguments = Get.arguments;
    final url = arguments is Map ? '${arguments['url']}' : '';
    return Scaffold(body: Center(child: Text('webview:$url')));
  }
}

/// 一张进度卡片：字段名与接口文档「APP首页 → PROCESS_LIST」一致。
Map<String, dynamic> _progressCard({
  required String orderNo,
  required int status,
  required String statusLabel,
  String productName = 'Handa Peso',
  String amount = '₱60,000',
  String amountLabel = 'Loan Amount',
  String date = '09-10-2026',
  String dateLabel = 'Loan Date',
  String detailRoute = '',
  List<Map<String, dynamic>> actions = const <Map<String, dynamic>>[],
}) {
  return <String, dynamic>{
    'eelworm': orderNo,
    'cotype': 2,
    'facetiae': productName,
    'pottiest': '',
    'canonic': '',
    'luciferins': 60000,
    'outwaits': amountLabel,
    'predicating': date,
    'mispainted': dateLabel,
    'calipash': '',
    'narrating': '',
    'simplicia': 21,
    'compacts': status,
    'whinger': amount,
    'sandglasses': statusLabel,
    'unglove': '',
    'microfarads': <Map<String, dynamic>>[],
    'tidewaters': detailRoute,
    'nearsighted': actions,
  };
}

Map<String, dynamic> _action({
  required String type,
  required String label,
  int pump = 1,
  String route = '',
}) {
  return <String, dynamic>{
    'trollopy': type,
    'pump': pump,
    'philtring': label,
    'schoolteacher': '',
    'cheekiness': route,
  };
}

String _body(List<Map<String, dynamic>> progress) {
  return jsonEncode(<String, dynamic>{
    'unaccepted': 0,
    'unstably': 'success',
    'indulgences': <String, dynamic>{
      'latchstrings': <Map<String, dynamic>>[
        <String, dynamic>{'trollopy': 'PeriplasmAddition', 'ranulas': progress},
      ],
    },
  });
}

/// 与设计稿 02- 贷款-订单进度 一一对应的六张卡片。
List<Map<String, dynamic>> _designCards() {
  return <Map<String, dynamic>>[
    _progressCard(
      orderNo: 'A1',
      status: 6,
      statusLabel: 'Funding Failed',
      detailRoute: '/#/FiggingJuncture?orderId=1',
      actions: <Map<String, dynamic>>[_action(type: 'change', label: 'Change')],
    ),
    _progressCard(
      orderNo: 'A2',
      status: 5,
      statusLabel: 'Funding Failed',
      detailRoute: '/#/FiggingJuncture?orderId=2',
      actions: <Map<String, dynamic>>[
        _action(type: 'retry', label: 'Try Again'),
        _action(type: 'change', label: 'Change'),
      ],
    ),
    _progressCard(
      orderNo: 'A3',
      status: 1,
      statusLabel: 'In Review',
      detailRoute: '/#/FiggingJuncture?orderId=3',
    ),
    _progressCard(
      orderNo: 'A4',
      status: 4,
      statusLabel: 'Releasing Funds',
      detailRoute: '/#/FiggingJuncture?orderId=4',
    ),
    _progressCard(
      orderNo: 'A5',
      status: 2,
      statusLabel: 'Pending Payment',
      amountLabel: 'Repayment',
      detailRoute: '/#/FiggingJuncture?orderId=5',
      actions: <Map<String, dynamic>>[
        _action(
          type: 'repay',
          label: 'Repay',
          route: '/repayment-detail?orderNo=A5&tab=1',
        ),
      ],
    ),
    _progressCard(
      orderNo: 'A6',
      status: 3,
      statusLabel: 'Past Due',
      detailRoute: '/#/FiggingJuncture?orderId=6',
      actions: <Map<String, dynamic>>[
        _action(
          type: 'early_repay',
          label: 'Early Repay',
          route: '/repayment-detail?orderNo=A6&tab=2',
        ),
      ],
    ),
  ];
}

/// 组装准入通过且有跳转地址的信封；字段名与接口文档「点击申请」一致。
String _applyBody({required String target}) {
  return jsonEncode(<String, dynamic>{
    'unaccepted': 0,
    'unstably': 'success',
    'indulgences': <String, dynamic>{
      'murdering': 200,
      'tidewaters': target,
      'trollopy': 1,
      'bioscope': 'success',
    },
  });
}

GatewaySettings _config() {
  return GatewaySettings(
    apiOrigin: 'http://home.test',
    webOrigin: _webOrigin,
    signSecret: 'unit-test-secret',
    localSession: LocalSession.memory(),
    clock: () => 1700000000000,
    noiseDigits: (length) => '1' * length,
  );
}

GatewayClient _client(GatewaySettings config, HttpClientAdapter adapter) {
  return GatewayClient(config, dio: Dio()..httpClientAdapter = adapter);
}

/// 定位授权的替身：申请前的定位准入不能真去打系统弹窗。
class _StubPermissions extends PermissionCoordinator {
  int requests = 0;

  @override
  Future<LocationAccessDecision> requestLocationAccess() async {
    requests += 1;
    return LocationAccessDecision.granted;
  }
}

/// 以登录态启动外壳并切到 Loan Tab（进度数据在 Tab 可见时才请求）。
///
/// 进度页按宽度等比缩放，因此加高视口不会改变卡片几何，只会让更多卡片进入
/// 渲染范围。
Future<void> _pumpLoanTab(
  WidgetTester tester,
  GatewayClient client, {
  bool settle = true,
  double height = 1400,
  PermissionCoordinator? permissions,
}) async {
  tester.view.physicalSize = Size(375, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: AppRoutes.main,
      builder: EasyLoading.init(),
      navigatorObservers: <NavigatorObserver>[appRouteObserver],
      initialBinding: MainBinding(
        gatewayClient: client,
        // 申请前的定位准入默认放行，个别用例自己传替身。
        permissionCoordinator: permissions ?? _StubPermissions(),
      ),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(name: AppRoutes.main, page: () => const MainShellPage()),
        GetPage<void>(
          name: AppRoutes.webView,
          page: () => const _WebViewStub(),
        ),
        GetPage<void>(
          name: AppRoutes.login,
          page: () => const Scaffold(body: Center(child: Text('login'))),
        ),
        GetPage<void>(
          name: AppRoutes.certification,
          page: () =>
              const Scaffold(body: Center(child: Text('certification'))),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('tab-loan')));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }
}

Finder _card(String orderNo) =>
    find.byKey(ValueKey<String>('loan-progress-$orderNo'));

Finder _actionButton(String orderNo, String type) => find.descendant(
  of: _card(orderNo),
  matching: find.byKey(ValueKey<String>('loan-progress-action-$type')),
);

void main() {
  setUp(() => Get.reset());
  tearDown(() {
    if (Get.isRegistered<MainController>()) {
      Get.delete<MainController>(force: true);
    }
    Get.reset();
  });

  group('借款进度列表', () {
    testWidgets('切到 Loan Tab 才刷新并渲染六张进度卡片', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      // 首次进入首页一次、切到 Loan Tab 再补一次：进度卡片与首页共用同一条
      // 信息流接口。
      expect(adapter.homeCalls, 2);
      expect(find.byType(LoanProgressCard), findsNWidgets(6));
      expect(find.text('Funding Failed'), findsNWidgets(2));
      expect(find.text('In Review'), findsOneWidget);
      expect(find.text('Releasing Funds'), findsOneWidget);
      expect(find.text('Pending Payment'), findsOneWidget);
      expect(find.text('Past Due'), findsOneWidget);
      expect(find.text('09-10-2026'), findsNWidgets(6));
      expect(find.text('₱60,000'), findsNWidgets(6));
      expect(find.text('Repayment'), findsOneWidget);
    });

    testWidgets('卡片几何按设计稿：宽 347、间距 20，有按钮 174 / 无按钮 128', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      final first = tester.getRect(_card('A1'));
      expect(first.left, closeTo(14, 0.01));
      expect(first.width, closeTo(347, 0.01));
      expect(first.height, closeTo(174, 0.01));
      // 首张卡片本体落在设计稿的 102（徽标向上悬挑 6）。
      expect(first.top, closeTo(102, 0.01));

      final second = tester.getRect(_card('A2'));
      expect(second.top - first.bottom, closeTo(20, 0.01));

      // 审核中 / 放款中不下发按钮：卡片矮 46。
      final idle = tester.getRect(_card('A3'));
      expect(idle.height, closeTo(128, 0.01));
      expect(idle.top - second.bottom, closeTo(20, 0.01));

      final fourth = tester.getRect(_card('A4'));
      expect(fourth.top - idle.bottom, closeTo(20, 0.01));
      expect(fourth.height, closeTo(128, 0.01));
      final fifth = tester.getRect(_card('A5'));
      expect(fifth.top - fourth.bottom, closeTo(20, 0.01));
      expect(fifth.height, closeTo(174, 0.01));
    });

    testWidgets('按钮取自网关文案，两枚并排、单枚居中', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      final card = tester.getRect(_card('A2'));
      final retry = tester.getRect(_actionButton('A2', 'retry'));
      final change = tester.getRect(_actionButton('A2', 'change'));
      expect(
        find.descendant(of: _card('A2'), matching: find.text('Try Again')),
        findsOneWidget,
      );
      expect(retry.left, closeTo(card.left + 28, 0.01));
      expect(retry.width, closeTo(136, 0.01));
      expect(retry.height, closeTo(32, 0.01));
      expect(change.left, closeTo(card.left + 28 + 136 + 19, 0.01));

      final singleCard = tester.getRect(_card('A1'));
      final single = tester.getRect(_actionButton('A1', 'change'));
      expect(single.left, closeTo(singleCard.left + (347 - 136) / 2, 0.01));
    });

    testWidgets('卡片铺设计稿导出的票券分隔带与按钮切片', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      List<String> assetsOf(String orderNo) => tester
          .widgetList<Image>(
            find.descendant(of: _card(orderNo), matching: find.byType(Image)),
          )
          .map((image) => (image.image as AssetImage).assetName)
          .toList();

      for (final orderNo in <String>['A1', 'A2', 'A3', 'A4', 'A5', 'A6']) {
        expect(
          assetsOf(orderNo),
          contains('assets/loan_progress_card_divider.png'),
          reason: '$orderNo 的票券分隔带',
        );
      }
      // 一枚按钮（原卡重试 / 还款）用主色切片，两枚时左位按钮用灰色切片。
      expect(
        assetsOf('A1'),
        contains('assets/loan_progress_action_primary.png'),
      );
      expect(
        assetsOf('A1'),
        isNot(contains('assets/loan_progress_action_muted.png')),
      );
      expect(
        assetsOf('A2'),
        containsAll(<String>[
          'assets/loan_progress_action_muted.png',
          'assets/loan_progress_action_primary.png',
        ]),
      );
      expect(
        assetsOf('A3'),
        isNot(contains('assets/loan_progress_action_primary.png')),
      );
    });

    testWidgets('徽标按状态码取深棕 / 红色切片', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      Iterable<String> imagesOf(String orderNo) => tester
          .widgetList<Image>(
            find.descendant(of: _card(orderNo), matching: find.byType(Image)),
          )
          .map((image) => (image.image as AssetImage).assetName);

      String shapeOf(String orderNo) =>
          imagesOf(orderNo).singleWhere((name) => name.contains('status'));

      expect(shapeOf('A3'), 'assets/loan_progress_status_dark.png');
      expect(shapeOf('A2'), 'assets/loan_progress_status_dark.png');
      expect(shapeOf('A5'), 'assets/loan_progress_status_alert.png');
      expect(shapeOf('A6'), 'assets/loan_progress_status_alert.png');
    });

    testWidgets('点击卡片打开网关下发的订单详情地址', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      await tester.tapAt(tester.getCenter(_card('A3')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.webView);
      expect(
        find.textContaining('/#/FiggingJuncture?orderId=3'),
        findsOneWidget,
      );
      expect(
        find.textContaining('$_webOrigin/#/FiggingJuncture'),
        findsOneWidget,
      );
    });

    testWidgets('右上角客服入口进入客服 WebView', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(const <Map<String, dynamic>>[]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      await tester.tap(find.byKey(const Key('loan-customer-service')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.webView);
      expect(find.text('webview:$_webOrigin/#/Toolcutting'), findsOneWidget);
    });

    testWidgets('带跳转地址的按钮直接打开还款页', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      await tester.tap(
        find.descendant(of: _card('A5'), matching: find.text('Repay')),
      );
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.webView);
      expect(
        find.text('webview:$_webOrigin/repayment-detail?orderNo=A5&tab=1'),
        findsOneWidget,
      );
    });

    testWidgets('不下发地址的按钮（Try Again / Change）落到订单详情页', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      await tester.tap(
        find.descendant(of: _card('A2'), matching: find.text('Try Again')),
      );
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.webView);
      expect(find.textContaining('orderId=2'), findsOneWidget);
    });

    testWidgets('没有订单详情地址时回到产品申请流程', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter((options) async {
        // 没有详情地址时卡片回到产品申请流程：与大小卡一样先走准入接口，
        // 再按服务端下发的地址跳转。
        if (options.uri.toString().contains('legongs')) {
          return ResponseBody.fromString(
            _applyBody(target: 'http://example.test/admission'),
            200,
            headers: _jsonHeaders,
          );
        }
        return ResponseBody.fromString(
          _body(<Map<String, dynamic>>[
            _progressCard(
              orderNo: 'B1',
              status: 1,
              statusLabel: 'In Review',
              actions: <Map<String, dynamic>>[
                _action(type: 'change', label: 'Change'),
              ],
            ),
          ]),
          200,
          headers: _jsonHeaders,
        );
      });
      await _pumpLoanTab(tester, _client(config, adapter));

      await tester.tap(
        find.descendant(of: _card('B1'), matching: find.text('Change')),
      );
      await tester.pumpAndSettle();

      expect(adapter.applyCalls, 1);
      expect(Get.currentRoute, AppRoutes.webView);
      expect(
        find.text('webview:http://example.test/admission'),
        findsOneWidget,
      );
    });

    testWidgets('游客进入 Loan Tab 仍走登录门禁，不发进度请求', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(_config(), adapter));

      expect(Get.currentRoute, AppRoutes.login);
      expect(find.byType(LoanProgressCard), findsNothing);
      expect(adapter.homeCalls, 1);
    });
  });

  group('借款进度状态', () {
    testWidgets('进度为空时展示 Apply Now，点击回到首页 Tab', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _body(const <Map<String, dynamic>>[]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      expect(find.byType(LoanProgressCard), findsNothing);
      expect(find.byKey(const Key('loan-progress-apply')), findsOneWidget);
      expect(find.text('Apply Now'), findsOneWidget);
      // 设计稿：按钮 220x40，落在 y=398、水平居中。
      final button = tester.getRect(
        find.byKey(const Key('loan-progress-apply')),
      );
      expect(button.width, closeTo(220, 0.01));
      expect(button.height, closeTo(40, 0.01));
      expect(button.top, closeTo(398, 0.01));
      expect(button.left, closeTo((375 - 220) / 2, 0.01));

      // 设计稿：纸飞机插画 200x200，水平居中，上沿在按钮上方 224（200 + 24）。
      final illustrationFinder = find.byKey(
        const Key('loan-progress-empty-illustration'),
      );
      final illustration = tester.getRect(illustrationFinder);
      expect(illustration.width, closeTo(200, 0.01));
      expect(illustration.height, closeTo(200, 0.01));
      expect(illustration.left, closeTo((375 - 200) / 2, 0.01));
      expect(illustration.bottom, closeTo(398 - 24, 0.01));
      expect(
        (tester.widget<Image>(illustrationFinder).image as AssetImage)
            .assetName,
        'assets/loan_progress_empty_illustration.png',
      );

      await tester.tap(find.byKey(const Key('loan-progress-apply')));
      await tester.pumpAndSettle();

      expect(Get.find<MainController>().activeTab.value, 0);
    });

    testWidgets('接口失败时展示可重试的错误态', (tester) async {
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString('boom', 500),
      );
      await _pumpLoanTab(tester, _client(config, adapter));

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.byKey(const Key('loan-progress-retry')), findsOneWidget);
      expect(reported, isNotEmpty);
    });

    testWidgets('数据未返回时展示 loading', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final completer = Completer<ResponseBody>();
      var homeCalls = 0;
      final adapter = _StubAdapter((options) {
        if (options.uri.toString().contains('counterchecked')) {
          return Future<ResponseBody>.value(
            ResponseBody.fromString(
              _body(const <Map<String, dynamic>>[]),
              200,
              headers: _jsonHeaders,
            ),
          );
        }
        // 首次进入首页的请求立即返回，切到 Loan Tab 的那次一直挂起。
        homeCalls += 1;
        if (homeCalls == 1) {
          return Future<ResponseBody>.value(
            ResponseBody.fromString(
              _body(const <Map<String, dynamic>>[]),
              200,
              headers: _jsonHeaders,
            ),
          );
        }
        return completer.future;
      });
      await _pumpLoanTab(tester, _client(config, adapter), settle: false);

      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        ResponseBody.fromString(
          _body(_designCards()),
          200,
          headers: _jsonHeaders,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(LoanProgressCard), findsNWidgets(6));
    });
  });

  group('进度卡片解析', () {
    test('按接口文档字段解析，并过滤掉不展示的按钮', () {
      final item = LoanProgressItem.fromJson(<String, dynamic>{
        'eelworm': '39236372837263237',
        'cotype': 1,
        'facetiae': 'Pera Agad(AA)',
        'pottiest': 'https://example.test/logo.png',
        'outwaits': 'Loan Amount',
        'predicating': '28-12-2022',
        'mispainted': 'Application date',
        'simplicia': 21,
        'compacts': 2,
        'whinger': '₱50,000',
        'sandglasses': '待还款',
        'tidewaters': 'hsjdh://jhdkshdks',
        'nearsighted': <Map<String, dynamic>>[
          <String, dynamic>{
            'trollopy': 'retry',
            'pump': 1,
            'philtring': 'Retry Original Account',
            'schoolteacher': '',
            'cheekiness': '',
          },
          <String, dynamic>{
            'trollopy': 'repay',
            'pump': 0,
            'philtring': 'Repay',
            'schoolteacher': '',
            'cheekiness': '/repayment-detail?orderNo=1&tab=1',
          },
        ],
      });

      expect(item.orderNo, '39236372837263237');
      expect(item.productId, '1');
      expect(item.productName, 'Pera Agad(AA)');
      expect(item.status, LoanProgressStatus.pendingPayment);
      expect(item.status.isAlert, isTrue);
      expect(item.statusLabel, '待还款');
      expect(item.dateLabel, 'Application date');
      expect(item.date, '28-12-2022');
      expect(item.amountLabel, 'Loan Amount');
      expect(item.amount, '₱50,000');
      expect(item.detailRoute, 'hsjdh://jhdkshdks');
      // `pump` 为 0 的按钮是历史配置，不参与渲染。
      expect(item.actions, hasLength(1));
      expect(item.visibleActions.single.label, 'Retry Original Account');
      expect(item.visibleActions.single.isRetry, isTrue);
    });

    test('最多保留两枚按钮，避免卡片被撑破', () {
      final item = LoanProgressItem.fromJson(<String, dynamic>{
        'compacts': 6,
        'nearsighted': <Map<String, dynamic>>[
          for (final label in <String>['A', 'B', 'C', 'D'])
            <String, dynamic>{
              'trollopy': 'change',
              'pump': 1,
              'philtring': label,
            },
        ],
      });

      expect(item.visibleActions.map((action) => action.label), <String>[
        'A',
        'B',
      ]);
    });

    test('徽标配色由状态码决定，而不是文案', () {
      expect(LoanProgressStatus.fromCode(3).isAlert, isTrue);
      expect(LoanProgressStatus.fromCode(1).isAlert, isFalse);
      expect(LoanProgressStatus.fromCode(99), LoanProgressStatus.unknown);
    });
  });
}
