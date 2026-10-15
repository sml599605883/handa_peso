import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/core/analytics/analytics_service.dart';

/// 转发时又绕回 [CrashReporter] 的出口。
///
/// 真机上这一圈是真实存在的：debug 出口调用 `FlutterError.reportError`，而
/// `main()` 又把框架错误接回 [CrashReporter.record]。
class _LoopingSink implements TelemetrySink {
  int recordCalls = 0;

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {
    recordCalls += 1;
    CrashReporter.record(error, stackTrace);
  }

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}

  @override
  void setUserProperty(String name, String? value) {}

  @override
  void setUserId(String? userId) {}
}

/// 自己就会抛异常的出口。
class _BrokenSink implements TelemetrySink {
  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {
    throw StateError('sink is broken');
  }

  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {}

  @override
  void setUserProperty(String name, String? value) {}

  @override
  void setUserId(String? userId) {}
}

void main() {
  test('上报出口绕回上报入口时不再递归', () {
    final sink = _LoopingSink();
    AnalyticsService.configure(sink);

    // 没有防重入闸时这里会一路递归到栈溢出。
    CrashReporter.record(StateError('boom'), StackTrace.current);

    // 只有最外层那一次真正交给了出口，递归进来的那层被丢弃。
    expect(sink.recordCalls, 1);
  });

  test('出口自己失败时也不把异常丢给调用方', () {
    AnalyticsService.configure(_BrokenSink());

    expect(() => CrashReporter.recordMessage('boom'), returnsNormally);
    expect(
      () => CrashReporter.record(StateError('boom'), StackTrace.current),
      returnsNormally,
    );
  });
}
