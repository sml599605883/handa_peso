import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/navigation/app_route_observer.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/app/theme/app_colors.dart';
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/main_shell/main_binding.dart';
import 'package:handa_peso/features/main_shell/main_controller.dart';
import 'package:handa_peso/features/main_shell/main_shell_page.dart';
import 'package:handa_peso/features/mine/mine_header_card.dart';
import 'package:handa_peso/features/mine/mine_order_entries.dart';
import 'package:handa_peso/features/mine/mine_page.dart';
import 'package:handa_peso/features/mine/mine_service_section.dart';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

/// 记录请求的脚本化适配器：首页信息流返回空模块，订单列表返回一张卡片。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter();

  final List<RequestOptions> requests = <RequestOptions>[];

  List<String> get urls =>
      requests.map((request) => request.uri.toString()).toList(growable: false);

  /// 订单列表请求（`/dropcloth/pyranoside`）带上的筛选状态码。
  List<String> get orderStatusCodes => requests
      .where((request) => request.uri.path.contains('pyranoside'))
      .map((request) => '${(request.data as Map?)?['corequisites'] ?? ''}')
      .toList(growable: false);

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) {
    requests.add(options);
    return Future<ResponseBody>.value(
      ResponseBody.fromString(_bodyFor(options), 200, headers: _jsonHeaders),
    );
  }

  String _bodyFor(RequestOptions options) {
    if (options.uri.path.contains('pyranoside')) {
      return _orderListBody();
    }
    return _emptyHomeBody();
  }

  @override
  void close({bool force = false}) {}
}

String _emptyHomeBody() {
  return '{"unaccepted":0,"unstably":"success","indulgences":{"latchstrings":[]}}';
}

/// 一张带主按钮的订单卡片，字段名与接口文档「订单列表」一致。
String _orderListBody() {
  return '{"unaccepted":0,"unstably":"success","indulgences":{"latchstrings":['
      '{"prefabricating":4,"redecorates":"672024120400405591971039",'
      '"knife":1,"dullard":"Vplus Pro","circularise":"",'
      '"heresies":21,"frogmarched":"Outstanding",'
      '"luciferins":"₱60,000","contingences":"Loan Amount",'
      '"unchivalrous":"Repay Now","steelier":"",'
      '"deterrently":"Loan Date","brisked":"09-10-2026","retaped":0,'
      '"codesigned":"/order/detail?orderId=4",'
      '"southed":"/repayment-detail?orderNo=4&tab=1",'
      '"concretion":true,"pressurising":"","quadrumvirates":""}'
      '],"cabildo":1}}';
}

GatewaySettings _config() {
  return GatewaySettings(
    apiOrigin: 'http://home.test',
    webOrigin: 'http://h5.test',
    signSecret: 'unit-test-secret',
    localSession: LocalSession.memory(),
    clock: () => 1700000000000,
    noiseDigits: (length) => '1' * length,
  );
}

GatewayClient _client(GatewaySettings config, HttpClientAdapter adapter) {
  return GatewayClient(config, dio: Dio()..httpClientAdapter = adapter);
}

/// 订单列表的替身：把拿到的筛选参数渲染出来，便于断言入口传对了状态码。
class _OrdersProbe extends StatelessWidget {
  const _OrdersProbe();

  @override
  Widget build(BuildContext context) {
    final arguments = Get.arguments;
    final status = arguments is Map ? '${arguments['status']}' : '';
    return Scaffold(body: Center(child: Text('orders:$status')));
  }
}

