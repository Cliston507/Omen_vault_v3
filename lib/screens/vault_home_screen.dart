import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/models/vault_entry.dart';
import 'package:omen_vault_v3/repositories/vault_repository.dart';
import 'package:omen_vault_v3/screens/edit_entry_screen.dart';

class VaultHomeScreen extends ConsumerWidget {
  const VaultHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vaultItemsAsync = ref.watch(vaultItemsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Omen Vault'),
        centerTitle: true,
      ),
      body: vaultItemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No vault items yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];

              return Card(
                elevation: 2,
                margin: const EdgeInsets.symmetric(vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.enhanced_encryption_rounded),
                  title: Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('Username: ${item.username}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () async {
                      ref.read(vaultRepositoryProvider).deleteItem(item.id.toString());
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Deleted "${item.title}"')),
                      );
                    },
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text('Error loading vault: $err'),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EditEntryScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

final vaultItemsStreamProvider = StreamProvider<List<VaultEntry>>((ref) {
  final vaultRepository = ref.watch(vaultRepositoryProvider);
  return vaultRepository.getItems();
});
