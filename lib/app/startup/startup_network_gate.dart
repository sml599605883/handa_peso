import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/gateway_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

typedef StartupNetworkProbe = Future<bool> Function();
typedef StartupNetworkReadyBuilder = Widget Function();

/// 门禁通过、真实界面首帧渲染完成后的一次性回调。
///
/// 上报与系统授权弹窗（通知、ATT）挂在这里：等界面真正出来再弹，
/// 弹窗才不会盖在启动图上（与 peso_shield 的启动流程一致）。
typedef StartupReadyCallback = void Function();

/// 上报一次动态域名切换的日志载荷（app上报 `khedas=1`）。
typedef EndpointSwitchReporter = Future<void> Function(String payload);

/// 解析启动门禁所需的网关可达性。
///
/// 先探测编译内置的地址；失败时从远程配置链接拉取备用基础地址后再次探测。
/// [onReachable] 只会在某个地址成功响应后执行，避免设备名称查询打到失效的网关上。
/// 真正发生换址时，会把本次过程累积的日志交给 [reportSwitch] 上报（best-effort）。
///
/// 远程配置链接为空时该回退不生效，第一次探测即为最终判断。
Future<bool> probeStartupTransport(
  GatewayClient gatewayClient, {
  String? spareSourceUrl,
  Future<void> Function()? onReachable,
  EndpointSwitchReporter? reportSwitch,
}) async {
  final logs = <String>[];
  void log(String message) {
    logs.add('${DateTime.now().toIso8601String()} $message');
  }

  final builtInHost = _hostOf(gatewayClient.settings.apiOrigin);
  log('launch probe opened against built-in host $builtInHost');

  if (await gatewayClient.probeReachability()) {
    log('built-in host $builtInHost answered; nothing to switch');
  } else {
    log('built-in host $builtInHost stayed silent');

    final switched = await gatewayClient.refreshOrigins(
      sourceUrl: spareSourceUrl,
    );
    if (!switched) {
      log('no spare host source configured; staying on $builtInHost');
      return false;
    }

    final spareHost = _hostOf(gatewayClient.settings.apiOrigin);
    log('spare host $spareHost read from the config source; verifying');

    if (!await gatewayClient.probeReachability()) {
      log('spare host $spareHost stayed silent too; giving up the switch');
      return false;
    }

    log('spare host $spareHost answered; moving traffic $builtInHost -> $spareHost');

    final reporter = reportSwitch;
    if (reporter != null) {
      unawaited(_reportSwitchQuietly(reporter, jsonEncode(logs)));
    }
  }

  final reachable = onReachable;
  if (reachable != null) {
    await reachable();
  }
  return true;
}

String _hostOf(String url) => Uri.tryParse(url)?.host ?? url;

Future<void> _reportSwitchQuietly(
  EndpointSwitchReporter report,
  String payload,
) async {
  try {
    await report(payload);
  } catch (_) {
    // 换址上报是尽力而为的，绝不影响启动。
  }
}

/// 门禁所处的阶段。
enum _GateStage {
  /// 首次探测：启动图持续停留在屏幕上。
  launch,

  /// 探测成功，改为构建真正的应用界面。
  ready,

  /// 探测失败，停在失败页等用户重试。
  offline,

  /// 用户在失败页触发的重试，探测进行中。
  retrying,
}

/// 在网关可达之前，让启动图一直停留在屏幕上。
///
/// 与 fund_nexus 的启动流程保持一致：传输层探测运行期间保持启动页可见，
/// 失败时提供显式的重试入口（并在应用回到前台时自动重试），
/// 只有在网关响应后才构建真正的应用界面。
class StartupNetworkGate extends StatefulWidget {
  const StartupNetworkGate({
    required this.probe,
    required this.readyBuilder,
    this.onReady,
    this.retryOnResume = true,
    super.key,
  });

  final StartupNetworkProbe probe;
  final StartupNetworkReadyBuilder readyBuilder;

