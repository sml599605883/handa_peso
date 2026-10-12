import 'package:encrypt/encrypt.dart';

/// 用于上报类接口的 AES-CBC 辅助工具，这类接口的载荷必须在离开设备前
/// 完成加密（设备详情、通讯录等）。
///
/// 密钥与 IV 在构建时注入，绝不持久化到设备上，也绝不写入日志。
class ApiCrypto {
  ApiCrypto({required String key, required String iv})
    : _key = Key.fromUtf8(key),
      _iv = IV.fromUtf8(iv);

  final Key _key;
  final IV _iv;

  String encrypt(String plainText) {
    return Encrypter(AES(_key, mode: AESMode.cbc))
        .encrypt(plainText, iv: _iv)
        .base64;
  }

  String decrypt(String cipherText) {
    return Encrypter(AES(_key, mode: AESMode.cbc))
        .decrypt64(cipherText, iv: _iv);
  }
}
