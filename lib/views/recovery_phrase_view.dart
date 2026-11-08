import 'package:flutter/material.dart';
import 'package:omen_vault_v3/services/omen_vault_key_recovery_service.dart';
import 'package:omen_vault_v3/services/vault_cloud.dart';
import 'package:omen_vault_v3/services/vault_repository.dart';
import 'package:omen_vault_v3/views/restore_vault_view.dart';

/// Create-vault flow: show a new 12-word recovery phrase, make the user type
/// back 3 of the words, and only then save the master key.
///
/// Nothing is stored until the quiz passes, so quitting halfway leaves no
/// half-made vault behind. If the account already has a phrase (set up on
/// another phone), the user is sent to Restore instead, so one account can
/// never end up with two different keys.
class RecoveryPhraseView extends StatefulWidget {
  final String userId;
  final OmenVaultKeyRecoveryService? service;
  final VaultCloud? cloud;
  final VaultRepository? repository;

  const RecoveryPhraseView({
    super.key,
    required this.userId,
    this.service,
    this.cloud,
    this.repository,
  });

  @override
  State<RecoveryPhraseView> createState() => _RecoveryPhraseViewState();
}

enum _Step {
  loading,
  offline,
  alreadySetUp,
  mustRestore,
  intro,
  showWords,
  verify,
  saving,
  done,
}

class _RecoveryPhraseViewState extends State<RecoveryPhraseView> {
  late final OmenVaultKeyRecoveryService _service =
      widget.service ?? OmenVaultKeyRecoveryService();
  late final VaultCloud _cloud = widget.cloud ?? VaultCloud();
  late final VaultRepository _repository =
      widget.repository ?? VaultRepository(userId: widget.userId);

