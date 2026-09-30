import 'package:flutter/foundation.dart';
import '../models/company_model.dart';
import '../services/supabase_service.dart';

class SuperAdminProvider extends ChangeNotifier {
  final List<CompanyModel> _tenants = [];
  bool _isLoading = false;
  String? _error;

  /// Ids of tenants with an in-flight status toggle, so the row can show a
  /// spinner instead of the whole list blocking.
  final Set<String> _pendingToggles = {};

  List<CompanyModel> get tenants => List.unmodifiable(_tenants);
  bool get isLoading => _isLoading;
  String? get error => _error;

  bool isTogglePending(String tenantId) => _pendingToggles.contains(tenantId);

  /// Revenue from the real subscription plans held by active tenants rather
  /// than a flat per-tenant figure.
  double get monthlySaasRevenue => _tenants
      .where((t) => t.isActive)
      .fold<double>(0, (sum, t) => sum + _planPrice(t.subscriptionPlan));

  int get activeStoresCount => _tenants.where((t) => t.isActive).length;

  static double _planPrice(String plan) {
    switch (plan.toLowerCase()) {
      case 'basic plan':
      case 'basic':
        return 15000;
      case 'professional plan':
      case 'professional':
        return 35000;
      case 'gold edition':
      case 'gold':
        return 26000;
      default:
        return 26000;
    }
  }

  SuperAdminProvider() {
    fetchTenants();
  }

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  /// Fetch all tenants from Supabase.
  Future<void> fetchTenants() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await SupabaseService().fetchAllTenants();
      _tenants
        ..clear()
        ..addAll(data.map(CompanyModel.fromJson));
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[SuperAdmin] Error fetching tenants: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Provision a new business tenant and its initial business_admin login.
  ///
  /// The tenant row is written first because the auth user carries the tenant
  /// id in its metadata. If user creation then fails the tenant row is removed
  /// again, otherwise the console would list a tenant nobody can log into.
  Future<bool> addCompanyTenant(
    CompanyModel company, {
    String? adminPassword,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    final service = SupabaseService();
    var tenantWritten = false;

    try {
      await service.upsertCompany(company.toJson());
      tenantWritten = true;

      if (adminPassword != null && adminPassword.isNotEmpty) {
        await service.createTenantAdminUser(
          email: company.email,
          password: adminPassword,
          tenantId: company.id,
          fullName: company.ownerName,
        );
      }

      _tenants.add(company);
      return true;
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[SuperAdmin] Error creating tenant: $e');

      if (tenantWritten) {
        try {
          await service.deleteTenant(company.id);
          _error = '${_error!} The tenant record was rolled back.';
        } catch (rollbackError) {
          _error = '${_error!} The tenant row was created but its admin login '
              'was not; delete tenant ${company.id} manually.';
          debugPrint('[SuperAdmin] Rollback failed: $rollbackError');
        }
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Toggle tenant active/inactive status.
  Future<bool> toggleTenantStatus(String companyId) async {
    final index = _tenants.indexWhere((c) => c.id == companyId);
    if (index < 0) return false;

    final old = _tenants[index];
    final newStatus = !old.isActive;

    _pendingToggles.add(companyId);
    _error = null;
    notifyListeners();

    try {
      await SupabaseService().updateCompanyStatus(
        companyId: companyId,
        isActive: newStatus,
      );

      _tenants[index] = old.copyWith(
        isActive: newStatus,
        updatedAt: DateTime.now(),
      );
      return true;
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[SuperAdmin] Error toggling tenant status: $e');
      return false;
    } finally {
      _pendingToggles.remove(companyId);
      notifyListeners();
    }
  }

  /// Update tenant details.
  Future<bool> updateTenant(CompanyModel updatedCompany) async {
    _error = null;
    try {
      final withTimestamp =
          updatedCompany.copyWith(updatedAt: DateTime.now());
      await SupabaseService().upsertCompany(withTimestamp.toJson());

      final index = _tenants.indexWhere((t) => t.id == withTimestamp.id);
      if (index >= 0) _tenants[index] = withTimestamp;

      notifyListeners();
      return true;
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[SuperAdmin] Error updating tenant: $e');
      notifyListeners();
      return false;
    }
  }
}
