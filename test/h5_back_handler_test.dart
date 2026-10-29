import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/features/webview/h5_back_handler.dart';

import 'support/fake_inappwebview_platform.dart';

/// H5 返回桥的决策链：有桥 → 内联兜底 → 原生 API → 关闭。
///
/// 文档 v1 §7 只要求「有桥 → 原生 → 关闭」，`H5BackHandler` 按需要多留了
/// 内联兜底一层（理由与删除条件见类注释），所以这里也把它当契约覆盖。
/// 每个分支都单测一遍，避免 iOS 27 的 entry 过滤再悄悄回到主路径上。
///
/// 换卡返回打转（reczz28Sjm17GWSd）的根因在原生栈（替换谓词停在账户列表
/// 上），已由 `AppNavigator.toWebViewResettingFlow` 修掉，这里不再断言
/// 「回退前后比对位置」那层兜底；见 `webview_navigation_test.dart` 的栈深用例。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakePlatformController platform;
  late InAppWebViewController controller;
  late int closed;
  late H5BackHandler handler;

  setUp(() {
    platform = FakePlatformController('http://host/#/order-detail');
    controller = InAppWebViewController.fromPlatform(platform: platform);
    closed = 0;
    handler = H5BackHandler(closePage: () async => closed++);
  });

  Future<void> back() => handler.handleBack(controller);

  test('H5 有桥且还有上一页：用 history.back() 回退，不关页面', () async {
    platform.bridgeCanGoBack = true;

    await back();

    expect(platform.askedBridge, isTrue);
    expect(platform.historyBackCalls, 1);
    expect(closed, 0);
    // iOS 27 的原生 goBack() 会漏计无手势 entry，主路径上不允许出现。
    expect(platform.goBackCalls, 0);
  });

  test('H5 有桥但已在首屏：关闭 H5，不再问内联脚本', () async {
    platform.bridgeCanGoBack = false;

    await back();

    expect(platform.historyBackCalls, 0);
    expect(closed, 1);
    expect(
      platform.evaluated.any((source) => source.contains('history.state')),
      isFalse,
    );
    expect(platform.goBackCalls, 0);
  });

  test('插件把布尔值当字符串回传时同样按结果处理', () async {
    platform.bridgeCanGoBack = 'true';
    await back();
    expect(platform.historyBackCalls, 1);
    expect(closed, 0);

    platform.bridgeCanGoBack = 'false';
    platform.evaluated.clear();
    await back();
    expect(platform.historyBackCalls, 0);
    expect(closed, 1);
  });

  test('没有桥（三方支付页 / 老 H5）时读 history.state.idx：仍能退回，不落原生', () async {
    platform.bridgeCanGoBack = null;
    platform.inlineCanGoBack = true;

    await back();

    expect(platform.historyBackCalls, 1);
    // 这一层是相对文档 §7 多出来的保护：原生 canGoBack() 可能漏计三方 entry。
    expect(platform.goBackCalls, 0);
    expect(closed, 0);
  });

  test('没有桥且已在首屏：关闭 H5', () async {
    platform.bridgeCanGoBack = null;
    platform.inlineCanGoBack = false;

    await back();

    expect(platform.historyBackCalls, 0);
    expect(closed, 1);
    expect(platform.goBackCalls, 0);
  });

  test('JS 完全不可用（白屏 / 脚本被禁）：原生 canGoBack() 是最后一道', () async {
    platform.failJavaScript = true;
    platform.nativeCanGoBack = true;

    await back();

    expect(platform.goBackCalls, 1);
    expect(closed, 0);
  });

  test('JS 完全不可用且原生也退不了：关闭 H5', () async {
    platform.failJavaScript = true;
    platform.nativeCanGoBack = false;

    await back();

    expect(platform.goBackCalls, 0);
    expect(closed, 1);
  });

  test('JS 求值一直不返回：超时后按「已到首屏」收尾，不卡死', () async {
    platform.hangJavaScript = true;
    platform.nativeCanGoBack = false;

    await H5BackHandler(
      closePage: () async => closed++,
      timeout: const Duration(milliseconds: 10),
    ).handleBack(controller);

    expect(closed, 1);
    expect(platform.historyBackCalls, 0);
  });

  test('没有控制器（页面已销毁）：直接关闭', () async {
    await handler.handleBack(null);

    expect(closed, 1);
  });

  test('关闭动作自己抛错时不再往外抛，返回键不会把 App 带崩', () async {
    final broken = H5BackHandler(
      closePage: () async => throw StateError('host is gone'),
    );

    await broken.handleBack(null);
  });
}
