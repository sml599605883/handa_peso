import 'dart:async';

import 'package:flutter/foundation.dart';

import '../analytics/analytics_service.dart';
import '../network/gateway_client.dart';
import '../network/gateway_failure.dart';
import 'report_bridge.dart';
import 'report_models.dart';
import 'report_payload.dart';
import 'report_scene.dart';
import 'report_store.dart';

/// 数据上报的唯一入口。
///
/// 负责把接口文档里的上报接口串成一条生命周期：启动/回前台、登录成功、
/// 认证与申贷过程中的风控埋点与 Apple token。业务页面只描述“发生了什么”，
/// 具体发哪条路由、字段如何拼、什么条件下跳过，全部收敛在这里。
///
/// 设计约束（与接口文档一致，改动需回查文档）：
/// - 位置与设备详情都要求登录态，没有会话时直接跳过；
/// - 未授权的定位不上报，只有经纬度齐全的快照才算有效；
/// - 设备详情必须加密后放在信封锁载荷字段里，不加密会直接被服务端丢弃；
/// - 推送 token 只在拿到非空值后上报，同一个 token 本次进程只成功上报一次
///   （登录成功例外：换账号要让服务端重新绑定）；空串绝不上报；
/// - 定位缓存只活在本次进程里，不落盘；
/// - 所有上报都是尽力而为：任何失败都不得影响用户流程。
class ReportService {
  ReportService({
    required this.gatewayClient,
    ReportStore? store,
    ReportNativeBridge? bridge,
    int Function()? clock,
    Future<void> Function(Duration)? pause,
    this.onInstallToken,
    this.locationTimeout = const Duration(seconds: 3),
  }) : store = store ?? ReportStore(),
       bridge = bridge ?? ReportNativeBridge(),
       _clock = clock ?? (() => DateTime.now().millisecondsSinceEpoch),
       _pause = pause ?? Future<void>.delayed;

  /// 当前秒级时间戳；登录等场景要在进入页面时先取一次作为埋点开始时间。
  static int nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final GatewayClient gatewayClient;
  final ReportStore store;
  final ReportNativeBridge bridge;

  /// 定位等待上限：超过就退回上次缓存，宁可报旧坐标也不让流程卡住。
  final Duration locationTimeout;

  /// google_market 上报成功后下发的渠道归因 token（文档字段 `guardsman`）。
  ///
  /// 本端没有接入归因 SDK，因此只把 token 交出去：接上 SDK 时在这里初始化，
  /// 没接时也不会把服务端下发的 token 丢掉。
  final Future<void> Function(String token)? onInstallToken;

  final int Function() _clock;
  final Future<void> Function(Duration) _pause;

  bool _started = false;
  bool _starting = false;
  bool _reportingInstallSource = false;

  /// 已经成功上报过的推送 token：同一个 token 不再发第二条请求。
  final Set<String> _reportedPushTokens = <String>{};

  /// 正在上报中的推送 token：启动路径与原生 `push_token` 事件可能同一刻触发，
  /// 用它在途去重，避免同一个 token 并发发两次。
  final Set<String> _reportingPushTokens = <String>{};
  bool _awaitingTracking = false;
  bool _requestingTracking = false;
  Future<ReportLocation?>? _pendingLocation;
  StreamSubscription<Map<String, dynamic>>? _events;

  /// 最近一次成功拿到的定位；只活在本次进程里（参考端的缓存同样不落盘）。
  ReportLocation? _lastLocation;

  /// 启动时调用一次：请求必要授权、登记 APNs、补报待上报的内容。
  Future<void> start() async {
    if (_started || _starting) return;
    _starting = true;
    try {
      final first = await store.markLaunched();
      _awaitingTracking = first;
      _started = true;
      _listenToNativeEvents();

      // 通知授权必须先弹：系统只在状态未决时展示弹窗，升级安装的用户也要经过
      // 这一次判断，之后的 APNs 注册才有意义。
      await bridge.requestNotificationPermission();
      // 通知弹窗与 ATT 弹窗不能在同一个瞬间接连弹出，留一点让 UIKit 收尾。
      await _pause(const Duration(milliseconds: 400));
      await _requestTrackingOnce();

      await _afterPermissions();
      unawaited(reportLocationAndDevice());
    } catch (error) {
      _log(error);
    } finally {
      _starting = false;
    }
  }

