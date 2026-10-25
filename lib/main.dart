import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:omen_vault_v3/screens/key_recovery_screen.dart';
import 'package:omen_vault_v3/screens/lock_screen.dart';
import 'package:omen_vault_v3/screens/login_screen.dart';
import 'package:omen_vault_v3/screens/vault_home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: OmenVaultApp()));
}

class OmenVaultApp extends StatefulWidget {
  const OmenVaultApp({super.key});

  @override
  State<OmenVaultApp> createState() => _OmenVaultAppState();
}

class _OmenVaultAppState extends State<OmenVaultApp>
    with WidgetsBindingObserver {
  static const _privacyChannel = MethodChannel('omen_vault/privacy');
  final _navigatorKey = GlobalKey<NavigatorState>();
  bool _wasPaused = false;

  // Privacy guard handshake (iOS only): tell native that a safe frame is
  // on screen so it may release the black overlay. No handler on Android
  // (FLAG_SECURE needs none) — the try/catch swallows that case.
  Future<void> _releasePrivacyOverlay() async {
    if (!Platform.isIOS) return;
    try {
      await _privacyChannel.invokeMethod('releasePrivacyOverlay');
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Privacy guard: only a real backgrounding locks the vault. Pulling the
    // notification shade (inactive -> resumed, never paused) must NOT lock it.
    if (state == AppLifecycleState.paused) {
      _wasPaused = true;
    }
    if (state == AppLifecycleState.resumed) {
      if (_wasPaused) {
        _wasPaused = false;
        _navigatorKey.currentState?.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LockScreen()),
          (_) => false,
        );
      }
      // Release the iOS overlay only after a frame is rendered — by then
      // the screen on display is the LockScreen (backgrounded case) or the
      // already-visible screen (shade-pull case). Never before the frame.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _releasePrivacyOverlay(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