/// 以登录态启动外壳并切到 Mine Tab。
Future<void> _pumpMineTab(WidgetTester tester, GatewayClient client) async {
  tester.view.physicalSize = const Size(375, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: AppRoutes.main,
      builder: EasyLoading.init(),
      navigatorObservers: <NavigatorObserver>[appRouteObserver],
      initialBinding: MainBinding(gatewayClient: client),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(name: AppRoutes.main, page: () => const MainShellPage()),
        GetPage<void>(name: AppRoutes.orders, page: () => const _OrdersProbe()),
      ],
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('tab-mine')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => Get.reset());
  tearDown(() {
    if (Get.isRegistered<MainController>()) {
      Get.delete<MainController>(force: true);
    }
    Get.reset();
  });

  group('个人中心', () {
    testWidgets('头部按设计稿坐标：标题 58、卡片 347x126 @ 98、头像 86', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await config.localSession.writePhone('9621231210');
      await _pumpMineTab(tester, _client(config, _StubAdapter()));

      // 标题与底部 Tab 的文案同名，因此这里数到两个。
      expect(find.text('Mine'), findsNWidgets(2));
      expect(find.text('962****1210'), findsOneWidget);
      expect(find.text(MineHeaderCard.userIdLabel), findsOneWidget);
      expect(find.byKey(const Key('mine-avatar')), findsOneWidget);

      final header = tester.widget<MineHeaderCard>(find.byType(MineHeaderCard));
      expect(header.scale, 1);
      expect(
        tester.getSize(find.byType(MineHeaderCard)),
        const Size(MineHeaderCard.width, MineHeaderCard.height),
      );
      expect(
        tester.getTopLeft(find.byType(MineHeaderCard)),
        const Offset(14, 98),
      );
      expect(
        tester.getSize(find.byKey(const Key('mine-avatar'))),
        const Size(MineHeaderCard.avatarSize, MineHeaderCard.avatarSize),
      );
    });

    testWidgets('三个订单入口等宽、图标 66，点 Outstanding 带状态码进订单列表', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await config.localSession.writePhone('9621231210');
      final adapter = _StubAdapter();
      await _pumpMineTab(tester, _client(config, adapter));

      expect(find.byType(MineOrderEntries), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MineOrderEntries)),
        const Offset(0, 244),
      );
      expect(
        tester.getSize(find.byType(MineOrderEntries)),
        const Size(375, 96),
      );
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Outstanding'), findsOneWidget);
      expect(find.text('Settled'), findsOneWidget);

      await tester.tap(find.byKey(const Key('mine-order-entry-outstanding')));
      await tester.pumpAndSettle();

      expect(find.byType(_OrdersProbe), findsOneWidget);
      expect(find.text('orders:7'), findsOneWidget);
    });

    testWidgets('服务菜单三行 52 高、间距 14，账号行进账号页', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await _pumpMineTab(tester, _client(config, _StubAdapter()));

      expect(find.text(MineServiceSection.title), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(MineServiceSection)),
        const Offset(14, 364),
      );
      expect(
        tester.getSize(find.byType(MineServiceSection)),
        const Size(MineServiceSection.width, 218),
      );
      expect(find.text('Customer service'), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const Key('mine-service-customer-service'))),
        const Size(347, MineServiceSection.rowHeight),
      );

      final firstRow = tester.getTopLeft(
        find.byKey(const Key('mine-service-customer-service')),
      );
      final secondRow = tester.getTopLeft(
        find.byKey(const Key('mine-service-privacy')),
      );
      expect(
        secondRow.dy - firstRow.dy,
        MineServiceSection.rowHeight + MineServiceSection.rowGap,
      );
    });

    testWidgets('短号不脱敏、长号保留前 3 后 4', (tester) async {
      expect(maskPhone(''), '');
      expect(maskPhone('1234567'), '1234567');
      expect(maskPhone('9621231210'), '962****1210');
      expect(maskPhone(' 639171234567 '), '639****4567');
    });

    testWidgets('内容下方的白底铺满整个 Tab，不露出外层底色', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await _pumpMineTab(tester, _client(config, _StubAdapter()));

      // 本页内容（含底部留白）只有 606 高；底色要一直铺到 Tab 底边，
      // 否则内容下面会露出外壳的页面底色。
      final background = tester.getSize(
        find.byKey(const Key('mine-background')),
      );
      final page = tester.getSize(find.byType(MinePage));
      expect(background.height, page.height);
      expect(background.height, greaterThan(700));
    });

    testWidgets('底部导航栏带设计稿的向上阴影', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await _pumpMineTab(tester, _client(config, _StubAdapter()));

      // 设计稿 07-01 `box_7`：`box-shadow: 0 -1 8 rgba(0,0,0,0.1)`。
      final navBar = tester.widget<DecoratedBox>(
        find
            .byWidgetPredicate(
              (widget) =>
                  widget is DecoratedBox &&
                  widget.decoration is BoxDecoration &&
                  ((widget.decoration as BoxDecoration).boxShadow?.isNotEmpty ??
                      false),
            )
            .first,
      );
      expect((navBar.decoration as BoxDecoration).boxShadow, const <BoxShadow>[
        BoxShadow(
          color: AppColors.tabBarShadow,
          offset: Offset(0, -1),
          blurRadius: 8,
        ),
      ]);
    });
  });
}
