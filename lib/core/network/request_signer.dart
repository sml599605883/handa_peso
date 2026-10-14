import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'gateway_failure.dart';
import 'gateway_settings.dart';

/// 组装随每个请求发送的已签名公有参数。
///
/// 网关要求把请求路径与一组固定的设备/应用字段一起签名：所有键按字典序排序
/// 后拼成 `键 + 值` 的长串，再取 HMAC-SHA256。摘要以不透明参数 `lasses` 返回，
/// 同时带上时间戳与一个随机数字串。
class RequestSigner {
  const RequestSigner(this.settings);

  final GatewaySettings settings;

  /// 本次请求的完整查询参数：公有参数 + 调用方附加参数 + 时间戳与签名。
  Future<Map<String, dynamic>> signedQuery({
    required String path,
    Map<String, dynamic> extra = const <String, dynamic>{},
  }) async {
    final secret = settings.signSecret;
    if (secret.isEmpty) {
      throw GatewayFailure.misconfigured(
        'Missing API signing secret. Provide --dart-define=API_SIGN_SECRET.',
      );
    }

    final stamp =
        settings.clock?.call() ?? DateTime.now().millisecondsSinceEpoch;
    final common = <String, dynamic>{
      'procuration': settings.appVersion,
      'especially': settings.deviceLabel,
      'corkscrewed': settings.deviceId,
      'truculency': settings.systemVersion,
      'muttonfishes': settings.marketTag,
      'sandman': await settings.sessionStore.sessionId(),
      'parcener': settings.pairedDeviceId,
      'absorbing': '$stamp',
    };
    final digest = signatureOf(<String, dynamic>{
      ...common,
      'distorters': routeOf(path),
    }, secret);

    return <String, dynamic>{
      ...common,
      ...extra,
      'wrencher': settings.noiseDigits?.call(6) ?? secureDigits(6),
      'lasses': digest,
    };
  }

  /// 计算签名：键按字典序排序后拼成 `键+值`，再取 HMAC-SHA256 的十六进制值。
  static String signatureOf(Map<String, dynamic> params, String secret) {
    final canonical = StringBuffer();
    for (final key in params.keys.toList()..sort()) {
      canonical
        ..write(key)
        ..write(params[key] ?? '');
    }
    return Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(canonical.toString())).toString();
  }

  /// 只保留路由：去掉 scheme/host 与 query，让签名不受换址影响。
  static String routeOf(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) return uri.path;
    return path.split('?').first;
  }

  /// 安全随机的数字串，用作网关要求的干扰字段。
  static String secureDigits(int length) {
    final random = Random.secure();
    final buffer = StringBuffer();
    for (var index = 0; index < length; index++) {
      buffer.write(random.nextInt(10));
    }
    return buffer.toString();
  }
}
