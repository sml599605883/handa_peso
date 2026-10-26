import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/permissions/permission_coordinator.dart';

PermissionCoordinator _coordinatorFor(String status) =>
    PermissionCoordinator(requestLocationPermission: () async => status);

void main() {
  group('定位准入状态映射', () {
    test('原生状态决定调用方下一步做什么', () async {
      expect(
        await _coordinatorFor('authorized_when_in_use').requestLocationAccess(),
        LocationAccessDecision.granted,
      );
      expect(
        await _coordinatorFor('authorized_always').requestLocationAccess(),
        LocationAccessDecision.granted,
      );
      expect(
        await _coordinatorFor('denied').requestLocationAccess(),
        LocationAccessDecision.denied,
      );
      expect(
        await _coordinatorFor('restricted').requestLocationAccess(),
        LocationAccessDecision.restricted,
      );
      expect(
        await _coordinatorFor('service_disabled').requestLocationAccess(),
        LocationAccessDecision.serviceDisabled,
      );
      // 弹窗被系统打断（还没结论）或原生不可用时都不拦申请。
      expect(
        await _coordinatorFor('not_determined').requestLocationAccess(),
        LocationAccessDecision.unavailable,
      );
      expect(
        await _coordinatorFor('').requestLocationAccess(),
        LocationAccessDecision.unavailable,
      );
    });

    test('原生通道抛错时放行申请', () async {
      final coordinator = PermissionCoordinator(
        requestLocationPermission: () async => throw StateError('bridge down'),
      );

      expect(
        await coordinator.requestLocationAccess(),
        LocationAccessDecision.unavailable,
      );
    });
  });
}
