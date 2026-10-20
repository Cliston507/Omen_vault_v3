import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/models/vault_entry.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) => DatabaseService());

class DatabaseService {
  static const _databaseName = 'omen_vault.db';
  static const _databaseVersion = 1;

  static const table = 'vault';

  static const columnId = 'id';
  static const columnTitle = 'title';
  static const columnUsername = 'username';
  static const columnPassword = 'password';
  static const columnUrl = 'url';
  static const columnNotes = 'notes';

  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  static Database? _database;
  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $table (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnTitle TEXT NOT NULL,
            $columnUsername TEXT NOT NULL,
            $columnPassword TEXT NOT NULL,
            $columnUrl TEXT NOT NULL,
            $columnNotes TEXT NOT NULL
          )
          ''');
  }

  factory DatabaseService() => instance;

  Future<int> insertVaultEntry(VaultEntry entry) async {
    final db = await instance.database;
    return await db.insert(table, entry.toMap());
  }

  Future<List<VaultEntry>> getAllVaultEntries() async {
    final db = await instance.database;
    final maps = await db.query(table);
    return List.generate(maps.length, (i) {
      return VaultEntry.fromMap(maps[i]);
    });
  }

  Stream<List<VaultEntry>> watchAllVaultEntries() async* {
    final db = await instance.database;
    final entries = await db.query(table);
    yield List.generate(entries.length, (i) {
      return VaultEntry.fromMap(entries[i]);
    });
  }

  Future<int> deleteVaultEntry(String id) async {
    final db = await instance.database;
    return await db.delete(table, where: '$columnId = ?', whereArgs: [id]);
  }
}
