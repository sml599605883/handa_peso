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
