import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// H5 原生返回桥（native-back-bridge v1）的客户端实现。
///
/// iOS 27 起 WKWebView 会把「没有用户手势时创建的 history entry」从
/// `canGoBack()`、`backForwardList`、`goBack()` 里过滤掉，而页面自己的
/// `history.back()` 不受影响。所以「能不能退」不能再问原生，要问 H5：
///
/// - `window.__canGoBack()`：只查询当前栈深，不导航；
/// - `window.history.back()`：回退动作本身；
/// - 没有桥的文档（三方支付页、老 H5、还在加载的页面）：内联脚本读
///   `history.state.idx`，非 react-router 的文档再回退到 `history.length`。
///
/// 《H5 原生返回桥接入说明》v1（2026-10）§7 的决策链只有三级：问桥 →
/// 原生 `canGoBack()/goBack()` → 关闭，前提是 `__canGoBack()` 返回 `null`
/// 只出现在「当前文档不是 H5」。
///
/// 这里故意多留了一层内联兜底（②）：H5 在 `await` 之后自动跳三方支付时，
/// 三方 entry 本身也可能是无手势创建的，此时原生 `canGoBack()` 同样不可信，
/// 而 `history.back()` 仍能退回 H5。真机确认「H5 自动跳三方 → 三方页点返回」
/// 不会误关之后，可以删掉 ② 与 [_inlineCanBackScript] 直接对齐文档。
///
/// 任何一步拿不到答案（弱网超时、JS 被禁、白屏）都按「关掉 H5」收尾，
/// 不能让返回键卡住。
///
/// 「能退」不等于「退走了」：换卡成功后的确定用款页会在 `history.back()`
/// 之后被 H5 原地重定向回同一个页面（栈里还留着换卡前的 entry），只看
/// `__canGoBack()` 就会让返回键永远停在原地（缺陷 reczz28Sjm17GWSd）。
/// 所以真正发出回退之后还要比对一次页面位置，位置没变就按「已经退到底」
/// 关闭 H5，保证返回键最终一定能退出到原生页。
class H5BackHandler {
  const H5BackHandler({
    required this.closePage,
    this.timeout = const Duration(milliseconds: 800),
    this.verifyDelay = const Duration(milliseconds: 400),
  });

  /// 关闭 H5：退回 Flutter 栈的上一页，或交给宿主收起容器。
  final Future<void> Function() closePage;

  /// 单次 JS 求值的上限。白屏或弱网时 `evaluateJavascript` 可能一直不返回。
  final Duration timeout;

  /// 发出 `history.back()` 之后，给 H5 换页留的时间窗。
  ///
  /// 采样两次（`2 * verifyDelay`）取最后落点：换卡后的确认页会「先退开、
  /// 再被 H5 重定向回来」，只采一次容易正好撞在半路上。最后落点仍然等于
  /// 回退前的位置，才算这次回退没生效。
  final Duration verifyDelay;

  /// 返回键统一入口：iOS 自绘返回、Android 物理键、PopScope 都走这里。
  ///
  /// 只负责「退一页或关掉」；返回后要不要刷新导航栏交给 WebView 自己的
  /// `onUpdateVisitedHistory` / `onTitleChanged`，别在这里读 URL。
  Future<void> handleBack(InAppWebViewController? controller) async {
    if (controller == null) {
      await _close();
      return;
    }

    // ① 先问桥：true = 还有上一页（这里自己发起回退）/ false = 已在首屏。
    final bridged = _toBool(await _eval(controller, _canGoBackScript));
    if (bridged == true) {
      await _historyBack(controller);
      return;
    }
    if (bridged == false) {
      await _close();
      return;
    }

    // ② 没有桥：三方支付页、老 H5、以及本页还没加载完的时候。
    //    这层是相对文档 §7 多出来的保护，理由见类注释；退还是走 history.back()，
    //    不回落到原生。
    final inline = _toBool(await _eval(controller, _inlineCanBackScript));
    if (inline == true) {
      await _historyBack(controller);
      return;
    }
    if (inline == false) {
      await _close();
      return;
    }

    // ③ JS 完全不可用（白屏、脚本被禁）：原生 API 是最后一道。
    //    文档 §11.1 允许在「当前文档不是 H5」时用它，但它会漏计被标记的
    //    entry，只有前两级都问不到答案才走到这里。
    try {
      if (await controller.canGoBack().timeout(timeout)) {
        await controller.goBack();
        return;
      }
    } catch (error) {
      debugPrint('[H5_BACK] native canGoBack failed: $error');
    }
    await _close();
  }

  Future<dynamic> _eval(InAppWebViewController controller, String source) async {
    try {
      return await controller
          .evaluateJavascript(source: source)
          .timeout(timeout);
    } catch (error) {
      debugPrint('[H5_BACK] eval failed: $error');
      return null;
    }
  }

  /// 发起 `history.back()`，并确认页面真的离开了当前位置。
  ///
  /// 判据是「两次采样后的落点仍等于回退前的位置」：这次回退对页面没有任何
  /// 净效果。拿不到位置快照（JS 被禁、文档正在被替换）时不做判断——宁可把
  /// 这一页交给 H5 自己处理，也不能把正在正常换文档的页面误关掉。
  Future<void> _historyBack(InAppWebViewController controller) async {
    final before = await _eval(controller, _historyPositionScript);
    await _eval(controller, _historyBackScript);
    if (before == null) return;
    Object? settled;
    for (var probe = 0; probe < 2; probe++) {
      if (verifyDelay > Duration.zero) {
        await Future<void>.delayed(verifyDelay);
      }
      settled = await _eval(controller, _historyPositionScript);
      if (settled == null) return;
    }
    if (settled != before) return;
    debugPrint('[H5_BACK] history.back() left the page in place, closing');
    await _close();
  }

  Future<void> _close() async {
    try {
      await closePage();
    } catch (error) {
      debugPrint('[H5_BACK] close failed: $error');
    }
  }

  /// 部分插件版本把 `true`/`false` 当字符串回传；非布尔一律当作「没有答案」。
  static bool? _toBool(Object? value) {
    if (value is bool) return value;
    if (value is String) {
      if (value == 'true') return true;
      if (value == 'false') return false;
    }
    return null;
  }
}

/// 桥查询：页面没有这个函数时返回 `null`，由内联脚本接手。
const String _canGoBackScript =
    'window.__canGoBack ? window.__canGoBack() : null';

/// 回退动作。只走 `history.back()`，不回落到原生 `goBack()`：后者在 iOS 27
/// 上会跳着退（被标记的 entry 不计入）。
const String _historyBackScript = 'window.history.back();';

/// 回退前后比对用的位置快照：地址 + react-router 栈深 + 条目数。
///
/// 第一行的标记注释给测试替身用来识别这条脚本，别删。
const String _historyPositionScript = '''
/* handa-history-position */
(function () {
  var s = history.state;
  return JSON.stringify([
    String(location.href),
    (s && typeof s.idx === 'number') ? s.idx : -1,
    history.length
  ]);
})()
''';

/// 与 H5 的 `__canGoBack()` 等价，但能在任意文档里执行（含三方页面）。
///
/// 这是文档 §7 三级链路之外多留的一层，删除条件见类注释。
///
/// `history.state.idx` 是 react-router 写的栈深（首屏为 0）；没有它说明这个
/// 文档不是 react-router 管理的，退回「条目数 > 1 就算能退」。
const String _inlineCanBackScript = '''
(function () {
  var s = history.state;
  if (s && typeof s.idx === 'number') return s.idx > 0;
  return history.length > 1;
})()
''';
