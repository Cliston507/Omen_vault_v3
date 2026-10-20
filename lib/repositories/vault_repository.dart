import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/models/vault_entry.dart';
import 'package:omen_vault_v3/services/database_service.dart';

final vaultRepositoryProvider = Provider<VaultRepository>((ref) {
  final dbService = ref.watch(databaseServiceProvider);
  return VaultRepository(dbService);
});

class VaultRepository {
  final DatabaseService _dbService;

  VaultRepository(this._dbService);

  Stream<List<VaultEntry>> getItems() {
    return _dbService.watchAllVaultEntries();
  }

  void saveItem(VaultEntry entry) {
    _dbService.insertVaultEntry(entry);
  }

  void deleteItem(String id) {
    _dbService.deleteVaultEntry(id);
  }
}
