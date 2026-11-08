
import 'dart:math';
import 'package:sqflite_sqlcipher/sqflite.dart';
import '../helpers/db_helper.dart';
import '../models/vault_entry.dart';
import 'mutation_queue_service.dart';
import 'sync_service.dart';

/// Creates, reads, updates and deletes vault entries in the encrypted local
/// database and enqueues the matching mutations for cloud sync.
///
/// The local change and its outbox record are written in a single SQLite
/// transaction, so a save can never half-apply. Failures are propagated to
/// the caller — the UI shows them instead of reporting false success.
class VaultRepository {
  final DBHelper _dbHelper;
  final String userId;

  VaultRepository({
    DBHelper? dbHelper,
    String? userId,
  })  : _dbHelper = dbHelper ?? DBHelper(),
        userId = userId ?? currentUserIdOrNull() ?? '';

  Future<Database> get _db async => _dbHelper.database;

  Future<List<VaultEntry>> getEntries() async {
    final db = await _db;
    final maps = await db.query(
      'vault_entries',
      where: 'ownerId = ?',
      whereArgs: [userId],
      orderBy: 'updatedAt DESC',
    );
    return maps.map(VaultEntry.fromMap).toList();
  }

  Future<VaultEntry?> getEntry(String id) async {
    final db = await _db;
    final maps = await db.query(
      'vault_entries',
      where: 'id = ? AND ownerId = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    if (maps.isEmpty) return null;
    return VaultEntry.fromMap(maps.first);
  }

  /// Creates or updates an entry locally and queues the remote mutation in
  /// the same transaction, then requests a sync pass.
  Future<void> saveEntry({
    String? id,
    required String title,
    required String body,
  }) async {
    final now = DateTime.now();
    final existing = id == null ? null : await getEntry(id);
    final entryId = id ?? _generateId(now);
    final entry = VaultEntry(
      id: entryId,
      title: title,
      body: body,
      ownerId: userId,
      updatedAt: now,
    );

    final action = existing == null ? 'create' : 'update';
    final mutation = Mutation(
      model: 'vault_entries',
      data: entry.toRemoteData(),
      action: action,
      timestamp: now,
      ownerId: userId,
    );

    final db = await _db;
    await db.transaction((txn) async {
      await txn.insert(
        'vault_entries',
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        'mutation_queue',
        mutation.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });

    SyncService.instance.scheduleSync();
  }

  /// Deletes an entry locally and queues the remote deletion in the same
  /// transaction, then requests a sync pass.
  Future<void> deleteEntry(String id) async {
    final mutation = Mutation(
      model: 'vault_entries',
      data: {'id': id},
      action: 'delete',
      timestamp: DateTime.now(),
      ownerId: userId,
    );

    final db = await _db;
    final affected = await db.transaction((txn) async {
      final count = await txn.delete(
        'vault_entries',
        where: 'id = ? AND ownerId = ?',
        whereArgs: [id, userId],
      );
      if (count > 0) {
        await txn.insert(
          'mutation_queue',
          mutation.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      return count;
    });
    if (affected == 0) {
      throw StateError('No entry with id "$id" in this vault.');
    }

    SyncService.instance.scheduleSync();
  }

  /// Saves entries downloaded during a restore. A local copy that is newer
  /// than the cloud copy is kept.
  Future<void> importEntries(List<VaultEntry> remote) async {
    final db = await _db;
    await db.transaction((txn) async {
      for (final e in remote) {
        if (e.ownerId != userId) continue;
        final existing = await txn.query(
          'vault_entries',
          where: 'id = ? AND ownerId = ?',
          whereArgs: [e.id, userId],
          limit: 1,
        );
        if (existing.isNotEmpty &&
            DateTime.parse(existing.first['updatedAt'] as String)
                .isAfter(e.updatedAt)) {
          continue;
        }
        await txn.insert('vault_entries', e.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  /// Queues every local entry for upload. Run once after a recovery phrase
  /// is set up or restored: it replaces any plain-text cloud copies with
  /// encrypted ones. Returns how many entries were queued.
  Future<int> queueAllForUpload() async {
    final entries = await getEntries();
    if (entries.isEmpty) return 0;
    final now = DateTime.now();
    final db = await _db;
    await db.transaction((txn) async {
      for (final e in entries) {
        await txn.insert(
          'mutation_queue',
          Mutation(
            model: 'vault_entries',
            data: e.toRemoteData(),
            action: 'update',
            timestamp: now,
            ownerId: userId,
          ).toMap(),
        );
      }
    });
    SyncService.instance.scheduleSync();
    return entries.length;
  }

  /// Sortable unique id without extra dependencies: time-ordered with a
  /// random suffix.
  static String _generateId(DateTime now) =>
      '${now.microsecondsSinceEpoch.toRadixString(36)}'
      '-${Random().nextInt(1 << 32).toRadixString(36)}';
}
