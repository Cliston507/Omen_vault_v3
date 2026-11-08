import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Title + body of a vault entry after decryption.
class DecryptedEntry {
  final String title;
  final String body;
  const DecryptedEntry({required this.title, required this.body});
}

/// End-to-end encryption for vault entries that go to the cloud.
///
/// AES-256-GCM with the master key from the recovery phrase. The cloud only
/// ever stores `enc` (nonce + ciphertext + auth tag, base64). The owner id and
/// entry id are bound in as associated data, so an encrypted body can't be
/// copied onto a different entry or account without failing to decrypt.
class EntryCipher {
  static const int version = 1;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static final AesGcm _aes = AesGcm.with256bits(nonceLength: _nonceLength);

  static List<int> _aad(String ownerId, String entryId) =>
      utf8.encode('omen-vault|v$version|$ownerId|$entryId');

  static Future<String> encrypt({
    required Uint8List key,
    required String ownerId,
    required String entryId,
    required String title,
    required String body,
  }) async {
    final clear = utf8.encode(jsonEncode({'title': title, 'body': body}));
    final box = await _aes.encrypt(
      clear,
      secretKey: SecretKey(key),
      aad: _aad(ownerId, entryId),
    );
    return base64.encode(box.concatenation());
  }

  /// Throws [SecretBoxAuthenticationError] if the key is wrong or the data
  /// was tampered with.
  static Future<DecryptedEntry> decrypt({
    required Uint8List key,
    required String ownerId,
    required String entryId,
    required String payload,
  }) async {
    final box = SecretBox.fromConcatenation(
      base64.decode(payload),
      nonceLength: _nonceLength,
      macLength: _macLength,
    );
    final clear = await _aes.decrypt(
      box,
      secretKey: SecretKey(key),
      aad: _aad(ownerId, entryId),
    );
    final map = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
    return DecryptedEntry(
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
    );
  }
}
