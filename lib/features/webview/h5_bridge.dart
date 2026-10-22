import 'dart:convert';

/// 当前线上 H5 的桥接契约。
///
/// 网页端暂时保留了旧项目前缀；原生侧同时注册新的 Handa 通道，便于 H5
/// 后续单独换名，不要求客户端和网页同版本发布。
abstract final class H5Bridge {
  static const legacyHandler = 'ph_cash_alalay_ios';
  static const currentHandler = 'ph_handa_peso_ios';
  static const handlers = <String>[legacyHandler, currentHandler];

  static const reportLoan = 'cash_alalay_ios_BulpJ0rgaYaU6Fn';
  static const openExternal = 'cash_alalay_ios_xfh1bs20COCGTmq';
  static const openLink = 'cash_alalay_ios_gzuoJBjQGU42MRv';
  static const closePage = 'cash_alalay_ios_rXM95kcpoNFbdVd';
  static const goHome = 'cash_alalay_ios_lVHfWn47O8oT1oA';
  static const appReview = 'cash_alalay_ios_Zf7dNN1vn4hLDre';
  static const retryLoan = 'cash_alalay_ios_HCDGUlbAXsAjnQT';
  static const replaceAccount = 'cash_alalay_ios_XYxDLYsI7etxIZC';
  static const signedParams = 'cash_alalay_ios_pijsHm7O1BWkeR0';
}

class H5BridgeMessage {
  const H5BridgeMessage({
    required this.action,
    required this.callbackId,
    required this.value,
  });

  factory H5BridgeMessage.decode(Object? raw) {
    final decoded = raw is String ? jsonDecode(raw) : raw;
    final source = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : const <String, dynamic>{};
    final callback = _trim(
      source['callbackId'] ?? source['callback'] ?? source['id'],
    );
    final data = source['data'] ?? source['payload'] ?? source['params'];
    return H5BridgeMessage(
      action: _trim(source['action'] ?? source['name']),
      callbackId: callback,
      value: data,
    );
  }

  final String action;
  final String callbackId;
  final Object? value;

  bool get expectsReply => callbackId.isNotEmpty;

  String get rawText {
    final data = value;
    if (data is String) return data.trim();
    if (data == null) return '';
    if (data is num || data is bool) return '$data';
    return jsonEncode(data);
  }

  Map<String, dynamic> get mapValue {
    final data = value;
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    if (data is String && data.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } on FormatException {
        return const <String, dynamic>{};
      }
    }
    return const <String, dynamic>{};
  }

  String text(Iterable<String> keys, {bool rawFallback = false}) {
    for (final key in keys) {
      final found = _trim(mapValue[key]);
      if (found.isNotEmpty) return found;
    }
    return rawFallback ? rawText : '';
  }

  static String _trim(Object? value) => value?.toString().trim() ?? '';
}

class H5BridgeResult {
  const H5BridgeResult(this.code, this.message, [this.data]);

  const H5BridgeResult.ok([this.data]) : code = 0, message = 'success';

  const H5BridgeResult.error(String message) : this(-1, message);

  final int code;
  final String message;
  final Object? data;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'code': code,
    'message': message,
    'data': data ?? <String, dynamic>{},
  };

  String? callbackScript(String handler, String callbackId) {
    if (callbackId.isEmpty) return null;
    final payload = jsonEncode(<String, Object?>{
      'callbackId': callbackId,
      'data': data ?? <String, dynamic>{},
    });
    return 'window.$handler && window.$handler.handleMessage($payload);';
  }
}

typedef H5ReportLoan = Future<void> Function({
  required String productId,
  required String orderNo,
  required int startedAtSeconds,
});
typedef H5OpenWebPage = Future<void> Function(String url);
typedef H5OpenInternal = Future<void> Function(String target);
typedef H5OpenExternalApp = Future<bool> Function(Uri uri);
typedef H5VoidAction = Future<void> Function();
typedef H5SignedQueryBuilder = Future<Map<String, dynamic>> Function(
  String path,
);
typedef H5RetryLoan = Future<String> Function(String orderNo);
typedef H5ReplaceAccount = Future<void> Function({
  required String productId,
  required String orderNo,
});
typedef H5MessageSink = Future<void> Function(String message);

class H5ActionDispatcher {
  const H5ActionDispatcher({
    this.reportLoan,
    this.openWebPage,
    this.openInternal,
    this.openExternalApp,
    this.closePage,
    this.goHome,
    this.requestReview,
    this.buildSignedQuery,
    this.retryLoan,
    this.replaceAccount,
    this.showLoading,
    this.dismissLoading,
    this.showError,
    this.nowSeconds,
  });

  final H5ReportLoan? reportLoan;
  final H5OpenWebPage? openWebPage;
  final H5OpenInternal? openInternal;
  final H5OpenExternalApp? openExternalApp;
  final H5VoidAction? closePage;
  final H5VoidAction? goHome;
  final H5VoidAction? requestReview;
  final H5SignedQueryBuilder? buildSignedQuery;
  final H5RetryLoan? retryLoan;
  final H5ReplaceAccount? replaceAccount;
  final H5VoidAction? showLoading;
  final H5VoidAction? dismissLoading;
  final H5MessageSink? showError;
  final int Function()? nowSeconds;

