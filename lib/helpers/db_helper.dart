import 'dart:async';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';
import 'package:path/path.dart';

class DBHelper {
  static final DBHelper _instance = DBHelper._internal();
  factory DBHelper() => _instance;
  DBHelper._internal();

  static Database? _database;
  static const _dbName = 'vault.db';
  static const _dbVersion = 1;
  static const _masterKey = 'master_key';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);

    const secureStorage = FlutterSecureStorage();
    String? masterKey = await secureStorage.read(key: _masterKey);
    if (masterKey == null) {
      masterKey = await _generateMasterKey();
      await secureStorage.write(key: _masterKey, value: masterKey);
    }

    return await openDatabase(
      path,
      version: _dbVersion,
      password: masterKey,
      onCreate: _onCreate,
    );
  }

  Future<String> _generateMasterKey() async {
    // In a real app, you should use a more secure way to generate the master key.
    // For this example, we'll use a simple string.
    return 'a_very_secure_master_key';
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE mutation_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        model TEXT NOT NULL,
        data TEXT NOT NULL,
        action TEXT NOT NULL,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  }
}
