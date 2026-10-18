import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  // Initialize ffi implementation
  sqfliteFfiInit();

  databaseFactory = databaseFactoryFfi;

  test('database isolation test', () async {
    // Your test code here
  });
}
