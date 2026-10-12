import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';

/// 为每个入栈路由发送页面浏览埋点事件。
///
/// 集中在这里处理可保证导航漏斗完整，而无需每个页面自行记得上报。
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
