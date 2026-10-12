import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'api_exception.dart';
import 'api_config.dart';

/// Builds the signed public-parameter set attached to every request.
///
/// The gateway requires the request path plus a fixed set of device/app fields
/// to be signed with the app secret. Values are sorted by key and concatenated
/// as `key + value`, then HMAC-SHA256 hashed; the hash travels as an opaque
/// `lasses` parameter alongside a time-stamped, obfuscated field.
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

  /// Strips scheme/host/query so only the route participates in the signature.
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
