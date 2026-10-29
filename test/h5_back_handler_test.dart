import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:handa_peso/features/webview/h5_back_handler.dart';

import 'support/fake_inappwebview_platform.dart';

/// H5 返回桥的决策链：有桥 → 内联兜底 → 原生 API → 关闭。
///
/// 文档 v1 §7 只要求「有桥 → 原生 → 关闭」，`H5BackHandler` 按需要多留了
/// 内联兜底一层（理由与删除条件见类注释），所以这里也把它当契约覆盖。
/// 每个分支都单测一遍，避免 iOS 27 的 entry 过滤再悄悄回到主路径上。
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

  test('history.back() 被页面弹回原地时关闭 H5：确定用款页返回不再死循环', () async {
    // 换卡成功后 H5 在 history.back() 之后立刻重定向回同一个页面：位置探针
    // 前后完全一致。这种情况继续「退一页」永远不会离开当前页面（reczz28Sjm17GWSd）。
    platform.bridgeCanGoBack = true;
    platform.historyPosition = '["http://host/#/loan-confirmation",2,4]';

    await H5BackHandler(
      closePage: () async => closed++,
      verifyDelay: Duration.zero,
    ).handleBack(controller);

    expect(platform.historyBackCalls, 1);
    expect(closed, 1, reason: '位置没变就按「已经退到底」关闭 H5，退回原生页');
  });

  test('history.back() 真的换了页时只退一页，不关 H5', () async {
    platform.bridgeCanGoBack = true;
    platform.historyPosition = '["http://host/#/loan-confirmation",2,4]';
    platform.historyPositionAfterBack = '["http://host/#/loan-details",1,4]';

    await H5BackHandler(
      closePage: () async => closed++,
      verifyDelay: Duration.zero,
    ).handleBack(controller);

    expect(platform.historyBackCalls, 1);
    expect(closed, 0);
    // 回退仍然只走 history.back()，不回落到 iOS 27 会漏 entry 的原生 goBack()。
    expect(platform.goBackCalls, 0);
  });

  test('回退先退开又被弹回原页面时按「没退走」处理：关闭 H5', () async {
    // 换卡后的确认页会先真的退回换卡前的 entry，再被 H5 重定向回确认页。
    // 只看第一次采样会误判成「退成功了」，所以在时间窗末尾再采一次。
    platform.bridgeCanGoBack = true;
    platform.historyPositionSequence = <Object?>[
      '["http://host/#/loan-confirmation",2,4]',
      '["http://host/#/loan-details",1,4]',
      '["http://host/#/loan-confirmation",2,4]',
    ];

    await H5BackHandler(
      closePage: () async => closed++,
      verifyDelay: Duration.zero,
    ).handleBack(controller);

    expect(platform.historyBackCalls, 1);
    expect(platform.positionProbes, 3);
    expect(closed, 1);
  });

  test('没有桥时同样校验回退是否生效：内联兜底原地打转也关闭 H5', () async {
    platform.bridgeCanGoBack = null;
    platform.inlineCanGoBack = true;
    platform.historyPosition = '["http://host/#/pay",0,2]';

    await H5BackHandler(
      closePage: () async => closed++,
      verifyDelay: Duration.zero,
    ).handleBack(controller);

    expect(platform.historyBackCalls, 1);
    expect(closed, 1);
  });

  test('拿不到位置快照时不猜：白屏 / 文档正在替换时按 H5 的结果收尾', () async {
    // historyPosition 为 null = 求值失败。此时不能把正在换文档的页面误关掉。
    platform.bridgeCanGoBack = true;

    await H5BackHandler(
      closePage: () async => closed++,
      verifyDelay: Duration.zero,
    ).handleBack(controller);

    expect(platform.historyBackCalls, 1);
    expect(closed, 0);
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
