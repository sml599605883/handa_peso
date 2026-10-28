import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/navigation/app_navigator.dart';
import '../../app/navigation/h5_paths.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/client/platform_bridge.dart';
import '../../core/network/gateway_client.dart';
import '../../core/order/order_redirect.dart';
import '../../core/report/report_scene.dart';
import '../../core/report/report_service.dart';
import '../certification/identity_models.dart';
import '../certification/widgets/identity_retention_dialog.dart';
import 'h5_bridge.dart';

bool _isInlineScheme(String scheme) => switch (scheme.toLowerCase()) {
  'http' || 'https' || 'about' || 'data' || 'javascript' || 'file' => true,
  _ => false,
};

/// 进度回调不能把已经完成的主文档重新标记为加载中。
///
/// H5 在 `onLoadStop` 之后仍可能继续加载图片或接口。此时 WebView 进度可能
/// 回落或停在 99 以下，但不应该再次显示顶部进度条。
bool keepWebViewLoadingAfterProgress({
  required bool loading,
  required int progress,
}) {
  if (progress >= 100) return false;
  return loading;
}

/// 确认用款页地址里的产品 ID。
///
/// 当前服务端下发的是 `knife`（同一地址里 `redecorates` 是订单号、
/// `prefabricating` 是订单 ID）；其余键是旧包或接口文档登记过的别名，保留兼容。
String confirmationProductIdFromH5Url(String source) {
  final uri = Uri.tryParse(source.trim());
  if (uri == null) return '';
  final fragment = Uri.tryParse(uri.fragment);
  if (!H5Paths.isLoanConfirmation(uri)) return '';

  for (final key in const <String>[
    'knife',
    'drippier',
    'polarimetric',
    'productId',
    'cotype',
    'transported',
  ]) {
    final direct = uri.queryParameters[key]?.trim() ?? '';
    if (direct.isNotEmpty) return direct;
    final nested = fragment?.queryParameters[key]?.trim() ?? '';
    if (nested.isNotEmpty) return nested;
  }
  return '';
}

bool _isLoginTarget(String target) {
  final uri = Uri.tryParse(target);
  if (uri == null || uri.scheme != 'ph') return false;
  return uri.pathSegments.length == 2 &&
      uri.pathSegments.first == 'ios' &&
      uri.pathSegments.last == 'Disaccording';
}

/// 承载 H5 业务流程，并提供网页与原生之间的命令通道。
///
/// H5 负责具体页面展示；原生负责签名参数、登录态跳转、评分、订单重试与
/// 换绑等网页无法独立完成的动作。页面本身只接受 http(s) 地址，防止服务端
/// 配置异常时把 WebView 带入不可控内容。
class AppWebViewPage extends StatefulWidget {
  const AppWebViewPage({this.retentionImageProvider, super.key});

  /// 测试时注入本地图片，避免挽留弹窗依赖网络。
  final ImageProvider<Object>? retentionImageProvider;

  @override
  State<AppWebViewPage> createState() => _AppWebViewPageState();
}

class _AppWebViewPageState extends State<AppWebViewPage> {
  late final String _initialUrl;
  late final String _fallbackTitle;
  late final GatewayClient _gateway;
  late final PlatformBridge _platform;
  late final H5ActionDispatcher _dispatcher;

  InAppWebViewController? _controller;
  String _title = 'Details';
  bool _loading = true;
  bool _failed = false;
  bool _checkingRetention = false;
  bool _backInFlight = false;
  bool _replacingAccount = false;

