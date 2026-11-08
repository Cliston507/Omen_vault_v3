import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/vault_entry.dart';
import 'entry_cipher.dart';

/// Cloud-side pieces of the recovery flow: the account's key fingerprint and
/// downloading entries for a restore.
class VaultCloud {
  final FirebaseFirestore? _injected;

  VaultCloud({FirebaseFirestore? db}) : _injected = db;

  FirebaseFirestore get _db => _injected ?? FirebaseFirestore.instance;

  /// The fingerprint of this account's master key, or null if the account
  /// has never set up a recovery phrase.
  Future<String?> getKeyId(String uid) async {
    final snap = await _db.collection('users').doc(uid).get();
    return snap.data()?['vaultKeyId'] as String?;
  }

  Future<void> setKeyId(String uid, String keyId) => _db
      .collection('users')
      .doc(uid)
      .set({'vaultKeyId': keyId}, SetOptions(merge: true));

  /// Downloads and decrypts every entry for [uid]. Entries uploaded before
  /// encryption existed (plain title/body) are returned as-is so they can be
  /// re-uploaded encrypted.
  Future<List<VaultEntry>> downloadEntries({
    required String uid,
    required Uint8List key,
  }) async {
    final snap = await _db
        .collection('vault_entries')
        .where('ownerId', isEqualTo: uid)
        .get();

    final entries = <VaultEntry>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      final ts = data['updatedAt'];
      final updatedAt = ts is Timestamp ? ts.toDate() : DateTime.now();

      String title;
      String body;
      final enc = data['enc'];
      if (enc is String) {
        final clear = await EntryCipher.decrypt(
          key: key,
          ownerId: uid,
          entryId: doc.id,
          payload: enc,
        );
        title = clear.title;
        body = clear.body;
      } else {
        title = data['title'] as String? ?? '';
        body = data['body'] as String? ?? '';
      }

      entries.add(VaultEntry(
        id: doc.id,
        title: title,
        body: body,
        ownerId: uid,
        updatedAt: updatedAt,
      ));
    }
    return entries;
  }
}