  Future<H5BridgeResult> dispatch(H5BridgeMessage message) async {
    try {
      return switch (message.action) {
        H5Bridge.reportLoan => await _report(message),
        H5Bridge.openExternal => await _openExternalApp(message),
        H5Bridge.openLink => await _openLink(message),
        H5Bridge.closePage => await _voidAction(closePage),
        H5Bridge.goHome => await _voidAction(goHome),
        H5Bridge.appReview => await _voidAction(requestReview),
        H5Bridge.retryLoan => await _retry(message),
        H5Bridge.replaceAccount => await _replace(message),
        H5Bridge.signedParams => await _signedParams(message),
        _ => H5BridgeResult.error('Unsupported action: ${message.action}'),
      };
    } catch (error) {
      final text = error.toString().trim();
      final messageText = text.isEmpty ? 'Unable to complete action' : text;
      await showError?.call(messageText);
      return H5BridgeResult.error(messageText);
    }
  }

  Future<H5BridgeResult> _report(H5BridgeMessage message) async {
    final productId = message.text(const <String>[
      'drippier',
      'polarimetric',
      'productId',
    ]);
    if (productId.isEmpty) return H5BridgeResult.error('Missing product ID');
    await reportLoan?.call(
      productId: productId,
      orderNo: message.text(const <String>['qktp', 'cysticercosis', 'orderNo']),
      startedAtSeconds:
          nowSeconds?.call() ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    );
    return const H5BridgeResult.ok();
  }

  Future<H5BridgeResult> _openExternalApp(H5BridgeMessage message) async {
    final uri = Uri.tryParse(message.rawText);
    if (uri == null ||
        uri.scheme.isEmpty ||
        const <String>{
          'javascript',
          'file',
          'data',
          'about',
        }.contains(uri.scheme.toLowerCase())) {
      return H5BridgeResult.error('Invalid external URL');
    }
    final opened = await openExternalApp?.call(uri) ?? false;
    return opened
        ? const H5BridgeResult.ok()
        : H5BridgeResult.error('Unable to open external app');
  }

  Future<H5BridgeResult> _openLink(H5BridgeMessage message) async {
    final target = message.text(const <String>[
      'url',
      'target',
      'link',
    ], rawFallback: true);
    final uri = Uri.tryParse(target);
    if (uri == null || uri.scheme.isEmpty) {
      return H5BridgeResult.error('Invalid URL');
    }
    if (uri.scheme == 'http' || uri.scheme == 'https') {
      if (uri.host.isEmpty) return H5BridgeResult.error('Invalid URL');
      await openWebPage?.call(target);
      return const H5BridgeResult.ok();
    }
    if (uri.scheme == 'ph') {
      await openInternal?.call(target);
      return const H5BridgeResult.ok();
    }
    if (const <String>{
      'javascript',
      'file',
      'data',
      'about',
    }.contains(uri.scheme.toLowerCase())) {
      return H5BridgeResult.error('Invalid URL');
    }
    final opened = await openExternalApp?.call(uri) ?? false;
    return opened
        ? const H5BridgeResult.ok()
        : H5BridgeResult.error('Unable to open link');
  }

  Future<H5BridgeResult> _retry(H5BridgeMessage message) async {
    final orderNo = message.text(const <String>['qktp', 'orderNo']);
    if (orderNo.isEmpty) return H5BridgeResult.error('Missing order number');
    await showLoading?.call();
    try {
      final target = (await retryLoan?.call(orderNo) ?? '').trim();
      if (target.isEmpty) {
        return H5BridgeResult.error('Retry link is unavailable');
      }
      await openWebPage?.call(target);
      return const H5BridgeResult.ok();
    } finally {
      await dismissLoading?.call();
    }
  }

  Future<H5BridgeResult> _replace(H5BridgeMessage message) async {
    final productId = message.text(const <String>['drippier', 'productId']);
    final orderNo = message.text(const <String>['qktp', 'orderNo']);
    if (productId.isEmpty || orderNo.isEmpty) {
      return H5BridgeResult.error('Missing account information');
    }
    await replaceAccount?.call(productId: productId, orderNo: orderNo);
    return const H5BridgeResult.ok();
  }

  Future<H5BridgeResult> _signedParams(H5BridgeMessage message) async {
    final path = message.rawText;
    if (path.isEmpty) return H5BridgeResult.error('Missing request path');
    final params = await buildSignedQuery?.call(path);
    if (params == null) {
      return H5BridgeResult.error('Signed parameters are unavailable');
    }
    return H5BridgeResult.ok(params);
  }

  Future<H5BridgeResult> _voidAction(H5VoidAction? action) async {
    await action?.call();
    return const H5BridgeResult.ok();
  }
}
