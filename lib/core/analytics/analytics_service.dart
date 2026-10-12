import 'package:flutter/foundation.dart';

/// 规范的埋点事件名称。
///
/// 把字符串集中在一处可避免拼写错误导致的数据丢失，也让审计哪些业务行为
/// 已接入埋点变得非常简单。
abstract final class AppEvents {
  static const appOpen = 'app_open';
  static const loginSubmit = 'login_submit';
  static const loginSuccess = 'login_success';
  static const applyNowTapped = 'apply_now_tapped';
  static const certificationStepCompleted = 'certification_step_completed';
  static const loanSubmitted = 'loan_submitted';
  static const repaymentViewed = 'repayment_viewed';
  static const supportTicketCreated = 'support_ticket_created';
  static const accountDeleted = 'account_deleted';
}

/// 埋点与崩溃上报的目标出口。
///
/// 默认实现仅在 debug 构建下打印日志。待原生配置文件就绪后，会在启动时
/// 注册 Firebase Analytics / Crashlytics 适配器，因此业务代码无需直接引入
/// 厂商 SDK。
abstract interface class TelemetrySink {
  void logEvent(String name, [Map<String, Object?> parameters = const {}]);
  void setUserProperty(String name, String? value);
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false});
  void setUserId(String? userId);
}

class DebugTelemetrySink implements TelemetrySink {
  @override
  void logEvent(String name, [Map<String, Object?> parameters = const {}]) {
    if (kDebugMode) {
      debugPrint('[telemetry] event=$name params=$parameters');
    }
  }

  @override
  void setUserProperty(String name, String? value) {
    if (kDebugMode) {
      debugPrint('[telemetry] userProperty $name=$value');
    }
  }

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stackTrace, library: 'handa_peso'),
    );
  }

  @override
  void setUserId(String? userId) {
    if (kDebugMode) {
      debugPrint('[telemetry] userId=$userId');
    }
  }
}

/// 静态外观（Facade），使调用点与具体厂商无关。
abstract final class AnalyticsService {
  static TelemetrySink _sink = DebugTelemetrySink();

  static void configure(TelemetrySink sink) {
    _sink = sink;
  }

  static void logEvent(String name, [Map<String, Object?> parameters = const {}]) {
    _sink.logEvent(name, parameters);
  }

  static void setUserProperty(String name, String? value) {
    _sink.setUserProperty(name, value);
  }

  static void setUserId(String? userId) {
    _sink.setUserId(userId);
  }
}

/// 崩溃上报的专用入口，确保失败始终可追溯。
abstract final class CrashReporter {
  static TelemetrySink get _sink => AnalyticsService._sink;

  static void record(Object error, StackTrace stackTrace, {bool fatal = false}) {
    _sink.recordError(error, stackTrace, fatal: fatal);
  }

  static void recordMessage(String message, {bool fatal = false}) {
    _sink.recordError(message, StackTrace.current, fatal: fatal);
  }
}