  Uri? get _initialUri {
    final uri = Uri.tryParse(_initialUrl);
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  @override
  void initState() {
    super.initState();
    final arguments = Get.arguments;
    final values = arguments is Map
        ? Map<String, dynamic>.from(arguments)
        : const <String, dynamic>{};
    _initialUrl = values['url']?.toString().trim() ?? '';
    final title = values['title']?.toString().trim() ?? '';
    _fallbackTitle = title.isEmpty ? 'Details' : title;
    _title = _fallbackTitle;
    _gateway = Get.find<GatewayClient>();
    _platform = PlatformBridge();
    _dispatcher = _createDispatcher();
    AnalyticsService.logEvent('webview_open', <String, Object?>{
      'host': _initialUri?.host ?? '',
    });
  }

  H5ActionDispatcher _createDispatcher() {
    return H5ActionDispatcher(
      reportLoan:
          ({required productId, required orderNo, required startedAtSeconds}) {
            final reporter = Get.isRegistered<ReportService>()
                ? Get.find<ReportService>()
                : null;
            return reporter?.reportScene(
                  scene: ReportScene.applyFinished,
                  productId: productId,
                  orderNo: orderNo,
                  startedAtSeconds: startedAtSeconds,
                ) ??
                Future<void>.value();
          },
      openWebPage: (url) async {
        final uri = Uri.tryParse(url);
        if (uri == null || !_isInlineScheme(uri.scheme) || uri.host.isEmpty) {
          throw StateError('Invalid page URL');
        }
        await AppNavigator.toWebView(
          url: url,
          title: 'Details',
          replaceCurrent: true,
        );
      },
      openInternal: _openInternal,
      openExternalApp: _launchExternal,
      closePage: () async {
        if (Navigator.of(context).canPop()) Navigator.of(context).pop();
      },
      goHome: () async {
        await AppNavigator.toMain();
      },
      requestReview: _platform.requestAppReview,
      buildSignedQuery: _gateway.publicParametersFor,
      retryLoan: _retryLoan,
      replaceAccount: _replacePayoutAccount,
      showLoading: AppNavigator.showLoading,
      dismissLoading: AppNavigator.dismissLoading,
      showError: (message) async => AppNavigator.showError(message),
      nowSeconds: ReportService.nowSeconds,
    );
  }

  Future<void> _openInternal(String target) async {
    if (_isLoginTarget(target)) {
      // 登录态失效：导航层会清掉本地会话、收起这张 H5 再打开登录页。这里不等
      // 用户登录完——这张页面马上就不在栈里了。
      unawaited(AppNavigator.openTarget(target, title: _fallbackTitle));
      return;
    }
    final previousSession = await _sessionMarker();
    await AppNavigator.openTarget(target, title: _fallbackTitle);
    if (!mounted) return;
    final currentSession = await _sessionMarker();
    if (currentSession.isEmpty || currentSession == previousSession) return;
    await _reload();
  }

  Future<String> _sessionMarker() async {
    return _gateway.settings.localSession.readSessionId();
  }

  Future<bool> _launchExternal(Uri uri) async {
    try {
      if (!await canLaunchUrl(uri)) return false;
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  Future<String> _retryLoan(String orderNo) async {
    final reply = await _gateway.reorderExistingLoan(orderNo: orderNo);
    reply.orThrow();
    final target = orderRedirectUrlFrom(reply);
    if (target.isEmpty) throw StateError('Retry link is unavailable');
    return target;
  }

  Future<void> _replacePayoutAccount({
    required String productId,
    required String orderNo,
  }) async {
    if (_replacingAccount) return;
    _replacingAccount = true;
    try {
      final result = await AppNavigator.changePayoutAccount(
        productId: productId,
        orderNo: orderNo,
      );
      if (mounted && result.changed && result.redirectUrl.isNotEmpty) {
        await _replaceWithPage(result.redirectUrl);
      }
    } finally {
      _replacingAccount = false;
    }
  }

  Future<void> _replaceWithPage(String target) async {
    final uri = Uri.tryParse(target.trim());
    if (uri == null ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      throw StateError('Invalid result URL');
    }
    await AppNavigator.toWebView(
      url: uri.toString(),
      title: 'Details',
      replaceCurrent: true,
    );
  }

  Future<dynamic> _onBridgeCall(
    InAppWebViewController controller,
    String handler,
    List<dynamic> arguments,
  ) async {
    if (!mounted || !identical(controller, _controller)) {
      return const H5BridgeResult.error('WebView is inactive').toJson();
    }
    final message = H5BridgeMessage.decode(
      arguments.isEmpty ? null : arguments.first,
    );
    final result = await _dispatcher.dispatch(message);
    final script = result.callbackScript(handler, message.callbackId);
    if (script != null && mounted && identical(controller, _controller)) {
      await controller.evaluateJavascript(source: script);
    }
    return result.toJson();
  }

  Future<void> _goBack() async {
    if (_backInFlight) return;
    _backInFlight = true;
    try {
      final controller = _controller;
      var hasHistory = false;
      if (controller != null && identical(controller, _controller)) {
        hasHistory = await controller.canGoBack();
      }

      if (await _shouldStayForRetention(controller)) return;

      if (hasHistory && controller != null && mounted) {
        await _goBackInPage(controller);
        return;
      }
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } finally {
      _backInFlight = false;
    }
  }

  Future<bool> _shouldStayForRetention(
    InAppWebViewController? controller,
  ) async {
    if (_checkingRetention ||
        controller == null ||
        !identical(controller, _controller)) {
      return false;
    }
    _checkingRetention = true;
    try {
      final current = await controller.getUrl();
      final productId = confirmationProductIdFromH5Url(
        current?.toString() ?? '',
      );
      if (productId.isEmpty) return false;

      await AppNavigator.showLoading();
      IdentityRetentionPrompt? prompt;
      try {
        final reply = await _gateway.fetchRetentionPrompt(
          scene: '5',
          productId: productId,
        );
        reply.orThrow();
        prompt = IdentityRetentionPrompt.fromReply(reply);
      } catch (_) {
        return false;
      } finally {
        await AppNavigator.dismissLoading();
      }
      if (!mounted || !prompt.shouldShow) return false;
      return await showIdentityRetentionDialog(
        context,
        prompt: prompt,
        imageProvider: widget.retentionImageProvider,
      );
    } finally {
      _checkingRetention = false;
    }
  }

  Future<void> _goBackInPage(InAppWebViewController controller) async {
    final history = await controller.getCopyBackForwardList();
    final index = history?.currentIndex ?? -1;
    final items = history?.list ?? const <WebHistoryItem>[];
    if (index > 0 && index < items.length) {
      final current = Uri.tryParse(items[index].url?.toString() ?? '');
      final previous = Uri.tryParse(items[index - 1].url?.toString() ?? '');
      if (current != null &&
          previous != null &&
          current.fragment.isNotEmpty &&
          previous.fragment.isNotEmpty &&
          current.removeFragment() == previous.removeFragment()) {
        await controller.evaluateJavascript(source: 'window.history.go(-1);');
        return;
      }
    }
    await controller.goBack();
  }

  Future<NavigationActionPolicy> _handleNavigation(
    InAppWebViewController controller,
    NavigationAction action,
  ) async {
    final uri = action.request.url;
    if (uri == null) return NavigationActionPolicy.CANCEL;
    if (_isInlineScheme(uri.scheme)) return NavigationActionPolicy.ALLOW;

    if (uri.scheme == 'ph') {
      await _openInternal(uri.toString());
    } else {
      await _launchExternal(uri);
    }
    return NavigationActionPolicy.CANCEL;
  }

  Future<void> _reload() async {
    final controller = _controller;
    if (controller == null || !identical(controller, _controller)) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    await controller.reload();
  }

  void _appendHandlers(InAppWebViewController controller) {
    for (final handler in H5Bridge.handlers) {
      controller.addJavaScriptHandler(
        handlerName: handler,
        callback: (arguments) => _onBridgeCall(controller, handler, arguments),
      );
    }
  }

  @override
  void dispose() {
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uri = _initialUri;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_goBack());
      },
      child: Scaffold(
        backgroundColor: AppColors.surface,
        resizeToAvoidBottomInset: false,
        appBar: AppBar(
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.textStrong,
          elevation: 0,
          title: Text(_title),
          leading: IconButton(
            key: const Key('webview-back'),
            onPressed: _goBack,
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
          ),
        ),
        body: uri == null
            ? const _LoadFailure(message: 'This page could not be loaded.')
            : Stack(
                children: [
                  InAppWebView(
                    initialUrlRequest: URLRequest(url: WebUri.uri(uri)),
                    initialUserScripts: _webViewScripts,
                    initialSettings: InAppWebViewSettings(
                      javaScriptEnabled: true,
                      useShouldOverrideUrlLoading: true,
                      useHybridComposition: true,
                      isInspectable: kDebugMode,
                      supportZoom: false,
                      allowsLinkPreview: false,
                      mediaPlaybackRequiresUserGesture: true,
                      mixedContentMode:
                          MixedContentMode.MIXED_CONTENT_COMPATIBILITY_MODE,
                    ),
                    onWebViewCreated: (controller) {
                      _controller = controller;
                      _appendHandlers(controller);
                    },
                    shouldOverrideUrlLoading: _handleNavigation,
                    onPermissionRequest: (controller, request) async {
                      return PermissionResponse(
                        resources: request.resources,
                        action: PermissionResponseAction.DENY,
                      );
                    },
                    onLoadStart: (controller, url) {
                      if (!mounted || !identical(controller, _controller)) {
                        return;
                      }
                      setState(() {
                        _loading = true;
                        _failed = false;
                      });
                    },
                    onLoadStop: (controller, url) async {
                      if (!mounted || !identical(controller, _controller)) {
                        return;
                      }
                      // 跳转转圈一直挂到首屏出来：加载完成才收，站内跳转重复
                      // 触发时是空操作（见 `dismissNavigationLoading`）。
                      unawaited(AppNavigator.dismissNavigationLoading());
                      final pageTitle = await controller.getTitle();
                      if (!mounted) return;
                      setState(() {
                        _loading = false;
                        final title = pageTitle?.trim() ?? '';
                        if (title.isNotEmpty) _title = title;
                      });
                    },
                    onProgressChanged: (controller, progress) {
                      if (!mounted || !identical(controller, _controller)) {
                        return;
                      }
                      setState(() {
                        _loading = keepWebViewLoadingAfterProgress(
                          loading: _loading,
                          progress: progress,
                        );
                      });
                    },
                    onReceivedError: (controller, request, error) {
                      if (!mounted ||
                          !identical(controller, _controller) ||
                          request.isForMainFrame != true) {
                        return;
                      }
                      // 首屏打不开时不能再等加载完成，转圈立刻收掉，让用户看到
                      // 页面自己的失败提示与重试。
                      unawaited(AppNavigator.dismissNavigationLoading());
                      setState(() {
                        _loading = false;
                        _failed = true;
                      });
                    },
                    onTitleChanged: (controller, title) {
                      final value = title?.trim() ?? '';
                      if (mounted && value.isNotEmpty) {
                        setState(() => _title = value);
                      }
                    },
                  ),
                  if (_loading)
                    const Align(
                      alignment: Alignment.topCenter,
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: AppColors.accent,
                        backgroundColor: AppColors.surfaceMuted,
                      ),
                    ),
                  if (_failed)
                    _LoadFailure(
                      message: 'The page could not be loaded.',
                      onRetry: _reload,
                    ),
                ],
              ),
      ),
    );
  }
}

final UnmodifiableListView<UserScript> _webViewScripts =
    UnmodifiableListView<UserScript>([
      UserScript(
        source: _imageInteractionGuard,
        injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
        forMainFrameOnly: false,
      ),
    ]);

const String _imageInteractionGuard = r'''
(() => {
  const install = () => {
    const root = document.head || document.documentElement;
    if (!root || document.getElementById('handa-image-guard')) return;
    const style = document.createElement('style');
    style.id = 'handa-image-guard';
    style.textContent = 'img{-webkit-touch-callout:none!important;'
      + '-webkit-user-select:none!important;user-select:none!important}';
    root.appendChild(style);
  };
  install();
  document.addEventListener('contextmenu', (event) => {
    if (event.target instanceof Element && event.target.closest('img')) {
      event.preventDefault();
    }
  }, true);
})();
''';

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, this.onRetry});

  final String message;
  final Future<void> Function()? onRetry;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.wifi_off_rounded,
                size: 48,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textPrimary),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  key: const Key('webview-retry'),
                  onPressed: () => unawaited(onRetry!()),
                  child: const Text('Retry'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
