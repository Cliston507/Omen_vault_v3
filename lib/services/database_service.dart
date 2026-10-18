import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vault_record.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService.instance);

class DatabaseService {
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<Map<String, dynamic>> _collection =
      _firestore.collection('vault_items');

  Future<List<VaultRecord>> getAllRecords() async {
    final snapshot = await _collection.get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      data['firestoreId'] = doc.id;
      return VaultRecord.fromMap(data);
    }).toList();
  }

  Future<void> saveRecord(VaultRecord record) async {
    final docRef = record.firestoreId != null
        ? _collection.doc(record.firestoreId)
        : _collection.doc();

    final data = record.toMap();
    data['firestoreId'] = docRef.id;

    await docRef.set(data, SetOptions(merge: true));
  }

  Future<void> deleteRecord(String firestoreId) async {
    await _collection.doc(firestoreId).delete();
  }
}
