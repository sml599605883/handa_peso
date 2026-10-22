import 'dart:async';

typedef PushEventSource = Stream<Map<String, dynamic>> Function();
typedef PushRouteHandler = Future<void> Function(String route);

/// 接收原生通知点击下发的跳转目标，并按到达顺序派发。
///
/// 冷启动或启动门禁期间导航尚未就绪时先入队，待根页面挂载后再补发。
class PushRouteCoordinator {
  PushRouteCoordinator(this._events);

  static const eventType = 'push_route';

  final PushEventSource _events;
  final List<String> _queued = <String>[];
  StreamSubscription<Map<String, dynamic>>? _subscription;
  PushRouteHandler? _handler;
  bool _disposed = false;

  void start() {
    if (_subscription != null || _disposed) return;
    _subscription = _events().listen(_onEvent, onError: (_) {});
  }

  void attach(PushRouteHandler? handler) {
    _handler = handler;
    if (handler == null || _queued.isEmpty) return;
    scheduleMicrotask(_drain);
  }

  Future<void> dispose() async {
    _disposed = true;
    _handler = null;
    _queued.clear();
    await _subscription?.cancel();
    _subscription = null;
  }

  void _onEvent(Map<String, dynamic> event) {
    if (event['type']?.toString() != eventType) return;
    final target = event['url']?.toString().trim() ?? '';
    if (target.isEmpty) return;
    _queued.add(target);
    if (_handler != null) scheduleMicrotask(_drain);
  }

  void _drain() {
    final handler = _handler;
    if (handler == null) return;
    while (_queued.isNotEmpty) {
      unawaited(_dispatch(handler, _queued.removeAt(0)));
    }
  }

  Future<void> _dispatch(PushRouteHandler handler, String target) async {
    try {
      await handler(target);
    } catch (_) {
      // 一条通知失败不阻断后续通知。
    }
  }
}
