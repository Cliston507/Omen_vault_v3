
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/auth_wrapper.dart';
import 'package:omen_vault_v3/firebase_options.dart';
import 'package:omen_vault_v3/helpers/db_helper.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:omen_vault_v3/theme_provider.dart';
import 'package:omen_vault_v3/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await DBHelper.initDB();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Fatal Error: Could not initialize Firebase.\n\n$e',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }
  runApp(const ProviderScope(child: OmenVaultApp()));
}

class OmenVaultApp extends ConsumerWidget {
  const OmenVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    return MaterialApp(
      title: 'Omen Vault V3',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const AuthWrapper(),
    );
  }
}
