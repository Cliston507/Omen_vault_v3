
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omen_vault_v3/helpers/db_helper.dart';
import 'package:omen_vault_v3/services/mutation_queue_service.dart';
import 'package:omen_vault_v3/services/sync_service.dart';

void main() {
  // Initialize FFI for sqflite
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  Future<Database> newTestDb() => databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE mutation_queue(
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                model TEXT NOT NULL,
                data TEXT NOT NULL,
                action TEXT NOT NULL,
                timestamp TEXT NOT NULL,
                ownerId TEXT
              )
            ''');
          },
        ),
      );

  group('SyncService Unit Tests', () {
    late DBHelper dbHelper;
    late MutationQueueService mutationQueueService;
    late SyncService syncService;
    late Database db;

    setUp(() async {
      db = await newTestDb();
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
      expect(unsynced.first.ownerId, isNull);

      // 3. Process the queue
      await (syncService as dynamic).processQueue(); // Using dynamic to access private method for testing

      // 4. Verify mutations were processed and queue is empty
      unsynced = await mutationQueueService.getUnsyncedMutations();
      expect(unsynced.length, 0);
    });

    test('A failed dispatch retains the mutation and stops the queue in order', () async {
      final failing = SyncService.test(
        mutationQueueService,
        dispatcher: (m) async => false,
      );

      await mutationQueueService.enqueue(Mutation(
        model: 'test', data: {'id': 1}, action: 'create',
        timestamp: DateTime.now().subtract(const Duration(minutes: 1)),
      ));
      await mutationQueueService.enqueue(Mutation(
        model: 'test', data: {'id': 2}, action: 'create',
        timestamp: DateTime.now(),
      ));

      await failing.processQueue();

      // Both mutations stay queued: the first failed, so the second must not
      // be applied (and removed) out of order.
      final unsynced = await mutationQueueService.getUnsyncedMutations();
      expect(unsynced.length, 2);
      expect(unsynced.first.data['id'], 1);
    });

    test('Mutations owned by another user are never dispatched', () async {
      var dispatched = 0;
      final svc = SyncService(
        dispatcher: (m) async {
          dispatched++;
          return true;
        },
        uidProvider: () => 'user-a',
        queue: mutationQueueService,
      );

      await mutationQueueService.enqueue(Mutation(
        model: 'test', data: {'id': 1}, action: 'create',
        timestamp: DateTime.now(), ownerId: 'user-b',
      ));

      await svc.processQueue();

      expect(dispatched, 0);
      final retained = await mutationQueueService.getUnsyncedMutations();
      expect(retained.where((m) => m.ownerId == 'user-b').length, 1);
    });

    test('Ownerless legacy mutations are skipped, not auto-assigned', () async {
      var dispatched = 0;
      final svc = SyncService(
        dispatcher: (m) async {
          dispatched++;
          return true;
        },
        uidProvider: () => 'user-a',
        queue: mutationQueueService,
      );

      await db.insert('mutation_queue', {
        'model': 'test',
        'data': '{"id": 1}',
        'action': 'create',
        'timestamp': DateTime.now().toIso8601String(),
        'ownerId': null,
      });

      await svc.processQueue();

      expect(dispatched, 0);
      final retained = await mutationQueueService.getUnsyncedMutations();
      expect(retained.where((m) => m.ownerId == null).length, 1);
    });
  });
}
