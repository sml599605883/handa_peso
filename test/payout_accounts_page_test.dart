import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
import 'package:handa_peso/core/network/gateway_failure.dart';
import 'package:handa_peso/features/certification/bind_card_models.dart';
import 'package:handa_peso/features/webview/payout_account_models.dart';
import 'package:handa_peso/features/webview/payout_accounts_page.dart';

const _catalog = PayoutAccountCatalog(<PayoutAccountGroup>[
  PayoutAccountGroup(
    title: 'Bank',
    type: '2',
    accounts: <PayoutAccount>[
      PayoutAccount(
        id: 'bank-1',
        bankName: 'BDO',
        accountNumber: '5490123232341238',
        logoUrl: '',
        holderName: 'Ana Cruz Santos',
        maintenanceNote:
            'The bank is under maintenance. Loans may be delayed. '
            'Please wait or choose another option',
        isPrimary: true,
        // 维护中：只有 uppropped=0 才展示提示（可用账户就算有文案也不展示）。
        available: false,
        holderFirstName: 'Ana',
        holderMiddleName: 'Cruz',
        holderLastName: 'Santos',
      ),
    ],
  ),
  PayoutAccountGroup(
    title: 'E-wallet',
    type: '1',
    accounts: <PayoutAccount>[
      PayoutAccount(
        id: 'wallet-1',
        bankName: 'GCash',
        accountNumber: '09171234567',
        logoUrl: 'https://example.test/gcash.png',
        holderName: 'Ana Cruz Santos',
        maintenanceNote: '',
        isPrimary: false,
        holderFirstName: 'Ana',
        holderMiddleName: 'Cruz',
        holderLastName: 'Santos',
      ),
    ],
  ),
  PayoutAccountGroup(
    title: 'Cash Pickup',
    type: '3',
    accounts: <PayoutAccount>[
      PayoutAccount(
        id: 'cash-1',
        bankName: 'Cebuana Lhuillier',
        accountNumber: '',
        logoUrl: '',
        holderName: 'Ana Cruz Santos',
        maintenanceNote: '',
        isPrimary: false,
        holderFirstName: 'Ana',
        holderMiddleName: 'Cruz',
        holderLastName: 'Santos',
      ),
    ],
  ),
]);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => Get.testMode = true);
  tearDown(() {
    // EasyLoading 是单例：上一条用例留下的提示浮层会盖在下一张页面上，
    // 让后续用例的点击落空。
    unawaited(EasyLoading.dismiss());
    Get.reset();
  });

  testWidgets('放款账户页按设计稿尺寸和选中态渲染', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: PayoutAccountsPage(
          catalog: _catalog,
          productId: 'p1',
          orderNo: 'o1',
          switchAccount: ({required orderNo, required cardId}) async => '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final banner = find.byKey(const Key('payout-account-add'));
    expect(tester.getTopLeft(banner), const Offset(14, 102));
    expect(tester.getSize(banner), const Size(347, 44));
    expect(tester.getTopLeft(find.text('Bank')), const Offset(14, 160));

    final bank = find.byKey(const Key('payout-account-card-bank-1'));
    final wallet = find.byKey(const Key('payout-account-card-wallet-1'));
    final cash = find.byKey(const Key('payout-account-card-cash-1'));
    expect(tester.getRect(bank), const Rect.fromLTWH(14, 203, 347, 202));
    expect(tester.getRect(wallet), const Rect.fromLTWH(14, 459, 347, 150));
    expect(tester.getRect(cash), const Rect.fromLTWH(14, 663, 347, 150));
    expect(
      tester.getRect(find.byKey(const Key('payout-account-submit'))),
      const Rect.fromLTWH(77.5, 833, 220, 52),
    );

    expect(
      find.byKey(const Key('payout-account-selected-bank-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('payout-account-unselected-wallet-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('payout-account-unselected-cash-1')),
      findsOneWidget,
    );
    expect(find.text('Receipt Account'), findsNWidgets(2));
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Middle Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);

    // headway（logo 图）为空时不渲染 logo 组件：银行/取现卡片只有文字，
    // 电子钱包下发了图才显示。
    expect(find.byKey(const Key('payout-account-logo-bank-1')), findsNothing);
    expect(find.byKey(const Key('payout-account-logo-cash-1')), findsNothing);
    expect(
      find.byKey(const Key('payout-account-logo-wallet-1')),
      findsOneWidget,
    );

    final assetImages = tester
        .widgetList<Image>(find.byType(Image))
        .map((image) => image.image)
        .whereType<AssetImage>()
        .map((image) => image.assetName)
        .toSet();
    expect(
      assetImages,
      containsAll(<String>[
        'assets/payout_account_add_banner.png',
        'assets/payout_account_card_header.png',
        'assets/payout_account_checkbox_selected.png',
        'assets/payout_account_checkbox_unselected.png',
      ]),
    );
  });

  testWidgets('勾选角标贴在卡片右上角，不被卡片圆角裁掉', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: PayoutAccountsPage(
          catalog: _catalog,
          productId: 'p1',
          orderNo: 'o1',
          switchAccount: ({required orderNo, required cardId}) async => '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final bank = find.byKey(const Key('payout-account-card-bank-1'));
    final bankRect = tester.getRect(bank);
    final selected = find.byKey(const Key('payout-account-selected-bank-1'));
    // 设计稿 04-01：16x16 角标，右边/上边与卡片外沿重合。
    expect(
      tester.getRect(selected),
      Rect.fromLTWH(bankRect.right - 16, bankRect.top, 16, 16),
    );
    // 角标不能放进卡片的圆角裁剪里：放进去右上角会被切掉一块（reczz28SjhwDQe5G）。
    expect(
      find.descendant(
        of: find.descendant(of: bank, matching: find.byType(ClipRRect)),
        matching: selected,
      ),
      findsNothing,
    );

    // 未选中的角标用同一套几何（设计稿 E-wallet 卡片同样贴角）。
    final wallet = find.byKey(const Key('payout-account-card-wallet-1'));
    final walletRect = tester.getRect(wallet);
    final unselected = find.byKey(
      const Key('payout-account-unselected-wallet-1'),
    );
    expect(
      tester.getRect(unselected),
      Rect.fromLTWH(walletRect.right - 16, walletRect.top, 16, 16),
    );
  });

  testWidgets('勾选角标画在卡片描边之上', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      GetMaterialApp(
        home: PayoutAccountsPage(
          catalog: _catalog,
          productId: 'p1',
          orderNo: 'o1',
          switchAccount: ({required orderNo, required cardId}) async => '',
        ),
      ),
    );
    await tester.pumpAndSettle();

    final selected = find.byKey(const Key('payout-account-selected-bank-1'));
    final stackFinder = find
        .ancestor(of: selected, matching: find.byType(Stack))
        .first;
    final children = tester.widget<Stack>(stackFinder).children;
    // 卡片 Stack 的绘制顺序：圆角裁剪的卡片内容 → 描边 → 角标。角标必须最后
    // 画，否则描边会横穿角标右上角。
    expect(children.length, 3);
    expect(
      find.descendant(of: find.byWidget(children.last), matching: selected),
      findsOneWidget,
    );
  });

  testWidgets('提交选中的已有账户后回传新 H5 地址并离开原生页', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final outcome = PayoutAccountFlowOutcome();
    String? selectedCardId;

    await tester.pumpWidget(
      GetMaterialApp(
        builder: EasyLoading.init(),
        initialRoute: '/home',
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/home',
            page: () => const Scaffold(
              body: Text('source-web', key: Key('source-web')),
            ),
          ),
          GetPage<void>(
            name: AppRoutes.payoutAccounts,
            page: () => PayoutAccountsPage(
              switchAccount: ({required orderNo, required cardId}) async {
                expect(orderNo, 'o1');
                selectedCardId = cardId;
                return 'https://example.test/updated-order';
              },
            ),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Get.toNamed<void>(
        AppRoutes.payoutAccounts,
        arguments: <String, dynamic>{
          'catalog': _catalog,
          'productId': 'p1',
          'orderNo': 'o1',
          PayoutAccountFlowOutcome.argumentKey: outcome,
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('payout-account-card-wallet-1')));
    await tester.tap(find.byKey(const Key('payout-account-submit')));
    await tester.pumpAndSettle();

    expect(selectedCardId, 'wallet-1');
    expect(outcome.changed, isTrue);
    expect(outcome.redirectUrl, 'https://example.test/updated-order');
    expect(find.byKey(const Key('source-web')), findsOneWidget);
    expect(find.byKey(const Key('payout-account-page')), findsNothing);
  });

  testWidgets('从列表新增账户后逐级返回并保留最终 H5 地址', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final outcome = PayoutAccountFlowOutcome();

    await tester.pumpWidget(
      GetMaterialApp(
        builder: EasyLoading.init(),
        initialRoute: '/home',
        getPages: <GetPage<dynamic>>[
          GetPage<void>(
            name: '/home',
            page: () => const Scaffold(
              body: Text('source-web', key: Key('source-web')),
            ),
          ),
          GetPage<void>(
            name: AppRoutes.payoutAccounts,
            page: () => PayoutAccountsPage(
              switchAccount: ({required orderNo, required cardId}) async => '',
            ),
          ),
          GetPage<void>(
            name: AppRoutes.bindCard,
            page: () => const _BindCardProbe(),
          ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    unawaited(
      Get.toNamed<void>(
        AppRoutes.payoutAccounts,
        arguments: <String, dynamic>{
          'catalog': _catalog,
          'productId': 'p1',
          'orderNo': 'o1',
          PayoutAccountFlowOutcome.argumentKey: outcome,
        },
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('payout-account-add')));
    await tester.pumpAndSettle();

    expect(find.text('bind-card-probe'), findsNothing);
    expect(outcome.changed, isTrue);
    expect(outcome.redirectUrl, 'https://example.test/new-account-order');
    expect(find.byKey(const Key('source-web')), findsOneWidget);
    expect(find.byKey(const Key('payout-account-page')), findsNothing);
  });

  testWidgets('没有主卡时不默认勾选，未勾选点提交只给提示', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var switchCalls = 0;
    final catalog = PayoutAccountCatalog(const <PayoutAccountGroup>[
      PayoutAccountGroup(
        title: 'E-wallet',
        type: '1',
        accounts: <PayoutAccount>[
          PayoutAccount(
            id: 'wallet-1',
            bankName: 'GCash',
            accountNumber: '09171234567',
            logoUrl: '',
            holderName: 'Ana Cruz Santos',
            maintenanceNote: '',
            isPrimary: false,
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(
      GetMaterialApp(
        builder: EasyLoading.init(),
        home: PayoutAccountsPage(
          catalog: catalog,
          productId: 'p1',
          orderNo: 'o1',
          switchAccount: ({required orderNo, required cardId}) async {
            switchCalls += 1;
            return 'https://example.test/updated-order';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 非主卡不能默认勾选。
    expect(
      find.byKey(const Key('payout-account-unselected-wallet-1')),
      findsOneWidget,
    );

    // 未勾选就点提交：不发请求，只给提示。
    await tester.tap(find.byKey(const Key('payout-account-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(switchCalls, 0);
    expect(find.text('Please select a payout account'), findsOneWidget);
  });

  testWidgets('维护中的账户展示兜底文案，仍可选中并提交', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // 不可用且服务端没下发文案：页面用通用兜底文案，卡片按带提示的高度渲染。
    final catalog = PayoutAccountCatalog(const <PayoutAccountGroup>[
      PayoutAccountGroup(
        title: 'Bank',
        type: '2',
        accounts: <PayoutAccount>[
          PayoutAccount(
            id: 'bank-1',
            bankName: 'BDO',
            accountNumber: '5490123232341238',
            logoUrl: '',
            holderName: 'Ana Cruz Santos',
            maintenanceNote: '',
            isPrimary: false,
            available: false,
          ),
        ],
      ),
    ]);
    final outcome = PayoutAccountFlowOutcome();
    String? selectedCardId;

    await tester.pumpWidget(_appWithSource(
      switchAccount: ({required orderNo, required cardId}) async {
        selectedCardId = cardId;
        return 'https://example.test/updated-order';
      },
    ));
    await tester.pumpAndSettle();
    await _openPayoutPage(tester: tester, outcome: outcome, catalog: catalog);
    await tester.pumpAndSettle();

    expect(find.textContaining('under maintenance'), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const Key('payout-account-card-bank-1'))).height,
      202,
    );
    // 维护中不预选（非主卡），点一下就能选中：维护状态只提示、不禁止（R-F17-3）。
    expect(
      find.byKey(const Key('payout-account-unselected-bank-1')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const Key('payout-account-card-bank-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('payout-account-selected-bank-1')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('payout-account-submit')));
    await tester.pumpAndSettle();

    expect(selectedCardId, 'bank-1');
    expect(outcome.changed, isTrue);
    expect(find.byKey(const Key('payout-account-page')), findsNothing);
  });

  testWidgets('可用账户即使带文案也不展示维护提示', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // uppropped=1（可用）但服务端仍下发了文案：按状态判断，不展示。
    final catalog = PayoutAccountCatalog(const <PayoutAccountGroup>[
      PayoutAccountGroup(
        title: 'Bank',
        type: '2',
        accounts: <PayoutAccount>[
          PayoutAccount(
            id: 'bank-1',
            bankName: 'BDO',
            accountNumber: '5490123232341238',
            logoUrl: '',
            holderName: 'Ana Cruz Santos',
            maintenanceNote: 'Scheduled maintenance tonight',
            isPrimary: true,
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(
      GetMaterialApp(
        builder: EasyLoading.init(),
        home: PayoutAccountsPage(
          catalog: catalog,
          productId: 'p1',
          orderNo: 'o1',
          switchAccount: ({required orderNo, required cardId}) async =>
              'https://example.test/updated-order',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Scheduled maintenance tonight'), findsNothing);
    expect(
      tester.getRect(find.byKey(const Key('payout-account-card-bank-1'))).height,
      150,
    );
  });

  testWidgets('换绑失败时停留在列表页，重试可以成功', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final outcome = PayoutAccountFlowOutcome();
    var attempts = 0;

    await tester.pumpWidget(_appWithSource(
      switchAccount: ({required orderNo, required cardId}) async {
        attempts += 1;
        if (attempts == 1) {
          throw const GatewayFailure('This account is under maintenance');
        }
        return 'https://example.test/updated-order';
      },
    ));
    await tester.pumpAndSettle();
    await _openPayoutPage(tester: tester, outcome: outcome, catalog: _catalog);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('payout-account-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // 失败被交给崩溃上报出口（debug 下即 FlutterError.reportError），测试里
    // 取走这条异常，确认它没有掀掉页面。
    expect(tester.takeException(), isA<GatewayFailure>());
    expect(attempts, 1);
    // 失败不替换来源页、不带走列表页：用户停在原页可以重试。
    expect(outcome.changed, isFalse);
    expect(find.byKey(const Key('payout-account-page')), findsOneWidget);
    expect(find.byKey(const Key('source-web')), findsNothing);

    await tester.tap(find.byKey(const Key('payout-account-submit')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(outcome.changed, isTrue);
    expect(outcome.redirectUrl, 'https://example.test/updated-order');
    expect(find.byKey(const Key('payout-account-page')), findsNothing);
    expect(find.byKey(const Key('source-web')), findsOneWidget);
  });

  testWidgets('缺订单号时点提交只提示参数缺失，不发换绑请求', (tester) async {
    tester.view.physicalSize = const Size(375, 939);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var switchCalls = 0;

    await tester.pumpWidget(
      GetMaterialApp(
        builder: EasyLoading.init(),
        home: PayoutAccountsPage(
          catalog: _catalog,
          productId: 'p1',
          orderNo: '',
          switchAccount: ({required orderNo, required cardId}) async {
            switchCalls += 1;
            return 'https://example.test/updated-order';
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('payout-account-submit')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(switchCalls, 0);
    expect(find.text('Missing account information'), findsOneWidget);
    expect(find.byKey(const Key('payout-account-page')), findsOneWidget);
  });
}

/// 来源页在底、放款账户页由用例自己压上去的导航栈。
Widget _appWithSource({required PayoutAccountSwitcher switchAccount}) {
  return GetMaterialApp(
    builder: EasyLoading.init(),
    initialRoute: '/home',
    getPages: <GetPage<dynamic>>[
      GetPage<void>(
        name: '/home',
        page: () => const Scaffold(
          body: Text('source-web', key: Key('source-web')),
        ),
      ),
      GetPage<void>(
        name: AppRoutes.payoutAccounts,
        page: () => PayoutAccountsPage(switchAccount: switchAccount),
      ),
    ],
  );
}

Future<void> _openPayoutPage({
  required WidgetTester tester,
  required PayoutAccountFlowOutcome outcome,
  required PayoutAccountCatalog catalog,
}) async {
  unawaited(
    Get.toNamed<void>(
      AppRoutes.payoutAccounts,
      arguments: <String, dynamic>{
        'catalog': catalog,
        'productId': 'p1',
        'orderNo': 'o1',
        PayoutAccountFlowOutcome.argumentKey: outcome,
      },
    ),
  );
  await tester.pumpAndSettle();
}

class _BindCardProbe extends StatefulWidget {
  const _BindCardProbe();

  @override
  State<_BindCardProbe> createState() => _BindCardProbeState();
}

class _BindCardProbeState extends State<_BindCardProbe> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final outcome = BindCardFlowOutcome.of(Get.arguments)
        ?..completed = true
        ..changed = true
        ..redirectUrl = 'https://example.test/new-account-order';
      expect(outcome, isNotNull);
      Get.back<void>();
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Text('bind-card-probe'));
  }
}
