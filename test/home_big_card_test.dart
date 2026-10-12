import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/money/money.dart';
import 'package:handa_peso/features/home/home_big_card.dart';

void main() {
  testWidgets('HomeBigCard renders the design copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 375,
              child: HomeBigCard(
                creditLimit: Money.fromMinor(5000000),
                onApply: () {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('HANDA PESO'), findsOneWidget);
    expect(find.text('Available up to'), findsOneWidget);
    // 两层（硬投影 + 渐变填充）绘制同一个金额。
    expect(find.text('₱50,000.00'), findsNWidgets(2));
    expect(find.text('Loan terms'), findsOneWidget);
    expect(find.text('180 Days'), findsOneWidget);
    expect(find.text('Interest rate'), findsOneWidget);
    expect(find.text('≤0.5% / Day'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Apply Now invokes the callback', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 375,
              child: HomeBigCard(
                creditLimit: Money.fromMinor(5000000),
                onApply: () => taps++,
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(HomeBigCard.applyButtonKey));
    expect(taps, 1);
  });
}
