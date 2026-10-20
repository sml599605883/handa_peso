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
import 'package:handa_peso/core/network/gateway_client.dart';
import 'package:handa_peso/core/network/gateway_settings.dart';
import 'package:handa_peso/core/permissions/permission_coordinator.dart';
import 'package:handa_peso/core/session/local_session.dart';
import 'package:handa_peso/features/home/home_big_card.dart';
import 'package:handa_peso/features/home/home_banner.dart';
import 'package:handa_peso/features/home/home_recommendations.dart';
import 'package:handa_peso/features/main_shell/main_binding.dart';
import 'package:handa_peso/features/main_shell/main_controller.dart';
import 'package:handa_peso/app/widgets/app_empty_state.dart';
import 'package:handa_peso/features/main_shell/main_shell_page.dart';

const String _stubRoute = '/stub';

const Map<String, List<String>> _jsonHeaders = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

/// 记录请求的脚本化适配器，用于统计首页接口被调用的次数。
class _StubAdapter implements HttpClientAdapter {
  _StubAdapter(this.handler);

  final Future<ResponseBody> Function(RequestOptions options) handler;
  final List<String> urls = <String>[];

  int get homeCalls => urls.where((url) => url.contains('indulgences')).length;

  /// Banner 点击上报（`/dropcloth/fluorochromes`）的调用次数。
  int get bannerClickCalls =>
      urls.where((url) => url.contains('fluorochromes')).length;

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

Map<String, dynamic> _loanItem({
  String amount = '₱50,000',
  List<Map<String, dynamic>> steps = const [],
  List<Map<String, dynamic>> periods = const [],
}) {
  return <String, dynamic>{
    'dependable': 'main',
    'dullard': 'Handa Peso',
    'circularise': '',
    'flaunter': amount,
    'outeating': 'Available up to',
    'pyranoside': '180 Days',
    'farle': 'Loan terms',
    'phalarope': '≤0.5% / Day',
    'disgruntle': 'Interest rate',
    'unglove': 'Complete the authentication in just 3 minutes and get ₱60,000',
    'bioregional': 0,
    'microfarads': steps,
    'varyingly': periods,
  };
}

Map<String, dynamic> _offerItem(String id, int tone) {
  return <String, dynamic>{
    'dependable': id,
    'dullard': 'App Name',
    'circularise': '',
    'flaunter': '₱60,000',
    'outeating': 'Available up to',
    'pyranoside': '180 Days',
    'phalarope': '≤0.5% / Day',
    'unchivalrous': 'Apply Now',
    'asbestine': tone,
    'coughs': <String>[],
  };
}

/// 组装首页接口信封；`latchstrings` 模拟网关下发的模块列表。
String _envelope(List<Map<String, dynamic>> modules) {
  return jsonEncode(<String, dynamic>{
    'unaccepted': 0,
    'unstably': 'success',
    'indulgences': <String, dynamic>{'latchstrings': modules},
  });
}

/// 组装准入接口信封；字段名与接口文档「点击申请」一致。
String _applyBody({
  int code = 200,
  String target = '',
  String message = '',
  int jumpType = 1,
}) {
  return jsonEncode(<String, dynamic>{
    'unaccepted': 0,
    'unstably': 'success',
    'indulgences': <String, dynamic>{
      'murdering': code,
      'tidewaters': target,
      'trollopy': jumpType,
      'bioscope': message,
    },
  });
}

String _plainBody({bool withOffers = false}) {
  return _envelope(<Map<String, dynamic>>[
    <String, dynamic>{
      'trollopy': 'Jailbirds',
      'ranulas': <Map<String, dynamic>>[_loanItem()],
    },
    if (withOffers)
      <String, dynamic>{
        'trollopy': 'InspissateDismantling',
        'ranulas': <Map<String, dynamic>>[
          _offerItem('offer-1', 1),
          _offerItem('offer-2', 0),
          _offerItem('offer-3', -1),
        ],
      },
  ]);
}

/// `TophBacks`（Banner）条目；字段名与 2026-10-13 抓包一致。
Map<String, dynamic> _bannerItem(int id, {String? image, String link = ''}) {
  return <String, dynamic>{
    'dependable': id,
    'originator': image ?? 'http://example.test/banner-$id.png',
    'tidewaters': link,
  };
}

String _bannerBody(List<Map<String, dynamic>> banners) {
  return _envelope(<Map<String, dynamic>>[
    <String, dynamic>{'trollopy': 'TophBacks', 'ranulas': banners},
    <String, dynamic>{
      'trollopy': 'Jailbirds',
      'ranulas': <Map<String, dynamic>>[_loanItem()],
    },
  ]);
}

String _progressBody() {
  return _envelope(<Map<String, dynamic>>[
    <String, dynamic>{
      'trollopy': 'Jailbirds',
      'ranulas': <Map<String, dynamic>>[
        _loanItem(
          steps: <Map<String, dynamic>>[
            <String, dynamic>{
              'canonic': '₱30,000',
              'triodes': '₱30,000',
              'gametogenous': 1,
            },
            <String, dynamic>{
              'canonic': '₱40,000',
              'triodes': '₱40,000',
              'gametogenous': 1,
            },
            <String, dynamic>{
              'canonic': '₱50,000',
              'triodes': '₱50,000',
              'gametogenous': 1,
            },
            <String, dynamic>{
              'canonic': '₱60,000',
              'triodes': '₱60,000',
              'gametogenous': 0,
            },
          ],
        ),
      ],
    },
  ]);
}

/// 抓包自测试网关的模块令牌与字段：`TophBacks`(Banner)、`Jailbirds`(大卡位)、
/// `Broodiest`(滚动广告)、`PeriplasmAddition`(借款进度卡片，游客为空)。
/// 卡位 Logo 留空，避免 widget 测试去加载网络图片；其余字段与网关一致。
String _liveGuestBody() {
  return _envelope(<Map<String, dynamic>>[
    <String, dynamic>{
      'trollopy': 'TophBacks',
      'ranulas': <Map<String, dynamic>>[
        <String, dynamic>{
          'dependable': 3,
          'originator': 'http://example.test/banner.png',
          'tidewaters': 'http://example.test/landing?elbow=3',
        },
      ],
    },
    <String, dynamic>{
      'trollopy': 'Jailbirds',
      'ranulas': <Map<String, dynamic>>[
        <String, dynamic>{
          'dependable': 2,
          'dullard': 'Handa Peso',
          'circularise': '',
          'unchivalrous': 'Apply Now',
          'flaunter': '₱60,000',
          'outeating': 'Maximum Loan Amount Upto',
          'pyranoside': '120 days',
          'farle': 'Loan Term',
          'phalarope': '0.05% day',
          'disgruntle': 'Interest Rate',
          'unglove':
              'Complete the authentication in just 3 minutes and got ₱60,000',
          'bioregional': 0,
          'microfarads': <Map<String, dynamic>>[],
          'varyingly': <Map<String, dynamic>>[],
        },
      ],
    },
    <String, dynamic>{
      'trollopy': 'Broodiest',
      'ranulas': <Map<String, dynamic>>[
        <String, dynamic>{'canonic': '<span>2,500 pesos</span> to user C***'},
      ],
    },
    <String, dynamic>{
      'trollopy': 'PeriplasmAddition',
      'ranulas': <Map<String, dynamic>>[],
    },
  ]);
}

GatewaySettings _config() {
  return GatewaySettings(
    apiOrigin: 'http://home.test',
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
  _StubPermissions(this.decision);

  final LocationAccessDecision decision;
  int requests = 0;
  bool settingsOpened = false;

  @override
  Future<LocationAccessDecision> requestLocationAccess() async {
    requests += 1;
    return decision;
  }

  @override
  Future<bool> openSettings() async {
    settingsOpened = true;
    return true;
  }
}

/// 一直挂着的定位授权弹窗：模拟用户还没在系统弹窗上做选择。
class _PendingPermissions extends PermissionCoordinator {
  final Completer<LocationAccessDecision> gate =
      Completer<LocationAccessDecision>();
  int requests = 0;

  @override
  Future<LocationAccessDecision> requestLocationAccess() {
    requests += 1;
    return gate.future;
  }
}

/// 首页接口正常返回，准入接口按 [applyBody] 应答。
_StubAdapter _adapterWithApply(String applyBody) {
  return _StubAdapter((options) async {
    final body = options.uri.toString().contains('legongs')
        ? applyBody
        : _plainBody();
    return ResponseBody.fromString(body, 200, headers: _jsonHeaders);
  });
}

/// 以登录态启动外壳。
Future<void> _pumpLoggedIn(
  WidgetTester tester,
  _StubAdapter adapter, {
  PermissionCoordinator? permissions,
}) async {
  final config = _config();
  await config.localSession.writeSessionId('session-1');
  await _pumpShell(tester, _client(config, adapter), permissions: permissions);
}

/// 用真实路由启动外壳，使 `Get.currentRoute` 与设计一致（`/main`）。
Future<void> _pumpShell(
  WidgetTester tester,
  GatewayClient client, {
  bool settle = true,
  PermissionCoordinator? permissions,
}) async {
  tester.view.physicalSize = const Size(375, 812);
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
        permissionCoordinator:
            permissions ?? _StubPermissions(LocationAccessDecision.granted),
      ),
      getPages: <GetPage<dynamic>>[
        GetPage<void>(name: AppRoutes.main, page: () => const MainShellPage()),
        GetPage<void>(
          name: _stubRoute,
          page: () => const Scaffold(body: Center(child: Text('stub'))),
        ),
        GetPage<void>(
          name: AppRoutes.webView,
          page: () => const Scaffold(body: Center(child: Text('webview'))),
        ),
        GetPage<void>(
          name: AppRoutes.orders,
          page: () => const Scaffold(body: Center(child: Text('orders'))),
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
        GetPage<void>(
          name: AppRoutes.calculator,
          page: () => const Scaffold(body: Center(child: Text('calculator'))),
        ),
        GetPage<void>(
          name: AppRoutes.account,
          page: () => const Scaffold(body: Center(child: Text('account'))),
        ),
      ],
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

void main() {
  setUp(() => Get.reset());
  // `Get.reset()` 只是清空注册表，不会回调 `onClose`，因此必须显式销毁控制器，
  // 否则上一轮的控制器会继续订阅生命周期事件，把请求量算到别的用例头上。
  tearDown(() {
    if (Get.isRegistered<MainController>()) {
      Get.delete<MainController>(force: true);
    }
    Get.reset();
  });

  group('首页状态', () {
    testWidgets('默认态渲染主卡片与宣传条，不渲染推荐列表', (tester) async {
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      expect(adapter.homeCalls, 1);
      expect(find.byType(HomeBigCard), findsOneWidget);
      expect(find.byType(HomeBanner), findsOneWidget);
      expect(find.byType(HomeRecommendations), findsNothing);

      // 未下发 Banner：退回设计稿内置宣传条，不套 PageView。
      expect(find.byType(PageView), findsNothing);

      // 设计稿：宣传条紧贴按钮下方 18，落在 532。
      expect(tester.getTopLeft(find.byType(HomeBanner)).dy, closeTo(532, 0.01));
    });

    testWidgets('真实网关令牌下渲染主卡片，而不是空状态', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _liveGuestBody(),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      expect(find.byType(AppEmptyState), findsNothing);
      expect(find.byType(HomeBigCard), findsOneWidget);
      expect(find.text('₱60,000'), findsWidgets);
    });

    testWidgets('认证进行中时票据把按钮与 Banner 整体下移 119', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _progressBody(),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      expect(find.text('My unlocked limit'), findsOneWidget);
      expect(
        tester.getRect(find.byKey(HomeBigCard.applyButtonKey)).top,
        closeTo(577, 0.01),
      );
      expect(tester.getTopLeft(find.byType(HomeBanner)).dy, closeTo(651, 0.01));
    });

    testWidgets('推荐列表按设计稿顺序渲染并下发按钮状态', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _plainBody(withOffers: true),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      expect(find.byType(HomeRecommendations), findsOneWidget);
      expect(find.text('Recommendation!'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
      expect(find.text('App Name'), findsNWidgets(3));
      expect(find.text('₱60,000'), findsNWidgets(3));

      // 推荐区落在宣传条下方 20。
      expect(
        tester.getTopLeft(find.byType(HomeRecommendations)).dy,
        closeTo(682, 0.01),
      );

      // 卡片几何：内容宽 347（左右各 14），高 120，卡片间距 14。
      final firstCard = tester.getRect(
        find.byKey(const Key('home-offer-card-offer-1')),
      );
      expect(firstCard.left, closeTo(14, 0.01));
      expect(firstCard.right, closeTo(361, 0.01));
      expect(firstCard.height, closeTo(120, 0.01));
      final secondCard = tester.getRect(
        find.byKey(const Key('home-offer-card-offer-2')),
      );
      expect(secondCard.top - firstCard.bottom, closeTo(14, 0.01));

      // 申请按钮右对齐到卡片内容区右边缘（卡片 14~361，内边距 14）。
      final offerButton = tester.getRect(
        find.byKey(const Key('home-offer-offer-1')),
      );
      expect(offerButton.right, closeTo(347, 0.01));

      // 置灰的导流卡片不响应点击。
      final disabled = tester.widget<GestureDetector>(
        find.byKey(const Key('home-offer-offer-3')),
      );
      expect(disabled.onTap, isNull);
      expect(
        tester
            .widget<GestureDetector>(
              find.byKey(const Key('home-offer-offer-1')),
            )
            .onTap,
        isNotNull,
      );

      // 整张卡片也是申请入口（与大小卡一致），置灰卡片整卡不响应。
      expect(
        tester
            .widget<GestureDetector>(
              find.byKey(const Key('home-offer-card-tap-offer-1')),
            )
            .onTap,
        isNotNull,
      );
      expect(
        tester
            .widget<GestureDetector>(
              find.byKey(const Key('home-offer-card-tap-offer-3')),
            )
            .onTap,
        isNull,
      );
    });

    testWidgets('接口返回前展示 loading，返回后渲染内容', (tester) async {
      final completer = Completer<ResponseBody>();
      final adapter = _StubAdapter((options) => completer.future);
      await _pumpShell(tester, _client(_config(), adapter), settle: false);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      completer.complete(
        ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(HomeBigCard), findsOneWidget);
    });

    testWidgets('接口失败时展示可重试的错误态', (tester) async {
      // 失败会被上报给 Crashlytics 适配器；此处拦截上报，只断言页面表现。
      final reported = <FlutterErrorDetails>[];
      final previous = FlutterError.onError;
      FlutterError.onError = reported.add;
      addTearDown(() => FlutterError.onError = previous);

      final adapter = _StubAdapter(
        (options) async => throw DioException.connectionError(
          requestOptions: options,
          reason: 'offline',
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      expect(reported, isNotEmpty);

      expect(find.text('We could not load your home feed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byType(HomeBigCard), findsNothing);
    });

    testWidgets('接口返回空数据时展示空状态', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _envelope(const <Map<String, dynamic>>[]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      expect(find.byType(AppEmptyState), findsOneWidget);
      expect(find.text('Nothing here yet'), findsOneWidget);
    });
  });

  group('首页 Banner', () {
    testWidgets('单张 Banner 按设计稿铺满，不套 PageView', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _bannerBody(<Map<String, dynamic>>[
            _bannerItem(7, link: 'http://example.test/landing/7'),
          ]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      expect(find.byType(PageView), findsNothing);
      expect(find.byType(HomeBanner), findsOneWidget);

      // 设计稿 08-04：左右留白 14、高 130。
      final rect = tester.getRect(find.byKey(const ValueKey('home-banner-7')));
      expect(rect.left, closeTo(14, 0.01));
      expect(rect.right, closeTo(361, 0.01));
      expect(rect.height, closeTo(130, 0.01));
    });

    testWidgets('点击 Banner 打开下发的 H5 落地页', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _bannerBody(<Map<String, dynamic>>[
            _bannerItem(7, link: 'http://8.220.178.113/ph-mti/suppose/hundred'),
          ]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      await tester.tap(find.byKey(const ValueKey('home-banner-7')));
      await tester.pumpAndSettle();

      expect(find.text('webview'), findsOneWidget);
      expect(Get.currentRoute, AppRoutes.webView);
      // 游客没有登录态：按接口文档不上报点击。
      expect(adapter.bannerClickCalls, 0);
    });

    testWidgets('登录态点击 Banner 会先补记一次点击上报', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _bannerBody(<Map<String, dynamic>>[
            _bannerItem(7, link: 'http://example.test/landing/7'),
          ]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(config, adapter));

      await tester.tap(find.byKey(const ValueKey('home-banner-7')));
      await tester.pumpAndSettle();

      expect(adapter.bannerClickCalls, 1);
      expect(Get.currentRoute, AppRoutes.webView);
    });

    testWidgets('跳转链接为空的 Banner 只展示，不跳转也不上报', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _bannerBody(<Map<String, dynamic>>[_bannerItem(9)]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(config, adapter));

      await tester.tap(find.byKey(const ValueKey('home-banner-9')));
      await tester.pump();

      expect(Get.currentRoute, AppRoutes.main);
      expect(adapter.bannerClickCalls, 0);
    });

    testWidgets('Banner 下发应用深链时打开对应页面', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _bannerBody(<Map<String, dynamic>>[
            _bannerItem(4, link: 'ph://handa-peso/ios/Brusker'),
          ]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      await tester.tap(find.byKey(const ValueKey('home-banner-4')));
      await tester.pumpAndSettle();

      expect(find.text('orders'), findsOneWidget);
      expect(Get.currentRoute, AppRoutes.orders);
    });

    testWidgets('Banner 下发还没有落地页的深链时不跳转', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _bannerBody(<Map<String, dynamic>>[
            // 重新授信（`Herbivory`）当前版本还没有原生落地页。
            _bannerItem(5, link: 'ph://handa-peso/ios/Herbivory'),
          ]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      await tester.tap(find.byKey(const ValueKey('home-banner-5')));
      await tester.pumpAndSettle();

      expect(find.text('Unable to open link'), findsOneWidget);
      expect(Get.currentRoute, AppRoutes.main);
      expect(find.text('webview'), findsNothing);

      // 等错误提示的自动消失计时器跑完，避免测试结束时留下未完成的定时器。
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('Banner 下的设置深链打开账号页', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _bannerBody(<Map<String, dynamic>>[
            _bannerItem(6, link: 'ph://handa-peso/ios/HelistopSaintliest'),
          ]),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      await tester.tap(find.byKey(const ValueKey('home-banner-6')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.account);
      expect(find.text('account'), findsOneWidget);
    });

    testWidgets('多张 Banner 从第一张开始，每 3 秒自动翻页', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _bannerBody(<Map<String, dynamic>>[
            _bannerItem(1, link: 'http://example.test/1'),
            _bannerItem(2, link: 'http://example.test/2'),
            _bannerItem(3, link: 'http://example.test/3'),
          ]),
          200,
          headers: _jsonHeaders,
        ),
      );
      // 自动翻页是常驻定时器，settle 会因为一直有新动画而超时。
      await _pumpShell(tester, _client(_config(), adapter), settle: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(PageView), findsOneWidget);
      expect(find.byKey(const ValueKey('home-banner-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-banner-2')), findsNothing);

      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey('home-banner-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('home-banner-1')), findsNothing);
    });
  });

  group('首页刷新时机', () {
    testWidgets('下拉刷新会重新请求首页接口', (tester) async {
      final adapter = _StubAdapter(
        (options) async => ResponseBody.fromString(
          _plainBody(withOffers: true),
          200,
          headers: _jsonHeaders,
        ),
      );
      await _pumpShell(tester, _client(_config(), adapter));
      expect(adapter.homeCalls, 1);

      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();

      expect(adapter.homeCalls, 2);
    });

    testWidgets('切回首页 Tab 会刷新', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await _pumpShell(tester, _client(config, adapter));
      final controller = Get.find<MainController>();

      await controller.switchTab(1);
      await controller.switchTab(0);
      await tester.pumpAndSettle();

      expect(adapter.homeCalls, 2);
    });

    testWidgets('系统弹窗关闭后只补刷一次，真正回到前台每次都刷新', (tester) async {
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await _pumpShell(tester, _client(_config(), adapter));
      expect(adapter.homeCalls, 1);

      Future<void> dialogRoundTrip() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      }

      Future<void> backgroundRoundTrip() async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await tester.pump();
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.inactive,
        );
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pumpAndSettle();
      }

      await dialogRoundTrip();
      expect(adapter.homeCalls, 2);

      // 弹窗已经消费过一次，后续的 inactive -> resumed 不再刷新。
      await dialogRoundTrip();
      expect(adapter.homeCalls, 2);

      await backgroundRoundTrip();
      expect(adapter.homeCalls, 3);

      await backgroundRoundTrip();
      expect(adapter.homeCalls, 4);
    });

    testWidgets('二级页面覆盖首页时不刷新，返回后补一次', (tester) async {
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await _pumpShell(tester, _client(_config(), adapter));
      expect(adapter.homeCalls, 1);

      Get.toNamed<void>(_stubRoute);
      await tester.pumpAndSettle();

      await Get.find<MainController>().refreshOverview();
      await tester.pumpAndSettle();
      expect(adapter.homeCalls, 1);

      Get.back<void>();
      await tester.pumpAndSettle();
      expect(adapter.homeCalls, 2);
    });
  });

