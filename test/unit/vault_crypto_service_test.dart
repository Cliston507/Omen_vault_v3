import 'package:flutter_test/flutter_test.dart';
import 'package:omen_vault_v3/services/vault_crypto_service.dart';

void main() {
  group('VaultCryptoService', () {
    final cryptoService = VaultCryptoService.instance;

    test('encrypt and decrypt successfully with correct password', () async {
      const plainText = 'This is a secret message.';
      const password = 'mySuperSecretPassword';

      // Encrypt the data
      final encryptedPayload = await cryptoService.encrypt(plainText, password);

      // Ensure the encrypted payload is not the same as the plaintext
      expect(encryptedPayload, isNot(equals(plainText)));
      expect(encryptedPayload, isA<String>());

      // Decrypt the data
      final decryptedText = await cryptoService.decrypt(encryptedPayload, password);

      // Verify that the decrypted text matches the original
      expect(decryptedText, equals(plainText));
    });

    test('decrypt throws an exception with incorrect password', () async {
      const plainText = 'This is another secret message.';
      const correctPassword = 'correctPassword';
      const wrongPassword = 'wrongPassword';

      // Encrypt with the correct password
      final encryptedPayload = await cryptoService.encrypt(plainText, correctPassword);

      // Attempt to decrypt with the wrong password and expect an exception
      expect(
            () async => await cryptoService.decrypt(encryptedPayload, wrongPassword),
        throwsA(isA<Exception>().having(
              (e) => e.toString(),
          'message',
          contains('Decryption failed: Invalid password or corrupted data.'),
        )),
      );
    });

    test('decrypt throws FormatException for invalid payload', () {
      const invalidPayload = 'not-a-base64-string';
      const password = 'any-password';

      expect(
            () async => await cryptoService.decrypt(invalidPayload, password),
        throwsA(isA<Exception>()),
      );
    });
  });
}
