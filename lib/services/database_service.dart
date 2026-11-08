
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entry_cipher.dart';
import 'mutation_queue_service.dart';
import 'omen_vault_key_recovery_service.dart';

typedef MasterKeyProvider = Future<Uint8List?> Function();

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final MasterKeyProvider _masterKey;

  DatabaseService({MasterKeyProvider? masterKey})
      : _masterKey =
            masterKey ?? OmenVaultKeyRecoveryService().getActiveMasterKey;

  Future<void> createUser(String uid, String email) async {
    await _db.collection('users').doc(uid).set({
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Sends a queued mutation to Firestore in a user-scoped way.
  ///
  /// The mutation is stamped with the *queued* owner (validated by the
  /// SyncService against the currently signed-in user), so an account change
  /// mid-run can never re-attribute data. Documents without a stable id are
  /// refused so retries can never create duplicates.
  Future<bool> dispatchMutation(Mutation mutation) async {
    final uid = mutation.ownerId ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      // Never drop a queued mutation just because the user is signed out;
      // report failure so it stays in the local queue for a later attempt.
      return false;
    }

    final data = Map<String, dynamic>.from(mutation.data);
    final docId = data['id']?.toString();
    data.remove('id');
    if (docId == null || docId.isEmpty) {
      // No stable id: refuse rather than risk duplicate documents on retry.
      return false;
    }
    data['ownerId'] = uid;
    data['updatedAt'] = FieldValue.serverTimestamp();

    try {
      // Vault entries are end-to-end encrypted: the cloud gets only `enc`,
      // and any old plain title/body fields are deleted. With no recovery
      // phrase set up yet, the upload waits in the local queue.
      if (mutation.model == 'vault_entries' &&
          (mutation.action == 'create' || mutation.action == 'update')) {
        final key = await _masterKey();
        if (key == null) return false;
        data['enc'] = await EntryCipher.encrypt(
          key: key,
          ownerId: uid,
          entryId: docId,
          title: data['title'] as String? ?? '',
          body: data['body'] as String? ?? '',
        );
        data['encV'] = EntryCipher.version;
        data['title'] = FieldValue.delete();
        data['body'] = FieldValue.delete();
      }

      switch (mutation.action) {
        case 'create':
        case 'update':
          await _db
              .collection(mutation.model)
              .doc(docId)
              .set(data, SetOptions(merge: true));
          return true;
        case 'delete':
          await _db.collection(mutation.model).doc(docId).delete();
          return true;
        default:
          return false;
      }
    } catch (e) {
      return false;
    }
  }
}
