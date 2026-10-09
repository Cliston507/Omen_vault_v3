import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:omen_vault_v3/login_screen.dart';
import 'package:omen_vault_v3/services/vault_repository.dart';
import 'package:omen_vault_v3/views/vault_home_view.dart';
import 'package:provider/provider.dart';

/// Gate for the whole app: unauthenticated users see the login screen,
/// authenticated users see their vault.
///
/// The signed-in subtree is keyed by user id so that switching accounts
/// rebuilds the vault (and its per-user repository) from scratch instead of
/// showing the previous account's state.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<User?>(context);

    if (user == null) {
      return const LoginScreen();
    }
    return VaultHomeView(
      key: ValueKey('vault-${user.uid}'),
      repository: VaultRepository(userId: user.uid),
    );
  }
}
