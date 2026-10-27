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
    int? capturedSource;
    AppNavigator.admissionHandler = (value, {int source = 0}) async {
      productId = value;
      capturedSource = source;
    };

    await AppNavigator.openTarget(
      'ph://handa-peso/ios/PeacefulnessesQuesters'
      '?cotype=1000460&efflorescence=7',
    );

    expect(productId, '1000460');
    expect(capturedSource, 7);
  });

  test('准入 scheme 未带来源时使用调用方兜底来源', () async {
    var capturedSource = 0;
    AppNavigator.admissionHandler = (_, {int source = 0}) async {
      capturedSource = source;
    };

    await AppNavigator.openTarget(
      'ph://handa-peso/ios/PeacefulnessesQuesters?cotype=1000460',
      source: 3,
    );

    expect(capturedSource, 3);
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

  testWidgets('ph 重新授信深链进入等待授信页并携带产品 ID', (tester) async {
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
        'ph://handa-peso/ios/Herbivory?cotype=1000460',
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

  testWidgets('H5 登录态失效深链清掉过期网页，登录页盖在首页之上', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.main,
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: AppRoutes.main,
            page: () => const Scaffold(body: Text('home')),
          ),
          GetPage<void>(
            name: AppRoutes.webView,
            page: () => const Scaffold(body: Text('expired-web')),
          ),
          GetPage<void>(
            name: AppRoutes.login,
            page: () => const Scaffold(body: Text('login-page')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    unawaited(Get.toNamed<void>(AppRoutes.webView));
    await tester.pumpAndSettle();
    expect(find.text('expired-web'), findsOneWidget);

    // H5 判定登录态失效后下发 login 深链。
    unawaited(AppNavigator.openTarget('ph://handa-peso/ios/Disaccording'));
    await tester.pumpAndSettle();

    expect(find.text('login-page'), findsOneWidget);
    // 过期网页被移除：登录页的返回键只能回到首页。
    expect(find.text('expired-web'), findsNothing);

    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('准入下发授信页时把来源订单详情 H5 一起清掉', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: AppRoutes.main,
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: AppRoutes.main,
            page: () => const Scaffold(body: Text('home')),
          ),
          GetPage<void>(
            name: AppRoutes.webView,
            page: () => const Scaffold(body: Text('order-detail')),
          ),
          GetPage<void>(
            name: AppRoutes.creditReview,
            page: () => const Scaffold(body: Text('credit-review')),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    unawaited(Get.toNamed<void>(AppRoutes.webView));
    await tester.pumpAndSettle();
    expect(find.text('order-detail'), findsOneWidget);

    unawaited(
      AppNavigator.openTarget(
        'ph://handa-peso/ios/Herbivory',
        fallbackProductId: '1000460',
        cleanWorkflowForWeb: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('credit-review'), findsOneWidget);
    // 订单详情 H5 被移除：它不会继续留在栈底轮询，退出授信页也不回到它。
    expect(find.text('order-detail'), findsNothing);

    Get.back<void>();
    await tester.pumpAndSettle();
    expect(find.text('home'), findsOneWidget);
  });
}
