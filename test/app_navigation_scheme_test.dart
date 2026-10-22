import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/navigation/app_navigator.dart';
import 'package:handa_peso/app/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(() {
    AppNavigator.admissionHandler = null;
    Get.reset();
  });

  test('准入 scheme 带产品 ID 时交回产品准入流程', () async {
    String? productId;
    AppNavigator.admissionHandler = (value) async => productId = value;

    await AppNavigator.openTarget(
      'ph://handa-peso/ios/PeacefulnessesQuesters?cotype=1000460',
    );

    expect(productId, '1000460');
  });

  testWidgets('推送打开 H5 时移除当前绑卡流程页', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/home',
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/home',
            page: () => const Scaffold(body: Text('home')),
          ),
          GetPage<void>(
            name: AppRoutes.bindCard,
            page: () => const Scaffold(body: Text('bind-card')),
          ),
          GetPage<void>(
            name: AppRoutes.webView,
            page: () => Scaffold(
              body: Text(
                '${Get.arguments is Map ? (Get.arguments as Map)['url'] : ''}',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    unawaited(Get.toNamed<void>(AppRoutes.bindCard));
    await tester.pumpAndSettle();
    expect(find.text('bind-card'), findsOneWidget);

    unawaited(
      AppNavigator.openTarget(
        'http://h5.test/notification',
        fromPush: true,
        cleanWorkflowForWeb: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('http://h5.test/notification'), findsOneWidget);
    expect(find.text('bind-card'), findsNothing);
  });

  testWidgets('gold 重新授信地址进入等待授信页并携带产品 ID', (tester) async {
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
            page: () => Scaffold(
              body: Text(
                'credit-review:'
                '${Get.arguments is Map ? (Get.arguments as Map)['productId'] : ''}',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();

    unawaited(
      AppNavigator.openTarget(
        'gold://pocket/recredit',
        fallbackProductId: '1000460',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('credit-review:1000460'), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.creditReview);
  });

  testWidgets('等待授信成功进入 H5 后移除等待页', (tester) async {
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
            page: () => const Scaffold(body: Text('credit-review')),
          ),
          GetPage<void>(
            name: AppRoutes.webView,
            page: () => Scaffold(
              body: Text(
                '${Get.arguments is Map ? (Get.arguments as Map)['url'] : ''}',
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    unawaited(Get.toNamed<void>(AppRoutes.creditReview));
    await tester.pumpAndSettle();
    expect(find.text('credit-review'), findsOneWidget);

    unawaited(
      AppNavigator.openTarget(
        'http://h5.test/credit-approved',
        cleanWorkflowForWeb: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('http://h5.test/credit-approved'), findsOneWidget);
    expect(find.text('credit-review'), findsNothing);
  });
}
