import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Salted SHA-256 hashing for pharmacist authorisation PINs.
///
/// A PIN is a 4–6 digit secret, so the keyspace is small enough to brute force
/// offline regardless of the hash. The salt is what stops one leaked hash from
/// revealing every pharmacist who happens to share that PIN, and it means the
/// stored value cannot be matched against a precomputed table. Verification is
/// constant time so a caller cannot learn the hash byte by byte from timing.
class PinHasher {
  PinHasher._();

  static final Random _random = Random.secure();

  /// Generates a 32 character hex salt.
  static String generateSalt() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Hashes [pin] with [salt]. Returns lowercase hex.
  static String hash(String pin, String salt) {
    final digest = sha256.convert(utf8.encode('$pin$salt'));
    return digest.toString();
  }

  /// Constant-time comparison of the hash of [pin] against [expectedHash].
  static bool verify({
    required String pin,
    required String salt,
    required String expectedHash,
  }) {
    if (expectedHash.isEmpty || salt.isEmpty) return false;
    return _constantTimeEquals(hash(pin, salt), expectedHash);
  }

  /// A PIN must be 4 to 6 digits. Returns null when valid.
  static String? validateFormat(String pin) {
    if (pin.isEmpty) return 'Enter a PIN';
    if (pin.length < 4 || pin.length > 6) return 'PIN must be 4 to 6 digits';
    if (!RegExp(r'^\d+$').hasMatch(pin)) return 'PIN must contain only digits';
    if (RegExp(r'^(\d)\1+$').hasMatch(pin)) {
      return 'PIN cannot be a single repeated digit';
    }
    return null;
  }

  static bool _constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return diff == 0;
  }
}
