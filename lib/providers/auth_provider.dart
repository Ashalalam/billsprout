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

  // ── Demo login (no backend) ───────────────────────────────────────────────
  void login({required String email, required UserRole role}) {
    // In demo mode, leave tenant/branch IDs null - they'll be set properly in production
    _tenantId = null;
    _branchId = null;
    _currentUser = AppUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: role == UserRole.superAdmin
          ? 'Lifesprout Super Admin'
          : role == UserRole.customer
              ? 'Patient User'
              : 'Dr. Sarah Connor (Pharmacist)',
      email: email,
      phone: '+44 7747 571513',
      role: role,
      companyId: _tenantId,
      licenseNo: role == UserRole.pharmacist || role == UserRole.businessAdmin
          ? 'PH-UK-984721'
          : null,
    );
    notifyListeners();
  }

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
      
      // Load user from Supabase with tenant context
      _currentUser = await _userFromSupabaseAsync(user, role);
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

    // Demo mode — create local account instantly
    if (!AppConfig.supabaseConfigured) {
      await Future.delayed(const Duration(milliseconds: 500));
      _currentUser = AppUser(
        id: 'cust_${DateTime.now().millisecondsSinceEpoch}',
        name: name,
        email: email,
        phone: phone,
        role: UserRole.customer,
        companyId: null,
        licenseNo: null,
      );
      _isLoading = false;
      notifyListeners();
      return;
    }

    // Live Supabase registration
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
      _currentUser = await _userFromSupabaseAsync(user, UserRole.customer);
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
  Future<void> _restoreSession() async {
    final session = SupabaseService().currentSession;
    if (session != null) {
      final meta     = session.user.userMetadata;
      final roleName = meta?['role'] as String? ?? 'businessAdmin';
      final role     = UserRole.values.firstWhere(
        (r) => r.name == roleName,
        orElse: () => UserRole.businessAdmin,
      );
      _currentUser = await _userFromSupabaseAsync(session.user, role);
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

  /// Loads user from Supabase auth and fetches tenant context from public.users table
  Future<AppUser> _userFromSupabaseAsync(User user, UserRole role) async {
    final meta = user.userMetadata ?? {};
    
    // Try to get tenant_id and branch_id from metadata first
    String? tenantId = meta['tenant_id'] as String? ?? meta['companyId'] as String?;
    String? branchId = meta['branch_id'] as String?;
    
    // If metadata is missing tenant_id, fetch from public.users table
    if (tenantId == null || tenantId.isEmpty) {
      try {
        final client = Supabase.instance.client;
        final response = await client
            .from('users')
            .select('tenant_id, name, phone, role, license_no')
            .eq('id', user.id)
            .maybeSingle();
        
        if (response != null) {
          tenantId = response['tenant_id'] as String?;
          
          // If we found tenant_id in the table, also get the default branch
          if (tenantId != null && tenantId.isNotEmpty) {
            final branchResponse = await client
                .from('branches')
                .select('id')
                .eq('tenant_id', tenantId)
                .eq('is_active', true)
                .order('created_at')
                .limit(1)
                .maybeSingle();
            
            if (branchResponse != null) {
              branchId = branchResponse['id'] as String?;
            }
          }
          
          // Update our local state
          _tenantId = tenantId;
          _branchId = branchId;
          
          if (kDebugMode) {
            print('[Auth] Loaded tenant context from database: tenant=$tenantId, branch=$branchId');
          }
          
          // Return user with data from public.users table
          return AppUser(
            id: user.id,
            name: (response['name'] as String?) ?? user.email ?? 'User',
            email: user.email ?? '',
            phone: (response['phone'] as String?) ?? '',
            role: role,
            companyId: tenantId,
            licenseNo: response['license_no'] as String?,
          );
        }
      } catch (e) {
        if (kDebugMode) {
          print('[Auth] Error fetching tenant context from database: $e');
        }
      }
    }
    
    // Fall back to metadata-only approach
    _tenantId = tenantId;
    _branchId = branchId;
    
    if (kDebugMode) {
      print('[Auth] Using metadata tenant context: tenant=$tenantId, branch=$branchId');
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
      companyId: tenantId,
      licenseNo: meta['licenseNo'] as String?,
    );
  }

  @Deprecated('Use _userFromSupabaseAsync instead')
  AppUser _userFromSupabase(User user, UserRole role) {
    final meta = user.userMetadata ?? {};
    _tenantId = meta['tenant_id'] as String? ?? meta['companyId'] as String?;
    _branchId = meta['branch_id'] as String?;
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
