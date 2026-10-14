import 'package:flutter/material.dart';

import '../../core/analytics/analytics_service.dart';

/// 全局路由观察者，供页面订阅「返回」事件。
///
/// 页面通过 `RouteAware` 订阅它，即可在被上层路由覆盖后重新可见时刷新数据。
/// 泛型取 `ModalRoute<dynamic>`，因为本项目的命名路由都是 `GetPageRoute`。
final RouteObserver<ModalRoute<dynamic>> appRouteObserver =
    RouteObserver<ModalRoute<dynamic>>();

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
