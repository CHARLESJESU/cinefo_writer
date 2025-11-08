import 'package:encrypt/encrypt.dart';

String decryptAES(String encryptedText, String encryptionKey, IV iv) {
  final key = Key.fromUtf8(encryptionKey);
  final encrypter = Encrypter(AES(key, mode: AESMode.cbc, padding: 'PKCS7'));
  final decrypted = encrypter.decrypt64(encryptedText, iv: iv);
  return decrypted;
}
