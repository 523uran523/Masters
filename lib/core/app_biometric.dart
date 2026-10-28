import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:local_auth/local_auth.dart';

/// Обёртка над `local_auth`. Возвращает false на unsupported/web.
class AppBiometricService {
  const AppBiometricService._();

  static final LocalAuthentication _auth = LocalAuthentication();

  static Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    try {
      final supported = await _auth.canCheckBiometrics;
      final deviceSupported = await _auth.isDeviceSupported();
      return supported || deviceSupported;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate({
    String reason = 'Подтвердите вход в Masters',
  }) async {
    if (kIsWeb) return false;
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(biometricOnly: false),
      );
    } catch (_) {
      return false;
    }
  }
}
