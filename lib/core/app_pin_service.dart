import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Local PIN verification for sensitive screens/data.
///
/// This is the application-level lock mentioned in the roadmap. It is not
/// hardware-backed, so pair it with OS lock screen / biometrics later.
class AppPinService {
  const AppPinService._();

  /// Normalize and hash the supplied PIN.
  static String hash(String pin) =>
      sha256.convert(utf8.encode('masters::pin::v1::$pin')).toString();

  /// Weak password rejection for a 4–6 digit PIN.
  static bool isValid(String pin) {
    final normalized = pin.trim();
    return RegExp(r'^\d{4,6}$').hasMatch(normalized) && !_isTrivial(normalized);
  }

  static bool _isTrivial(String pin) =>
      pin == pin[0] * pin.length ||
      pin == '0123' ||
      pin == '1234' ||
      pin == '4321';

  static bool verify(String pin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return true;
    final candidate = hash(pin);
    // Constant-time comparison to avoid timing hints.
    var result = storedHash.length == candidate.length ? 0 : 1;
    for (var i = 0; i < storedHash.length && i < candidate.length; i++) {
      result |= storedHash.codeUnitAt(i) ^ candidate.codeUnitAt(i);
    }
    return result == 0;
  }
}