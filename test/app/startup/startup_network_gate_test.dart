import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/app/startup/startup_network_gate.dart';

void main() {
  testWidgets('holds the launch art while probing, then enters the app', (
    tester,
  ) async {
    final probe = Completer<bool>();
    await tester.pumpWidget(
      StartupNetworkGate(probe: () => probe.future, readyBuilder: _readyPage),
    );
    await tester.pump();

    expect(find.byKey(const Key('startup-launch')), findsOneWidget);
    expect(find.byKey(const Key('startup-network-retry')), findsNothing);
    expect(find.text('ready'), findsNothing);

    probe.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('ready'), findsOneWidget);
    expect(find.byKey(const Key('startup-launch')), findsNothing);
  });

  testWidgets('shows the retry page when the probe fails', (tester) async {
    await tester.pumpWidget(
      StartupNetworkGate(probe: () async => false, readyBuilder: _readyPage),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('startup-launch')), findsNothing);
    expect(find.byKey(const Key('startup-network-retry')), findsOneWidget);
    expect(
      find.textContaining('Network error, please try again later or'),
      findsOneWidget,
    );
    expect(find.text('ready'), findsNothing);
  });

  testWidgets('re-probes on retry tap and then enters the app', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () async {
          attempts++;
          return attempts > 1;
        },
        readyBuilder: _readyPage,
      ),
    );
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.text('ready'), findsNothing);

    await tester.tap(find.byKey(const Key('startup-network-retry')));
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('ready'), findsOneWidget);
  });

  testWidgets('does not start a duplicate probe while checking', (
    tester,
  ) async {
    final retryProbe = Completer<bool>();
    var attempts = 0;
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () {
          attempts++;
          return attempts == 1 ? Future.value(false) : retryProbe.future;
        },
        readyBuilder: _readyPage,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('startup-network-retry')));
    await tester.pump();
    expect(attempts, 2);

    await tester.tap(find.byKey(const Key('startup-network-retry')));
    await tester.pump();
    expect(attempts, 2);

    retryProbe.complete(false);
    await tester.pumpAndSettle();
  });

  testWidgets('回到前台时只在失败页补测一次，进入应用后不再补测', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () async {
          attempts++;
          return attempts > 1;
        },
        readyBuilder: _readyPage,
      ),
    );
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.byKey(const Key('startup-network-retry')), findsOneWidget);

    _leaveAndReturnToForeground(tester);
    await tester.pumpAndSettle();

    expect(attempts, 2);
    expect(find.text('ready'), findsOneWidget);

    _leaveAndReturnToForeground(tester);
    await tester.pumpAndSettle();

    expect(attempts, 2);
  });

  testWidgets('retryOnResume 关闭时回到前台不会自动补测', (tester) async {
    var attempts = 0;
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () async {
          attempts++;
          return false;
        },
        readyBuilder: _readyPage,
        retryOnResume: false,
      ),
    );
    await tester.pumpAndSettle();
    expect(attempts, 1);

    _leaveAndReturnToForeground(tester);
    await tester.pumpAndSettle();

    expect(attempts, 1);
    expect(find.byKey(const Key('startup-network-retry')), findsOneWidget);
  });

  testWidgets('首次探测进行中回到前台不会重复探测', (tester) async {
    var calls = 0;
    final probe = Completer<bool>();
    await tester.pumpWidget(
      StartupNetworkGate(
        probe: () {
          calls++;
          return probe.future;
        },
        readyBuilder: _readyPage,
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('startup-launch')), findsOneWidget);

    _leaveAndReturnToForeground(tester);
    await tester.pump();
    expect(calls, 1);

    probe.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('ready'), findsOneWidget);
  });
}

/// 模拟「切到后台再回到前台」，结束后前台状态已被还原。
void _leaveAndReturnToForeground(WidgetTester tester) {
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
}

Widget _readyPage() {
  return const Directionality(
    textDirection: TextDirection.ltr,
    child: Text('ready'),
  );
}
