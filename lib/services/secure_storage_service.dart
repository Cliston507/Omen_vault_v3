import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final secureStorageServiceProvider = Provider<SecureStorageService>((ref) => SecureStorageService.instance);

class SecureStorageService {
  SecureStorageService._privateConstructor();
  static final SecureStorageService instance = SecureStorageService._privateConstructor();

  final _storage = const FlutterSecureStorage();

  Future<void> saveMasterKey(String password) async {
    await _storage.write(key: 'master_password', value: password);
  }

  Future<String?> getMasterKey() async {
    return await _storage.read(key: 'master_password');
  }

  Future<void> deleteMasterKey() async {
    await _storage.delete(key: 'master_password');
  }
}