  /// 回到前台：补一次渠道归因与推送 token。
  ///
  /// 推送 token 这里是非强制上报：只在还没成功上报过（上次失败、或系统换了
  /// 新 token）时才真正发请求，避免每次切前台都重发同一条。
  Future<void> resumed() async {
    if (!_started) return;
    unawaited(reportInstallSource());
    unawaited(reportPushToken());
  }

  /// 回到前台补弹一次 ATT。
  ///
  /// 启动阶段的系统弹窗有被吞掉的可能（App 还没激活、和通知弹窗撞在一起时
  /// 会直接回 `not_determined` 且不展示），而 ATT 只在状态未决时才能弹一次。
  /// 不补这一下，本次进程内 IDFA 会一直是空串，[reportInstallSource] 整条
  /// 归因链路都会静默跳过——peso_shield 同样在每次回前台重试。
  Future<void> retryTrackingPermission() async {
    if (!_started) return;
    try {
      if (!await _trackingUndecided()) return;
      // 与启动时一致：先让 UIKit 收尾回前台的转场，再弹系统弹窗。
      await _pause(const Duration(milliseconds: 400));
      // 等待期间启动那次请求可能已经有结论，弹之前再确认一次。
      if (!await _trackingUndecided()) return;
      await _requestTrackingOnce();
      await reportInstallSource();
    } catch (error) {
      _log(error);
    }
  }

  /// ATT 是否还没做过选择；原生不可用（空串）按“已有结论”处理，不去打扰用户。
  Future<bool> _trackingUndecided() async {
    final status = await bridge.trackingStatus();
    return status == ReportNativeBridge.trackingNotDetermined;
  }

  /// 同一时刻只发一次 ATT 请求：启动那次还在等用户作答时，回前台不得再弹一次。
  Future<void> _requestTrackingOnce() async {
    if (_requestingTracking) return;
    _requestingTracking = true;
    try {
      await bridge.requestTrackingPermission();
    } finally {
      _requestingTracking = false;
    }
  }

  /// 登录成功：记录登录时间，补报注册埋点、渠道归因、定位与设备详情。
  ///
  /// 这里只上报已有授权能够取得的定位，不主动申请权限；定位授权由点击申请后
  /// 的业务链路触发，避免用户刚登录就看到与当前操作无关的系统弹窗。
  ///
  /// [registeredAtSeconds] 是注册时长的起点，由登录页在打开时取一次、之后每次
  /// 成功获取验证码再刷新（参考端同款）；不传则退化为“从现在开始计时”，时长会偏短。
  Future<void> loginSucceeded({int? registeredAtSeconds}) async {
    await store.saveLoginAt(_clock());
    // 注册埋点的结束时间固定取「登录成功」这一刻，后续异步上报不能影响时长。
    final endedAtSeconds = _clock() ~/ 1000;
    unawaited(
      _reportAfterLogin(
        startedAtSeconds: registeredAtSeconds ?? endedAtSeconds,
        endedAtSeconds: endedAtSeconds,
      ),
    );
  }

  Future<void> _reportAfterLogin({
    required int startedAtSeconds,
    required int endedAtSeconds,
  }) async {
    unawaited(
      reportScene(
        scene: ReportScene.registration,
        startedAtSeconds: startedAtSeconds,
        endedAtSeconds: endedAtSeconds,
      ),
    );
    unawaited(reportInstallSource());
    unawaited(reportLocationAndDevice());
    // 登录成功强制重报一次：换账号后服务端要按当前用户重新绑定这个 token。
    unawaited(reportPushToken(force: true));
  }

