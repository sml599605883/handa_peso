import 'dart:async';

import 'package:flutter/widgets.dart';

import 'report_service.dart';

/// 把应用生命周期转发给 [ReportService]。
///
/// 上报只关心“回到前台”：初次启动由 `start()` 负责，退到后台不需要上报动作，
/// 因此这里不做节流，直接转发即可。
class ReportLifecycleObserver with WidgetsBindingObserver {
  ReportLifecycleObserver(this._service);

  final ReportService _service;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_service.resumed());
    }
  }
}
