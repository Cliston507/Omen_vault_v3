import 'package:flutter/material.dart';
import 'package:omen_vault_v3/services/omen_vault_key_recovery_service.dart';
import 'package:omen_vault_v3/services/vault_cloud.dart';
import 'package:omen_vault_v3/services/vault_repository.dart';

/// Restore on a new (or reset) phone: type the 12 words, check them against
/// the account's key fingerprint, then download and decrypt the vault.
class RestoreVaultView extends StatefulWidget {
  final String userId;
  final OmenVaultKeyRecoveryService? service;
  final VaultCloud? cloud;
  final VaultRepository? repository;

  const RestoreVaultView({
    super.key,
    required this.userId,
    this.service,
    this.cloud,
    this.repository,
  });

  @override
  State<RestoreVaultView> createState() => _RestoreVaultViewState();
}

class _RestoreVaultViewState extends State<RestoreVaultView> {
  late final OmenVaultKeyRecoveryService _service =
      widget.service ?? OmenVaultKeyRecoveryService();
  late final VaultCloud _cloud = widget.cloud ?? VaultCloud();
  late final VaultRepository _repository =
      widget.repository ?? VaultRepository(userId: widget.userId);

  final _phrase = TextEditingController();
  bool _working = false;
  String? _error;
  int? _restoredCount;

  @override
  void dispose() {
    _phrase.clear();
    _phrase.dispose();
    super.dispose();
  }

  Future<void> _restore() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      // 1. Check the words and derive the key (nothing saved yet).
      final key = await _service.deriveMasterKey(mnemonic: _phrase.text);

      // 2. Make sure this phrase belongs to this account.
      final keyId = await OmenVaultKeyRecoveryService.keyId(key);
      final cloudKeyId = await _cloud.getKeyId(widget.userId);
      if (cloudKeyId != null && cloudKeyId != keyId) {
        throw const VaultKeyRecoveryException(
          code: 'wrong_phrase',
          message: 'Those are real recovery words, but they don\'t match this '
              'account\'s vault. Check you\'re signed in to the right account '
              'and that the words are in the right order.',
        );
      }

      // 3. Download and decrypt before saving anything, so a failure here
      //    leaves the phone exactly as it was.
      final entries =
          await _cloud.downloadEntries(uid: widget.userId, key: key);

      // 4. Commit: register the key if needed, save it, import entries,
      //    and re-upload so any old plain-text cloud copies get encrypted.
      if (cloudKeyId == null) await _cloud.setKeyId(widget.userId, keyId);
      await _service.storeMasterKey(key,
          backupVerified: true, overwriteExisting: true);
      await _repository.importEntries(entries);
      await _repository.queueAllForUpload();

      _phrase.clear();
      if (!mounted) return;
      setState(() {
        _working = false;
        _restoredCount = entries.length;
      });
    } on VaultKeyRecoveryException catch (e) {
      _fail(e.message);
    } catch (_) {
      _fail('Couldn\'t restore your vault. Check your internet connection '
          'and try again. Nothing on this phone was changed.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _working = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Restore vault')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _restoredCount != null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    Icon(Icons.check_circle,
                        size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 24),
                    Text('Vault restored',
                        style: theme.textTheme.titleLarge,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Text(
                      _restoredCount == 1
                          ? '1 entry is back on this phone.'
                          : '$_restoredCount entries are back on this phone.',
                      textAlign: TextAlign.center,
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Done'),
                    ),
                  ],
                )
              : ListView(
                  children: [
                    Text('Enter your 12 recovery words',
                        style: theme.textTheme.titleLarge),
                    const SizedBox(height: 8),
                    const Text('Type them in order, separated by spaces.'),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _phrase,
                      enabled: !_working,
                      minLines: 3,
                      maxLines: 5,
                      autocorrect: false,
                      enableSuggestions: false,
                      keyboardType: TextInputType.visiblePassword,
                      decoration: const InputDecoration(
                        hintText: 'word1 word2 word3 ...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (_error != null) ...[
                      Text(_error!,
                          style: TextStyle(color: theme.colorScheme.error)),
                      const SizedBox(height: 16),
                    ],
                    _working
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton(
                            onPressed: _restore,
                            child: const Text('Restore my vault'),
                          ),
                  ],
                ),
        ),
      ),
    );
  }
}
