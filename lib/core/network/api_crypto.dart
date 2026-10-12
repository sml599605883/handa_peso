import 'package:encrypt/encrypt.dart';

/// AES-CBC helper for the reporting endpoints whose payload must be encrypted
/// before it leaves the device (device details, contacts, ...).
///
/// The key and IV are injected at build time; they are never persisted on the
/// device and never logged.
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
