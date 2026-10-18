import 'dart:convert';
import 'package:sqflite/sqflite.dart';

import 'package:omen_vault_v3/models/vault_entry.dart';

class MutationQueueService {
  final Database _database;

  MutationQueueService(this._database);

  Future<void> _ensureQueueTableExists() async {
    await _database.execute('''
      CREATE TABLE IF NOT EXISTS mutation_queue(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        timestamp INTEGER NOT NULL
      )
      ''');
  }

  Future<void> enqueueAdd(VaultEntry entry) async {
    await _ensureQueueTableExists();
    final data = jsonEncode(entry.toJson());
    await _database.insert('mutation_queue', {
      'type': 'add',
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> enqueueUpdate(VaultEntry entry) async {
    await _ensureQueueTableExists();
    final data = jsonEncode(entry.toJson());
    await _database.insert('mutation_queue', {
      'type': 'update',
      'data': data,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<void> enqueueDelete(int entryId) async {
    await _ensureQueueTableExists();
    await _database.insert('mutation_queue', {
      'type': 'delete',
      'data': jsonEncode({'id': entryId}),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingMutations() async {
    await _ensureQueueTableExists();
    return await _database.query('mutation_queue', orderBy: 'timestamp ASC');
  }

  Future<void> clearProcessedMutations(List<int> processedIds) async {
    if (processedIds.isEmpty) return;
    await _ensureQueueTableExists();
    final ids = processedIds.join(',');
    await _database.delete('mutation_queue', where: 'id IN ($ids)');
  }
}
