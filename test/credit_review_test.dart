import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/network/gateway_reply.dart';
import 'package:handa_peso/features/credit_review/credit_review_page.dart';
import 'package:handa_peso/features/credit_review/credit_review_poller.dart';

GatewayReply _reply(int state) {
  return GatewayReply.parse(<String, dynamic>{
    'unaccepted': 0,
    'unstably': 'success',
    'indulgences': <String, dynamic>{'murdering': state},
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  for (var index = 0; index < 40 && !condition(); index++) {
    await Future<void>.delayed(const Duration(milliseconds: 2));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  test('授信完成后在等待页自动续跑准入', () async {
    var requests = 0;
    String? admittedProductId;
    final poller = CreditReviewPoller(
      request: () async {
        requests += 1;
        return _reply(requests == 1 ? 2 : 1);
      },
      currentRoute: () => AppRoutes.creditReview,
      homeVisible: () => false,
      refreshHome: () async {},
      runAdmission: (productId) async => admittedProductId = productId,
      interval: const Duration(milliseconds: 1),
    );
    addTearDown(poller.stop);

    poller.start('1000460');
    await _waitUntil(() => admittedProductId != null);

    expect(requests, 2);
    expect(admittedProductId, '1000460');
    expect(poller.isRunning, isFalse);
  });

  test('离开等待页后仅在首页可见时刷新首页', () async {
    var refreshed = 0;
    var visible = true;
    final poller = CreditReviewPoller(
      request: () async => _reply(1),
      currentRoute: () => AppRoutes.main,
      homeVisible: () => visible,
      refreshHome: () async => refreshed++,
      runAdmission: (_) async {},
      interval: const Duration(milliseconds: 1),
    );
    addTearDown(poller.stop);

    poller.start('p1');
    await _waitUntil(() => refreshed == 1);
    expect(refreshed, 1);

    visible = false;
    poller.start('p2');
    await _waitUntil(() => !poller.isRunning);
    expect(refreshed, 1);
  });

  testWidgets('等待授信页按设计稿尺寸和位置渲染', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final poller = CreditReviewPoller(
      request: () async => _reply(2),
      currentRoute: () => AppRoutes.creditReview,
      homeVisible: () => false,
      refreshHome: () async {},
      runAdmission: (_) async {},
      interval: const Duration(days: 1),
    );
    addTearDown(poller.stop);
    Get.put<CreditReviewPoller>(poller, permanent: true);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/home',
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/home',
            page: () => const Scaffold(body: Text('home')),
          ),
          GetPage<void>(
            name: AppRoutes.creditReview,
            page: () => const CreditReviewPage(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Get.toNamed<void>(
        AppRoutes.creditReview,
        arguments: <String, dynamic>{'productId': '1000460'},
      ),
    );
    await tester.pumpAndSettle();

    final illustration = find.byKey(const Key('credit-review-illustration'));
    final progress = find.byKey(const Key('credit-review-progress'));
    final message = find.byKey(const Key('credit-review-message'));
    final back = find.byKey(const Key('design-back'));
    expect(back, findsOneWidget);
    expect(tester.getTopLeft(back), const Offset(14, 56));
    expect(tester.getSize(back), const Size(24, 24));
    expect(tester.getTopLeft(illustration), const Offset(90.5, 195));
    expect(tester.getSize(illustration), const Size(194, 194));
    expect(tester.getTopLeft(progress), const Offset(36, 409));
    expect(tester.getSize(progress), const Size(303, 12));
    expect(tester.getTopLeft(message), const Offset(32, 435));
    expect(tester.getSize(message), const Size(311, 40));
    expect(find.text('0%'), findsOneWidget);
    expect(
      find.text(
        'Calculating your credit limit, just 30\n'
        'seconds Please wait patiently',
      ),
      findsOneWidget,
    );
    poller.stop();
  });

  test('进度条填充宽度按真实进度取值，并处理 0/100 边界', () {
    double widthFor(int progress) =>
        creditReviewProgressFillWidth(trackWidth: 303, progress: progress);

    // 0%：只留承载「0%」文案的起始块，文字不被裁掉。
    expect(widthFor(0), 32);
    expect(widthFor(-20), 32);
    expect(widthFor(20), closeTo(60.6, 0.001));
    expect(widthFor(50), closeTo(151.5, 0.001));
    // 99%：宽度必须跟着数值走，几乎铺满轨道。
    expect(widthFor(99), closeTo(299.97, 0.001));
    // 100%：正好铺满，不溢出。
    expect(widthFor(100), 303);
    expect(widthFor(120), 303);
    // 轨道未布局（宽度 0）不产生负宽度；轨道比起始块还窄时不溢出轨道。
    expect(creditReviewProgressFillWidth(trackWidth: 0, progress: 50), 0);
    expect(creditReviewProgressFillWidth(trackWidth: 20, progress: 0), 20);
  });

  testWidgets('等待授信页进度条填充随百分比推进到 99%', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: CreditReviewPage(
          progressDelayGenerator: () => const Duration(milliseconds: 10),
          progressIncrementGenerator: (_) => 99,
        ),
      ),
    );
    await tester.pump();

    final fill = find.byKey(const Key('credit-review-progress-fill'));
    final track = find.byKey(const Key('credit-review-progress'));
    expect(tester.getSize(track), const Size(303, 12));
    // 起始：0% 只有起始块，填充贴着轨道左端。
    expect(find.text('0%'), findsOneWidget);
    expect(tester.getSize(fill), const Size(32, 12));
    expect(tester.getTopLeft(fill), tester.getTopLeft(track));

    await tester.pump(const Duration(milliseconds: 20));

    // 文案与填充同源：数值到 99%，宽度也要到轨道 303 的 99%。
    expect(find.text('99%'), findsOneWidget);
    expect(tester.getSize(fill).width, closeTo(303 * 0.99, 0.01));
    expect(tester.getSize(fill).height, 12);
    expect(tester.getTopLeft(fill), tester.getTopLeft(track));
  });

  testWidgets('等待授信页左上角返回键回到来源页', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/home',
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/home',
            page: () => const Scaffold(body: Text('home')),
          ),
          GetPage<void>(
            name: AppRoutes.creditReview,
            page: () => const CreditReviewPage(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Get.toNamed<void>(
        AppRoutes.creditReview,
        arguments: <String, dynamic>{'productId': '1000460'},
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('credit-review-illustration')), findsOneWidget);

    await tester.tap(find.byKey(const Key('design-back')));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(Get.currentRoute, '/home');
  });
}
