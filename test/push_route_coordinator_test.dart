import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/push/push_route_coordinator.dart';

void main() {
  test('导航未就绪时先排队，attach 后按顺序派发', () async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    final dispatched = <String>[];
    final coordinator = PushRouteCoordinator(() => events.stream);
    addTearDown(coordinator.dispose);

    coordinator.start();
    events
      ..add(<String, dynamic>{
        'type': PushRouteCoordinator.eventType,
        'url': 'ph://handa-peso/ios/Brusker',
      })
      ..add(<String, dynamic>{
        'type': PushRouteCoordinator.eventType,
        'url': 'http://h5.test/offer',
      });
    await Future<void>.delayed(Duration.zero);
    expect(dispatched, isEmpty);

    coordinator.attach((route) async => dispatched.add(route));
    await Future<void>.delayed(Duration.zero);

    expect(dispatched, <String>[
      'ph://handa-peso/ios/Brusker',
      'http://h5.test/offer',
    ]);
  });

  test('忽略非 push_route 与空地址事件', () async {
    final events = StreamController<Map<String, dynamic>>.broadcast();
    addTearDown(events.close);
    final dispatched = <String>[];
    final coordinator = PushRouteCoordinator(() => events.stream);
    addTearDown(coordinator.dispose);
    coordinator.start();
    coordinator.attach((route) async => dispatched.add(route));

    events
      ..add(<String, dynamic>{'type': 'push_token', 'token': 'abc'})
      ..add(<String, dynamic>{
        'type': PushRouteCoordinator.eventType,
        'url': '  ',
      });
    await Future<void>.delayed(Duration.zero);

    expect(dispatched, isEmpty);
  });
}
