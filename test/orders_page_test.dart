import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/navigation/app_route_observer.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/app/theme/app_colors.dart';
import 'package:handa_peso/core/analytics/analytics_service.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/main_shell/main_binding.dart';
import 'package:handa_peso/features/main_shell/main_controller.dart';
import 'package:handa_peso/features/orders/order_card.dart';
import 'package:handa_peso/features/orders/orders_filter_bar.dart';
import 'package:handa_peso/features/orders/orders_page.dart';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

const String _webOrigin = 'http://h5.test';

/// 订单列表的脚本化适配器：记录筛选状态码并按状态返回脚本化的响应。
class _OrdersAdapter implements HttpClientAdapter {
  _OrdersAdapter({this.bodyFor, this.bodyForPage, this.failFirst = false});

  final String Function(String status)? bodyFor;
  final String Function(String status, String page)? bodyForPage;

  /// 第一次请求返回业务失败，用于验证错误态与重试。
  bool failFirst;

  final List<String> statusCodes = <String>[];
  final List<String> pages = <String>[];
  int calls = 0;

  /// 只统计订单列表接口（`/dropcloth/pyranoside`）的调用，首页信息流不算。
  bool _isOrderList(RequestOptions options) =>
      options.uri.path.contains('pyranoside');

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    calls += 1;
    if (!_isOrderList(options)) {
      return Future<ResponseBody>.value(
        ResponseBody.fromString(
          '{"unaccepted":0,"unstably":"success","indulgences":{"latchstrings":[]}}',
          200,
          headers: _jsonHeaders,
        ),
      );
    }
    final status = '${(options.data as Map?)?['corequisites'] ?? ''}';
    final page = '${(options.data as Map?)?['girlies'] ?? ''}';
    statusCodes.add(status);
    pages.add(page);
    if (failFirst) {
      failFirst = false;
      return Future<ResponseBody>.value(
        ResponseBody.fromString(
          '{"unaccepted":-1,"unstably":"Service unavailable"}',
          200,
          headers: _jsonHeaders,
        ),
      );
    }
    final body =
        bodyForPage?.call(status, page) ??
        bodyFor?.call(status) ??
        _body(status);
    return Future<ResponseBody>.value(
      ResponseBody.fromString(body, 200, headers: _jsonHeaders),
    );
  }

  String _body(String status) {
    if (status == '5') return _settledBody();
    return _twoCardsBody();
  }

  @override
  void close({bool force = false}) {}
}

/// 只记录订单卡片的产品兜底入口，不真正发起定位和准入请求。
class _RecordingMainController extends MainController {
  _RecordingMainController({
    required super.gatewayClient,
    required super.localSession,
  });

  final List<String> appliedProductIds = <String>[];
  final List<int> appliedSources = <int>[];

  @override
  Future<void> applyNow(
    String productId, {
    bool requestLocation = true,
    int source = 0,
    bool reportApplyTap = true,
    String fallbackProductId = 'home_card',
  }) async {
    appliedProductIds.add(productId);
    appliedSources.add(source);
  }
}

/// 接口文档「订单列表」的一张卡片（字段名逐字对齐文档）。
String _card({
  required int orderId,
  required String orderNo,
  required int statusCode,
  required String statusText,
  String actionText = 'Repay Now',
  String actionTarget = '',
  String cardTarget = '',
  String productId = '1',
}) {
  return '{"prefabricating":$orderId,"redecorates":"$orderNo",'
      '"knife":"$productId","dullard":"Vplus Pro","circularise":"",'
      '"heresies":$statusCode,'
      '"frogmarched":"$statusText","luciferins":"₱60,000",'
      '"contingences":"Loan Amount","unchivalrous":"$actionText",'
      '"steelier":"","deterrently":"Loan Date","brisked":"09-10-2026",'
      '"retaped":0,"codesigned":"$cardTarget","southed":"$actionTarget",'
      '"concretion":true,"pressurising":"","quadrumvirates":""}';
}

