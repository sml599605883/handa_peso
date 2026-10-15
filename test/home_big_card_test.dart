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

  testWidgets('点击大卡任意位置都触发申请，而不只是按钮', (tester) async {
    var taps = 0;
    await _pumpCard(tester, _card(), onApply: () => taps++);

    // 热区按设计稿覆盖卡片底板到按钮底部（14~361 / 142~514）。
    final hitArea = tester.getRect(find.byKey(HomeBigCard.cardTapKey));
    expect(hitArea.left, closeTo(14, 0.01));
    expect(hitArea.right, closeTo(361, 0.01));
    expect(hitArea.top, closeTo(142, 0.01));
    expect(hitArea.bottom, closeTo(514, 0.01));

    // 卡片底板内的金额面板（设计稿 332x148 @20,174）。
    await tester.tapAt(const Offset(180, 200));
    expect(taps, 1);

    // 卡片底板内的条款条（设计稿 323x58 @26,332）。
    await tester.tapAt(const Offset(180, 360));
    expect(taps, 2);

    // 底板下方的按钮同样是申请入口。
    await tester.tap(find.byKey(HomeBigCard.applyButtonKey));
    expect(taps, 3);
  });

  testWidgets('认证进度票据也在大卡热区内', (tester) async {
    var taps = 0;
    await _pumpCard(
      tester,
      _card(
        limitSteps: const <HomeLimitStep>[
          HomeLimitStep(title: '₱30,000', amountText: '₱30,000', reached: true),
        ],
      ),
      onApply: () => taps++,
    );

    // 票据区（设计稿 323x108 @26,404）随卡片一起属于大卡。
    await tester.tapAt(const Offset(180, 440));
    expect(taps, 1);
  });

  testWidgets('大卡上方的插画不是申请入口', (tester) async {
    var taps = 0;
    await _pumpCard(tester, _card(), onApply: () => taps++);

    await tester.tapAt(const Offset(180, 60));
    expect(taps, 0);
  });
}
