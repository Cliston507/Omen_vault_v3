
import 'dart:async';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class DBHelper {
  static Database? _database;
  final Database? _testDb;

  DBHelper() : _testDb = null;

  DBHelper.test(this._testDb);

  Future<Database> get database async {
    if (_testDb != null) return _testDb!;
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'app.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE mutation_queue(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            model TEXT NOT NULL,
            data TEXT NOT NULL,
            action TEXT NOT NULL,
            timestamp TEXT NOT NULL
          )
        ''');
      },
    );
  }
}
