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
///
/// 上报是旁路能力：它出问题绝不能影响业务，更不能把调用方后面的错误提示吃掉。
abstract final class CrashReporter {
  static TelemetrySink get _sink => AnalyticsService._sink;

  /// 是否正在把一条错误交给出口。
  ///
  /// 出口有可能绕回 `FlutterError.onError`：debug 出口就是
  /// `FlutterError.reportError`，而 `main()` 又把框架错误交回这里上报。不设闸
  /// 就会无限递归，栈溢出会打断调用点后面的流程——例如登录失败时，接口下发的
  /// 「验证码错误」文案还没来得及弹出来，异常就先把提示那一段掀掉了。
  static bool _forwarding = false;

  static void record(
    Object error,
    StackTrace stackTrace, {
    bool fatal = false,
  }) {
    // 递归进来的那一层直接丢弃：它上报的就是正在处理中的同一条错误。
    if (_forwarding) return;
    _forwarding = true;
    try {
      _sink.recordError(error, stackTrace, fatal: fatal);
    } catch (failure) {
      // 出口自己坏了只留一行日志：这里再抛就会一路掀掉业务代码的错误处理。
      if (kDebugMode) {
        debugPrint('[telemetry] crash report failed: $failure');
      }
    } finally {
      _forwarding = false;
    }
  }

  static void recordMessage(String message, {bool fatal = false}) {
    record(message, StackTrace.current, fatal: fatal);
  }
}
