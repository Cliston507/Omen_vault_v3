
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:flutter/foundation.dart';

class DBHelper {
  static Future<void> initDB() async {
    if (kIsWeb) {
      // Use the web-specific factory
      databaseFactory = databaseFactoryFfiWeb;
    }
  }
}
