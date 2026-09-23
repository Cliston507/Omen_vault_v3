
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omen_vault_v3/helpers/db_helper.dart';
import 'package:omen_vault_v3/services/mutation_queue_service.dart';
import 'package:omen_vault_v3/services/sync_service.dart';

void main() {
  // Initialize FFI for sqflite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SyncService Unit Tests', () {
    late DBHelper dbHelper;
    late MutationQueueService mutationQueueService;
    late SyncService syncService;
    late Database db;

    setUp(() async {
      // Use an in-memory database for testing
      db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath, options: OpenDatabaseOptions(version: 1, onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mutation_queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model TEXT NOT NULL,
            data TEXT NOT NULL,
            action TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      }));

      dbHelper = DBHelper.test(db);
      mutationQueueService = MutationQueueService.test(dbHelper);
      syncService = SyncService.test(mutationQueueService);
    });

    tearDown(() async {
      await db.close();
    });

    test('Should enqueue mutations, process them in order, and clear the queue', () async {
      // 1. Enqueue mutations out of order
      final mutation1 = Mutation(model: 'test', data: {'id': 1, 'name': 'first'}, action: 'create', timestamp: DateTime.now().subtract(const Duration(minutes: 1)));
      final mutation2 = Mutation(model: 'test', data: {'id': 2, 'name': 'second'}, action: 'create', timestamp: DateTime.now());

      await mutationQueueService.enqueue(mutation2);
      await mutationQueueService.enqueue(mutation1);

      // 2. Verify mutations were enqueued
      List<Mutation> unsynced = await mutationQueueService.getUnsyncedMutations();
      expect(unsynced.length, 2);

      // 3. Process the queue
      await (syncService as dynamic).processQueue(); // Using dynamic to access private method for testing

      // 4. Verify mutations were processed and queue is empty
      unsynced = await mutationQueueService.getUnsyncedMutations();
      expect(unsynced.length, 0);
    });
  });
}
