import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/navigation/app_navigator.dart';
import 'package:handa_peso/app/routes/app_routes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets('H5 页面内的网页跳转替换来源页面', (tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/home',
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/home',
            page: () => const Scaffold(body: Text('home')),
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

    unawaited(AppNavigator.toWebView(url: 'source-page', title: 'Details'));
    await tester.pumpAndSettle();
    expect(find.text('source-page'), findsOneWidget);

    unawaited(
      AppNavigator.toWebView(
        url: 'confirmation-page',
        title: 'Details',
        replaceCurrent: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('confirmation-page'), findsOneWidget);
    expect(find.text('source-page'), findsNothing);

    // 换卡成功走的也是这条替换路径：栈里只允许留下一个新 H5，旧的来源页
    // 必须已被移除。否则返回键会退到旧确认页，看起来像原地打转
    // （reczz28Sjm17GWSd）。一次 pop 就回到首页即证明深度只有一层。
    Get.back<void>();
    await tester.pumpAndSettle();

    expect(Get.currentRoute, '/home');
    expect(find.text('home'), findsOneWidget);
    expect(find.text('confirmation-page'), findsNothing);
  });
}
