import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:handa_peso/app/routes/app_routes.dart';
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
  tearDown(Get.reset);

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
