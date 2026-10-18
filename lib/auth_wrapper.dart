import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/login_screen.dart';
import 'package:omen_vault_v3/services/auth_service.dart';
import 'package:omen_vault_v3/services/database_service.dart';
import 'package:omen_vault_v3/views/vault_home_screen.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);

    return StreamBuilder<User?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Something went wrong. Please try again later.'),
            ),
          );
        }

        final user = snapshot.data;

        if (user == null) {
          return const LoginScreen();
        } else {
          return ProviderScope(
            overrides: [
              databaseServiceProvider.overrideWithValue(DatabaseService.instance),
            ],
            child: const VaultHomeScreen(),
          );
        }
      },
    );
  }
}
