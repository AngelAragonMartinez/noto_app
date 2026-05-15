import 'package:local_auth/local_auth.dart';

class AppLockController {
  AppLockController({LocalAuthentication? localAuth})
      : _localAuth = localAuth ?? LocalAuthentication();

  final LocalAuthentication _localAuth;

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  Future<bool> unlock() async {
    if (!await canUseBiometrics()) {
      return true;
    }
    try {
      return _localAuth.authenticate(
        localizedReason: 'Unlock to open your notes',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return true;
    }
  }
}
