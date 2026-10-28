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
  Future<String?> getTitle() async => title;

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
    if (!controller.created) {
      controller.created = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final widgetController = params.controllerFromPlatform!(controller);
        params.onWebViewCreated?.call(widgetController);
        params.onLoadStop?.call(
          widgetController,
          WebUri(controller.currentUrl),
        );
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
