import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pin_hasher.dart';

class AppConfig {
  static const String appName      = 'BillSprout';
  static const String appSubtitle  = 'Smart ERP & Billing System';
  static const String companyName  = 'LIFESPROUT Care';
  static const String version      = 'v1.3.0+1 (OTA Ready)';

  // Official Support Channels
  static const String customerCareEmail      = 'info@lifesproutcare.com';
  static const String technicalSupportEmail  = 'Support@billsprout.online';
  static const String whatsappSupportNumber  = '+44 7747 571513';
  static const String whatsappLink           = 'https://wa.me/447747571513';

  // Demo Credentials
  static const String superAdminEmail = 'superadmin@billsprout.online';
  static const String storeAdminEmail = 'admin@lifesproutcare.com';
  static const String customerEmail   = 'patient@lifesproutcare.com';

  /// Fallback PIN applied only on a device that has never had one set.
  static const String _fallbackPin = '1234';

  /// v2 keys store a salt + hash. The v1 key held the PIN in plaintext and is
  /// deleted during migration so the old value does not linger on disk.
  static const String _legacyPinKey = 'pharmacist_pin_v1';
  static const String _pinHashKey = 'pharmacist_pin_hash_v2';
  static const String _pinSaltKey = 'pharmacist_pin_salt_v2';

  // ── Dynamic PIN management ────────────────────────────────────────────────
  static String _pinHash = '';
  static String _pinSalt = '';

  /// True when the device is still on the shipped default PIN.
  static bool _isDefaultPin = true;
  static bool get isUsingDefaultPin => _isDefaultPin;

  /// Call once at startup to load the stored PIN hash.
  ///
  /// Migrates a v1 plaintext PIN to a salted hash on first run, then erases it.
  static Future<void> loadPin() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final storedHash = prefs.getString(_pinHashKey);
      final storedSalt = prefs.getString(_pinSaltKey);

      if (storedHash != null && storedSalt != null) {
        _pinHash = storedHash;
        _pinSalt = storedSalt;
        _isDefaultPin = PinHasher.verify(
          pin: _fallbackPin,
          salt: _pinSalt,
          expectedHash: _pinHash,
        );
        return;
      }

      final legacyPin = prefs.getString(_legacyPinKey);
      final pinToStore = legacyPin ?? _fallbackPin;

      _pinSalt = PinHasher.generateSalt();
      _pinHash = PinHasher.hash(pinToStore, _pinSalt);
      _isDefaultPin = pinToStore == _fallbackPin;

      await prefs.setString(_pinHashKey, _pinHash);
      await prefs.setString(_pinSaltKey, _pinSalt);
      await prefs.remove(_legacyPinKey);
    } catch (_) {
      // Last resort so the app still boots; the default PIN applies in memory.
      _pinSalt = PinHasher.generateSalt();
      _pinHash = PinHasher.hash(_fallbackPin, _pinSalt);
      _isDefaultPin = true;
    }
  }

  /// Verify an entered PIN against the stored salted hash.
  static bool verifyPharmacistPin(String pin) {
    if (_pinHash.isEmpty) return false;
    return PinHasher.verify(
      pin: pin.trim(),
      salt: _pinSalt,
      expectedHash: _pinHash,
    );
  }

  /// Save a new PIN (4–6 digits). Returns true on success.
  static Future<bool> setPharmacistPin({
    required String currentPin,
    required String newPin,
  }) async {
    if (!verifyPharmacistPin(currentPin)) return false;
    if (PinHasher.validateFormat(newPin) != null) return false;

    try {
      final salt = PinHasher.generateSalt();
      final hash = PinHasher.hash(newPin, salt);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pinHashKey, hash);
      await prefs.setString(_pinSaltKey, salt);

      _pinHash = hash;
      _pinSalt = salt;
      _isDefaultPin = newPin == _fallbackPin;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Reset to fallback (emergency use — requires old PIN verification).
  static Future<bool> resetPin(String currentPin) =>
      setPharmacistPin(currentPin: currentPin, newPin: _fallbackPin);

  // ── Supabase Configuration ────────────────────────────────────────────────
  static const String supabaseUrl =
      'https://juvbhjqaioevpusnmonz.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imp1dmJoanFhaW9ldnB1c25tb256Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTAzMjE2MDYsImV4cCI6MjEwNTg5NzYwNn0.D1bXZHEAnkdsSpWOeMpFlKOdhL-V8zpeficOneLPY0U';

  static bool get supabaseConfigured =>
      !supabaseUrl.contains('your-project-ref') &&
      !supabaseAnonKey.contains('YOUR_ANON_KEY');
}
