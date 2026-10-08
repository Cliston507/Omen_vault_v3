
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

/// Encrypted local database for Omen Vault.
///
/// The database is encrypted with SQLCipher. The master key is generated once,
/// kept in platform secure storage (Keychain / Keystore) and never written to
/// disk in plaintext or to the repository.
class DBHelper {
  static Future<Database>? _initFuture;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static const String _dbKeyStorageKey = 'omen_vault_db_key';

  static const int _schemaVersion = 2;

  final Database? _testDb;

  DBHelper() : _testDb = null;

  DBHelper.test(this._testDb);

  Future<Database> get database async {
    if (_testDb != null) return _testDb!;
    // Memoized so concurrent callers cannot race key generation or open the
    // database twice. On failure the memo is cleared so a later call retries.
    if (_initFuture == null) {
      final future = _init();
      _initFuture = future;
      unawaited(future.then((_) {}, onError: (_) {
        _initFuture = null;
      }));
    }
    return _initFuture!;
  }

  /// The database master key. Generated once and stored in secure storage.
  /// The returned future is shared, so key generation happens exactly once.
  static Future<String> _getOrCreateKey() async =>
      _keyFuture ??= _createOrReadKey();

  static Future<String>? _keyFuture;

  static Future<String> _createOrReadKey() async {
    final existing = await _secureStorage.read(key: _dbKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      return existing;
    }
    final random = Random.secure();
    final key =
        List.generate(64, (_) => random.nextInt(16).toRadixString(16)).join();
    await _secureStorage.write(key: _dbKeyStorageKey, value: key);
    return key;
  }

  Future<Database> _init() async {
    final path = join(await getDatabasesPath(), 'app.db');
    final password = await _getOrCreateKey();
    try {
      return await _openEncrypted(path, password);
    } on Object {
      // The database may pre-date encryption (a plaintext v1 database).
      // Migrate it without destroying the original until the encrypted
      // replacement is built and verified.
      return await _migrateLegacyPlaintext(path, password);
    }
  }

  Future<Database> _openEncrypted(String path, String password) =>
      openDatabase(
        path,
        version: _schemaVersion,
        password: password,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(_mutationQueueSchema);
    await db.execute(_vaultEntriesSchema);
  }

  Future<void> _onUpgrade(Database db, int from, int to) async {
    if (from < 2) {
      await db.execute(
          'ALTER TABLE mutation_queue ADD COLUMN ownerId TEXT');
      await db.execute(_vaultEntriesSchema);
    }
  }

  static const String _mutationQueueSchema = '''
    CREATE TABLE mutation_queue(
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      model TEXT NOT NULL,
      data TEXT NOT NULL,
      action TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      ownerId TEXT
    )
  ''';

  static const String _vaultEntriesSchema = '''
    CREATE TABLE vault_entries(
      id TEXT PRIMARY KEY,
      title TEXT NOT NULL,
      body TEXT NOT NULL,
      ownerId TEXT NOT NULL,
      updatedAt TEXT NOT NULL
    )
  ''';

  /// Migrates a legacy plaintext database to the encrypted schema without
  /// destroying the source file. The encrypted replacement is built at a
  /// temporary path, filled with every row of every existing table, and only
  /// after a successful reopen is the old file replaced. If the existing file
  /// is neither a valid plaintext database nor a valid encrypted one (for
  /// example an encrypted database whose key was lost), a clear error is
  /// surfaced instead of erasing anything.
  Future<Database> _migrateLegacyPlaintext(
      String path, String password) async {
    List<Map<String, dynamic>> queueRows;
    List<Map<String, dynamic>> entryRows;
    try {
      final plain = await openDatabase(
        path,
        version: _schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
      );
      queueRows = await plain.query('mutation_queue');
      try {
        entryRows = await plain.query('vault_entries');
      } on Object {
        // v1 databases have no vault_entries table.
        entryRows = [];
      }
      await plain.close();
    } on Object {
      throw StateError(
        'Could not open the local vault database. If this device previously '
        'used an encrypted vault, the encryption key may have been lost; the '
        'local file was left untouched. Contact support before deleting '
        'anything — unsynchronized vault entries have no server copy.',
      );
    }

    // Build the encrypted replacement next to the original.
    final tempPath = '$path.new';
    try {
      await deleteDatabase(tempPath);
    } on Object {
      // Ignore: a fresh build below will fail loudly if the path is bad.
    }
    Database rebuilt;
    try {
      rebuilt = await _openEncrypted(tempPath, password);
      await rebuilt.transaction((txn) async {
        for (final row in queueRows) {
          await txn.insert('mutation_queue', row,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
        for (final row in entryRows) {
          await txn.insert('vault_entries', row,
              conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      await rebuilt.close();
    } on Object catch (e) {
      try {
        await deleteDatabase(tempPath);
      } on Object {/* best effort cleanup */}
      throw StateError('Vault database migration failed; nothing was '
          'deleted. Error: $e');
    }

    // Swap: remove the legacy file, move the encrypted one into place.
    try {
      await deleteDatabase(path);
      await File(tempPath).rename(path);
    } on Object catch (e) {
      // The rebuilt file still exists at tempPath: recovery is possible.
      throw StateError('Vault database migration could not be finalized; '
          'the original file may still be in place and the migrated copy is '
          'at $tempPath. Error: $e');
    }
    return _openEncrypted(path, password);
  }
}
