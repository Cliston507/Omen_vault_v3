import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Covers the whole app with a lock screen until the user unlocks with
/// Face ID / fingerprint / phone PIN.
///
/// Locks when: the app opens signed in, the user signs in, or the app comes
/// back after being in the background longer than [relockAfter]. The app
/// underneath stays alive (it's only covered), so unsaved edits aren't lost.
class AppLockGate extends StatefulWidget {
  final Widget child;

  /// Only lock while signed in — the login screen needs no lock.
  final bool enabled;
  final LocalAuthentication? auth;
  final Duration relockAfter;

  const AppLockGate({
    super.key,
    required this.child,
    required this.enabled,
    this.auth,
    this.relockAfter = const Duration(seconds: 30),
  });

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late final LocalAuthentication _auth = widget.auth ?? LocalAuthentication();

  bool _unlocked = false;
  bool _authInProgress = false;

  /// True while the app is not in the foreground. Covers the screen so the
  /// app-switcher preview (taken by the phone at that moment) shows nothing.
  bool _obscured = false;
  DateTime? _backgroundedAt;
  String? _error;

  bool get _active => widget.enabled && !kIsWeb;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_active) _scheduleUnlock();
  }

  @override
  void didUpdateWidget(AppLockGate old) {
    super.didUpdateWidget(old);
    if (!old.enabled && widget.enabled) {
      _unlocked = false;
      if (_active) _scheduleUnlock();
    } else if (old.enabled && !widget.enabled) {
      // Signed out: next sign-in must unlock again.
      _unlocked = false;
      _error = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_active) return;
    final obscure = state != AppLifecycleState.resumed;
    if (obscure != _obscured) setState(() => _obscured = obscure);
    if (_authInProgress) return; // the unlock prompt itself pauses the app
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _backgroundedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final away = _backgroundedAt;
      _backgroundedAt = null;
      if (away != null &&
          _unlocked &&
          DateTime.now().difference(away) > widget.relockAfter) {
        setState(() => _unlocked = false);
        _unlock();
      }
    }
  }

  void _scheduleUnlock() {
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_authInProgress || _unlocked || !_active) return;
    _authInProgress = true;
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) {
        // No Face ID, fingerprint, or screen lock on this phone. Nothing to
        // check against, so let the user in rather than lock them out.
        if (mounted) {
          setState(() {
            _unlocked = true;
            _error = null;
          });
        }
        return;
      }
      final ok = await _auth.authenticate(
        localizedReason: 'Unlock Omen Vault',
        options: const AuthenticationOptions(stickyAuth: true),
      );
      if (!mounted) return;
      setState(() {
        _unlocked = ok;
        _error = ok ? null : 'Vault is still locked.';
      });
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() => _error = 'Couldn\'t unlock: ${e.message ?? e.code}');
      }
    } finally {
      _authInProgress = false;
      _backgroundedAt = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final locked = _active && !_unlocked;
    return Stack(
      children: [
        // Keep the app alive but hidden and untouchable while locked.
        Offstage(offstage: locked, child: widget.child),
        if (locked) Positioned.fill(child: _lockScreen(context)),
        if (_active && _obscured && !locked)
          Positioned.fill(child: _privacyCover(context)),
      ],
    );
  }

  Widget _privacyCover(BuildContext context) {
    final theme = Theme.of(context);
    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Icon(Icons.lock, size: 72, color: theme.colorScheme.primary),
      ),
    );
  }

  Widget _lockScreen(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(Icons.lock, size: 72, color: theme.colorScheme.primary),
              const SizedBox(height: 24),
              Text('Omen Vault is locked',
                  style: theme.textTheme.titleLarge,
                  textAlign: TextAlign.center),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.error)),
              ],
              const Spacer(),
              ElevatedButton.icon(
                icon: const Icon(Icons.fingerprint),
                label: const Text('Unlock'),
                onPressed: _unlock,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
