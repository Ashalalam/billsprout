import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/rtv_model.dart';
import '../models/stock_transfer_model.dart';
import '../services/supabase_service.dart';
import '../providers/auth_provider.dart';

class InventoryProvider extends ChangeNotifier {
  AuthProvider authProvider; // Required - for Supabase sync
  
  final List<ProductModel> _products = [];
  final List<RtvNoteModel> _rtvNotes = [];
  final List<StockTransferModel> _transfers = [];
  String _pricingTier = 'Retail'; // mutable — user can switch tier at runtime
  bool _isSyncing = false;

  List<ProductModel> get products => List.unmodifiable(_products);
  List<RtvNoteModel> get rtvNotes => List.unmodifiable(_rtvNotes);
  List<StockTransferModel> get transfers => List.unmodifiable(_transfers);
  String get pricingTier => _pricingTier;
  bool get isSyncing => _isSyncing;

  void setPricingTier(String tier) {
    _pricingTier = tier;
    notifyListeners();
  }

  InventoryProvider({required this.authProvider}) {
    _loadFromDisk();
    // Auto-sync from Supabase if configured
    if (authProvider.tenantId != null) {
      _syncFromSupabase();
    }
  }

  /// Update auth provider and re-sync if tenant context changed
  void updateAuth(AuthProvider auth) {
    final tenantChanged = authProvider.tenantId != auth.tenantId;
    authProvider = auth;
    if (tenantChanged && auth.tenantId != null) {
      debugPrint('[Inventory] Tenant context updated, re-syncing from Supabase');
      _syncFromSupabase();
    }
  }

  /// Adds a brand-new product to the catalogue and persists to disk.
  /// Also syncs to Supabase if configured.
  Future<void> addProduct(ProductModel product) async {
    // Validate tenant access before modifying data
    if (authProvider.tenantId != null) {
      await authProvider.validateTenantAccess(authProvider.tenantId!);
    }
    
    _products.add(product);
    await _saveToDisk();
    notifyListeners();
    
    // Sync to Supabase in background
    _syncProductToSupabase(product);
  }

  /// Adds a new [batch] to an existing product and persists to disk.
  /// Also syncs to Supabase if configured.
  Future<void> addBatchToProduct(String productId, BatchModel batch) async {
    // Validate tenant access before modifying data
    if (authProvider.tenantId != null) {
      await authProvider.validateTenantAccess(authProvider.tenantId!);
    }
    
    final index = _products.indexWhere((p) => p.id == productId);
    if (index < 0) return;
    _products[index].batches.add(batch);
    await _saveToDisk();
    notifyListeners();
    
    // Sync batch to Supabase in background
    _syncBatchToSupabase(productId, batch);
  }

  /// Update stock quantity for an existing batch (e.g. stock-in).
  Future<void> addStockToBatch({
    required String productId,
    required String batchId,
    required int additionalQty,
  }) async {
    // Validate tenant access before modifying stock
    if (authProvider.tenantId != null) {
      await authProvider.validateTenantAccess(authProvider.tenantId!);
    }
    
    final pIdx = _products.indexWhere((p) => p.id == productId);
    if (pIdx < 0) return;
    final bIdx =
        _products[pIdx].batches.indexWhere((b) => b.id == batchId);
    if (bIdx < 0) return;
    _products[pIdx].batches[bIdx].stockCount += additionalQty;
    _saveToDisk();
    notifyListeners();
  }

  /// Reduce stock quantity for a sale (called after POS checkout).
  Future<void> reduceStockForSale({
    required String productId,
    required String batchId,
    required int quantity,
  }) async {
    // Validate tenant access before modifying stock
    if (authProvider.tenantId != null) {
      await authProvider.validateTenantAccess(authProvider.tenantId!);
    }
    
    final pIdx = _products.indexWhere((p) => p.id == productId);
    if (pIdx < 0) return;
    final bIdx = _products[pIdx].batches.indexWhere((b) => b.id == batchId);
    if (bIdx < 0) return;
    
    final batch = _products[pIdx].batches[bIdx];
    batch.stockCount = (batch.stockCount - quantity).clamp(0, batch.stockCount);
    
    _saveToDisk();
    notifyListeners();
    debugPrint('[Inventory] Reduced stock for ${_products[pIdx].name} batch ${batch.batchNumber}: -$quantity (now: ${batch.stockCount})');
  }

