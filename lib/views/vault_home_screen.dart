import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/models/vault_entry.dart';
import 'package:omen_vault_v3/services/database_service.dart';
import 'package:omen_vault_v3/services/secure_storage_service.dart';
import 'package:omen_vault_v3/services/vault_crypto_service.dart';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart' show kIsWeb;

final masterPasswordProvider = FutureProvider<String?>((ref) async {
  final secureStorage = ref.watch(secureStorageServiceProvider);
  return await secureStorage.getMasterKey();
});

final vaultEntriesProvider = FutureProvider<List<VaultEntry>>((ref) async {
  final masterPassword = await ref.watch(masterPasswordProvider.future);
  if (masterPassword == null) {
    return [];
  }

  final dbService = ref.watch(databaseServiceProvider);
  final cryptoService = ref.watch(vaultCryptoServiceProvider);
  final records = await dbService.getAllRecords();
  final entries = <VaultEntry>[];

  for (final record in records) {
    try {
      final decryptedJson = await cryptoService.decrypt(record.encryptedData, masterPassword);
      final entryMap = jsonDecode(decryptedJson) as Map<String, dynamic>;

      if (kIsWeb) {
        entryMap['firestoreId'] = record.firestoreId;
      } else {
        entryMap['id'] = record.id;
      }

      entries.add(VaultEntry.fromMap(entryMap));
    } catch (e, s) {
      developer.log(
        'Could not decrypt record ${record.id}',
        name: 'omen_vault.vault_home',
        error: e,
        stackTrace: s,
      );
    }
  }
  return entries;
});

class VaultHomeScreen extends ConsumerStatefulWidget {
  const VaultHomeScreen({super.key});

  @override
  ConsumerState<VaultHomeScreen> createState() => _VaultHomeScreenState();
}

class _VaultHomeScreenState extends ConsumerState<VaultHomeScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    ref.read(masterPasswordProvider.future).then((masterPassword) {
      if (masterPassword == null) {
        _showCreateMasterPasswordDialog();
      }
    });
  }

  void _showCreateMasterPasswordDialog() {
    final passwordController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false, // User must enter a password
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Create Master Password'),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Enter your new master password',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (passwordController.text.isNotEmpty) {
                  final secureStorage = ref.read(secureStorageServiceProvider);
                  final navigator = Navigator.of(dialogContext);
                  await secureStorage.saveMasterKey(passwordController.text);
                  navigator.pop();
                  ref.refresh(masterPasswordProvider);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteEntry(VaultEntry entry) async {
    final dbService = ref.read(databaseServiceProvider);
    if (kIsWeb) {
      await dbService.deleteRecord(entry.firestoreId!);
    } else {
      await dbService.deleteRecord(entry.id!.toString());
    }
    ref.refresh(vaultEntriesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final entriesAsyncValue = ref.watch(vaultEntriesProvider);
    final masterPasswordAsyncValue = ref.watch(masterPasswordProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Vault'),
      ),
      body: masterPasswordAsyncValue.when(
        data: (masterPassword) {
          if (masterPassword == null) {
            return const Center(child: Text('Please create a master password.'));
          }
          return entriesAsyncValue.when(
            data: (entries) {
              if (entries.isEmpty) {
                return const Center(child: Text('No entries yet.'));
              }
              return ListView.builder(
                itemCount: entries.length,
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  return ListTile(
                    title: Text(entry.title),
                    subtitle: Text(entry.username),
                    onTap: () async {
                      await Navigator.pushNamed(
                        context,
                        '/edit_entry',
                        arguments: {
                          'entry': entry,
                          'masterPassword': masterPassword,
                        },
                      );
                      ref.refresh(vaultEntriesProvider);
                    },
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _deleteEntry(entry),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(child: Text('Error: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final masterPassword = await ref.read(masterPasswordProvider.future);
          if (masterPassword != null) {
            await Navigator.pushNamed(
              context,
              '/edit_entry',
              arguments: {
                'masterPassword': masterPassword,
              },
            );
            ref.refresh(vaultEntriesProvider);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
