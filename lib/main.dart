import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/screens/key_recovery_screen.dart';
import 'package:omen_vault_v3/screens/lock_screen.dart';
import 'package:omen_vault_v3/screens/login_screen.dart';
import 'package:omen_vault_v3/screens/vault_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OmenVaultApp()));
}

class OmenVaultApp extends StatelessWidget {
  const OmenVaultApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Omen Vault v3',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0F1117),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF6366F1),
          surface: Color(0xFF1A1D26),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const LockScreen(),
        '/login': (context) => const LoginScreen(),
        '/vault-home': (context) => const VaultHomeScreen(),
        '/recover-key': (context) => const KeyRecoveryScreen(),
      },
    );
  }
}
