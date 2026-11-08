// omen_vault_key_recovery_service.dart
//
// Omen Vault v3 — master key creation, backup verification, and recovery.
//
// Flows:
//   New vault:  generateMnemonic() -> show words to user -> createMasterKey()
//               -> pickVerificationPositions() -> confirmBackup()
//   Restore:    user types their phrase -> restoreMasterKey()
//
// Key derivation:
//   phrase (+ optional passphrase)
//     --BIP-39 (PBKDF2-HMAC-SHA512, 2048 rounds, NFKD)--> 512-bit seed
//     --HKDF-SHA256, info "omen-vault-master-key-v1"-->    256-bit AES-GCM key
//
// The key is derived on-device and stored only in this device's secure
// storage (Android Keystore-backed / iOS Keychain). It never leaves the phone.
//
// pubspec.yaml dependencies:
//   bip39: ^1.0.6
//   cryptography: ^2.7.0
//   flutter_secure_storage: ^10.3.4
//   unorm_dart: ^0.3.0

import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:bip39/bip39.dart' as bip39;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

/// Thrown when key creation or recovery fails. [code] is stable for UI logic;
/// [message] is safe to show to the user.
class VaultKeyRecoveryException implements Exception {
  final String code;
  final String message;

  const VaultKeyRecoveryException({required this.code, required this.message});

  @override
  String toString() => 'VaultKeyRecoveryException [$code]: $message';
}

class OmenVaultKeyRecoveryService {
  static const String masterKeyStorageKey = 'omen_vault_master_key_v1';
  static const String backupVerifiedStorageKey = 'omen_vault_mnemonic_backed_up';

  /// Domain-separation label for HKDF. Bump the version if the scheme changes.
  static const String _hkdfInfo = 'omen-vault-master-key-v1';
  static const int masterKeyLength = 32; // 256 bits for AES-256-GCM
  static const int minVerificationWords = 3;

  final FlutterSecureStorage _secureStorage;

