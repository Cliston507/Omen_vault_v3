import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:omen_vault_v3/services/omen_vault_key_recovery_service.dart';

final secureStorageProvider = Provider((ref) => const FlutterSecureStorage());

final omenVaultKeyRecoveryServiceProvider = Provider((ref) {
  final secureStorage = ref.watch(secureStorageProvider);
  return OmenVaultKeyRecoveryService(secureStorage);
});
