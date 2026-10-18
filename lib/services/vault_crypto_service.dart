import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final vaultCryptoServiceProvider = Provider<VaultCryptoService>((ref) => VaultCryptoService.instance);

class VaultCryptoService {
  VaultCryptoService._privateConstructor();
  static final VaultCryptoService instance = VaultCryptoService._privateConstructor();

  final _algorithm = AesGcm.with256bits();

  Future<SecretKey> _deriveKey(String password, Uint8List salt) async {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: 100000,
      bits: 256,
    );
    return await pbkdf2.deriveKeyFromPassword(
      password: password,
      nonce: salt,
    );
  }

  Future<String> encrypt(String jsonData, String password) async {
    final salt = Uint8List.fromList(List<int>.generate(16, (i) => Random.secure().nextInt(256)));
    final secretKey = await _deriveKey(password, salt);
    final secretBox = await _algorithm.encrypt(
      utf8.encode(jsonData),
      secretKey: secretKey,
    );
    return base64.encode(salt + secretBox.concatenation());
  }

  Future<String> decrypt(String encryptedData, String password) async {
    final data = base64.decode(encryptedData);
    final salt = data.sublist(0, 16);
    final secretBox = SecretBox.fromConcatenation(data.sublist(16), nonceLength: 12, macLength: 16);
    final secretKey = await _deriveKey(password, salt);
    final decryptedBytes = await _algorithm.decrypt(secretBox, secretKey: secretKey);
    return utf8.decode(decryptedBytes);
  }
}
