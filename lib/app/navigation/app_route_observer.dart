import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';

/// Emits analytics screen-view events for every pushed route.
///
/// Centralising this here guarantees a complete navigation funnel without each
/// screen remembering to report itself.
final RouteObserver<ModalRoute<void>> appRouteObserver =
    RouteObserver<ModalRoute<void>>();

class AnalyticsRouteObserver extends NavigatorObserver {
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (newRoute != null) _track(newRoute);
  }

  void _track(Route<dynamic> route) {
    final name = route.settings.name;
    if (name == null || name.isEmpty) return;
    AnalyticsService.logEvent('screen_view', {'screen_name': name});
  }
}
