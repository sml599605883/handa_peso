import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

typedef StartupNetworkProbe = Future<bool> Function();
typedef StartupNetworkReadyBuilder = Widget Function();

/// 解析启动门禁所需的网关可达性。
///
/// 先探测编译内置的地址；失败时从远程配置链接拉取备用基础地址后再次探测。
/// [onReachable] 只会在某个地址成功响应后执行，避免设备名称查询打到失效的网关上。
///
/// 远程配置链接为空时该回退不生效，第一次探测即为最终判断。
Future<bool> probeStartupTransport(
  ApiClient apiClient, {
  String? remoteConfigUrl,
  Future<void> Function()? onReachable,
}) async {
  if (!await apiClient.probeTransport()) {
    final switched = await apiClient.applyRemoteBaseUrls(
      remoteConfigUrl: remoteConfigUrl,
    );
    if (!switched || !await apiClient.probeTransport()) {
      return false;
    }
  }

  if (onReachable != null) {
    await onReachable();
  }
  return true;
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
    this.retryOnResume = true,
    super.key,
  });

  final StartupNetworkProbe probe;
  final StartupNetworkReadyBuilder readyBuilder;
  final bool retryOnResume;

  @override
  State<StartupNetworkGate> createState() => _StartupNetworkGateState();
}

class _StartupNetworkGateState extends State<StartupNetworkGate>
    with WidgetsBindingObserver {
  bool _checking = false;
  bool _ready = false;
  bool _failed = false;
  bool _showLaunch = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (widget.retryOnResume && state == AppLifecycleState.resumed && _failed) {
      unawaited(_check());
    }
  }

  Future<void> _check() async {
    if (_checking || _ready) return;
    setState(() {
      _checking = true;
      _failed = false;
    });
    try {
      final available = await widget.probe();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _showLaunch = false;
        _ready = available;
        _failed = !available;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _showLaunch = false;
        _failed = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return widget.readyBuilder();
    if (_showLaunch) return const _LaunchPage();
    return _NetworkUnavailablePage(checking: _checking, onRetry: _check);
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