  group('首页大卡点击', () {
    testWidgets('点击大卡任意位置都走准入接口并按下发地址跳转', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(target: 'http://example.test/admission'),
      );
      await _pumpLoggedIn(tester, adapter);

      // 设计稿金额面板（20~352, 174~322），点这里等价于点 Apply Now。
      await tester.tapAt(const Offset(180, 200));
      await tester.pumpAndSettle();

      expect(adapter.applyCalls, 1);
      expect(Get.currentRoute, AppRoutes.webView);
      expect(find.text('webview'), findsOneWidget);
    });

    testWidgets('游客点击大卡只弹登录页，不发准入请求', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(target: 'http://example.test/admission'),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      await tester.tapAt(const Offset(180, 200));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.login);
      expect(adapter.applyCalls, 0);
    });

    testWidgets('连点大卡只发一次准入请求', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(target: 'http://example.test/admission'),
      );
      await _pumpLoggedIn(tester, adapter);

      final controller = Get.find<MainController>();
      // 第一次点击会一路跳到落地页，导航 Future 要等落地页关闭才结束，因此不能
      // await（与「连点受保护 Tab」用例同理）；第二次点击应被连点保护挡下。
      unawaited(controller.applyNow('main'));
      unawaited(controller.applyNow('main'));
      await tester.pumpAndSettle();

      expect(adapter.applyCalls, 1);
    });

    testWidgets('准入失败且没有跳转地址时提示服务端文案', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(code: 505, message: 'Not eligible for this product'),
      );
      await _pumpLoggedIn(tester, adapter);

      await tester.tapAt(const Offset(180, 200));
      await tester.pump();
      await tester.pumpAndSettle();

      expect(find.text('Not eligible for this product'), findsOneWidget);
      expect(Get.currentRoute, AppRoutes.main);

      // 等提示的自动消失计时器跑完，避免测试结束时留下未完成的定时器。
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
    });

    testWidgets('准入通过但没有跳转地址时按本地认证状态继续', (tester) async {
      final adapter = _adapterWithApply(_applyBody());
      await _pumpLoggedIn(tester, adapter);

      await tester.tapAt(const Offset(180, 200));
      await tester.pumpAndSettle();

      expect(adapter.applyCalls, 1);
      expect(Get.currentRoute, AppRoutes.certification);
      expect(find.text('certification'), findsOneWidget);
    });
  });

  group('推荐卡点击', () {
    testWidgets('点击推荐卡任意位置都走准入接口并按下发地址跳转', (tester) async {
      final adapter = _StubAdapter((options) async {
        final body = options.uri.toString().contains('legongs')
            ? _applyBody(target: 'http://example.test/admission')
            : _plainBody(withOffers: true);
        return ResponseBody.fromString(body, 200, headers: _jsonHeaders);
      });
      await _pumpLoggedIn(tester, adapter);

      // 推荐区落在首屏之下：先把它滚上来，再点卡片本体的标题行（不是
      // Apply Now），验证整卡都是热区。
      await tester.drag(find.byType(ListView), const Offset(0, -220));
      await tester.pumpAndSettle();

      final card = tester.getRect(
        find.byKey(const Key('home-offer-card-offer-1')),
      );
      await tester.tapAt(Offset(card.left + 40, card.top + 20));
      await tester.pumpAndSettle();

      expect(adapter.applyCalls, 1);
      expect(Get.currentRoute, AppRoutes.webView);
    });
  });

  group('申请前的定位准入', () {
    testWidgets('先要一次定位权限，授权通过后照常走准入接口', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(target: 'http://example.test/admission'),
      );
      final permissions = _StubPermissions(LocationAccessDecision.granted);
      await _pumpLoggedIn(tester, adapter, permissions: permissions);

      await tester.tapAt(const Offset(180, 200));
      await tester.pumpAndSettle();

      expect(permissions.requests, 1);
      expect(adapter.applyCalls, 1);
      expect(Get.currentRoute, AppRoutes.webView);
    });

    testWidgets('权限被拒时先弹二次说明，取消后照常申请', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(target: 'http://example.test/admission'),
      );
      final permissions = _StubPermissions(LocationAccessDecision.denied);
      await _pumpLoggedIn(tester, adapter, permissions: permissions);

      await tester.tapAt(const Offset(180, 200));
      await tester.pumpAndSettle();

      expect(find.text('Location Access Is Off'), findsOneWidget);
      expect(adapter.applyCalls, 0);

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(permissions.settingsOpened, isFalse);
      expect(adapter.applyCalls, 1);
      expect(Get.currentRoute, AppRoutes.webView);
    });

    testWidgets('权限被拒时选择去系统设置则中止本次申请', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(target: 'http://example.test/admission'),
      );
      final permissions = _StubPermissions(LocationAccessDecision.denied);
      await _pumpLoggedIn(tester, adapter, permissions: permissions);

      await tester.tapAt(const Offset(180, 200));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(permissions.settingsOpened, isTrue);
      expect(adapter.applyCalls, 0);
      expect(Get.currentRoute, AppRoutes.main);
    });

    testWidgets('定位服务没打开时给出对应的说明', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(target: 'http://example.test/admission'),
      );
      final permissions = _StubPermissions(
        LocationAccessDecision.serviceDisabled,
      );
      await _pumpLoggedIn(tester, adapter, permissions: permissions);

      await tester.tapAt(const Offset(180, 200));
      await tester.pumpAndSettle();

      expect(find.text('Location Services Are Off'), findsOneWidget);

      await tester.tap(find.text('Not Now'));
      await tester.pumpAndSettle();

      expect(adapter.applyCalls, 1);
    });

    testWidgets('定位弹窗期间被切到后台：本次申请作废，入口不会被锁住', (tester) async {
      final adapter = _adapterWithApply(
        _applyBody(target: 'http://example.test/admission'),
      );
      final permissions = _PendingPermissions();
      await _pumpLoggedIn(tester, adapter, permissions: permissions);

      await tester.tapAt(const Offset(180, 200));
      await tester.pump();
      expect(permissions.requests, 1);

      // 用户还没在系统弹窗上做选择就把应用切到后台：原生回调不会再回来，
      // 这次申请要干净地结束，不能把申请入口锁在一次挂着的等待上。
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(adapter.applyCalls, 0);

      // 再点一次：重新走一遍定位准入与准入接口。
      permissions.gate.complete(LocationAccessDecision.granted);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(180, 200));
      await tester.pumpAndSettle();

      expect(permissions.requests, 2);
      expect(adapter.applyCalls, 1);
      expect(Get.currentRoute, AppRoutes.webView);
    });
  });

  group('Tab 登录门禁', () {
    testWidgets('游客点击 Loan Tab 只弹登录页，不切换 Tab', (tester) async {
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      await tester.tap(find.byKey(const Key('tab-loan')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.login);
      expect(find.text('login'), findsOneWidget);
      expect(Get.find<MainController>().activeTab.value, 0);
    });

    testWidgets('游客点击 Mine Tab 只弹登录页，不切换 Tab', (tester) async {
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await _pumpShell(tester, _client(_config(), adapter));

      await tester.tap(find.byKey(const Key('tab-mine')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.login);
      expect(Get.find<MainController>().activeTab.value, 0);
    });

    testWidgets('连点受保护 Tab 只叠加一个登录页', (tester) async {
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await _pumpShell(tester, _client(_config(), adapter));
      final controller = Get.find<MainController>();

      // 连点：门禁只应留下一个登录路由。登录页关闭前 switchTab 的 Future 不会
      // 结束，这里不能 await 它，否则测试会卡在导航上。
      unawaited(controller.switchTab(1));
      unawaited(controller.switchTab(2));
      await tester.pumpAndSettle();
      expect(Get.currentRoute, AppRoutes.login);

      Get.back<void>();
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.main);
      expect(controller.activeTab.value, 0);
    });

    testWidgets('登录态点击受保护 Tab 直接切换，不再弹登录页', (tester) async {
      final config = _config();
      await config.localSession.writeSessionId('session-1');
      await config.localSession.writePhone('09170000000');
      final adapter = _StubAdapter(
        (options) async =>
            ResponseBody.fromString(_plainBody(), 200, headers: _jsonHeaders),
      );
      await _pumpShell(tester, _client(config, adapter));

      await tester.tap(find.byKey(const Key('tab-mine')));
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.main);
      expect(Get.find<MainController>().activeTab.value, 2);
      // 个人中心的手机号按设计稿脱敏展示。
      expect(find.text('091****0000'), findsOneWidget);
      expect(find.text('Browsing as guest'), findsNothing);
    });
  });
}
