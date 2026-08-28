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
    // Nothing to unlock against: the device has no biometric or credential
    // check configured, so the lock is not in play at all.
    if (!await canUseBiometrics()) {
      return true;
    }
    try {
      // `return await` matters: without awaiting, the returned future escapes
      // this try block and a rejected authentication propagated out of
      // unlock() instead, leaving AppLockGate stuck on its spinner forever.
      return await _localAuth.authenticate(
        localizedReason: 'Unlock to open your notes',
        // local_auth 3.x flattened AuthenticationOptions into named
        // parameters; stickyAuth is now persistAcrossBackgrounding.
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      // Fail closed. A lock that opens whenever authentication errors out is
      // not a lock, and AppLockGate keeps a retry button on screen.
      return false;
    }
  }
}