  OmenVaultKeyRecoveryService({FlutterSecureStorage? secureStorage})
      : _secureStorage = secureStorage ??
            const FlutterSecureStorage(
              // resetOnError: false so a keystore hiccup never silently
              // deletes the master key.
              aOptions: AndroidOptions(resetOnError: false),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock_this_device,
              ),
            );

  // ---------------------------------------------------------------------------
  // Phrase generation & validation
  // ---------------------------------------------------------------------------

  /// Generates a standard 12-word BIP-39 phrase from 128 bits of secure entropy.
  String generateMnemonic() =>
      bip39.generateMnemonic(strength: 128, randomBytes: _secureRandomBytes);

  /// Lowercases, applies Unicode NFKD, and collapses whitespace so that
  /// "  Apple   BANANA\n" and "apple banana" are treated the same.
  static String normalizeMnemonic(String input) =>
      unorm.nfkd(input).trim().toLowerCase().split(RegExp(r'\s+')).join(' ');

  /// True if [mnemonic] is 12 or 24 real BIP-39 words with a valid checksum.
  static bool isValidMnemonic(String mnemonic) {
    try {
      _validateOrThrow(normalizeMnemonic(mnemonic));
      return true;
    } on VaultKeyRecoveryException {
      return false;
    }
  }

  static void _validateOrThrow(String normalizedPhrase) {
    final wordCount = normalizedPhrase.isEmpty ? 0 : normalizedPhrase.split(' ').length;
    if (wordCount != 12 && wordCount != 24) {
      throw VaultKeyRecoveryException(
        code: 'invalid_mnemonic_length',
        message: 'Recovery phrase must be exactly 12 or 24 words. You entered $wordCount.',
      );
    }
    // Checks every word against the official English list AND the checksum,
    // so a single typo or swapped word is caught here instead of silently
    // producing the wrong key.
    if (!bip39.validateMnemonic(normalizedPhrase)) {
      throw const VaultKeyRecoveryException(
        code: 'invalid_mnemonic',
        message: 'That recovery phrase is not valid. Check each word for typos '
            'and make sure the words are in the right order.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Key creation & recovery
  // ---------------------------------------------------------------------------

  /// New vault: derives and stores the master key from a freshly generated
  /// phrase. Backup is marked NOT verified until [confirmBackup] succeeds.
  ///
  /// Throws `vault_already_exists` if a key is already stored, unless
  /// [overwriteExisting] is true — overwriting makes existing encrypted data
  /// unreadable unless the old phrase is restored.
  Future<Uint8List> createMasterKey({
    required String mnemonic,
    String passphrase = '',
    bool overwriteExisting = false,
  }) =>
      _deriveAndStore(
        mnemonic: mnemonic,
        passphrase: passphrase,
        backupVerified: false,
        overwriteExisting: overwriteExisting,
      );

  /// Restore: the user typed their phrase from their backup, which proves they
  /// have it, so the backup is marked verified.
  Future<Uint8List> restoreMasterKey({
    required String mnemonic,
    String passphrase = '',
    bool overwriteExisting = false,
  }) =>
      _deriveAndStore(
        mnemonic: mnemonic,
        passphrase: passphrase,
        backupVerified: true,
        overwriteExisting: overwriteExisting,
      );

  Future<Uint8List> _deriveAndStore({
    required String mnemonic,
    required String passphrase,
    required bool backupVerified,
    required bool overwriteExisting,
  }) async {
    final masterKey = await deriveMasterKey(mnemonic: mnemonic, passphrase: passphrase);
    await storeMasterKey(
      masterKey,
      backupVerified: backupVerified,
      overwriteExisting: overwriteExisting,
    );
    // Caller should _wipe / discard this buffer once it's handed to the cipher.
    return masterKey;
  }

  /// Validates the phrase and derives the master key WITHOUT saving it.
  /// Use this to check a phrase against the cloud before committing to it.
  Future<Uint8List> deriveMasterKey({
    required String mnemonic,
    String passphrase = '',
  }) async {
    final phrase = normalizeMnemonic(mnemonic);
    _validateOrThrow(phrase);
    return _deriveMasterKey(phrase, unorm.nfkd(passphrase));
  }

  /// Saves an already-derived master key to this device's secure storage.
  Future<void> storeMasterKey(
    Uint8List masterKey, {
    required bool backupVerified,
    bool overwriteExisting = false,
  }) async {
    if (!overwriteExisting && await hasVault()) {
      throw const VaultKeyRecoveryException(
        code: 'vault_already_exists',
        message: 'A vault key already exists on this device.',
      );
    }
    await _secureStorage.write(
      key: masterKeyStorageKey,
      value: base64Url.encode(masterKey),
    );
    await _secureStorage.write(
      key: backupVerifiedStorageKey,
      value: backupVerified.toString(),
    );
  }

  /// A public fingerprint of the master key (HMAC, not the key itself).
  /// Stored in the cloud so a phone can tell whether a typed phrase belongs
  /// to this account — without the cloud ever learning the key.
  static Future<String> keyId(Uint8List masterKey) async {
    final mac = await Hmac.sha256().calculateMac(
      utf8.encode('omen-vault-key-id-v1'),
      secretKey: SecretKey(masterKey),
    );
    return base64Url.encode(mac.bytes);
  }

  /// BIP-39 seed (run in a background isolate so the UI doesn't freeze),
  /// then HKDF-SHA256 down to a 256-bit AES key.
  static Future<Uint8List> _deriveMasterKey(String phrase, String passphrase) async {
    final seed = await Isolate.run(
      () => bip39.mnemonicToSeed(phrase, passphrase: passphrase),
    );
    try {
      final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: masterKeyLength);
      final secretKey = await hkdf.deriveKey(
        secretKey: SecretKey(seed),
        info: utf8.encode(_hkdfInfo),
      );
      return Uint8List.fromList(await secretKey.extractBytes());
    } finally {
      _wipe(seed);
    }
  }

  // ---------------------------------------------------------------------------
  // Backup verification ("type word #3, #7, #11")
  // ---------------------------------------------------------------------------

  /// Picks [count] random distinct word positions (0-based, sorted) to quiz
  /// the user on after they write their phrase down.
  List<int> pickVerificationPositions(String mnemonic, {int count = minVerificationWords}) {
    final wordCount = normalizeMnemonic(mnemonic).split(' ').length;
    final positions = List<int>.generate(wordCount, (i) => i)..shuffle(Random.secure());
    return positions.take(count.clamp(1, wordCount)).toList()..sort();
  }

  /// [answers] maps word position (0-based) to what the user typed.
  /// Marks the backup verified only if every answer matches and at least
  /// [minVerificationWords] words were checked.
  Future<bool> confirmBackup({
    required String mnemonic,
    required Map<int, String> answers,
  }) async {
    if (answers.length < minVerificationWords) return false;

    final words = normalizeMnemonic(mnemonic).split(' ');
    for (final entry in answers.entries) {
      if (entry.key < 0 || entry.key >= words.length) return false;
      if (normalizeMnemonic(entry.value) != words[entry.key]) return false;
    }

    await _secureStorage.write(key: backupVerifiedStorageKey, value: 'true');
    return true;
  }

  // ---------------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------------

  Future<bool> hasVault() async =>
      await _secureStorage.read(key: masterKeyStorageKey) != null;

  /// Returns the stored master key, or null if no vault exists on this device.
  Future<Uint8List?> getActiveMasterKey() async {
    final base64Key = await _secureStorage.read(key: masterKeyStorageKey);
    if (base64Key == null) return null;
    return base64Url.decode(base64Key);
  }

  /// True only after the user passed [confirmBackup] or restored from a phrase.
  Future<bool> hasVerifiedMnemonicBackup() async =>
      await _secureStorage.read(key: backupVerifiedStorageKey) == 'true';

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Uint8List _secureRandomBytes(int size) {
    final rng = Random.secure();
    return Uint8List.fromList(List<int>.generate(size, (_) => rng.nextInt(256)));
  }

  /// Best-effort zeroing of a byte buffer. Dart can't guarantee no other copies
  /// exist (Strings are immutable and the GC may move memory), so this reduces
  /// exposure but is not a guarantee.
  static void _wipe(List<int> buffer) {
    for (var i = 0; i < buffer.length; i++) {
      buffer[i] = 0;
    }
  }
}
