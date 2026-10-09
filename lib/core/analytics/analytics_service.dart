import 'package:flutter/foundation.dart';

/// Canonical analytics event names.
///
/// Keeping the strings in one place prevents typo-driven data loss and makes it
/// trivial to audit which business actions are instrumented.
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

/// Destination for analytics and crash reports.
///
/// The default implementation only logs in debug builds. A Firebase Analytics /
/// Crashlytics adapter is registered at startup once the native config files are
/// provisioned, so no feature code needs to import a vendor SDK directly.
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

/// Static façade so call sites stay vendor-agnostic.
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

/// Dedicated entry point for crash reporting so failures are always attributable.
abstract final class CrashReporter {
  static TelemetrySink get _sink => AnalyticsService._sink;

  static void record(Object error, StackTrace stackTrace, {bool fatal = false}) {
    _sink.recordError(error, stackTrace, fatal: fatal);
  }

  static void recordMessage(String message, {bool fatal = false}) {
    _sink.recordError(message, StackTrace.current, fatal: fatal);
  }
}