  List<ProductModel> searchProducts(String query) {
    if (query.trim().isEmpty) return _products;
    final q = query.toLowerCase().trim();
    return _products.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.genericSalt.toLowerCase().contains(q) ||
          p.barcode.contains(q) ||
          p.hsnCode.contains(q);
    }).toList();
  }

  List<BatchModel> getNearExpiryBatches() {
    final List<BatchModel> nearExpiryList = [];
    for (var p in _products) {
      for (var b in p.batches) {
        if (b.isNearExpiry || b.isExpired) {
          nearExpiryList.add(b);
        }
      }
    }
    return nearExpiryList;
  }

  void createRtvNote({
    required String supplierName,
    required ProductModel product,
    required BatchModel batch,
    required int quantity,
    required String reason,
  }) async {
    // Validate tenant access before creating RTV note
    if (authProvider.tenantId != null) {
      await authProvider.validateTenantAccess(authProvider.tenantId!);
    }
    
    if (quantity <= 0 || quantity > batch.stockCount) return;
    batch.stockCount -= quantity;

    final rtv = RtvNoteModel(
      id: 'rtv_${DateTime.now().millisecondsSinceEpoch}',
      rtvNumber: 'RTV-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      supplierName: supplierName,
      productName: product.name,
      batchNumber: batch.batchNumber,
      quantity: quantity,
      returnUnitPrice: batch.purchasePrice,
      reason: reason,
      date: DateTime.now(),
    );

    _rtvNotes.add(rtv);
    _saveToDisk();
    notifyListeners();
  }

  void createStockTransfer({
    required String destinationBranch,
    required ProductModel product,
    required BatchModel batch,
    required int quantity,
  }) async {
    // Validate tenant access before creating stock transfer
    if (authProvider.tenantId != null) {
      await authProvider.validateTenantAccess(authProvider.tenantId!);
    }
    
    if (quantity <= 0 || quantity > batch.stockCount) return;
    batch.stockCount -= quantity;

    final transfer = StockTransferModel(
      id: 'trf_${DateTime.now().millisecondsSinceEpoch}',
      transferNumber: 'TRF-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}',
      sourceBranch: 'Main Store / Central Warehouse',
      destinationBranch: destinationBranch,
      productName: product.name,
      batchNumber: batch.batchNumber,
      quantity: quantity,
      timestamp: DateTime.now(),
    );

    _transfers.add(transfer);
    _saveToDisk();
    notifyListeners();
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsJson = jsonEncode(_products.map((p) => p.toJson()).toList());
      final rtvJson = jsonEncode(_rtvNotes.map((r) => r.toJson()).toList());
      final trfJson = jsonEncode(_transfers.map((t) => t.toJson()).toList());

      await prefs.setString('inv_products', productsJson);
      await prefs.setString('inv_rtv', rtvJson);
      await prefs.setString('inv_transfers', trfJson);
    } catch (_) {}
  }

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final productsStr = prefs.getString('inv_products');
      final rtvStr = prefs.getString('inv_rtv');
      final trfStr = prefs.getString('inv_transfers');

      if (productsStr != null) {
        final List list = jsonDecode(productsStr);
        _products.clear();
        _products.addAll(list.map((e) => ProductModel.fromJson(e)).toList());
      } else {
        _seedSampleInventory();
      }

      if (rtvStr != null) {
        final List list = jsonDecode(rtvStr);
        _rtvNotes.clear();
        _rtvNotes.addAll(list.map((e) => RtvNoteModel.fromJson(e)).toList());
      }

      if (trfStr != null) {
        final List list = jsonDecode(trfStr);
        _transfers.clear();
        _transfers.addAll(list.map((e) => StockTransferModel.fromJson(e)).toList());
      }
    } catch (_) {
      _seedSampleInventory();
    }
    notifyListeners();
  }

  void _seedSampleInventory() {
    _products.clear();
    _products.addAll([
      ProductModel(
        id: 'prod_1',
        name: 'Amoxicillin 500mg Capsules',
        genericSalt: 'Amoxicillin Trihydrate',
        barcode: '8901234567890',
        hsnCode: '30041010',
        taxPercent: 12.0,
        manufacturer: 'LIFESPROUT Pharma Labs',
        isScheduleH: true,
        batches: [
          BatchModel(
            id: 'b_101',
            batchNumber: 'AMX-2024-09',
            mfgDate: DateTime(2024, 1, 15),
            expDate: DateTime(2026, 12, 31),
            mrp: 120.0,
            purchasePrice: 75.0,
            wholesalePrice: 95.0,
            stockCount: 150,
            rackLocation: 'Rack A-2',
          ),
          BatchModel(
            id: 'b_102',
            batchNumber: 'AMX-2024-03',
            mfgDate: DateTime(2024, 2, 1),
            expDate: DateTime(2026, 10, 15),
            mrp: 120.0,
            purchasePrice: 75.0,
            wholesalePrice: 95.0,
            stockCount: 45,
            rackLocation: 'Rack A-2',
          ),
        ],
      ),
      ProductModel(
        id: 'prod_2',
        name: 'Paracetamol 650mg Tablets (Dolo/Calpol)',
        genericSalt: 'Paracetamol (Acetaminophen)',
        barcode: '8901234567891',
        hsnCode: '30049060',
        taxPercent: 12.0,
        manufacturer: 'CareSprout Remedies',
        isScheduleH: false,
        batches: [
          BatchModel(
            id: 'b_201',
            batchNumber: 'PCM-650-A',
            mfgDate: DateTime(2024, 3, 10),
            expDate: DateTime(2027, 5, 20),
            mrp: 32.50,
            purchasePrice: 18.0,
            wholesalePrice: 24.0,
            stockCount: 500,
            rackLocation: 'Rack B-1',
          ),
        ],
      ),
      ProductModel(
        id: 'prod_3',
        name: 'Alprazolam 0.5mg Tablets',
        genericSalt: 'Alprazolam',
        barcode: '8901234567892',
        hsnCode: '30049099',
        taxPercent: 12.0,
        manufacturer: 'Lifesprout Neuro',
        isScheduleH1: true,
        isNarcotic: true,
        batches: [
          BatchModel(
            id: 'b_301',
            batchNumber: 'ALP-H1-88',
            mfgDate: DateTime(2024, 5, 1),
            expDate: DateTime(2026, 11, 30),
            mrp: 85.0,
            purchasePrice: 40.0,
            wholesalePrice: 60.0,
            stockCount: 80,
            rackLocation: 'Vault Lock Box 3',
          ),
        ],
      ),
      ProductModel(
        id: 'prod_4',
        name: 'Metformin 500mg Sustained Release',
        genericSalt: 'Metformin Hydrochloride',
        barcode: '8901234567893',
        hsnCode: '30049080',
        taxPercent: 12.0,
        manufacturer: 'Diabetes Care Ltd',
        isScheduleH: true,
        batches: [
          BatchModel(
            id: 'b_401',
            batchNumber: 'MET-SR-44',
            mfgDate: DateTime(2024, 2, 10),
            expDate: DateTime(2026, 10, 05),
            mrp: 65.0,
            purchasePrice: 32.0,
            wholesalePrice: 45.0,
            stockCount: 320,
            rackLocation: 'Rack C-4',
          ),
        ],
      ),
      ProductModel(
        id: 'prod_5',
        name: 'Digital Blood Pressure Monitor',
        genericSalt: 'Medical Device / Hardware',
        barcode: '8901234567894',
        hsnCode: '90189099',
        taxPercent: 18.0,
        manufacturer: 'Lifesprout HealthTech',
        isScheduleH: false,
        batches: [
          BatchModel(
            id: 'b_501',
            batchNumber: 'BPM-2024-X',
            mfgDate: DateTime(2024, 1, 1),
            expDate: DateTime(2030, 1, 1),
            mrp: 1850.0,
            purchasePrice: 1100.0,
            wholesalePrice: 1400.0,
            stockCount: 25,
            rackLocation: 'Showcase Shelf 1',
          ),
        ],
      ),
    ]);
  }

  // ── Supabase Sync ──────────────────────────────────────────────────────────

  /// Sync products from Supabase to local state
  Future<void> _syncFromSupabase() async {
    if (authProvider.tenantId == null) return;
    
    _isSyncing = true;
    notifyListeners();
    
    try {
      final tenantId = authProvider.tenantId!;
      final productsData = await SupabaseService().fetchProducts(tenantId);
      
      if (productsData.isNotEmpty) {
        _products.clear();
        
        for (final productRow in productsData) {
          // Convert snake_case DB fields to camelCase for model
          final product = _productFromDbRow(productRow);
          _products.add(product);
        }
        
        await _saveToDisk();
        debugPrint('[Inventory] Synced ${_products.length} products from Supabase');
      }
    } on PostgrestException catch (e) {
      debugPrint('[Inventory] Supabase sync error: ${e.message}');
    } catch (e) {
      debugPrint('[Inventory] Sync error: $e');
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Sync a single product to Supabase
  Future<void> _syncProductToSupabase(ProductModel product) async {
    if (authProvider.tenantId == null) {
      debugPrint('[Inventory] Cannot sync product: missing tenant context');
      return;
    }
    
    try {
      final tenantId = authProvider.tenantId!;
      final productRow = _productToDbRow(product, tenantId);
      
      await SupabaseService().upsertProduct(productRow);
      debugPrint('[Inventory] Product synced to Supabase: ${product.name}');
      
      // Sync batches
      for (final batch in product.batches) {
        await _syncBatchToSupabase(product.id, batch);
      }
    } on PostgrestException catch (e) {
      debugPrint('[Inventory] Product sync failed: ${e.message}');
    } catch (e) {
      debugPrint('[Inventory] Product sync error: $e');
    }
  }

  /// Sync a single batch to Supabase
  Future<void> _syncBatchToSupabase(String productId, BatchModel batch) async {
    if (authProvider.tenantId == null || authProvider.branchId == null) {
      debugPrint('[Inventory] Cannot sync batch: missing tenant/branch context');
      return;
    }
    
    try {
      final tenantId = authProvider.tenantId!;
      final branchId = authProvider.branchId!;
      final batchRow = _batchToDbRow(batch, productId, tenantId, branchId);
      
      await SupabaseService().upsertBatch(batchRow);
      debugPrint('[Inventory] Batch synced to Supabase: ${batch.batchNumber}');
    } on PostgrestException catch (e) {
      debugPrint('[Inventory] Batch sync failed: ${e.message}');
    } catch (e) {
      debugPrint('[Inventory] Batch sync error: $e');
    }
  }

  // ── DB Mapping Helpers ────────────────────────────────────────────────────

  /// Convert database row (snake_case) to ProductModel (camelCase)
  ProductModel _productFromDbRow(Map<String, dynamic> row) {
    // Extract batches if present
    final batchesData = row['batches'] as List<dynamic>? ?? [];
    final batches = batchesData.map((b) => _batchFromDbRow(b as Map<String, dynamic>)).toList();
    
    return ProductModel(
      id: row['id'] as String,
      name: row['name'] as String,
      genericSalt: row['generic_salt'] as String? ?? '',
      barcode: row['barcode'] as String? ?? '',
      hsnCode: row['hsn_code'] as String? ?? '',
      taxPercent: (row['gst_percent'] as num?)?.toDouble() ?? 0.0,
      manufacturer: row['manufacturer'] as String? ?? '',
      isScheduleH: row['is_schedule_h'] as bool? ?? false,
      isScheduleH1: row['is_schedule_h1'] as bool? ?? false,
      isNarcotic: row['is_narcotic'] as bool? ?? false,
      batches: batches,
    );
  }

  /// Convert database row (snake_case) to BatchModel (camelCase)
  BatchModel _batchFromDbRow(Map<String, dynamic> row) {
    return BatchModel(
      id: row['id'] as String,
      batchNumber: row['batch_number'] as String,
      // BatchModel.mfgDate is non-nullable. mfg_date is optional in the schema,
      // so fall back to the expiry date rather than passing null.
      mfgDate: row['mfg_date'] != null
          ? DateTime.parse(row['mfg_date'] as String)
          : DateTime.parse(row['exp_date'] as String),
      expDate: DateTime.parse(row['exp_date'] as String),
      mrp: (row['mrp'] as num).toDouble(),
      purchasePrice: (row['purchase_price'] as num).toDouble(),
      wholesalePrice: (row['wholesale_price'] as num?)?.toDouble() ?? 0.0,
      ptrPrice: (row['ptr_price'] as num?)?.toDouble() ?? 0.0,
      stockCount: row['stock_quantity'] as int? ?? 0,
      rackLocation: row['rack_location'] as String? ?? '',
    );
  }

  /// Convert ProductModel to database row (snake_case)
  Map<String, dynamic> _productToDbRow(ProductModel product, String tenantId) {
    return {
      'id': product.id,
      'tenant_id': tenantId,
      'name': product.name,
      'generic_salt': product.genericSalt,
      'barcode': product.barcode,
      'hsn_code': product.hsnCode,
      'gst_percent': product.taxPercent,
      'manufacturer': product.manufacturer,
      'is_schedule_h': product.isScheduleH,
      'is_schedule_h1': product.isScheduleH1,
      'is_narcotic': product.isNarcotic,
      'is_prescription_required': product.requiresPharmacistPin,
      // Product master fields added by migration 008. Without these the dosage
      // form and pack configuration entered in the UI were never persisted.
      'dosage_form': product.doseType.name,
      'dose_type': product.doseType.name,
      'packaging_label': product.packagingConfig?.label,
      'packaging_units_per_strip': product.packagingConfig?.unitsPerStrip,
      'packaging_strips_per_box': product.packagingConfig?.stripsPerBox,
      'pack_size': product.packagingConfig?.label,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  /// Convert BatchModel to database row (snake_case)
  Map<String, dynamic> _batchToDbRow(
    BatchModel batch,
    String productId,
    String tenantId,
    String branchId,
  ) {
    return {
      'id': batch.id,
      'product_id': productId,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'batch_number': batch.batchNumber,
      'mfg_date': batch.mfgDate.toIso8601String(),
      // expDate is the DateTime; batch.expiryDate is a display string (MM/YYYY)
      // and would be rejected by a DATE column.
      'exp_date': batch.expDate.toIso8601String(),
      'purchase_price': batch.purchasePrice,
      'ptr_price': batch.ptrPrice,
      'mrp': batch.mrp,
      'selling_price': batch.mrp, // Default selling price to MRP
      'wholesale_price': batch.wholesalePrice,
      'stock_quantity': batch.stockCount,
      'rack_location': batch.rackLocation,
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }
}
