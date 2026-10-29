import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/app/theme/app_colors.dart';
import 'package:handa_peso/features/mine/account_retention_dialog.dart';

/// 需求文档 M20-3 的按钮文案表（缺陷 `reczz28SlNC3NUCI`）：
/// 右侧暖橙 = 保留键，左侧灰色 = 动作键。
///
/// 这里刻意写字面量而不是引用实现里的常量：实现被改错时测试才拦得住。
const Map<AccountExitAction, ({String keep, String action})> _copyTable =
    <AccountExitAction, ({String keep, String action})>{
      AccountExitAction.logout: (keep: 'Keep Rates', action: 'Log Out'),
      AccountExitAction.deleteAccount: (
        keep: 'Keep Offers',
        action: 'Delete',
      ),
    };

const Key _keepButton = Key('account-retention-keep');
const Key _confirmButton = Key('account-retention-confirm');

/// 打开挽留弹窗。`size` 控制屏宽（375 = 设计基准），`textScale` 模拟系统字号。
Future<void> _pumpDialog(
  WidgetTester tester,
  AccountExitAction action, {
  Size size = const Size(375, 812),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              key: const Key('open-retention-dialog'),
              onPressed: () =>
                  showAccountRetentionDialog(context: context, action: action),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.byKey(const Key('open-retention-dialog')));
  await tester.pumpAndSettle();
}

/// 取按钮那枚胶囊容器的装饰。
BoxDecoration _buttonDecoration(WidgetTester tester, Key key) {
  final container = tester.widget<Container>(
    find.descendant(of: find.byKey(key), matching: find.byType(Container)).first,
  );
  return container.decoration! as BoxDecoration;
}

/// 按钮内某个文案实际渲染出来的外接矩形（`getRect` 会算上 `FittedBox` 的缩放）。
Rect _labelRect(WidgetTester tester, String label) =>
    tester.getRect(find.text(label));

void main() {
  group('按钮文案（M20-3 文案表）', () {
    test('四个常量与文案表逐字一致', () {
      expect(kAccountRetentionLogoutKeepLabel, 'Keep Rates');
      expect(kAccountRetentionLogoutActionLabel, 'Log Out');
      expect(kAccountRetentionDeleteKeepLabel, 'Keep Offers');
      expect(kAccountRetentionDeleteActionLabel, 'Delete');
    });

    for (final entry in _copyTable.entries) {
      final copy = entry.value;
      testWidgets('${entry.key.name}：右橙 = ${copy.keep}，左灰 = ${copy.action}', (
        tester,
      ) async {
        await _pumpDialog(tester, entry.key);

        // 每个弹窗只有这两枚按钮，旧文案不能再残留。
        expect(find.text(copy.keep), findsOneWidget);
        expect(find.text(copy.action), findsOneWidget);
        expect(find.text('Get Funds'), findsNothing);
        expect(find.text('Delete Account'), findsNothing);
        expect(find.text('Exit'), findsNothing);
        expect(find.text('Stay'), findsNothing);

        // 文案挂在正确的按钮上：保留词 -> 右橙，动作词 -> 左灰。
        expect(
          find.descendant(
            of: find.byKey(_keepButton),
            matching: find.text(copy.keep),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(_confirmButton),
            matching: find.text(copy.action),
          ),
          findsOneWidget,
        );

        // 颜色语义保持不变：左灰底、右橙渐变。
        final confirm = _buttonDecoration(tester, _confirmButton);
        expect(confirm.color, AppColors.accountMutedAction);
        expect(confirm.gradient, isNull);

        final keep = _buttonDecoration(tester, _keepButton);
        expect(keep.gradient, AppColors.accountWarmGradient);
        expect(keep.color, isNull);

        // 左右位置：灰色动作键在左，橙色保留键在右。
        final confirmCenter = tester.getCenter(find.byKey(_confirmButton));
        final keepCenter = tester.getCenter(find.byKey(_keepButton));
        expect(confirmCenter.dx, lessThan(keepCenter.dx));

        // 两枚按钮等宽（按钮行 295 减去 10 的间距）。
        expect(
          tester.getSize(find.byKey(_confirmButton)).width,
          moreOrLessEquals(142.5, epsilon: 0.01),
        );
      });
    }
  });

  group('长文案不溢出', () {
    for (final entry in _copyTable.entries) {
      for (final width in <double>[375, 320]) {
        for (final textScale in <double>[1, 1.8]) {
          testWidgets(
            '${entry.key.name} · 屏宽 ${width.toInt()} · 字号 ${textScale}x：两枚按钮文案都在胶囊内且不裁断',
            (tester) async {
              await _pumpDialog(
                tester,
                entry.key,
                size: Size(width, 812),
                textScale: textScale,
              );

              // 布局不能抛 RenderFlex overflow。
              expect(tester.takeException(), isNull);

              final copy = entry.value;
              for (final (key, label) in <(Key, String)>[
                (_confirmButton, copy.action),
                (_keepButton, copy.keep),
              ]) {
                final buttonRect = tester.getRect(find.byKey(key));
                final labelRect = _labelRect(tester, label);

                // 文案的可见外框必须落在按钮内部（留 0.5 的浮点容差）。
                expect(
                  labelRect.left,
                  greaterThanOrEqualTo(buttonRect.left - 0.5),
                  reason: '$label 左边缘超出按钮',
                );
                expect(
                  labelRect.right,
                  lessThanOrEqualTo(buttonRect.right + 0.5),
                  reason: '$label 右边缘超出按钮',
                );
                expect(
                  labelRect.top,
                  greaterThanOrEqualTo(buttonRect.top - 0.5),
                  reason: '$label 上边缘超出按钮',
                );
                expect(
                  labelRect.bottom,
                  lessThanOrEqualTo(buttonRect.bottom + 0.5),
                  reason: '$label 下边缘超出按钮',
                );

                // 不裁断：不用省略号，段落也没有因宽度不够而溢出。
                final text = tester.widget<Text>(find.text(label));
                expect(text.maxLines, 1);
                expect(text.overflow, isNot(TextOverflow.ellipsis));
                final paragraph = tester.renderObject<RenderParagraph>(
                  find.text(label),
                );
                expect(
                  paragraph.didExceedMaxLines,
                  isFalse,
                  reason: '$label 被截断',
                );
              }

              // 设计尺寸不动（整卡 335x294、按钮行 295x52 只是按屏宽等比缩放）。
              final scale = width / 375;
              final card = tester.getRect(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is Image &&
                      widget.image is AssetImage &&
                      (widget.image as AssetImage).assetName.contains(
                        'retention_card',
                      ),
                ),
              );
              expect(
                card.width,
                moreOrLessEquals(335 * scale, epsilon: 0.01),
              );
              expect(
                card.height,
                moreOrLessEquals(294 * scale, epsilon: 0.01),
              );
              expect(
                tester.getSize(find.byKey(_keepButton)).width,
                moreOrLessEquals((295 - 10) / 2 * scale, epsilon: 0.01),
              );
              expect(
                tester.getSize(find.byKey(_keepButton)).height,
                moreOrLessEquals(52 * scale, epsilon: 0.01),
              );
            },
          );
        }
      }
    }
  });
}
