import 'package:flutter/widgets.dart';

import 'analytics_service.dart';

/// 把导航栈的变化翻译成 `screen_view` 埋点。
///
/// 只在“新页面进入前台”时上报（入栈与替换两种变化），退回上一页不算一次
/// 新的曝光，由该页自身的刷新逻辑负责，避免同一屏被重复计数。
///
/// `NavigatorObserver` 的这两个回调在基类里都是空实现，因此这里不必回调
/// `super`，直接上报即可。
class ScreenViewReporter extends NavigatorObserver {
  ScreenViewReporter();

  static const String _event = 'screen_view';
  static const String _screenField = 'screen_name';

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _report(route.settings.name);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) =>
      _report(newRoute?.settings.name);

  void _report(String? routeName) {
    if (routeName == null || routeName.isEmpty) return;
    AnalyticsService.logEvent(_event, <String, Object?>{
      _screenField: routeName,
    });
  }
}