  /// 真正进入应用（首帧渲染完成）后回调一次；失败页的重试成功后同样会触发。
  final StartupReadyCallback? onReady;

  /// 失败页停留期间，应用回到前台是否自动再探测一次。
  final bool retryOnResume;

  @override
  State<StartupNetworkGate> createState() => _StartupNetworkGateState();
}

class _StartupNetworkGateState extends State<StartupNetworkGate> {
  _GateStage _stage = _GateStage.launch;
  late final AppLifecycleListener _resumeWatcher;
  bool _readyNotified = false;

  @override
  void initState() {
    super.initState();
    _resumeWatcher = AppLifecycleListener(onResume: _retryAfterResume);
    WidgetsBinding.instance.addPostFrameCallback((_) => _runProbe());
  }

  @override
  void dispose() {
    _resumeWatcher.dispose();
    super.dispose();
  }

  /// 回到前台时，只有停在失败页才值得再试一次。
  void _retryAfterResume() {
    if (!widget.retryOnResume || _stage != _GateStage.offline) return;
    unawaited(_runProbe());
  }

  /// 探测一次传输层可达性；同一时刻只允许一次探测在跑。
  Future<void> _runProbe() async {
    if (_stage != _GateStage.launch && _stage != _GateStage.offline) return;
    final firstAttempt = _stage == _GateStage.launch;
    final probe = widget.probe;
    setState(() {
      _stage = firstAttempt ? _GateStage.launch : _GateStage.retrying;
    });

    bool reachable;
    try {
      reachable = await probe();
    } catch (_) {
      reachable = false;
    }
    if (!mounted) return;
    setState(() {
      _stage = reachable ? _GateStage.ready : _GateStage.offline;
    });
    if (reachable) {
      _notifyReady();
    }
  }

  /// 网关可达后通知调用方「真实界面已经出来」，只通知一次。
  ///
  /// 走帧后回调：此时 root page 已经绘制完，通知/ATT 系统弹窗才会叠在应用界面上，
  /// 而不是盖着启动图。
  void _notifyReady() {
    if (_readyNotified) return;
    _readyNotified = true;
    final onReady = widget.onReady;
    if (onReady == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      onReady();
    });
  }

  @override
  Widget build(BuildContext context) {
    switch (_stage) {
      case _GateStage.ready:
        return widget.readyBuilder();
      case _GateStage.launch:
        return const _LaunchPage();
      case _GateStage.offline:
      case _GateStage.retrying:
        return _NetworkUnavailablePage(
          checking: _stage == _GateStage.retrying,
          onRetry: _runProbe,
        );
    }
  }
}

class _LaunchPage extends StatelessWidget {
  const _LaunchPage();

  static const _launchAsset = 'assets/launch.png';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: AppColors.surface,
        body: SizedBox.expand(
          child: Image.asset(
            _launchAsset,
            key: const Key('startup-launch'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
      ),
    );
  }
}

class _NetworkUnavailablePage extends StatelessWidget {
  const _NetworkUnavailablePage({
    required this.checking,
    required this.onRetry,
  });

  final bool checking;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: AppColors.pageBackgroundGradient,
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.wifi_off_rounded,
                      key: Key('startup-network-illustration'),
                      size: 96,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'Network error, please try again later or\n'
                      'contact our customer service',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 14,
                        height: 18 / 14,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.pill),
                          gradient: AppColors.heroGradient,
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadow,
                              offset: Offset(0, 3),
                              blurRadius: 5,
                            ),
                          ],
                        ),
                        child: TextButton(
                          key: const Key('startup-network-retry'),
                          onPressed: checking ? null : onRetry,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.textOnPrimary,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AppRadius.pill,
                              ),
                            ),
                          ),
                          child: Text(
                            checking ? 'Checking...' : 'Try Again',
                            style: const TextStyle(
                              color: AppColors.textOnPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              height: 17 / 14,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
