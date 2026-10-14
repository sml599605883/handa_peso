import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/features/home/home_big_card.dart';
import 'package:handa_peso/features/home/home_data.dart';

/// 构造一张覆盖设计稿 02-01 / 02-02 的主卡片数据。
HomeLoanCard _card({
  String productName = 'Handa Peso',
  String amountText = '₱50,000',
  String processText =
      'Complete the authentication in just 3 minutes and get ₱60,000',
  List<HomeLimitStep> limitSteps = const <HomeLimitStep>[],
  List<HomePeriodTerm> periodTerms = const <HomePeriodTerm>[],
}) {
  return HomeLoanCard(
    productId: 'main',
    productName: productName,
    logoUrl: '',
    amountText: amountText,
    amountCaption: 'Available up to',
    termText: '180 Days',
    termCaption: 'Loan terms',
    rateText: '≤0.5% / Day',
    rateCaption: 'Interest rate',
    processText: processText,
    limitSteps: limitSteps,
    periodTerms: periodTerms,
  );
}

Future<void> _pumpCard(
  WidgetTester tester,
  HomeLoanCard card, {
  VoidCallback? onApply,
}) async {
  tester.view.physicalSize = const Size(375, 812);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: HomeBigCard(card: card, onApply: onApply ?? () {}),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('单期卡片按设计稿渲染文案与金额', (tester) async {
    await _pumpCard(tester, _card());

    expect(find.text('HANDA PESO'), findsOneWidget);
    expect(find.text('Available up to'), findsOneWidget);
    // 金额绘制两层：2px 硬投影 + 银色渐变填充。
    expect(find.text('₱50,000'), findsNWidgets(2));
    expect(find.text('Loan terms'), findsOneWidget);
    expect(find.text('180 Days'), findsOneWidget);
    expect(find.text('Interest rate'), findsOneWidget);
    expect(find.text('≤0.5% / Day'), findsOneWidget);
    expect(
      find.text(
        'Complete the authentication in just 3 minutes and get ₱60,000',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('未认证时的按钮落在设计稿 458 位置', (tester) async {
    await _pumpCard(tester, _card());

    final button = tester.getRect(find.byKey(HomeBigCard.applyButtonKey));
    expect(button.left, closeTo(48, 0.01));
    expect(button.top, closeTo(458, 0.01));
    expect(button.width, closeTo(278, 0.01));
    expect(button.height, closeTo(56, 0.01));
  });

  testWidgets('认证进行中时卡片向下延伸，按钮落在设计稿 577 位置', (tester) async {
    await _pumpCard(
      tester,
      _card(
        limitSteps: const <HomeLimitStep>[
          HomeLimitStep(title: '₱30,000', amountText: '₱30,000', reached: true),
          HomeLimitStep(title: '₱40,000', amountText: '₱40,000', reached: true),
          HomeLimitStep(title: '₱50,000', amountText: '₱50,000', reached: true),
          HomeLimitStep(
            title: '₱60,000',
            amountText: '₱60,000',
            reached: false,
          ),
        ],
      ),
    );

    expect(find.text('My unlocked limit'), findsOneWidget);
    for (final chip in ['₱30,000', '₱40,000', '₱50,000', '₱60,000']) {
      expect(find.text(chip), findsWidgets);
    }

    final button = tester.getRect(find.byKey(HomeBigCard.applyButtonKey));
    expect(button.top, closeTo(577, 0.01));
  });

  testWidgets('多期方案以期数徽标替代单期的两个条款', (tester) async {
    await _pumpCard(
      tester,
      _card(
        periodTerms: const <HomePeriodTerm>[
          HomePeriodTerm(
            period: '2',
            caption: 'Period',
            rateText: '≤0.5% / Day',
          ),
          HomePeriodTerm(
            period: '3',
            caption: 'Period',
            rateText: '≤0.5% / Day',
          ),
        ],
      ),
    );

    expect(find.text('Loan terms'), findsNothing);
    expect(find.text('Interest rate'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Period'), findsNWidgets(2));
    expect(find.text('≤0.5% / Day'), findsNWidgets(2));

    // 多期与默认态高度一致，按钮同样停在 458。
    expect(
      tester.getRect(find.byKey(HomeBigCard.applyButtonKey)).top,
      closeTo(458, 0.01),
    );
  });

  testWidgets('点击 Apply Now 触发回调', (tester) async {
    var taps = 0;
    await _pumpCard(tester, _card(), onApply: () => taps++);

    await tester.tap(find.byKey(HomeBigCard.applyButtonKey));
    expect(taps, 1);
  });
}
