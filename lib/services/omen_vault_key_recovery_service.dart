import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:pointycastle/digests/sha256.dart';

class OmenVaultKeyRecoveryService {
  final FlutterSecureStorage _secureStorage;

  static const String masterKeyStorageKey = 'master_key';
  static const String mnemonicBackupStatusKey = 'mnemonic_backup_status';
  static const int pbkdf2Iterations = 200000;

  OmenVaultKeyRecoveryService(this._secureStorage);

  Uint8List _pbkdf2({
    required Uint8List password,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) {
    final derivator = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64))
      ..init(Pbkdf2Parameters(salt, iterations, keyLength));
    return derivator.process(password);
  }

  void _wipeBuffer(Uint8List buffer) {
    for (int i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }

  Future<Uint8List> recoverAndStoreMasterKey(
      List<int> passwordBytes, List<int> salt) async {
    final derivedSeed = _pbkdf2(
      password: Uint8List.fromList(passwordBytes),
      salt: Uint8List.fromList(salt),
      iterations: pbkdf2Iterations,
      keyLength: 64,
    );

    Uint8List masterKey;
    try {
      masterKey = Uint8List.fromList(sha256.convert(derivedSeed).bytes);
    } finally {
      _wipeBuffer(derivedSeed);
    }

    final base64Key = base64Url.encode(masterKey);
    await _secureStorage.write(
      key: masterKeyStorageKey,
      value: base64Key,
    );
    await _secureStorage.write(
      key: mnemonicBackupStatusKey,
      value: 'true',
    );

    return masterKey;
  }
}
