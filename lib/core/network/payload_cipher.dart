import 'package:encrypt/encrypt.dart';

/// 上报类接口的载荷加密器（AES-CBC）。
///
/// 设备详情这类载荷必须在离开设备前加密，网关只接受密文。
/// 密钥与初始向量由构建期注入：不落盘、不写日志。
class PayloadCipher {
  PayloadCipher({required String secret, required String vector})
    : _secret = Key.fromUtf8(secret),
      _vector = IV.fromUtf8(vector);

  final Key _secret;
  final IV _vector;

  late final Encrypter _codec = Encrypter(AES(_secret, mode: AESMode.cbc));

  /// 明文 -> base64 密文。
  String encipher(String readable) =>
      _codec.encrypt(readable, iv: _vector).base64;

  /// base64 密文 -> 明文。
  String decipher(String encoded) => _codec.decrypt64(encoded, iv: _vector);
}
