import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth;

  BiometricService({LocalAuthentication? auth})
      : _auth = auth ?? LocalAuthentication();

  Future<bool> canCheckBiometrics() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      final isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } on PlatformException catch (_) {
      return false;
    }
  }

  Future<bool> isBiometricsAvailable() => canCheckBiometrics();

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _auth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return <BiometricType>[];
    }
  }

  Future<bool> hasFingerprint() async {
    final available = await getAvailableBiometrics();
    return available.contains(BiometricType.fingerprint) ||
        available.contains(BiometricType.strong);
  }

  Future<bool> hasFaceRecognition() async {
    final available = await getAvailableBiometrics();
    return available.contains(BiometricType.face);
  }

  Future<bool> authenticate({
    String localizedReason = 'Please authenticate with fingerprint',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: localizedReason,
        options: const AuthenticationOptions(
          useErrorDialogs: true,
          stickyAuth: true,
        ),
      );
    } on PlatformException catch (_) {
      return false;
    }
  }
}