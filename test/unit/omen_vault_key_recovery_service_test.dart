
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omen_vault_v3/services/omen_vault_key_recovery_service.dart';

// Public test fixture only. Never use this mnemonic for a real vault.
const _mnemonic =
    'abandon abandon abandon abandon abandon abandon '
    'abandon abandon abandon abandon abandon about';

// These are custom Omen vectors, NOT standard BIP-39 output vectors.
const _emptyPassphraseKeyHex =
    '9c665b3f7b8338a81f77d569da9bcc508'
    'da9ab31a52a7b645cec8f4cf4613b96';

const _trezorPassphraseKeyHex =
    '1521fb1847bab444557a8974c9eebba1b'
    'd002691ac8a868849464241059367df';

void main() {
  late _MemorySecureStorage storage;
  late OmenVaultKeyRecoveryService service;

  setUp(() {
    storage = _MemorySecureStorage();
    service = OmenVaultKeyRecoveryService(storage);
  });

  group('derivation regression vectors', () {
    test('pins the current KDF parameters', () {
      expect(OmenVaultKeyRecoveryService.pbkdf2Iterations, 200000);
    });

    test('matches the fixed empty-passphrase vector', () async {
      final key = await service.recoverAndStoreMasterKey(
        utf8.encode(_mnemonic),
        utf8.encode('mnemonic'),
      );

      expect(key, isA<Uint8List>());
      expect(key.length, 32);
      expect(key, orderedEquals(_bytesFromHex(_emptyPassphraseKeyHex)));
    });

    test('matches the fixed TREZOR-passphrase vector', () async {
      final key = await service.recoverAndStoreMasterKey(
        utf8.encode(_mnemonic),
        utf8.encode('mnemonicTREZOR'),
      );

      expect(key.length, 32);
      expect(key, orderedEquals(_bytesFromHex(_trezorPassphraseKeyHex)));
    });
  });

  group('secure-storage persistence', () {
    test('stores the base64url key, then the backup flag', () async {
      final key = await service.recoverAndStoreMasterKey(
        utf8.encode(_mnemonic),
        utf8.encode('mnemonic'),
      );

      expect(
        storage.writes.map((write) => write.key).toList(),
        <String>[
          OmenVaultKeyRecoveryService.masterKeyStorageKey,
          OmenVaultKeyRecoveryService.mnemonicBackupStatusKey,
        ],
      );

      expect(storage.writes[0].value, base64Url.encode(key));
      expect(storage.writes[1].value, 'true');

      final stored = storage.values[
          OmenVaultKeyRecoveryService.masterKeyStorageKey]!;
      expect(
        base64Url.decode(stored),
        orderedEquals(_bytesFromHex(_emptyPassphraseKeyHex)),
      );
    });
  });
}

Uint8List _bytesFromHex(String hex) {
  if (hex.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex)) {
    throw ArgumentError.value(hex, 'hex', 'Invalid hex fixture');
  }

  return Uint8List.fromList(
    List<int>.generate(
      hex.length ~/ 2,
      (index) => int.parse(
        hex.substring(index * 2, index * 2 + 2),
        radix: 16,
      ),
    ),
  );
}

class _StorageWrite {
  final String key;
  final String? value;

  const _StorageWrite(this.key, this.value);
}

class _MemorySecureStorage extends FlutterSecureStorage {
  final Map<String, String> values = <String, String>{};
  final List<_StorageWrite> writes = <_StorageWrite>[];

  int? failOnWriteNumber;
  Object? writeFailure;
  Object? readFailure;

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    writes.add(_StorageWrite(key, value));

    if (writes.length == failOnWriteNumber) {
      throw writeFailure ?? StateError('Injected write failure');
    }

    if (value == null) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WindowsOptions? wOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
  }) async {
    final failure = readFailure;
    if (failure != null) {
      throw failure;
    }
    return values[key];
  }
}
