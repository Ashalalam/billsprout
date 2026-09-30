import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/pharmacist_model.dart';
import '../services/supabase_service.dart';
import '../utils/pin_hasher.dart';
import 'auth_provider.dart';

/// Tenant-scoped pharmacist roster and PIN authorisation.
///
/// PINs are only ever held as a salted SHA-256 hash. There is no way to read a
/// PIN back out; the only recovery path is a reset by the business admin.
class PharmacistProvider extends ChangeNotifier {
  PharmacistProvider(this._auth);

  AuthProvider _auth;
  final List<PharmacistModel> _pharmacists = [];
  final Map<String, String> _salts = {};

  bool _isLoading = false;
  String? _error;

  List<PharmacistModel> get pharmacists => List.unmodifiable(_pharmacists);
  List<PharmacistModel> get activePharmacists =>
      _pharmacists.where((p) => p.isActive).toList();
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Called by ChangeNotifierProxyProvider when auth state changes.
  void updateAuth(AuthProvider auth) {
    final tenantChanged = _auth.tenantId != auth.tenantId;
    _auth = auth;
    if (tenantChanged) {
      _pharmacists.clear();
      _salts.clear();
      if (auth.tenantId != null) fetchPharmacists();
    }
  }

  Future<void> fetchPharmacists() async {
    final tenantId = _auth.tenantId;
    if (tenantId == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final rows = await SupabaseService().fetchPharmacists(tenantId);
      _pharmacists.clear();
      _salts.clear();
      for (final row in rows) {
        _pharmacists.add(PharmacistModel.fromJson(row));
        final id = row['id'] as String?;
        final salt = row['pin_salt'] as String?;
        if (id != null && salt != null) _salts[id] = salt;
      }
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[Pharmacist] fetch failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a pharmacist with an initial PIN. Returns the new id, or null.
  Future<String?> addPharmacist({
    required String name,
    required String email,
    required String phone,
    String? licenseNo,
    String? registrationNo,
    required String pin,
  }) async {
    final tenantId = _auth.tenantId;
    if (tenantId == null) {
      _error = 'No tenant context. Sign in again.';
      notifyListeners();
      return null;
    }

    final formatError = PinHasher.validateFormat(pin);
    if (formatError != null) {
      _error = formatError;
      notifyListeners();
      return null;
    }

    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(pin, salt);
    final id = const Uuid().v4();
    final now = DateTime.now();

    try {
      await SupabaseService().upsertPharmacist({
        'id': id,
        'tenant_id': tenantId,
        'name': name.trim(),
        'email': email.trim(),
        'phone': phone.trim(),
        'license_no': licenseNo?.trim(),
        'registration_no': registrationNo?.trim(),
        'pharmacist_pin_hash': hash,
        'pin_salt': salt,
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      _pharmacists.add(PharmacistModel(
        id: id,
        tenantId: tenantId,
        name: name.trim(),
        email: email.trim(),
        phone: phone.trim(),
        licenseNo: licenseNo?.trim(),
        registrationNo: registrationNo?.trim(),
        pinHash: hash,
        createdAt: now,
        updatedAt: now,
      ));
      _salts[id] = salt;
      _error = null;
      notifyListeners();
      return id;
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[Pharmacist] create failed: $e');
      notifyListeners();
      return null;
    }
  }

  /// Reset a pharmacist's PIN. A new salt is generated each time, so the same
  /// PIN never produces the same stored hash twice.
  Future<bool> resetPin({required String pharmacistId, required String newPin}) async {
    final tenantId = _auth.tenantId;
    if (tenantId == null) return false;

    final formatError = PinHasher.validateFormat(newPin);
    if (formatError != null) {
      _error = formatError;
      notifyListeners();
      return false;
    }

    final index = _pharmacists.indexWhere((p) => p.id == pharmacistId);
    if (index < 0) return false;

    final salt = PinHasher.generateSalt();
    final hash = PinHasher.hash(newPin, salt);

    try {
      await SupabaseService().upsertPharmacist({
        'id': pharmacistId,
        'tenant_id': tenantId,
        'name': _pharmacists[index].name,
        'email': _pharmacists[index].email,
        'phone': _pharmacists[index].phone,
        'license_no': _pharmacists[index].licenseNo,
        'registration_no': _pharmacists[index].registrationNo,
        'pharmacist_pin_hash': hash,
        'pin_salt': salt,
        'is_active': _pharmacists[index].isActive,
        'updated_at': DateTime.now().toIso8601String(),
      });

      _pharmacists[index] = _pharmacists[index]
          .copyWith(pinHash: hash, updatedAt: DateTime.now());
      _salts[pharmacistId] = salt;
      _error = null;
      notifyListeners();
      return true;
    } catch (e) {
      _error = SupabaseService.describeError(e);
      notifyListeners();
      return false;
    }
  }

  Future<bool> setActive(String pharmacistId, bool isActive) async {
    final tenantId = _auth.tenantId;
    if (tenantId == null) return false;
    final index = _pharmacists.indexWhere((p) => p.id == pharmacistId);
    if (index < 0) return false;

    try {
      await SupabaseService().upsertPharmacist({
        'id': pharmacistId,
        'tenant_id': tenantId,
        'name': _pharmacists[index].name,
        'email': _pharmacists[index].email,
        'phone': _pharmacists[index].phone,
        'pharmacist_pin_hash': _pharmacists[index].pinHash,
        'pin_salt': _salts[pharmacistId],
        'is_active': isActive,
        'updated_at': DateTime.now().toIso8601String(),
      });
      _pharmacists[index] =
          _pharmacists[index].copyWith(isActive: isActive, updatedAt: DateTime.now());
      notifyListeners();
      return true;
    } catch (e) {
      _error = SupabaseService.describeError(e);
      notifyListeners();
      return false;
    }
  }

  /// Returns the pharmacist whose PIN matches, or null.
  ///
  /// Every active pharmacist is checked so the cashier does not have to pick a
  /// name first; the PIN itself identifies the authoriser. Only active
  /// pharmacists can authorise.
  PharmacistModel? authorise(String pin) {
    final entered = pin.trim();
    if (entered.isEmpty) return null;

    for (final p in _pharmacists.where((p) => p.isActive)) {
      final salt = _salts[p.id];
      if (salt == null || p.pinHash.isEmpty) continue;
      if (PinHasher.verify(pin: entered, salt: salt, expectedHash: p.pinHash)) {
        return p;
      }
    }
    return null;
  }

  /// True when the tenant has at least one pharmacist who can authorise.
  bool get hasAuthorisablePharmacist =>
      _pharmacists.any((p) => p.isActive && p.pinHash.isNotEmpty);
}
