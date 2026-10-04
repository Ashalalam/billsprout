import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../config/app_config.dart';
import '../services/supabase_service.dart';
import '../services/audit_service.dart';

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
  void login({required String email}) {
    // In demo mode, determine role from email pattern
    UserRole demoRole;
    if (email.contains('super') || email.contains('admin@lifesprout')) {
      demoRole = UserRole.superAdmin;
    } else if (email.contains('customer') || email.contains('patient')) {
      demoRole = UserRole.customer;
    } else {
      demoRole = UserRole.businessAdmin;
    }

    // In demo mode, leave tenant/branch IDs null - they'll be set properly in production
    _tenantId = demoRole == UserRole.superAdmin ? null : 'demo_tenant_001';
    _branchId = demoRole == UserRole.superAdmin ? null : 'demo_branch_001';
    _currentUser = AppUser(
      id: 'usr_${DateTime.now().millisecondsSinceEpoch}',
      name: demoRole == UserRole.superAdmin
          ? 'Lifesprout Super Admin'
          : demoRole == UserRole.customer
              ? 'Patient User'
              : 'Dr. Sarah Connor (Pharmacist)',
      email: email,
      phone: '+44 7747 571513',
      role: demoRole,
      companyId: _tenantId,
      licenseNo: demoRole == UserRole.pharmacist || demoRole == UserRole.businessAdmin
          ? 'PH-UK-984721'
          : null,
    );
    notifyListeners();
  }

  // ── Sign in ───────────────────────────────────────────────────────────────
  /// Sign in with email and password. Role is fetched from database, NOT from client.
  Future<void> signInWithSupabase({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await SupabaseService()
          .signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) throw Exception('Sign-in failed — no user returned.');
      
      // ✅ SECURITY FIX: Fetch role from database, not from client
      _currentUser = await _fetchUserFromDatabase(user.id);
      
      // Audit log successful login
      await AuditService.logAuth(
        action: AuditActions.userLogin,
        userId: _currentUser!.id,
        userRole: _currentUser!.role.name,
        tenantId: _tenantId,
        email: email,
        success: true,
      );
      
      notifyListeners();
    } on AuthException catch (e) {
      // Audit log failed login attempt
      await AuditService.logAuth(
        action: AuditActions.loginFailed,
        userId: email, // Use email as identifier since we don't have user ID
        userRole: 'unknown',
        tenantId: null,
        email: email,
        success: false,
        errorMessage: e.message,
      );
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
    // Audit log logout before clearing user data
    if (_currentUser != null) {
      AuditService.logAuth(
        action: AuditActions.userLogout,
        userId: _currentUser!.id,
        userRole: _currentUser!.role.name,
        tenantId: _tenantId,
        email: _currentUser!.email,
        success: true,
      );
    }
    
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
      // ✅ SECURITY FIX: Always fetch role from database on session restore
      _currentUser = await _fetchUserFromDatabase(session.user.id);
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

  // ── ✅ SECURITY FIX: Fetch user role from database ────────────────────────
  /// Fetches user data from public.users table and validates role.
  /// This is the ONLY source of truth for user roles.
  Future<AppUser> _fetchUserFromDatabase(String userId) async {
    if (kDebugMode) {
      print('[Auth] Fetching user from database: $userId');
    }

    final client = Supabase.instance.client;
    final response = await client
        .from('users')
        .select('id, tenant_id, name, phone, email, role, license_no, is_active')
        .eq('id', userId)
        .maybeSingle();

    if (response == null) {
      throw Exception('User not found in database. Please contact support.');
    }

    // Check if account is active
    if (response['is_active'] != true) {
      throw Exception('Your account has been deactivated. Please contact support.');
    }

    // Parse role from database
    final roleStr = response['role'] as String?;
    if (roleStr == null || roleStr.isEmpty) {
      throw Exception('User role not set. Please contact support.');
    }

    // Convert database role format (snake_case) to UserRole enum
    final role = _parseUserRole(roleStr);
    if (role == null) {
      throw Exception('Invalid user role: $roleStr');
    }

    // Store tenant context
    _tenantId = response['tenant_id'] as String?;
    
    // Get default branch for tenant users
    if (_tenantId != null && _tenantId!.isNotEmpty) {
      try {
        final branchResponse = await client
            .from('branches')
            .select('id')
            .eq('tenant_id', _tenantId!)
            .eq('is_active', true)
            .order('created_at')
            .limit(1)
            .maybeSingle();
        
        if (branchResponse != null) {
          _branchId = branchResponse['id'] as String?;
        }
      } catch (e) {
        if (kDebugMode) {
          print('[Auth] Could not fetch default branch: $e');
        }
      }
    }

    if (kDebugMode) {
      print('[Auth] User authenticated: role=$roleStr, tenant=$_tenantId, branch=$_branchId');
    }

    return AppUser(
      id: userId,
      name: (response['name'] as String?) ?? 'User',
      email: (response['email'] as String?) ?? '',
      phone: (response['phone'] as String?) ?? '',
      role: role,
      companyId: _tenantId,
      licenseNo: response['license_no'] as String?,
    );
  }

  /// Converts database role string (snake_case) to UserRole enum
  UserRole? _parseUserRole(String roleStr) {
    switch (roleStr.toLowerCase()) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'business_admin':
        return UserRole.businessAdmin;
      case 'pharmacist':
        return UserRole.pharmacist;
      case 'cashier':
        return UserRole.cashier;
      case 'customer':
        return UserRole.customer;
      default:
        return null;
    }
  }

  // ── ✅ SECURITY FIX: Revalidate role from database ────────────────────────
  /// Re-fetches the user's role from database to ensure it hasn't changed.
  /// Call this periodically or before sensitive operations.
  Future<bool> revalidateRole() async {
    if (_currentUser == null) return false;
    if (!AppConfig.supabaseConfigured) return true; // Demo mode bypass

    try {
      final freshUser = await _fetchUserFromDatabase(_currentUser!.id);
      
      // Check if role has changed
      if (freshUser.role != _currentUser!.role) {
        if (kDebugMode) {
          print('[Auth] Role changed from ${_currentUser!.role} to ${freshUser.role}');
        }
        
        // Audit log role change detection
        await AuditService.log(
          action: AuditActions.roleChanged,
          userId: _currentUser!.id,
          userRole: freshUser.role.name,
          tenantId: _tenantId,
          details: {
            'old_role': _currentUser!.role.name,
            'new_role': freshUser.role.name,
            'email': _currentUser!.email,
          },
        );
        
        _currentUser = freshUser;
        notifyListeners();
      }
      
      return true;
    } catch (e) {
      if (kDebugMode) {
        print('[Auth] Role revalidation failed: $e');
      }
      return false;
    }
  }

  // ── ✅ SECURITY FIX: Validate tenant access ───────────────────────────────
  /// Validates that current user has access to the specified tenant.
  /// Super admins have access to all tenants.
  /// Other users can only access their own tenant.
  Future<void> validateTenantAccess(String requestedTenantId) async {
    if (_currentUser == null) {
      throw Exception('Not authenticated');
    }

    // Super admins can access any tenant (for SaaS management)
    if (_currentUser!.role == UserRole.superAdmin) {
      return;
    }

    // Other users must match their tenant
    if (_currentUser!.tenantId != requestedTenantId) {
      // Audit log unauthorized access attempt
      await AuditService.logSecurityEvent(
        action: AuditActions.unauthorizedAttempt,
        userId: _currentUser!.id,
        userRole: _currentUser!.role.name,
        tenantId: _tenantId,
        severity: 'high',
        description: 'Attempted to access data from another business',
        details: {
          'user_tenant': _currentUser!.tenantId ?? 'null',
          'requested_tenant': requestedTenantId,
        },
      );
      
      throw Exception('Unauthorized: Cannot access data from another business');
    }
  }
}
