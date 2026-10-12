import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'api_exception.dart';
import 'api_config.dart';

/// 构造附加在每个请求上的已签名公有参数集合。
///
/// 网关要求把请求路径加上一组固定的设备/应用字段，用应用密钥进行签名。
/// 这些值按 key 排序后以 `key + value` 的形式拼接，再做 HMAC-SHA256 哈希；
/// 该哈希会作为一个不透明 `lasses` 参数，连同带时间戳的混淆字段一起传输。
class ApiSignature {
  ApiSignature(this.config);

  final ApiConfig config;

  Future<Map<String, dynamic>> buildSignedQuery({
    required String path,
    Map<String, dynamic> extraQuery = const <String, dynamic>{},
  }) async {
    final secret = config.signatureSecret;
    if (secret.isEmpty) {
      throw ApiException.configuration(
        'Missing API signing secret. Provide --dart-define=API_SIGN_SECRET.',
      );
    }

    final common = <String, dynamic>{
      'procuration': config.appVersion,
      'especially': config.deviceName,
      'corkscrewed': config.deviceId,
      'truculency': config.osVersion,
      'muttonfishes': config.appMarket,
      'sandman': await config.sessionStore.sessionId(),
      'parcener': config.gpsAdId,
      'absorbing':
          '${config.timestampProvider?.call() ?? DateTime.now().millisecondsSinceEpoch}',
    };

    final signInput = <String, dynamic>{
      ...common,
      'distorters': clearPath(path),
    };
    return <String, dynamic>{
      ...common,
      ...extraQuery,
      'wrencher': _randomDigits(6),
      'lasses': sign(signInput, secret),
    };
  }

  static String sign(Map<String, dynamic> params, String secret) {
    final keys = params.keys.toList()..sort();
    final source = keys.map((key) => '$key${params[key] ?? ''}').join();
    return Hmac(
      sha256,
      utf8.encode(secret),
    ).convert(utf8.encode(source)).toString();
  }

  /// 去掉 scheme/host/query，使只有路由参与签名。
  static String clearPath(String path) {
    final uri = Uri.tryParse(path);
    if (uri != null && uri.hasScheme) {
      return uri.path;
    }
    return path.split('?').first;
  }

  String _randomDigits(int length) {
    return config.randomDigitsProvider?.call(length) ?? randomDigits(length);
  }

  static String randomDigits(int length) {
    final random = Random.secure();
    return List.generate(length, (_) => random.nextInt(10)).join();
  }
}
