
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'mutation_queue_service.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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
