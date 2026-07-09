import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();

  /// Checks if the device is capable and has biometric configurations enrolled.
  static Future<bool> canAuthenticate() async {
    try {
      final bool canCheck = await _auth.canCheckBiometrics;
      final bool isSupported = await _auth.isDeviceSupported();
      return canCheck || isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Initiates the authentication prompt. Returns true if successful, false otherwise.
  static Future<bool> authenticate({
    String reason = "Confirma para registrar la transacción",
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        biometricOnly: false, // fallback to pin/code if biometrics fail/unavailable
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}
