import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import '../services/supabase_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _currentUser;
  String? _tenantId;
  String? _branchId;
  bool _isPinVerified = false;
  bool _isLoading = false;

  AppUser? get currentUser => _currentUser;
  String? get tenantId => _tenantId;
  String? get branchId => _branchId;
  String get userId => _currentUser?.id ?? '';
  bool get isLoggedIn => _currentUser != null;
  bool get isPinVerified => _isPinVerified;
  bool get isLoading => _isLoading;

  AuthProvider() {
    if (AppConfig.supabaseConfigured) {
      _restoreSession();
      SupabaseService().authStateStream.listen(_onAuthStateChange);
    }
  }

  // Production mode - no demo login
  // Users must have valid Supabase authentication

  // ── Sign in ───────────────────────────────────────────────────────────────
  Future<void> signInWithSupabase({
    required String email,
    required String password,
    required UserRole role,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SupabaseService()
          .signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw Exception('Sign-in failed — no user returned.');
      _currentUser = _userFromSupabase(user, role);
      notifyListeners();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Customer self-registration ────────────────────────────────────────────
  Future<void> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();

    // Production mode - always use Supabase registration
    if (!AppConfig.supabaseConfigured) {
      _isLoading = false;
      notifyListeners();
      throw Exception('Authentication system not configured. Please contact administrator.');
    }

    try {
      final response = await SupabaseService().signUp(
        email: email,
        password: password,
        data: {
          'name': name,
          'phone': phone,
          'role': UserRole.customer.name,
        },
      );
      final user = response.user;
      if (user == null) {
        // Supabase returns null user when email confirmation is required
        throw Exception(
            'Account created! Check your email to confirm, then sign in.');
      }
      _currentUser = _userFromSupabase(user, UserRole.customer);
      notifyListeners();
    } on AuthException catch (e) {
      throw Exception(e.message);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── Sign out ──────────────────────────────────────────────────────────────
  void logout() {
    if (AppConfig.supabaseConfigured) {
      SupabaseService().signOut().catchError((_) {});
    }
    _currentUser = null;
    _isPinVerified = false;
    notifyListeners();
  }

  // ── PIN verification ──────────────────────────────────────────────────────
  /// Compares against the stored salted hash. The plaintext PIN is never held
  /// anywhere outside this call.
  bool verifyPharmacistPin(String pin) {
    if (AppConfig.verifyPharmacistPin(pin)) {
      _isPinVerified = true;
      notifyListeners();
      return true;
    }
    return false;
  }

  // ── Internal ──────────────────────────────────────────────────────────────
  void _restoreSession() {
    final session = SupabaseService().currentSession;
    if (session != null) {
      final meta     = session.user.userMetadata;
      final roleName = meta?['role'] as String? ?? 'businessAdmin';
      final role     = UserRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => UserRole.businessAdmin,
      );
      _currentUser = _userFromSupabase(session.user, role);
      notifyListeners();
    }
  }

  void _onAuthStateChange(AuthState state) {
    if (state.event == AuthChangeEvent.signedOut) {
      _currentUser = null;
      _isPinVerified = false;
      notifyListeners();
    } else if (state.event == AuthChangeEvent.tokenRefreshed ||
        state.event == AuthChangeEvent.signedIn) {
      final user = state.session?.user;
      if (user != null && _currentUser == null) {
        _restoreSession();
      }
    }
  }

  AppUser _userFromSupabase(User user, UserRole role) {
    final meta = user.userMetadata ?? {};
    _tenantId = meta['tenant_id'] as String?;
    _branchId = meta['branch_id'] as String?;
    
    // Production mode: tenant_id is required for business users
    if ((role == UserRole.businessAdmin || role == UserRole.pharmacist) && 
        (_tenantId == null || _tenantId!.isEmpty)) {
      throw Exception('No tenant association found. Please contact your administrator.');
    }
    
    return AppUser(
      id: user.id,
      name: (meta['name'] as String?) ??
          (meta['full_name'] as String?) ??
          user.email ??
          'User',
      email: user.email ?? '',
      phone: (meta['phone'] as String?) ?? '',
      role: role,
      companyId: _tenantId,
      licenseNo: meta['licenseNo'] as String?,
    );
  }
}
