import 'package:flutter_test/flutter_test.dart';
import 'package:omen_vault_v3/services/omen_vault_key_recovery_service.dart';

void main() {
  const valid =
      'abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon abandon about';

  group('phrase validation', () {
    test('accepts the standard BIP-39 test phrase', () {
      expect(OmenVaultKeyRecoveryService.isValidMnemonic(valid), isTrue);
    });

    test('accepts messy spacing and capitals', () {
      expect(
        OmenVaultKeyRecoveryService.isValidMnemonic(
            '  ABANDON abandon\nabandon abandon abandon abandon abandon '
            'abandon abandon abandon   abandon About '),
        isTrue,
      );
    });

    test('rejects a typo', () {
      expect(
        OmenVaultKeyRecoveryService.isValidMnemonic(
            valid.replaceFirst('about', 'abuot')),
        isFalse,
      );
    });

    test('rejects real words with a bad checksum', () {
      expect(
        OmenVaultKeyRecoveryService.isValidMnemonic(
            List.filled(12, 'abandon').join(' ')),
        isFalse,
      );
    });

    test('rejects wrong word count', () {
      expect(OmenVaultKeyRecoveryService.isValidMnemonic('abandon about'), isFalse);
      expect(OmenVaultKeyRecoveryService.isValidMnemonic(''), isFalse);
    });
  });

  group('generation and quiz', () {
    final service = OmenVaultKeyRecoveryService();

    test('generates 12 valid, different phrases', () {
      final a = service.generateMnemonic();
      final b = service.generateMnemonic();
      expect(a.split(' '), hasLength(12));
      expect(OmenVaultKeyRecoveryService.isValidMnemonic(a), isTrue);
      expect(a, isNot(equals(b)));
    });

    test('picks 3 distinct, sorted, in-range positions', () {
      final positions = service.pickVerificationPositions(valid);
      expect(positions, hasLength(3));
      expect(positions.toSet(), hasLength(3));
      expect(positions, equals([...positions]..sort()));
      expect(positions.every((p) => p >= 0 && p < 12), isTrue);
    });
  });
}
