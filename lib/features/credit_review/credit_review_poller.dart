import 'dart:async';

import '../../app/routes/app_routes.dart';
import '../../core/json/json_utils.dart';
import '../../core/network/gateway_reply.dart';

typedef CreditReviewRequest = Future<GatewayReply> Function();
typedef CreditReviewRoute = String Function();
typedef CreditReviewHomeVisibility = bool Function();
typedef CreditReviewRefresh = Future<void> Function();
typedef CreditReviewAdmission = Future<void> Function(String productId);
typedef CreditReviewLogger = void Function(String message);

/// 重新授信状态轮询器。
///
/// 它是常驻对象，不随等待页销毁而停止：用户离开页面后，授信成功时若首页
/// 可见则刷新首页；若仍在等待页，则自动继续产品准入。
class CreditReviewPoller {
  factory CreditReviewPoller({
    required CreditReviewRequest request,
    required CreditReviewRoute currentRoute,
    required CreditReviewHomeVisibility homeVisible,
    required CreditReviewRefresh refreshHome,
    required CreditReviewAdmission runAdmission,
    CreditReviewLogger? logger,
    Duration interval = const Duration(seconds: 10),
  }) {
    return CreditReviewPoller._(
      request,
      currentRoute,
      homeVisible,
      refreshHome,
      runAdmission,
      logger ?? ((_) {}),
      interval,
    );
  }

  CreditReviewPoller._(
    this._request,
    this._currentRoute,
    this._homeVisible,
    this._refreshHome,
    this._runAdmission,
    this._logger,
    this.interval,
  );

  final CreditReviewRequest _request;
  final CreditReviewRoute _currentRoute;
  final CreditReviewHomeVisibility _homeVisible;
  final CreditReviewRefresh _refreshHome;
  final CreditReviewAdmission _runAdmission;
  final CreditReviewLogger _logger;
  final Duration interval;

  Timer? _timer;
  String _productId = '';
  int _generation = 0;
  bool _requesting = false;
  bool _running = false;

  bool get isRunning => _running;

  void start(String productId) {
    final normalized = productId.trim();
    if (normalized.isEmpty) return;
    _generation += 1;
    _productId = normalized;
    _running = true;
    _requesting = false;
    _timer?.cancel();
    final generation = _generation;
    _timer = Timer(Duration.zero, () => _poll(generation));
  }

  void stop() {
    _generation += 1;
    _timer?.cancel();
    _timer = null;
    _running = false;
    _requesting = false;
  }

  Future<void> _poll(int generation) async {
    if (!_active(generation) || _requesting) return;
    _requesting = true;
    try {
      final reply = await _request();
      reply.orThrow();
      if (_active(generation) && _isComplete(reply)) {
        await _finish(generation);
        return;
      }
    } catch (error) {
      _logger('credit review poll failed: $error');
    }
    _requesting = false;
    if (!_active(generation)) return;
    _timer?.cancel();
    _timer = Timer(interval, () => _poll(generation));
  }

  bool _isComplete(GatewayReply reply) {
    final payload = reply.payload;
    return payload.intValue('murdering') == 1 ||
        payload.intValue('recklessly') == 1;
  }

  Future<void> _finish(int generation) async {
    if (!_active(generation)) return;
    final productId = _productId;
    late final String route;
    late final bool homeVisible;
    try {
      route = _currentRoute();
      homeVisible = _homeVisible();
    } catch (error) {
      stop();
      _logger('credit review completion failed: $error');
      return;
    }
    stop();
    try {
      if (route == AppRoutes.creditReview) {
        await _runAdmission(productId);
      } else if (homeVisible) {
        await _refreshHome();
      }
    } catch (error) {
      _logger('credit review completion failed: $error');
    }
  }

  bool _active(int generation) => _running && generation == _generation;
}
