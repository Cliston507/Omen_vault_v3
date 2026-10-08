
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:omen_vault_v3/main.dart';
import 'package:omen_vault_v3/models/vault_entry.dart';
import 'package:omen_vault_v3/profile_screen.dart';
import 'package:omen_vault_v3/services/vault_repository.dart';
import 'package:omen_vault_v3/views/vault_edit_view.dart';

/// The signed-in home of Omen Vault: the user's encrypted entries.
class VaultHomeView extends StatefulWidget {
  final VaultRepository? repository;

  const VaultHomeView({super.key, this.repository});

  @override
  State<VaultHomeView> createState() => _VaultHomeViewState();
}

class _VaultHomeViewState extends State<VaultHomeView> {
  late final VaultRepository repository =
      widget.repository ?? VaultRepository();

  List<VaultEntry> _entries = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  Future<void> _loadEntries() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await repository.getEntries();
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load the vault. Your entries are still stored '
            'safely on this device.';
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({VaultEntry? entry}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => VaultEditView(entry: entry, repository: repository),
      ),
    );
    if (result == true) {
      await _loadEntries();
    }
  }

  Future<void> _confirmDelete(VaultEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(
            '"${entry.title}" will be deleted from this device and the cloud '
            'on the next sync.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await repository.deleteEntry(entry.id);
      await _loadEntries();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      // The encrypted local database (SQLCipher) is not available on the
      // web platform; show an honest notice instead of silently falling
      // back to unencrypted storage.
      return Scaffold(
        appBar: AppBar(title: const Text('Omen Vault')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24.0),
            child: Text(
              'The encrypted vault is available in the Omen Vault app '
              '(Android, iOS, Windows, macOS and Linux).',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }
    final themeProvider = Provider.of<ThemeProvider>(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Omen Vault'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProfileScreen()),
            ),
            tooltip: 'Profile',
          ),
          IconButton(
            icon: Icon(themeProvider.themeMode == ThemeMode.dark
                ? Icons.light_mode
                : Icons.dark_mode),
            onPressed: () =>
                Provider.of<ThemeProvider>(context, listen: false).toggleTheme(),
            tooltip: 'Toggle Theme',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'New entry',
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: _loadEntries,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _entries.isEmpty
                  ? const Center(
                      child: Text('Your vault is empty. Add your first entry.'),
                    )
                  : ListView.builder(
                      itemCount: _entries.length,
                      itemBuilder: (context, index) {
                        final entry = _entries[index];
                        return ListTile(
                          leading: const Icon(Icons.lock_outline),
                          title: Text(entry.title),
                          subtitle: Text(
                            entry.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _confirmDelete(entry),
                          ),
                          onTap: () => _openEditor(entry: entry),
                        );
                      },
                    ),
    );
  }
}