  _Step _step = _Step.loading;
  String? _mnemonic;
  bool _wroteItDown = false;
  List<int> _quizPositions = const [];
  final Map<int, TextEditingController> _answers = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _checkExisting();
  }

  @override
  void dispose() {
    for (final c in _answers.values) {
      c.dispose();
    }
    _mnemonic = null;
    super.dispose();
  }

  Future<void> _checkExisting() async {
    setState(() => _step = _Step.loading);
    try {
      if (await _service.hasVault()) {
        if (mounted) setState(() => _step = _Step.alreadySetUp);
        return;
      }
      final cloudKeyId = await _cloud.getKeyId(widget.userId);
      if (!mounted) return;
      setState(() =>
          _step = cloudKeyId == null ? _Step.intro : _Step.mustRestore);
    } catch (_) {
      if (mounted) setState(() => _step = _Step.offline);
    }
  }

  Future<void> _openRestore() async {
    final restored = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => RestoreVaultView(userId: widget.userId),
      ),
    );
    if (restored == true && mounted) Navigator.pop(context, true);
  }

  void _generate() {
    setState(() {
      _mnemonic = _service.generateMnemonic();
      _wroteItDown = false;
      _step = _Step.showWords;
    });
  }

  void _startQuiz() {
    for (final c in _answers.values) {
      c.dispose();
    }
    _answers.clear();
    _quizPositions = _service.pickVerificationPositions(_mnemonic!);
    for (final p in _quizPositions) {
      _answers[p] = TextEditingController();
    }
    setState(() {
      _error = null;
      _step = _Step.verify;
    });
  }

  Future<void> _submitQuiz() async {
    final mnemonic = _mnemonic!;
    final answers = {
      for (final e in _answers.entries) e.key: e.value.text,
    };
    final words = OmenVaultKeyRecoveryService.normalizeMnemonic(mnemonic).split(' ');
    final allCorrect = answers.entries.every((e) =>
        OmenVaultKeyRecoveryService.normalizeMnemonic(e.value) == words[e.key]);
    if (!allCorrect) {
      setState(() => _error = 'One or more words don\'t match. '
          'Check what you wrote down and try again.');
      return;
    }

    setState(() {
      _error = null;
      _step = _Step.saving;
    });
    try {
      final key = await _service.deriveMasterKey(mnemonic: mnemonic);
      // Claim the account's key in the cloud FIRST. If that fails, nothing
      // is saved and the user can retry. If it succeeds, they hold the
      // phrase on paper, so they can always restore.
      final existingId = await _cloud.getKeyId(widget.userId);
      if (existingId != null) {
        if (mounted) setState(() => _step = _Step.mustRestore);
        return;
      }
      await _cloud.setKeyId(
          widget.userId, await OmenVaultKeyRecoveryService.keyId(key));
      await _service.storeMasterKey(key, backupVerified: true);
      // Re-upload everything encrypted (replaces any old plain-text copies).
      await _repository.queueAllForUpload();
      if (!mounted) return;
      setState(() {
        _mnemonic = null;
        _step = _Step.done;
      });
    } on VaultKeyRecoveryException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _step = _Step.verify;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Couldn\'t save your key. Check your internet connection '
            'and try again.';
        _step = _Step.verify;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recovery phrase')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: switch (_step) {
            _Step.loading || _Step.saving =>
              const Center(child: CircularProgressIndicator()),
            _Step.alreadySetUp => _message(
                icon: Icons.verified_user,
                title: 'Your recovery phrase is set up',
                body: 'Keep your written copy somewhere safe. '
                    'It is the only way to get your vault back on a new phone.',
                buttonLabel: 'Done',
                onPressed: () => Navigator.pop(context),
              ),
            _Step.offline => _message(
                icon: Icons.cloud_off,
                title: 'You\'re offline',
                body: 'Connect to the internet to set up your recovery phrase.',
                buttonLabel: 'Try again',
                onPressed: _checkExisting,
              ),
            _Step.mustRestore => _message(
                icon: Icons.lock_reset,
                title: 'This account already has a recovery phrase',
                body: 'It was set up on another phone. Enter those same 12 '
                    'words to unlock your vault here.',
                buttonLabel: 'Enter my 12 words',
                onPressed: _openRestore,
              ),
            _Step.intro => _message(
                secondaryLabel: 'I already have a recovery phrase',
                onSecondary: _openRestore,
                icon: Icons.key,
                title: 'Create your recovery phrase',
                body: 'You\'ll get 12 words. Write them on paper, in order.\n\n'
                    '• Anyone with these words can open your vault.\n'
                    '• If you lose them, nobody can recover your vault — not even us.\n'
                    '• Don\'t screenshot them or save them in notes or email.',
                buttonLabel: 'Show my 12 words',
                onPressed: _generate,
              ),
            _Step.showWords => _buildWords(context),
            _Step.verify => _buildQuiz(context),
            _Step.done => _message(
                icon: Icons.check_circle,
                title: 'Backup confirmed',
                body: 'Your vault is now end-to-end encrypted. The cloud only '
                    'stores scrambled data, and your 12 words are the only '
                    'way to unlock it on a new phone.',
                buttonLabel: 'Done',
                onPressed: () => Navigator.pop(context, true),
              ),
          },
        ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String body,
    required String buttonLabel,
    required VoidCallback onPressed,
    String? secondaryLabel,
    VoidCallback? onSecondary,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Icon(icon, size: 64, color: theme.colorScheme.primary),
        const SizedBox(height: 24),
        Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text(body, style: theme.textTheme.bodyMedium),
        const Spacer(),
        ElevatedButton(onPressed: onPressed, child: Text(buttonLabel)),
        if (secondaryLabel != null) ...[
          const SizedBox(height: 8),
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel)),
        ],
      ],
    );
  }

  Widget _buildWords(BuildContext context) {
    final words = _mnemonic!.split(' ');
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Write these 12 words down, in order.',
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 16),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 3.2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < words.length; i++)
                Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${i + 1}. ${words[i]}',
                      style: theme.textTheme.titleMedium),
                ),
            ],
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: _wroteItDown,
          onChanged: (v) => setState(() => _wroteItDown = v ?? false),
          title: const Text('I wrote all 12 words down on paper'),
        ),
        const SizedBox(height: 8),
        ElevatedButton(
          onPressed: _wroteItDown ? _startQuiz : null,
          child: const Text('Next: check my backup'),
        ),
      ],
    );
  }

  Widget _buildQuiz(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      children: [
        Text('Type these words from your paper.',
            style: theme.textTheme.titleLarge),
        const SizedBox(height: 24),
        for (final p in _quizPositions) ...[
          TextField(
            controller: _answers[p],
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: 'Word #${p + 1}',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (_error != null) ...[
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          const SizedBox(height: 16),
        ],
        ElevatedButton(onPressed: _submitQuiz, child: const Text('Confirm')),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _step = _Step.showWords),
          child: const Text('Show the words again'),
        ),
      ],
    );
  }
}
