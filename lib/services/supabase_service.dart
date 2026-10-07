import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/app_config.dart';
import '../models/invoice_model.dart';
import '../models/ledger_entry_model.dart';
import '../utils/db_mapper.dart';

/// Central Supabase client wrapper.
/// Handles initialization, auth, and all DB operations.
/// Falls back gracefully when offline — callers catch [SupabaseException].
class SupabaseService {
  // ── Singleton ────────────────────────────────────────────────────────────
  static final SupabaseService _instance = SupabaseService._();
  factory SupabaseService() => _instance;
  SupabaseService._();

  // ── Initialization ───────────────────────────────────────────────────────
  /// Call once from main() before runApp().
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      publishableKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );
    debugPrint('[Supabase] Initialized → ${AppConfig.supabaseUrl}');
  }

  SupabaseClient get _client => Supabase.instance.client;

  /// Turn a raw backend error into something a user can act on.
  ///
  /// RLS denials arrive as PostgrestException with 42501 / PGRST301. Surfacing
  /// the raw policy text tells an attacker how the rules are shaped and tells a
  /// legitimate user nothing, so both collapse to a plain access message.
  static String describeError(Object error) {
    if (error is PostgrestException) {
      final code = error.code ?? '';
      if (code == '42501' || code == 'PGRST301' || code == 'PGRST116') {
        return 'You do not have access to this record.';
      }
      if (code == '23505') {
        return 'A record with these details already exists.';
      }
      if (code == '23503') {
        return 'A referenced record is missing or was removed.';
      }
      return error.message;
    }
    if (error is AuthException) return error.message;
    return error.toString().replaceFirst('Exception: ', '');
  }

  // ── Auth ─────────────────────────────────────────────────────────────────
  User? get currentUser => _client.auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Session? get currentSession => _client.auth.currentSession;

  Stream<AuthState> get authStateStream => _client.auth.onAuthStateChange;

  /// Sign in with email + password.
  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) =>
      _client.auth.signInWithPassword(email: email, password: password);

  /// Sign up a new user.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) =>
      _client.auth.signUp(email: email, password: password, data: data);

  /// Send OTP to email for Customer Portal login.
  Future<void> sendOtp(String email) =>
      _client.auth.signInWithOtp(email: email);

  /// Verify OTP entered by user.
  Future<AuthResponse> verifyOtp({
    required String email,
    required String token,
  }) =>
      _client.auth.verifyOTP(
        email: email,
        token: token,
        type: OtpType.email,
      );

  /// Sign out current session.
  Future<void> signOut() => _client.auth.signOut();

  // ── Invoices ──────────────────────────────────────────────────────────────
  /// Upsert a single invoice to Supabase (insert or update if exists).
  /// Maps InvoiceModel to 'sales' and 'sale_items' tables with proper field names.
  Future<void> upsertInvoice(
    InvoiceModel invoice, {
    required String tenantId,
    required String branchId,
    required String createdBy,
  }) async {
    // Insert into sales table
    final salesRow = DbMapper.invoiceToSalesRow(
      invoice,
      tenantId: tenantId,
      branchId: branchId,
      createdBy: createdBy,
    );
    await _client.from('sales').upsert(salesRow);

    // Insert sale items
    final saleItems = invoice.items.map((item) {
      return DbMapper.invoiceItemToSaleItemRow(
        invoice.id,
        item,
        tenantId: tenantId,
      );
    }).toList();
    
    if (saleItems.isNotEmpty) {
      await _client.from('sale_items').upsert(saleItems);
    }

    debugPrint('[Supabase] Invoice upserted: ${invoice.invoiceNumber} with ${invoice.items.length} items');
  }

  /// Upsert a batch of invoices (offline queue replay).
  Future<void> upsertInvoiceBatch(
    List<InvoiceModel> invoices, {
    required String tenantId,
    required String branchId,
    required String createdBy,
  }) async {
    if (invoices.isEmpty) return;

    // Batch insert sales
    final salesRows = invoices.map((inv) {
      return DbMapper.invoiceToSalesRow(
        inv,
        tenantId: tenantId,
        branchId: branchId,
        createdBy: createdBy,
      );
    }).toList();
    await _client.from('sales').upsert(salesRows);

    // Batch insert sale items
    final allSaleItems = <Map<String, dynamic>>[];
    for (final invoice in invoices) {
      for (final item in invoice.items) {
        allSaleItems.add(DbMapper.invoiceItemToSaleItemRow(
          invoice.id,
          item,
          tenantId: tenantId,
        ));
      }
    }
    
    if (allSaleItems.isNotEmpty) {
      await _client.from('sale_items').upsert(allSaleItems);
    }

    debugPrint('[Supabase] Batch upserted: ${invoices.length} invoices');
  }

  /// Fetch recent invoices for the current company.
  /// Note: This returns raw database rows and needs proper mapping to InvoiceModel
  Future<List<Map<String, dynamic>>> fetchRecentInvoices({
    required String tenantId,
    int limit = 50,
  }) async {
    final response = await _client
        .from('sales')
        .select('*, sale_items(*)')
        .eq('tenant_id', tenantId)
        .order('invoice_date', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // ── Ledger entries ────────────────────────────────────────────────────────
  Future<void> upsertLedgerEntry(LedgerEntryModel entry) async {
    await _client.from('ledger_entries').upsert(entry.toJson());
  }

  Future<void> upsertLedgerBatch(List<LedgerEntryModel> entries) async {
    if (entries.isEmpty) return;
    await _client
        .from('ledger_entries')
        .upsert(entries.map((e) => e.toJson()).toList());
  }

  // ── Products & Batches ────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchProducts(String tenantId) async {
    debugPrint('[STOCK DEBUG] Fetching products for tenant: $tenantId');
    final response = await _client
        .from('products')
        .select('*, batches(*)')
        .eq('tenant_id', tenantId);
    debugPrint('[STOCK DEBUG] Products query returned ${(response as List).length} products');
    if ((response as List).isNotEmpty) {
      final first = (response as List).first;
      debugPrint('[STOCK DEBUG] First product: ${first['name']} | batches field: ${first['batches']}');
    }
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> upsertProduct(Map<String, dynamic> product) async {
    await _client.from('products').upsert(product);
  }

  Future<void> deleteProduct(String productId) async {
    await _client.from('products').delete().eq('id', productId);
  }

  Future<void> upsertBatch(Map<String, dynamic> batch) async {
    await _client.from('batches').upsert(batch);
  }

  // ── Sales & Sale Items ────────────────────────────────────────────────────
  Future<void> upsertSale(Map<String, dynamic> sale) async {
    await _client.from('sales').upsert(sale);
  }

  Future<void> upsertSaleItem(Map<String, dynamic> saleItem) async {
    await _client.from('sale_items').upsert(saleItem);
  }

  // ── Restricted Drug Log ───────────────────────────────────────────────────
  Future<void> insertRestrictedDrugLog(Map<String, dynamic> log) async {
    await _client.from('restricted_drug_logs').insert(log);
  }

  Future<List<Map<String, dynamic>>> fetchRestrictedDrugLogs(
      String tenantId) async {
    final response = await _client
        .from('restricted_drug_logs')
        .select()
        .eq('tenant_id', tenantId)
        .order('authorization_timestamp', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // ── Companies / Tenants ───────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchAllTenants() async {
    final response =
        await _client.from('tenants').select().order('created_at');
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> upsertCompany(Map<String, dynamic> company) async {
    await _client.from('tenants').upsert(company);
  }

  Future<void> updateCompanyStatus({
    required String companyId,
    required bool isActive,
  }) async {
    await _client.from('tenants').update({
      'is_active': isActive,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', companyId);
  }

  Future<void> deleteTenant(String tenantId) async {
    await _client.from('tenants').delete().eq('id', tenantId);
  }

  /// Create the initial business_admin login for a freshly provisioned tenant.
  ///
  /// `tenant_id` and `role` go into user metadata because that is where
  /// [AuthProvider] reads tenant context from, and the RLS helper functions
  /// resolve the tenant from the matching `users` row.
  Future<void> createTenantAdminUser({
    required String email,
    required String password,
    required String tenantId,
    required String fullName,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {
        'tenant_id': tenantId,
        'role': 'business_admin',
        'full_name': fullName,
      },
    );

    final userId = response.user?.id;
    if (userId == null) {
      throw Exception(
        'Auth user was not created for $email. Check that email signups are '
        'enabled for this Supabase project.',
      );
    }

    // Mirror into the application users table that the RLS helpers read.
    // Column is `name`, not `full_name` (see migration 001).
    await _client.from('users').upsert({
      'id': userId,
      'tenant_id': tenantId,
      'name': fullName,
      'email': email,
      'role': 'business_admin',
      'is_active': true,
    });

    debugPrint('[Supabase] Tenant admin created: $email → tenant $tenantId');
  }

  // ── Stock Transfers ───────────────────────────────────────────────────────
  Future<void> upsertStockTransfer(Map<String, dynamic> transfer) async {
    await _client.from('stock_transfers').upsert(transfer);
  }

  Future<List<Map<String, dynamic>>> fetchStockTransfers(
      String tenantId) async {
    final response = await _client
        .from('stock_transfers')
        .select()
        .eq('tenant_id', tenantId)
        .order('transfer_date', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // ── OTA Version Manifest ──────────────────────────────────────────────────
  Future<Map<String, dynamic>?> fetchLatestVersionManifest() async {
    try {
      final response = await _client
          .from('ota_releases')
          .select()
          .order('releasedAt', ascending: false)
          .limit(1)
          .maybeSingle();
      return response;
    } catch (_) {
      return null;
    }
  }

  // ── Realtime subscriptions ────────────────────────────────────────────────
  RealtimeChannel subscribeToInvoices({
    required String tenantId,
    required void Function(Map<String, dynamic>) onInsert,
  }) {
    return _client
        .channel('sales:$tenantId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'sales',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'tenant_id',
            value: tenantId,
          ),
          callback: (payload) => onInsert(payload.newRecord),
        )
        .subscribe();
  }

  // ── Branches ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchBranches(String tenantId) async {
    final response = await _client
        .from('branches')
        .select()
        .eq('tenant_id', tenantId)
        .order('branch_name');
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> upsertBranch(Map<String, dynamic> branch) async {
    await _client.from('branches').upsert(branch);
  }

  Future<void> updateBranchStatus({
    required String branchId,
    required bool isActive,
  }) async {
    await _client
        .from('branches')
        .update({'is_active': isActive}).eq('id', branchId);
  }

  // ── Demo Requests ─────────────────────────────────────────────────────────
  Future<void> insertDemoRequest(Map<String, dynamic> request) async {
    await _client.from('demo_requests').insert(request);
  }

  Future<List<Map<String, dynamic>>> fetchDemoRequests({
    String status = 'new',
  }) async {
    final response = await _client
        .from('demo_requests')
        .select()
        .eq('status', status)
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  // ── Customers ─────────────────────────────────────────────────────────────
  /// Finds a customer within a tenant by phone or email.
  Future<List<Map<String, dynamic>>> findCustomer({
    required String tenantId,
    String? phone,
    String? email,
  }) async {
    final clauses = <String>[];
    if (phone != null && phone.trim().isNotEmpty) {
      clauses.add('phone.eq.${phone.trim()}');
    }
    if (email != null && email.trim().isNotEmpty) {
      clauses.add('email.eq.${email.trim()}');
    }
    if (clauses.isEmpty) return const [];

    final response = await _client
        .from('customers')
        .select()
        .eq('tenant_id', tenantId)
        .or(clauses.join(','))
        .limit(1);
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Purchase history with line items and the chronic flag, newest first.
  Future<List<Map<String, dynamic>>> fetchCustomerPurchaseHistory({
    required String tenantId,
    String? customerId,
    String? customerPhone,
    int limit = 100,
  }) async {
    var query = _client
        .from('sales')
        .select('*, sale_items(*, products(is_chronic, generic_salt))')
        .eq('tenant_id', tenantId);

    // Prefer the customer id; fall back to phone for walk-in sales that were
    // never linked to a customer record.
    if (customerId != null) {
      query = query.eq('customer_id', customerId);
    } else if (customerPhone != null && customerPhone.trim().isNotEmpty) {
      query = query.eq('customer_phone', customerPhone.trim());
    } else {
      return const [];
    }

    final response =
        await query.order('invoice_date', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Logs a chronic refill request. Uses the ledger table as a lightweight
  /// request log so no extra schema is needed for this feature.
  Future<void> insertRefillRequest({
    required String tenantId,
    required String customerId,
    required String medicineName,
  }) async {
    await _client.from('customer_refill_requests').insert({
      'tenant_id': tenantId,
      'customer_id': customerId,
      'medicine_name': medicineName,
      'status': 'requested',
    });
  }

  // ── Pricing Plans ─────────────────────────────────────────────────────────
  /// World-readable, so this works for anonymous visitors on the pricing page.
  Future<List<Map<String, dynamic>>> fetchPricingPlans() async {
    final response = await _client
        .from('pricing_plans')
        .select()
        .eq('is_active', true)
        .order('display_order');
    return List<Map<String, dynamic>>.from(response as List);
  }

  // ── Pharmacists ───────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> fetchPharmacists(String tenantId) async {
    final response = await _client
        .from('pharmacists')
        .select()
        .eq('tenant_id', tenantId)
        .order('name');
    return List<Map<String, dynamic>>.from(response as List);
  }

  Future<void> upsertPharmacist(Map<String, dynamic> pharmacist) async {
    await _client.from('pharmacists').upsert(pharmacist);
  }

  Future<void> deletePharmacist({
    required String pharmacistId,
    required String tenantId,
  }) async {
    await _client
        .from('pharmacists')
        .delete()
        .eq('id', pharmacistId)
        .eq('tenant_id', tenantId);
  }

  // ── Near Expiry Stock ─────────────────────────────────────────────────────
  /// Reads the `near_expiry_stock` view. The view carries a year of stock so
  /// the caller applies its own window via [withinDays].
  Future<List<Map<String, dynamic>>> fetchNearExpiryStock({
    required String tenantId,
    int withinDays = 90,
    String? branchId,
  }) async {
    var query = _client
        .from('near_expiry_stock')
        .select()
        .eq('tenant_id', tenantId)
        .lte('days_until_expiry', withinDays);

    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }

    final response = await query.order('exp_date');
    return List<Map<String, dynamic>>.from(response as List);
  }

  // ── Email Notifications ───────────────────────────────────────────────────
  /// Send email via Supabase Edge Function
  Future<void> sendEmail({
    required String to,
    required String subject,
    String? html,
    String? template,
    Map<String, dynamic>? templateData,
  }) async {
    await _client.functions.invoke(
      'send-email',
      body: {
        'to': to,
        'subject': subject,
        if (html != null) 'html': html,
        if (template != null) 'template': template,
        if (templateData != null) 'template_data': templateData,
      },
    );
    debugPrint('[Supabase] Email sent to: $to');
  }

  // ── Software Downloads & License Management ───────────────────────────────
  /// Fetch all software versions (for Super Admin)
  Future<List<Map<String, dynamic>>> fetchSoftwareVersions() async {
    final response = await _client
        .from('software_versions')
        .select()
        .order('release_date', ascending: false);
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Upload new software version metadata
  Future<Map<String, dynamic>> createSoftwareVersion({
    required String versionNumber,
    required String platform,
    required String filePath,
    String? releaseNotes,
    String? fileSize,
    bool isLatest = false,
  }) async {
    final response = await _client.from('software_versions').insert({
      'version_number': versionNumber,
      'platform': platform,
      'file_path': filePath,
      'release_notes': releaseNotes,
      'file_size': fileSize,
      'is_latest': isLatest,
      'status': 'active',
    }).select().single();
    return response as Map<String, dynamic>;
  }

  /// Update software version
  Future<void> updateSoftwareVersion(
    String versionId,
    Map<String, dynamic> updates,
  ) async {
    await _client
        .from('software_versions')
        .update(updates)
        .eq('id', versionId);
  }

  /// Fetch Business Admin access overview (for Super Admin dashboard)
  Future<List<Map<String, dynamic>>> fetchBusinessAdminAccess() async {
    final response = await _client
        .from('business_admin_access_overview')
        .select()
        .order('tenant_name');
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Update tenant access status (activate/suspend)
  Future<void> updateTenantAccessStatus({
    required String tenantId,
    required String status,
  }) async {
    if (status != 'active' && status != 'suspended') {
      throw ArgumentError('Status must be "active" or "suspended"');
    }
    await _client.from('tenants').update({
      'access_status': status,
    }).eq('id', tenantId);
    debugPrint('[Supabase] Tenant $tenantId access status → $status');
  }

  /// Fetch download logs (for Super Admin)
  Future<List<Map<String, dynamic>>> fetchDownloadLogs({
    String? tenantId,
    int limit = 100,
  }) async {
    var query = _client
        .from('download_logs')
        .select('''
          *,
          tenant:tenants!tenant_id(business_name),
          user:users!user_id(name, email),
          version:software_versions!version_id(version_number, platform)
        ''');

    if (tenantId != null) {
      query = query.eq('tenant_id', tenantId);
    }

    final response = await query.order('downloaded_at', ascending: false).limit(limit);
    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Check if current tenant can download software
  Future<Map<String, dynamic>> checkDownloadAuthorization(
    String tenantId,
  ) async {
    final response = await _client.rpc('get_download_authorization', params: {
      'p_tenant_id': tenantId,
    });
    return response as Map<String, dynamic>;
  }

  /// Generate authorized download URL via Edge Function
  Future<String> generateDownloadUrl({
    required String tenantId,
    required String versionId,
  }) async {
    final response = await _client.functions.invoke(
      'download-software',
      body: {
        'tenant_id': tenantId,
        'version_id': versionId,
      },
    );

    if (response.status != 200) {
      throw Exception(response.data['error'] ?? 'Download authorization failed');
    }

    return response.data['download_url'] as String;
  }

  /// Upload software file to Supabase Storage
  Future<String> uploadSoftwareFile({
    required String fileName,
    required List<int> fileBytes,
    required String platform,
  }) async {
    final path = 'software/$platform/$fileName';
    await _client.storage.from('software').uploadBinary(
          path,
          Uint8List.fromList(fileBytes),
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
          ),
        );
    debugPrint('[Supabase] Software file uploaded → $path');
    return path;
  }

  /// Fetch current subscription for Business Admin
  Future<Map<String, dynamic>?> fetchCurrentSubscription(
    String tenantId,
  ) async {
    final response = await _client
        .from('subscriptions')
        .select('''
          *,
          plan:subscription_plans!plan_id(*)
        ''')
        .eq('tenant_id', tenantId)
        .maybeSingle();
    return response as Map<String, dynamic>?;
  }
}
