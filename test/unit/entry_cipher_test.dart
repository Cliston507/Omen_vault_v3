import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omen_vault_v3/services/entry_cipher.dart';
import 'package:omen_vault_v3/services/omen_vault_key_recovery_service.dart';

void main() {
  final keyA = Uint8List.fromList(List.generate(32, (i) => i));
  final keyB = Uint8List.fromList(List.generate(32, (i) => 255 - i));

  Future<String> enc({String owner = 'u1', String id = 'e1'}) =>
      EntryCipher.encrypt(
        key: keyA,
        ownerId: owner,
        entryId: id,
        title: 'Bank PIN',
        body: 'Secret note ✓',
      );

  test('round trip returns the original title and body', () async {
    final payload = await enc();
    final clear = await EntryCipher.decrypt(
        key: keyA, ownerId: 'u1', entryId: 'e1', payload: payload);
    expect(clear.title, 'Bank PIN');
    expect(clear.body, 'Secret note ✓');
  });

  test('cloud payload contains no readable text', () async {
    final payload = await enc();
    expect(payload.contains('Bank'), isFalse);
    expect(payload.contains('Secret'), isFalse);
  });

  test('same entry encrypts differently each time (fresh nonce)', () async {
    expect(await enc(), isNot(equals(await enc())));
  });

  test('wrong key fails', () async {
    final payload = await enc();
    expect(
      EntryCipher.decrypt(
          key: keyB, ownerId: 'u1', entryId: 'e1', payload: payload),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('moving the payload to another entry or account fails', () async {
    final payload = await enc();
    expect(
      EntryCipher.decrypt(
          key: keyA, ownerId: 'u1', entryId: 'e2', payload: payload),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
    expect(
      EntryCipher.decrypt(
          key: keyA, ownerId: 'u2', entryId: 'e1', payload: payload),
      throwsA(isA<SecretBoxAuthenticationError>()),
    );
  });

  test('key fingerprint is stable and differs per key', () async {
    final a1 = await OmenVaultKeyRecoveryService.keyId(keyA);
    final a2 = await OmenVaultKeyRecoveryService.keyId(keyA);
    final b = await OmenVaultKeyRecoveryService.keyId(keyB);
    expect(a1, a2);
    expect(a1, isNot(b));
  });
}
