import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/vault_record.dart';
import '../services/database_service.dart';
import '../services/encryption_service.dart';

final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

final vaultItemsStreamProvider = StreamProvider<List<VaultRecord>>((ref) {
  final db = ref.watch(databaseServiceProvider);
  return db.getVaultEntries();
});

final vaultEntriesProvider = vaultItemsStreamProvider;

final encryptionServiceProvider = Provider<EncryptionService>((ref) {
  return EncryptionService();
});

class DecryptionCacheNotifier extends StateNotifier<Map<String, String>> {
  final EncryptionService _encryptionService;

  DecryptionCacheNotifier(this._encryptionService) : super(const {});

  Future<String> getOrDecrypt(VaultRecord item, String activeKey) async {
    if (state.containsKey(item.id)) {
      return state[item.id]!;
    }

    try {
      final decrypted = await _encryptionService.decryptData(
        item.encryptedData.isNotEmpty ? item.encryptedData : item.password,
        activeKey,
      );
      state = {...state, item.id: decrypted};
      return decrypted;
    } catch (e) {
      final errorMsg = item.password.isNotEmpty ? item.password : 'Decryption failed: $e';
      state = {...state, item.id: errorMsg};
      return errorMsg;
    }
  }

  void invalidate(String id) {
    if (state.containsKey(id)) {
      final updated = Map<String, String>.from(state)..remove(id);
      state = Map.unmodifiable(updated);
    }
  }

  void clearAll() {
    state = const {};
  }
}

final decryptionCacheProvider =
    StateNotifierProvider<DecryptionCacheNotifier, Map<String, String>>((ref) {
  final encryptionService = ref.watch(encryptionServiceProvider);
  return DecryptionCacheNotifier(encryptionService);
});
