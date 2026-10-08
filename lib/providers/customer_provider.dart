import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/customer_model.dart';
import '../models/invoice_model.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

/// Customer portal state, backed by real Supabase data.
///
/// Previously this held a hardcoded "John Doe" record with invented
/// prescriptions and refills, which meant every logged-in patient saw the same
/// fictional history. The customer is now resolved from the signed-in user, and
/// purchase history comes from the `sales` table under RLS.
class CustomerProvider extends ChangeNotifier {
  CustomerProvider(this._auth);

  AuthProvider _auth;

  CustomerModel? _currentCustomer;
  final List<InvoiceModel> _customerInvoices = [];
  final List<Map<String, dynamic>> _purchaseHistory = [];
  final List<CustomerModel> _allCustomers = [];

  bool _isLoading = false;
  String? _error;

  CustomerModel? get currentCustomer => _currentCustomer;
  List<InvoiceModel> get customerInvoices => List.unmodifiable(_customerInvoices);
  List<CustomerModel> get allCustomers => List.unmodifiable(_allCustomers);

  /// Raw sale rows for this customer, newest first.
  List<Map<String, dynamic>> get purchaseHistory =>
      List.unmodifiable(_purchaseHistory);

  bool get isLoading => _isLoading;
  String? get error => _error;

  double get lifetimeSpend => _purchaseHistory.fold<double>(
      0, (sum, r) => sum + ((r['grand_total'] as num?)?.toDouble() ?? 0));

  int get orderCount => _purchaseHistory.length;

  /// Chronic refill reminders derived from actual purchases of products flagged
  /// is_chronic, rather than a hardcoded list.
  final List<ChronicRefillItem> _chronicRefills = [];
  List<ChronicRefillItem> get chronicRefills =>
      List.unmodifiable(_chronicRefills);
  List<ChronicRefillItem> get refillsDueSoon =>
      _chronicRefills.where((r) => r.isDueSoon).toList();

  void updateAuth(AuthProvider auth) {
    final changed = _auth.currentUser?.id != auth.currentUser?.id ||
        _auth.tenantId != auth.tenantId;
    _auth = auth;
    if (changed) {
      _currentCustomer = null;
      _customerInvoices.clear();
      _purchaseHistory.clear();
      _chronicRefills.clear();
      if (auth.isLoggedIn) load();
    }
  }

  /// Load the signed-in customer and their purchase history.
  Future<void> load() async {
    final tenantId = _auth.tenantId;
    final user = _auth.currentUser;
    if (tenantId == null || user == null) return;

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final service = SupabaseService();

      // Match the customer record on the signed-in user's phone or email.
      final matches = await service.findCustomer(
        tenantId: tenantId,
        phone: user.phone,
        email: user.email,
      );
      if (matches.isNotEmpty) {
        _currentCustomer = CustomerModel.fromJson(matches.first);
      }

      final history = await service.fetchCustomerPurchaseHistory(
        tenantId: tenantId,
        customerId: _currentCustomer?.id,
        customerPhone: user.phone.isNotEmpty ? user.phone : null,
      );
      _purchaseHistory
        ..clear()
        ..addAll(history);

      _rebuildChronicRefills();
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[Customer] load failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Convenience method to load purchase history without loading customer data
  Future<void> loadCustomerPurchaseHistory() async {
    return load(); // Uses the same logic for now
  }

  /// Derives refill reminders from real purchases of chronic medicines.
  ///
  /// The interval is taken as 30 days, which is the standard chronic dispensing
  /// cycle; the due date is computed from the most recent actual purchase.
  void _rebuildChronicRefills() {
    const intervalDays = 30;
    final latest = <String, DateTime>{};

    for (final sale in _purchaseHistory) {
      final items = sale['sale_items'];
      if (items is! List) continue;
      final saleDate = DateTime.tryParse('${sale['invoice_date']}');
      if (saleDate == null) continue;

      for (final item in items) {
        if (item is! Map) continue;
        final product = item['products'];
        final isChronic =
            product is Map ? product['is_chronic'] == true : false;
        if (!isChronic) continue;

        final name = '${item['product_name']}';
        final existing = latest[name];
        if (existing == null || saleDate.isAfter(existing)) {
          latest[name] = saleDate;
        }
      }
    }

    _chronicRefills
      ..clear()
      ..addAll(latest.entries.map((e) => ChronicRefillItem(
            medicineName: e.key,
            refillIntervalDays: intervalDays,
            lastPurchasedDate: e.value,
            nextRefillDueDate: e.value.add(const Duration(days: intervalDays)),
          )))
      ..sort((a, b) => a.nextRefillDueDate.compareTo(b.nextRefillDueDate));
  }

  void addCustomerInvoice(InvoiceModel invoice) {
    _customerInvoices.add(invoice);
    notifyListeners();
  }

  /// Records a refill request against the customer's record so staff can act on
  /// it. Returns false when there is no customer context.
  Future<bool> requestChronicRefill(ChronicRefillItem item) async {
    final tenantId = _auth.tenantId;
    final customer = _currentCustomer;
    if (tenantId == null || customer == null) {
      _error = 'No customer profile is linked to this login yet.';
      notifyListeners();
      return false;
    }

    try {
      await SupabaseService().insertRefillRequest(
        tenantId: tenantId,
        customerId: customer.id,
        medicineName: item.medicineName,
      );
      return true;
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[Customer] refill request failed: $e');
      notifyListeners();
      return false;
    }
  }

  /// Fetch all customers for the tenant (for admin management)
  Future<void> fetchAllCustomers(String tenantId) async {
    // Validate tenant access before fetching customers
    await _auth.validateTenantAccess(tenantId);
    
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final List<Map<String, dynamic>> results = await client
          .from('customers')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      _allCustomers
        ..clear()
        ..addAll(results.map((json) => CustomerModel.fromJson(json)));
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[Customer] fetchAllCustomers failed: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save (create or update) a customer
  Future<void> saveCustomer(CustomerModel customer) async {
    // Validate tenant access before saving customer
    if (_auth.tenantId != null) {
      await _auth.validateTenantAccess(_auth.tenantId!);
    }
    
    try {
      // Only sync to Supabase if we have proper tenant context
      if (_auth.tenantId != null && _auth.tenantId!.isNotEmpty) {
        final client = Supabase.instance.client;
        await client
            .from('customers')
            .upsert(customer.toJson())
            .eq('id', customer.id);
        debugPrint('[Customer] ? Saved to Supabase: ${customer.name}');
      } else {
        debugPrint('[Customer] ??  Saved locally only (no tenant context): ${customer.name}');
      }

      // Update local list
      final index = _allCustomers.indexWhere((c) => c.id == customer.id);
      if (index >= 0) {
        _allCustomers[index] = customer;
      } else {
        _allCustomers.add(customer);
      }
      notifyListeners();
    } catch (e) {
      _error = SupabaseService.describeError(e);
      debugPrint('[Customer] saveCustomer failed: $e');
      rethrow;
    }
  }
}