  /// 上报风控埋点。
  ///
  /// 只有 [ReportScene.registration] 不需要产品 ID；其余场景由拥有页面的调用方
  /// 在进入点先取 [nowSeconds] 作为 [startedAtSeconds]。
  ///
  /// 结束时间在函数入口就取好：后面的设备快照与定位都是异步的（定位最多还要等
  /// [locationTimeout]），等它们回来再取值会把埋点时长算长。参考端同样是在进入
  /// 上报函数的那一刻取 endTime。
  Future<void> reportScene({
    required String scene,
    String productId = '',
    String orderNo = '',
    required int startedAtSeconds,
    int? endedAtSeconds,
  }) async {
    final endTimeSeconds = endedAtSeconds ?? _clock() ~/ 1000;
    try {
      final snapshot = await bridge.deviceSnapshot();
      final location = await _locationWithFallback();
      await gatewayClient.reportEvent(
        body: ReportPayload.riskBody(
          productId: productId,
          sceneType: scene,
          orderNo: orderNo,
          riskDeviceId: snapshot?.riskDeviceId ?? '',
          advertisingId: snapshot?.advertisingId ?? '',
          location: location,
          startTimeSeconds: '$startedAtSeconds',
          endTimeSeconds: '$endTimeSeconds',
        ),
      );
    } catch (error) {
      _log(error);
    }
  }

  /// 上报定位与设备详情；两者都要求登录态。
  Future<void> reportLocationAndDevice() async {
    if (!await _hasSession()) return;
    try {
      final location = await _locationWithFallback();
      if (location != null && location.isValid) {
        try {
          await gatewayClient.reportLocation(
            body: ReportPayload.locationBody(location),
          );
        } catch (error) {
          _log(error);
        }
      }
      await _reportDeviceProfile(location);
    } catch (error) {
      _log(error);
    }
  }

  /// 上报 Apple 推送 token。
  ///
  /// 与参考端（dali_cash / peso_shield / fund_nexus 的同名实现）对齐：
  /// - 本机还没拿到 token 时**不上报**。空串打到服务端只会把已登记的 token
  ///   覆盖掉，推送就此静默失效；真正的 token 由原生的 `push_token` 事件补发
  ///   （[start] 里已经订阅，原生 `onListen` 也会补发当前值）。
  /// - 同一个 token 只成功上报一次。启动路径、回前台、事件回调会从多处触发，
  ///   不拦就是同一 token 连发多条；失败不记账，之后还能重试。
  /// - [force] 只给登录成功用：换账号后要让服务端把 token 重新绑到当前用户。
  Future<void> reportPushToken({bool force = false}) async {
    String? token;
    try {
      token = (await bridge.pushToken()).trim();
      if (token.isEmpty) return;
      if (!force && _reportedPushTokens.contains(token)) return;
      if (!_reportingPushTokens.add(token)) return;
      try {
        await gatewayClient.reportPushToken(token: token);
        _reportedPushTokens.add(token);
      } finally {
        _reportingPushTokens.remove(token);
      }
    } catch (error) {
      _log(error);
    }
  }

  /// google_market 上报：渠道归因用的设备标识。
  ///
  /// ATT 未决或未授权时 IDFA 不可用，服务端也拿不到归因结果，因此直接跳过，
  /// 等授权结果出来（[start] 里会再试一次）。没有跨启动的去重签名——参考端每次
  /// 启动、每次登录都会上报，客户端记住签名会让归因 token 从此不再刷新。
  Future<void> reportInstallSource() async {
    if (_reportingInstallSource) return;
    try {
      final status = await bridge.trackingStatus();
      if (status.isEmpty ||
          status == ReportNativeBridge.trackingNotDetermined) {
        return;
      }
      final snapshot = await bridge.deviceSnapshot();
      final idfv = snapshot?.idfv ?? '';
      if (idfv.isEmpty) return;

      _reportingInstallSource = true;
      try {
        final reply = await gatewayClient.reportInstallSource(
          deviceId: idfv,
          advertisingId: snapshot?.advertisingId ?? '',
        );
        await _deliverInstallToken(reportText(reply.payload['guardsman']));
      } finally {
        _reportingInstallSource = false;
      }
    } catch (error) {
      _log(error);
    }
  }

