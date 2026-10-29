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

  testWidgets('换卡替换塌回根：账户列表与绑卡页跟旧 H5 一起出栈', (tester) async {
    // 对齐 peso_shield 的 toWebViewResettingFlow（app_navigator.dart:370）：
    // 换卡成功后只留「根页面 + 一个新 H5」。换卡链路会压账户列表，新增账户
    // 时再压绑卡页；这两页若留在栈里，返回键就在新确认页和 Loan details
    // 之间打转（reczz28Sjm17GWSd 的附件视频）。
    await _pumpApp(tester);

    unawaited(AppNavigator.toWebView(url: 'source-page', title: 'Details'));
    await tester.pumpAndSettle();
    Get.toNamed<void>(AppRoutes.payoutAccounts);
    await tester.pumpAndSettle();
    Get.toNamed<void>(AppRoutes.bindCard);
    await tester.pumpAndSettle();

    unawaited(
      AppNavigator.toWebViewResettingFlow(
        url: 'confirmation-page',
        title: 'Details',
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('confirmation-page'), findsOneWidget);
    // 用 skipOffstage: false 断言「真的被移除」：还留在栈里的路由只是不在屏上，
    // 默认的 skipOffstage: true 会让断言假通过。
    expect(find.text('source-page', skipOffstage: false), findsNothing);
    expect(find.text('payout-accounts', skipOffstage: false), findsNothing);
    expect(find.text('bind-card', skipOffstage: false), findsNothing);

    // 栈深只剩一层：一次 pop 就回到根页面，落点不是账户列表或旧 H5。
    Get.back<void>();
    await tester.pumpAndSettle();

    expect(Get.currentRoute, '/home');
    expect(find.text('home'), findsOneWidget);
    expect(find.text('confirmation-page', skipOffstage: false), findsNothing);
  });

  testWidgets('toWebView(replaceCurrent) 仍只清 WebView：其它调用方语义不变', (tester) async {
    // 登录失效、深链、H5 站内跳转仍走老入口：谓词只排除 WebView，遍历到账户
    // 列表这类普通页面就停下。这正是换卡链路不能继续用它、而要走
    // toWebViewResettingFlow 的原因。
    await _pumpApp(tester);

    unawaited(AppNavigator.toWebView(url: 'source-page', title: 'Details'));
    await tester.pumpAndSettle();
    Get.toNamed<void>(AppRoutes.payoutAccounts);
    await tester.pumpAndSettle();

    unawaited(
      AppNavigator.toWebView(
        url: 'login-page',
        title: 'Details',
        replaceCurrent: true,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('login-page'), findsOneWidget);
    // 谓词从栈顶开始问：栈顶是账户列表（普通页面）→ 直接停下，一个都没删。
    // 连来源 H5 都还在下面 —— 换卡链路若继续用它，返回就会在旧确认页和
    // 账户列表之间打转（reczz28Sjm17GWSd）。
    expect(find.text('payout-accounts', skipOffstage: false), findsOneWidget);
    expect(find.text('source-page', skipOffstage: false), findsOneWidget);
  });
}

Future<void> _pumpApp(WidgetTester tester) async {
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
        GetPage<void>(
          name: AppRoutes.payoutAccounts,
          page: () => const Scaffold(body: Text('payout-accounts')),
        ),
        GetPage<void>(
          name: AppRoutes.bindCard,
          page: () => const Scaffold(body: Text('bind-card')),
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}
