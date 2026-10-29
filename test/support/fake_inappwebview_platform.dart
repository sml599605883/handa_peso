import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// `flutter_inappwebview` 的测试替身。
///
/// 插件里的 `InAppWebViewController` 只是平台层的一层转发，所以注册一个假平台
/// 就能在测试里跑通整条返回决策链（H5 桥 → 内联兜底 → 原生兜底），不需要真机，
/// 也不需要 Xcode 构建。
class FakeInAppWebViewPlatform extends InAppWebViewPlatform {
  FakeInAppWebViewPlatform(this.controller);

  /// 当前生效的控制器。每个用例在 `setUp` 里换一个新的，重置求值记录。
  FakePlatformController controller;

  @override
  PlatformInAppWebViewWidget createPlatformInAppWebViewWidget(
    PlatformInAppWebViewWidgetCreationParams params,
  ) {
    return _FakeWebViewWidget(params, controller);
  }

  @override
  PlatformInAppWebViewController createPlatformInAppWebViewController(
    PlatformInAppWebViewControllerCreationParams params,
  ) {
    return controller;
  }

  @override
  PlatformInAppWebViewController createPlatformInAppWebViewControllerStatic() {
    return controller;
  }
}

class FakePlatformController extends PlatformInAppWebViewController {
  FakePlatformController(this.currentUrl)
    : super.implementation(
        PlatformInAppWebViewControllerCreationParams(id: 'test-webview'),
      );

  final String currentUrl;
  String title = 'Details';

  /// `window.__canGoBack()` 的返回值。`null` 表示页面没有返回桥
  /// （三方支付页、老 H5、页面还没加载完）；`'true'`/`'false'` 用来模拟
  /// 部分插件版本把布尔值当字符串回传。
  Object? bridgeCanGoBack;

  /// 内联兜底脚本的返回值。`null` 表示求值失败（白屏 / 脚本被禁）。
  Object? inlineCanGoBack;

  /// 原生 `canGoBack()` 的返回值，决策链的最后一道。
  bool nativeCanGoBack = true;

  /// 打开后所有 `evaluateJavascript` 都抛错，模拟 JS 完全不可用。
  bool failJavaScript = false;

  /// 打开后所有 `evaluateJavascript` 都不返回，模拟弱网 / 白屏卡住。
  bool hangJavaScript = false;

  /// 求值前的闸门：用来把「一次返回」按在半空中，验证连点只退一页。
  Completer<void>? holdEval;

  /// 按顺序记录所有注入过的脚本，用来断言「退了几次」「问的是哪个函数」。
  final List<String> evaluated = <String>[];

  /// 首屏回调是否已经派发过。挂在这里而不是 widget 实例上：页面 rebuild 会
  /// 生成新的平台 widget，实例级标记会被重置，`onLoadStop` 就会无限重入。
  bool created = false;

  /// 首屏创建后是否自动派发一次 `onLoadStop`（真机成功加载的终态）。
  ///
  /// 设为 `false` 用来模拟「首屏一直没走完」：请求失败、弱网卡住、下载中断
  /// 时 WebView 都不会回调完成。
  bool autoFinishLoad = true;

  /// `getTitle` 失败。iOS 侧它是一次单独的桥调用，页面不能因为取标题失败
  /// 就把顶部进度条留在屏上。
  bool failGetTitle = false;

  /// 最近一次构建交下来的回调集合。`onLoadStart` / `onProgressChanged` /
  /// `onReceivedError` / `shouldOverrideUrlLoading` 这些只有真机才会派发的
  /// 生命周期都在这里，用例通过下面的 `emit*` 方法驱动。
  PlatformInAppWebViewWidgetCreationParams? callbacks;

  /// 回调里传的控制器必须是**同一个**实例：页面用 `identical` 判活，换一个包装
  /// 对象就会被当成旧 WebView 的事件丢掉。
  InAppWebViewController? widgetController;

  InAppWebViewController get _widgetController => widgetController!;

  void emitLoadStart([String? url]) =>
      callbacks?.onLoadStart?.call(_widgetController, WebUri(url ?? currentUrl));

  void emitLoadStop([String? url]) =>
      callbacks?.onLoadStop?.call(_widgetController, WebUri(url ?? currentUrl));

  void emitProgress(int progress) =>
      callbacks?.onProgressChanged?.call(_widgetController, progress);

  void emitLoadError({bool isForMainFrame = true}) =>
      callbacks?.onReceivedError?.call(
        _widgetController,
        WebResourceRequest(
          url: WebUri(currentUrl),
          isForMainFrame: isForMainFrame,
        ),
        WebResourceError(
          type: WebResourceErrorType.CANNOT_CONNECT_TO_HOST,
          description: 'offline',
        ),
      );

  /// 模拟一次网页发起、由原生接管（`mailto:` / `ph://` 这类）的跳转。
  Future<NavigationActionPolicy?> emitNavigation(String url) async =>
      await callbacks!.shouldOverrideUrlLoading!(
        _widgetController,
        NavigationAction(
          isForMainFrame: true,
          request: URLRequest(url: WebUri(url)),
        ),
      );

  int goBackCalls = 0;

  /// `history.back()` 被调用的次数。
  int get historyBackCalls =>
      evaluated.where((source) => source.contains('history.back()')).length;

  /// 是否问过 H5 的返回桥。
  bool get askedBridge =>
      evaluated.any((source) => source.contains('__canGoBack'));

  @override
  Future<dynamic> evaluateJavascript({
    required String source,
    ContentWorld? contentWorld,
  }) async {
    evaluated.add(source);
    if (failJavaScript) throw StateError('JavaScript is disabled');
    if (hangJavaScript) return Completer<dynamic>().future;
    final gate = holdEval;
    if (gate != null) await gate.future;
    if (source.contains('__canGoBack')) return bridgeCanGoBack;
    if (source.contains('history.state')) return inlineCanGoBack;
    return null;
  }

  @override
  Future<WebUri?> getUrl() async => WebUri(currentUrl);

  @override
  Future<String?> getTitle() async {
    if (failGetTitle) throw StateError('Title is unavailable');
    return title;
  }

  @override
  Future<bool> canGoBack() async => nativeCanGoBack;

  @override
  Future<void> goBack() async {
    goBackCalls++;
  }

  @override
  void addJavaScriptHandler({
    required String handlerName,
    required JavaScriptHandlerCallback callback,
  }) {}

  @override
  void dispose({bool isKeepAlive = false}) {}
}

class _FakeWebViewWidget extends PlatformInAppWebViewWidget {
  _FakeWebViewWidget(super.params, this.controller) : super.implementation();

  final FakePlatformController controller;

  @override
  Widget build(BuildContext context) {
    // 回调集合跟着控制器走：页面 rebuild 会换掉平台 widget，但控制器是同一个，
    // 用例可以在任意一帧之后继续驱动生命周期。
    controller.callbacks = params;
    controller.widgetController ??=
        params.controllerFromPlatform!(controller);
    final widgetController = controller.widgetController!;
    if (!controller.created) {
      controller.created = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        params.onWebViewCreated?.call(widgetController);
        if (controller.autoFinishLoad) {
          params.onLoadStop?.call(
            widgetController,
            WebUri(controller.currentUrl),
          );
        }
      });
    }
    return const ColoredBox(color: Colors.white);
  }

  @override
  T controllerFromPlatform<T>(PlatformInAppWebViewController controller) {
    return params.controllerFromPlatform!(controller) as T;
  }

  @override
  void dispose() {}
}