  /// 上报当前定位快照；供需要单独上报位置的产品流程使用。
  Future<void> reportCurrentLocation() async {
    if (!await _hasSession()) return;
    final location = await _locationWithFallback();
    if (location == null || !location.isValid) return;
    try {
      await gatewayClient.reportLocation(
        body: ReportPayload.locationBody(location),
      );
    } catch (error) {
      _log(error);
    }
  }

  /// 把服务端下发的归因 token 交给注入的实现；未接入时静默跳过。
  Future<void> _deliverInstallToken(String token) async {
    final handler = onInstallToken;
    if (token.isEmpty || handler == null) return;
    try {
      await handler(token);
    } catch (error) {
      _log(error);
    }
  }

  Future<void> dispose() async {
    await _events?.cancel();
    _events = null;
  }

  /// 授权流程结束后的收尾：渠道归因、APNs 注册、推送 token。
  ///
  /// `registerForRemoteNotifications` 只是登记，token 要等系统回调才会回到原生
  /// 侧；这里紧接着读一次通常还是空串，[reportPushToken] 会直接跳过，真正的
  /// 上报由原生 `push_token` 事件触发。
  Future<void> _afterPermissions() async {
    _awaitingTracking = false;
    await reportInstallSource();
    await bridge.registerForRemoteNotifications();
    await reportPushToken();
  }

  Future<void> _reportDeviceProfile(ReportLocation? location) async {
    try {
      final snapshot = await bridge.deviceSnapshot();
      if (snapshot == null) return;
      final plaintext = ReportPayload.deviceJson(
        snapshot: snapshot,
        location: location,
        lastLoginAtMillis: await store.loginAt(),
        nowMillis: _clock(),
      );
      await gatewayClient.reportDeviceProfile(
        encryptedPayload: gatewayClient.cipher.encipher(plaintext),
      );
    } catch (error) {
      _log(error);
    }
  }

  /// 取一次定位：并发调用共用同一个请求；超时或失败退回进程内缓存。
  Future<ReportLocation?> _locationWithFallback() async {
    try {
      final pending = _pendingLocation ??= _loadLocation();
      final location = await pending.timeout(locationTimeout);
      if (location != null && location.isValid) return location;
    } catch (_) {
      // 定位超时/失败都走缓存兜底。
    } finally {
      _pendingLocation = null;
    }
    return _lastLocation;
  }

  Future<ReportLocation?> _loadLocation() async {
    try {
      final location = await bridge.location();
      if (location != null && location.isValid) {
        _lastLocation = location;
      }
      return location;
    } catch (error) {
      _log(error);
      return null;
    }
  }

  void _listenToNativeEvents() {
    _events ??= bridge.events().listen((event) {
      final type = reportText(event['type']);
      if (type == 'push_token') unawaited(reportPushToken());
      if (type == 'tracking_status_changed' &&
          _awaitingTracking &&
          reportText(event['status']) !=
              ReportNativeBridge.trackingNotDetermined) {
        unawaited(reportInstallSource());
      }
    }, onError: _log);
  }

  Future<bool> _hasSession() async =>
      (await gatewayClient.settings.localSession.readSessionId()).isNotEmpty;

  /// 上报失败只留日志：它既不该打断用户流程，也不该把 Crashlytics 刷满。
  /// 非网络类的意外错误仍然记一条非致命事件，便于回溯代码缺陷。
  void _log(Object error) {
    debugPrint('[HandReport] ${error.runtimeType}: $error');
    if (error is! GatewayFailure) {
      CrashReporter.recordMessage('report failed: $error');
    }
  }
}
