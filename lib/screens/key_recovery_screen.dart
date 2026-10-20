import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/providers/security_provider.dart';

class KeyRecoveryScreen extends ConsumerStatefulWidget {
  const KeyRecoveryScreen({super.key});

  @override
  ConsumerState<KeyRecoveryScreen> createState() => _KeyRecoveryScreenState();
}

class _KeyRecoveryScreenState extends ConsumerState<KeyRecoveryScreen> {
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  String? _successMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _recoverKey() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _successMessage = null;
    });

    try {
      final password = _passwordController.text;
      if (password.isEmpty) {
        throw Exception('Password cannot be empty');
      }

      // IMPORTANT: In a real application, the salt should be unique per user
      // and stored securely. For this example, we'll use a hardcoded salt.
      final salt = utf8.encode('a_very_salty_salt');

      final recoveryService = ref.read(omenVaultKeyRecoveryServiceProvider);
      final masterKey = await recoveryService.recoverAndStoreMasterKey(
        utf8.encode(password),
        salt,
      );

      setState(() {
        _successMessage = 'Master key recovered and stored successfully!';
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recover Master Key'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else
              ElevatedButton(
                onPressed: _recoverKey,
                child: const Text('Recover Key'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_successMessage != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  _successMessage!,
                  style: TextStyle(color: Theme.of(context).colorScheme.primary),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
