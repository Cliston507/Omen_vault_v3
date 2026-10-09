
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:omen_vault_v3/auth_wrapper.dart';
import 'package:omen_vault_v3/tracker_test_screen.dart';
import 'package:omen_vault_v3/views/vault_home_view.dart';
import 'package:omen_vault_v3/core/services/analytics_service.dart';
import 'package:omen_vault_v3/helpers/db_helper.dart';
import 'package:omen_vault_v3/services/vault_repository.dart';
import 'package:omen_vault_v3/services/mutation_queue_service.dart';
import 'package:omen_vault_v3/main.dart';

/// In-memory analytics double so widget tests need no Firebase.
class FakeAnalyticsService implements IAnalyticsService {
  @override
  Future<void> logScreen({required String screenName}) async {}

  @override
  Future<void> logAction(
      {required String name, Map<String, Object>? parameters}) async {}

  @override
  Future<void> setUserId(String? userId) async {}
}

Widget _wrap(Widget child, {User? user}) {
  return MultiProvider(
    providers: [
      Provider<IAnalyticsService>(create: (_) => FakeAnalyticsService()),
      StreamProvider<User?>(create: (_) => Stream.value(user), initialData: user),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
    ],
    child: MaterialApp(home: child),
  );
}

void main() {
  testWidgets('signed out: AuthWrapper shows the login screen',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const AuthWrapper()));
    await tester.pumpAndSettle();

    expect(find.byType(AuthWrapper), findsOneWidget);
    expect(find.text('Email'), findsWidgets);
    expect(find.text('Password'), findsWidgets);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Sign In Anonymously'), findsOneWidget);
  });

  testWidgets('home screen renders with app bar and tracker card',
      (WidgetTester tester) async {
    await tester.pumpWidget(_wrap(const TrackerTestScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Omen Vault'), findsOneWidget);
    expect(find.text('Firebase Analytics Tracker'), findsOneWidget);
    expect(find.byIcon(Icons.person), findsOneWidget);
    expect(find.byIcon(Icons.dark_mode), findsOneWidget);
  });

  group('vault flow', () {
    late VaultRepository repository;
    late MutationQueueService queue;
    late Database db;

    setUpAll(() {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      db = await databaseFactoryFfi.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 2,
          onCreate: (db, version) async {
            await db.execute('''
              CREATE TABLE vault_entries(
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                body TEXT NOT NULL,
                ownerId TEXT NOT NULL,
                updatedAt TEXT NOT NULL
              )
            ''');
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
      final dbHelper = DBHelper.test(db);
      repository = VaultRepository(
        dbHelper: dbHelper,
        userId: 'test-user',
      );
      queue = MutationQueueService.test(dbHelper);
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('vault home shows the empty state', (tester) async {
      await tester.pumpWidget(_wrap(VaultHomeView(repository: repository)));
      // The FFI database runs on a real isolate: bridge real async, then
      // pump frames. (The loading spinner never settles, so no pumpAndSettle.)
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      expect(find.text('Omen Vault'), findsOneWidget);
      expect(
          find.text('Your vault is empty. Add your first entry.'), findsOneWidget);
      expect(find.byIcon(Icons.add), findsOneWidget);
    });

    test('saving an entry writes it to the vault and queues the sync mutation',
        () async {
      await repository.saveEntry(title: 'Test entry', body: 'Secret content');

      final entries = await repository.getEntries();
      expect(entries.length, 1);
      expect(entries.first.title, 'Test entry');
      expect(entries.first.body, 'Secret content');

      final queued = await queue.getUnsyncedMutations();
      expect(queued.length, 1);
      expect(queued.first.model, 'vault_entries');
      expect(queued.first.action, 'create');
      expect(queued.first.ownerId, 'test-user');

      // Updating the entry enqueues an update mutation, not another create.
      await repository.saveEntry(
          id: entries.first.id, title: 'Renamed', body: 'Updated');
      final queuedAfter = await queue.getUnsyncedMutations();
      expect(queuedAfter.length, 2);
      expect(queuedAfter.last.action, 'update');

      // Deleting removes locally and queues a delete mutation.
      await repository.deleteEntry(entries.first.id);
      expect((await repository.getEntries()), isEmpty);
      final queuedDelete = await queue.getUnsyncedMutations();
      expect(queuedDelete.last.action, 'delete');
    });

    testWidgets('vault home lists saved entries',
        (tester) async {
      // Real-isolate DB calls must run inside runAsync or they deadlock
      // the fake async zone.
      await tester.runAsync(() async {
        await repository.saveEntry(title: 'Existing', body: 'Already here');
      });
      await tester.pumpWidget(_wrap(VaultHomeView(repository: repository)));
      await tester.runAsync(
          () => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      expect(find.text('Existing'), findsOneWidget);
      expect(find.text('Already here'), findsOneWidget);
    });
  });
}
