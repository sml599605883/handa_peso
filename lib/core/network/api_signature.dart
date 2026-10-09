import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Deterministic request signing.
///
/// Every authenticated call carries a short-lived signature computed over the
/// sorted parameter set plus a per-request nonce, which lets the backend reject
/// replayed or tampered requests. The secret is injected at build time and is
/// never persisted on device.
abstract final class ApiSignature {
  static String sign({
    required Map<String, String> params,
    required String secret,
    required String nonce,
    required int timestamp,
  }) {
    final keys = params.keys.toList()..sort();
    final buffer = StringBuffer()
      ..write('nonce=$nonce&')
      ..write('ts=$timestamp');
    for (final key in keys) {
      if (key.isEmpty) continue;
      buffer
        ..write('&')
        ..write(key)
        ..write('=')
        ..write(params[key]);
    }
    buffer
      ..write('&secret=')
      ..write(secret);
    return _hmacSha256Hex(buffer.toString(), secret);
  }

  static String nonce([int length = 16]) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final now = DateTime.now().microsecondsSinceEpoch;
    final buffer = StringBuffer();
    var seed = now;
    for (var i = 0; i < length; i++) {
      seed = (seed * 1103515245 + 12345) & 0x7fffffff;
      buffer.write(alphabet[seed % alphabet.length]);
    }
    return buffer.toString();
  }

  static String _hmacSha256Hex(String value, String secret) {
    final hmac = Hmac(sha256, utf8.encode(secret));
    return hmac.convert(utf8.encode(value)).toString();
  }
}