/// 设计稿的三张卡：逾期 / 待还款（带主按钮）+ 已结清（无按钮）。
String _twoCardsBody() {
  return '{"unaccepted":0,"unstably":"success","indulgences":{"latchstrings":['
      '${_card(orderId: 1, orderNo: 'A1', statusCode: 180, statusText: 'Overdue', cardTarget: '/order/detail?orderId=1', actionTarget: '/repayment-detail?orderNo=A1&tab=1')},'
      '${_card(orderId: 2, orderNo: 'A2', statusCode: 174, statusText: 'Outstanding', cardTarget: '/order/detail?orderId=2', actionTarget: '/repayment-detail?orderNo=A2&tab=1')},'
      '${_card(orderId: 3, orderNo: 'A3', statusCode: 200, statusText: 'Settled', actionText: '')}'
      '],"cabildo":1}}';
}

String _settledBody() {
  return '{"unaccepted":0,"unstably":"success","indulgences":{"latchstrings":['
      '${_card(orderId: 3, orderNo: 'A3', statusCode: 200, statusText: 'Settled', actionText: '')}'
      '],"cabildo":1}}';
}

String _emptyBody() {
  return '{"unaccepted":0,"unstably":"success","indulgences":{"latchstrings":[],"cabildo":1}}';
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

Future<void> _pumpOrders(
  WidgetTester tester,
  GatewayClient client, {
  Size size = const Size(375, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: AppRoutes.orders,
      builder: EasyLoading.init(),
      navigatorObservers: [appRouteObserver],
      initialBinding: MainBinding(gatewayClient: client),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(name: AppRoutes.orders, page: () => const OrdersPage()),
        GetPage<void>(
          name: AppRoutes.webView,
          page: () => const _WebViewStub(),
        ),
        GetPage<void>(
          name: AppRoutes.login,
          page: () => const Scaffold(body: Center(child: Text('login'))),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

Finder _cardFinder(String orderNo) => find.byKey(Key('order-card-$orderNo'));

Finder _inCard(String orderNo, Finder matching) =>
    find.descendant(of: _cardFinder(orderNo), matching: matching);

BoxDecoration _statusDecoration(WidgetTester tester, String orderNo) {
  final container = tester.widget<Container>(
    find.byKey(Key('order-status-tag-$orderNo')),
  );
  return container.decoration! as BoxDecoration;
}

/// 静默上报出口：错误路径的用例不希望 `CrashReporter` 把异常丢给测试框架。
class _QuietSink implements TelemetrySink {
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {}

  @override
  void setUserId(String? userId) {}

  @override
  void setUserProperty(String name, String? value) {}
}

void main() {
  setUp(() {
    Get.reset();
    AnalyticsService.configure(_QuietSink());
  });
  tearDown(Get.reset);

  group('订单列表', () {
    testWidgets('按设计稿渲染：标题 / 筛选条 347x50 @ 98 / 首卡 @ 168', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await _pumpOrders(tester, _client(config, _OrdersAdapter()));

      expect(find.text('Loan List'), findsOneWidget);
      expect(
        tester.getSize(find.byType(OrdersFilterBar)),
        const Size(OrdersFilterBar.width, OrdersFilterBar.height),
      );
      expect(
        tester.getTopLeft(find.byType(OrdersFilterBar)),
        const Offset(14, 98),
      );
      expect(_cardFinder('A1'), findsOneWidget);
      expect(tester.getTopLeft(_cardFinder('A1')), const Offset(14, 168));
      expect(
        tester.getSize(_cardFinder('A1')),
        const Size(OrderCard.width, 158),
      );
      // 终态卡没有主按钮，设计稿上是 112（比带按钮的卡矮 46），这里按内部
      // 留白推出来是 111——设计稿两档本身差 1px，实现取边框内的整数留白。
      expect(
        tester.getSize(_cardFinder('A3')),
        const Size(OrderCard.width, 111),
      );

      // 状态文案与筛选条标签同名，断言到卡片内部。
      expect(_inCard('A1', find.text('Overdue')), findsOneWidget);
      expect(_inCard('A2', find.text('Outstanding')), findsOneWidget);
      expect(_inCard('A3', find.text('Settled')), findsOneWidget);
      expect(find.text('₱60,000'), findsNWidgets(3));
      expect(find.text('09-10-2026'), findsNWidgets(3));
      expect(find.text('Loan Amount'), findsNWidgets(3));
      expect(find.text('Repay Now'), findsNWidgets(2));
    });

    testWidgets('状态文案取服务端值，仅 174 和 180 展示按钮与红色标签', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final cards = <String>[
        _card(
          orderId: 1,
          orderNo: 'A1',
          statusCode: 174,
          statusText: 'Outstanding from server',
        ),
        _card(
          orderId: 2,
          orderNo: 'A2',
          statusCode: 180,
          statusText: 'Overdue from server',
        ),
        _card(
          orderId: 3,
          orderNo: 'A3',
          statusCode: 200,
          statusText: 'Settled from server',
          actionText: 'Review',
        ),
        _card(
          orderId: 4,
          orderNo: 'A4',
          statusCode: 999,
          statusText: 'Rejected from server',
          actionText: 'View',
        ),
      ];
      final body =
          '{"unaccepted":0,"unstably":"success","indulgences":'
          '{"latchstrings":[${cards.join(',')}],"cabildo":1}}';
      await _pumpOrders(
        tester,
        _client(config, _OrdersAdapter(bodyFor: (_) => body)),
      );

      expect(find.text('Outstanding from server'), findsOneWidget);
      expect(find.text('Overdue from server'), findsOneWidget);
      expect(find.text('Settled from server'), findsOneWidget);
      expect(find.text('Rejected from server'), findsOneWidget);
      expect(find.byKey(const Key('order-action-A1')), findsOneWidget);
      expect(find.byKey(const Key('order-action-A2')), findsOneWidget);
      expect(find.byKey(const Key('order-action-A3')), findsNothing);
      expect(find.byKey(const Key('order-action-A4')), findsNothing);

      final outstanding = _statusDecoration(tester, 'A1');
      final overdue = _statusDecoration(tester, 'A2');
      final settled = _statusDecoration(tester, 'A3');
      final rejected = _statusDecoration(tester, 'A4');
      expect(
        (outstanding.gradient! as LinearGradient).colors,
        AppColors.ordersStatusDangerGradient.colors,
      );
      expect(
        (overdue.gradient! as LinearGradient).colors,
        AppColors.ordersStatusDangerGradient.colors,
      );
      expect(settled.color, AppColors.ordersStatusNeutralSurface);
      expect(settled.gradient, isNull);
      expect(rejected.color, AppColors.ordersStatusNeutralSurface);
      expect(rejected.gradient, isNull);
    });

    testWidgets('窄屏下状态文案保持最小 12 号字并在超宽时省略', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final card = _card(
        orderId: 1,
        orderNo: 'A1',
        statusCode: 180,
        statusText: 'Outstanding balance overdue',
      );
      final body =
          '{"unaccepted":0,"unstably":"success","indulgences":'
          '{"latchstrings":[$card],"cabildo":1}}';
      final adapter = _OrdersAdapter(bodyFor: (_) => body);
      await _pumpOrders(
        tester,
        _client(config, adapter),
        size: const Size(320, 900),
      );

      final statusFinder = find.byKey(const Key('order-status-A1'));
      final status = tester.widget<Text>(statusFinder);

      expect(status.style?.fontSize, OrderCard.statusLabelSize);
      expect(status.overflow, TextOverflow.ellipsis);
      expect(
        find.ancestor(of: statusFinder, matching: find.byType(FittedBox)),
        findsNothing,
      );
    });

    testWidgets('切换筛选按对应状态码重新请求', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _OrdersAdapter();
      await _pumpOrders(tester, _client(config, adapter));
      expect(adapter.statusCodes, <String>['4']);

      await tester.tap(find.byKey(const Key('orders-filter-settled')));
      await tester.pumpAndSettle();

      expect(adapter.statusCodes, <String>['4', '5']);
      expect(_cardFinder('A3'), findsOneWidget);
      expect(_cardFinder('A1'), findsNothing);
      expect(find.text('Repay Now'), findsNothing);
    });

    testWidgets('空列表展示设计稿插画', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await _pumpOrders(
        tester,
        _client(config, _OrdersAdapter(bodyFor: (status) => _emptyBody())),
      );

      expect(
        find.byKey(const Key('orders-empty-illustration')),
        findsOneWidget,
      );
      expect(find.byType(OrderCard), findsNothing);
    });

    testWidgets('请求失败给出重试，重试后恢复列表', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _OrdersAdapter(failFirst: true);
      await _pumpOrders(tester, _client(config, adapter));

      expect(find.text('Service unavailable'), findsOneWidget);
      expect(find.byType(OrderCard), findsNothing);

      await tester.tap(find.byKey(const Key('orders-retry')));
      await tester.pumpAndSettle();

      expect(adapter.statusCodes.length, 2);
      expect(_cardFinder('A1'), findsOneWidget);
    });

    testWidgets('未登录时先要求登录，不请求订单', (tester) async {
      final config = _config();
      final adapter = _OrdersAdapter();
      await _pumpOrders(tester, _client(config, adapter));

      expect(find.byKey(const Key('orders-sign-in')), findsOneWidget);
      expect(adapter.statusCodes, isEmpty);
    });

    testWidgets('卡片进订单详情、按钮进还款页，都用服务端下发的地址', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _OrdersAdapter();
      await _pumpOrders(tester, _client(config, adapter));
      expect(adapter.statusCodes, <String>['4']);

      await tester.tap(find.byKey(const Key('order-action-A1')));
      await tester.pumpAndSettle();
      expect(
        find.text('webview:$_webOrigin/repayment-detail?orderNo=A1&tab=1'),
        findsOneWidget,
      );

      Get.back<void>();
      await tester.pumpAndSettle();
      expect(adapter.statusCodes, <String>['4', '4']);

      await tester.tap(_cardFinder('A2'));
      await tester.pumpAndSettle();
      expect(
        find.text('webview:$_webOrigin/order/detail?orderId=2'),
        findsOneWidget,
      );
    });

    testWidgets('卡片没有下发地址时用产品 ID 继续申请流程', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final card = _card(
        orderId: 1,
        orderNo: 'A1',
        statusCode: 200,
        statusText: 'Settled',
        actionText: '',
        productId: '88',
      );
      final body =
          '{"unaccepted":0,"unstably":"success","indulgences":'
          '{"latchstrings":[$card],"cabildo":1}}';
      final client = _client(config, _OrdersAdapter(bodyFor: (_) => body));
      final controller = _RecordingMainController(
        gatewayClient: client,
        localSession: config.localSession,
      );
      Get.put<MainController>(controller);

      await _pumpOrders(tester, client);
      await tester.tap(_cardFinder('A1'));
      await tester.pumpAndSettle();

      expect(controller.appliedProductIds, <String>['88']);
      expect(controller.appliedSources, <int>[8]);
    });

    testWidgets('滚动到底部按 cabildo 继续加载后续页', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _OrdersAdapter(
        bodyForPage: (status, page) {
          final cards = page == '2'
              ? <String>[
                  _card(
                    orderId: 5,
                    orderNo: 'A5',
                    statusCode: 200,
                    statusText: 'Settled',
                    actionText: '',
                  ),
                ]
              : <String>[
                  for (var index = 1; index <= 4; index++)
                    _card(
                      orderId: index,
                      orderNo: 'A$index',
                      statusCode: 200,
                      statusText: 'Settled',
                      actionText: '',
                    ),
                ];
          return '{"unaccepted":0,"unstably":"success","indulgences":'
              '{"latchstrings":[${cards.join(',')}],"cabildo":2}}';
        },
      );
      await _pumpOrders(
        tester,
        _client(config, adapter),
        size: const Size(375, 600),
      );

      expect(adapter.pages, <String>['1']);
      expect(_cardFinder('A1'), findsOneWidget);
      expect(_cardFinder('A5'), findsNothing);

      await tester.fling(find.byType(ListView), const Offset(0, -900), 2000);
      await tester.pumpAndSettle();

      expect(adapter.pages, <String>['1', '2']);
      expect(_cardFinder('A5'), findsOneWidget);
    });
  });
}
