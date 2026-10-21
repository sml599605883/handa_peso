import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/features/certification/identity_design.dart';
import 'package:handa_peso/features/certification/personal_information_models.dart';
import 'package:handa_peso/features/certification/widgets/certification_single_select_sheet.dart';

const _options = <PersonalInformationOption>[
  PersonalInformationOption(
    label: 'PayMaya e-wallet',
    value: '8',
    logoUrl: 'https://example.com/paymaya.png',
  ),
  PersonalInformationOption(
    label: 'GCash e-wallet',
    value: '6',
    logoUrl: 'https://example.com/gcash.png',
  ),
  PersonalInformationOption(
    label: 'GrabPay e-wallet',
    value: '15',
    logoUrl: 'https://example.com/grabpay.png',
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('单选弹层按设计坐标布局并显示选中态', (tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    showModalBottomSheet<PersonalInformationOption>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const CertificationSingleSelectSheet(
                        options: _options,
                        selectedValue: '6',
                      ),
                    ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(
      tester.getRect(
        find.byKey(const Key('certification-single-select-sheet')),
      ),
      const Rect.fromLTWH(0, 427, 375, 385),
    );
    expect(
      tester.getRect(
        find.byKey(const ValueKey<String>('certification-option-8')),
      ),
      const Rect.fromLTWH(24, 498, 327, 48),
    );
    expect(
      tester.getRect(
        find.byKey(const ValueKey<String>('certification-option-6')),
      ),
      const Rect.fromLTWH(24, 566, 327, 48),
    );
    expect(
      tester.getRect(
        find.byKey(const ValueKey<String>('certification-option-15')),
      ),
      const Rect.fromLTWH(24, 634, 327, 48),
    );
    expect(
      tester.getRect(find.byKey(const Key('certification-single-select-back'))),
      const Rect.fromLTWH(24, 441, 24, 24),
    );
    expect(
      tester.getRect(
        find.byKey(const Key('certification-single-select-submit')),
      ),
      const Rect.fromLTWH(78, 706, 220, 52),
    );
    expect(
      find.byKey(const ValueKey<String>('certification-option-selected-6')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('certification-option-selected-8')),
      findsNothing,
    );
  });

  testWidgets('没有 logo 时文案直接从行内边距开始', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 327,
            child: CertificationSingleSelectOptionRow(
              option: const PersonalInformationOption(
                label: 'Bank transfer',
                value: 'BANK',
              ),
              metrics: const IdentityMetrics(screenWidth: 375),
              selected: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('certification-option-logo-BANK')),
      findsNothing,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(
              const ValueKey<String>('certification-option-label-BANK'),
            ),
          )
          .dx,
      14,
    );
  });

  testWidgets('有 logo 时文案位于 32px logo 和 12px 间距之后', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 327,
            child: CertificationSingleSelectOptionRow(
              option: const PersonalInformationOption(
                label: 'GCash e-wallet',
                value: '6',
                logoUrl: 'https://example.com/gcash.png',
              ),
              metrics: const IdentityMetrics(screenWidth: 375),
              selected: true,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('certification-option-logo-6')),
      findsOneWidget,
    );
    expect(
      tester
          .getTopLeft(
            find.byKey(const ValueKey<String>('certification-option-label-6')),
          )
          .dx,
      58,
    );
  });
}
