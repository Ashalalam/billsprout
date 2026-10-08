import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ledger_entry_model.dart';
import '../models/invoice_model.dart';
import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/selling_unit_model.dart';
import '../services/supabase_service.dart';

// ── Credit / Debit Note model ──────────────────────────────────────────────
class CreditDebitNote {
  final String id;
  final String noteNumber;
  final DateTime date;
  final String type; // 'credit' | 'debit'
  final String reason;
  final String referenceInvoice;
  final double amount;

  CreditDebitNote({
    required this.id,
    required this.noteNumber,
    required this.date,
    required this.type,
    required this.reason,
    required this.referenceInvoice,
    required this.amount,
  });
}

class AccountingProvider extends ChangeNotifier {
  final List<LedgerEntryModel> _ledgerEntries = [];
  final List<InvoiceModel> _salesInvoices = [];
  final List<CreditDebitNote> _cdNotes = [];
  
  String? _tenantId; // Track tenant context for validation
  String? _branchId; // Track branch context for sales

  List<LedgerEntryModel> get ledgerEntries => List.unmodifiable(_ledgerEntries);
  List<InvoiceModel> get salesInvoices => List.unmodifiable(_salesInvoices);
  List<CreditDebitNote> get creditDebitNotes => List.unmodifiable(_cdNotes);

  AccountingProvider() {
    _seedSampleLedger();
    // Note: _loadSalesFromDatabase() will be called by setTenantContext() 
    // when AccountingProvider is created via ChangeNotifierProxyProvider.
    // Don't load here to avoid loading before tenant context is set.
  }
  
  /// Set tenant context for validation
  void setTenantContext(String? tenantId, String? branchId) {
    debugPrint('[Accounting] Setting tenant context: tenant=$tenantId, branch=$branchId');
    
    if (_tenantId != tenantId || _branchId != branchId) {
      _tenantId = tenantId;
      _branchId = branchId;
      
      // Clear ALL data when tenant context changes
      _salesInvoices.clear();
      _ledgerEntries.clear();
      _cdNotes.clear();
      
      // Re-seed ledger and load fresh sales from database
      _seedSampleLedger();
      _loadSalesFromDatabase();
      
      debugPrint('[Accounting] ✅ Tenant context updated, data cleared and reloaded');
    }
  }

  // ── Load sales from database ──────────────────────────────────────────────
  Future<void> _loadSalesFromDatabase() async {
    // Don't load if no tenant context
    if (_tenantId == null) {
      debugPrint('⚠️ [Accounting] Cannot load sales: no tenant context');
      return;
    }
    
    try {
      final supabase = Supabase.instance.client;
      
      debugPrint('🔄 [Accounting] Loading sales from database for tenant: $_tenantId');
      
      // Load from 'sales' table with tenant filter
      // Select ALL fields needed for proper dashboard display
      final response = await supabase
          .from('sales')
          .select('''
            id,
            invoice_number,
            invoice_date,
            customer_name,
            customer_phone,
            customer_gstin,
            billing_type,
            doctor_name,
            doctor_mci_no,
            subtotal,
            item_discount_total,
            invoice_discount,
            taxable_amount,
            cgst_amount,
            sgst_amount,
            igst_amount,
            total_gst,
            round_off,
            grand_total,
            payment_mode,
            payment_status,
            is_synced,
            created_at,
            sale_items(
              id,
              product_name,
              batch_number,
              quantity,
              free_quantity,
              unit_price,
              mrp,
              line_discount,
              gst_percent,
              cgst_amount,
              sgst_amount,
              igst_amount,
              line_total
            )
          ''')
          .eq('tenant_id', _tenantId!)
          .order('invoice_date', ascending: false)
          .limit(100);
      
      // Convert to full InvoiceModel objects with complete data
      final invoices = (response as List).map<InvoiceModel>((row) {
        // Parse sale items
        final saleItemsData = row['sale_items'] as List? ?? [];
        final items = saleItemsData.map<InvoiceItem>((itemRow) {
          // Create minimal product and batch for display
          final product = ProductModel(
            id: 'prod_loaded',
            name: itemRow['product_name'] ?? 'Unknown Product',
            genericSalt: '',
            barcode: '',
            hsnCode: '',
            taxPercent: (itemRow['gst_percent'] as num?)?.toDouble() ?? 0.0,
            manufacturer: '',
            batches: [],
          );
          
          final batch = BatchModel(
            id: 'batch_loaded',
            batchNumber: itemRow['batch_number'] ?? '',
            mfgDate: DateTime.now().subtract(const Duration(days: 365)),
            expDate: DateTime.now().add(const Duration(days: 365)),
            mrp: (itemRow['mrp'] as num?)?.toDouble() ?? 0.0,
            purchasePrice: 0.0,
            wholesalePrice: 0.0,
            ptrPrice: 0.0,
            sellingPrice: (itemRow['mrp'] as num?)?.toDouble() ?? 0.0, // ✅ FIXED: Add sellingPrice for loaded batch
            stockCount: 0,
            rackLocation: '',
          );
          
          return InvoiceItem(
            product: product,
            batch: batch,
            quantity: (itemRow['quantity'] as int?) ?? 0,
            freeQuantity: (itemRow['free_quantity'] as int?) ?? 0,
            looseUnits: 0,
            freeLooseUnits: 0,
            unitPrice: (itemRow['unit_price'] as num?)?.toDouble() ?? 0.0,
            lineDiscount: (itemRow['line_discount'] as num?)?.toDouble() ?? 0.0,
            taxPercent: (itemRow['gst_percent'] as num?)?.toDouble() ?? 0.0,
            sellingUnit: SellingUnit.pack,
          );
        }).toList();
        
        return InvoiceModel(
          id: row['id'] ?? '',
          invoiceNumber: row['invoice_number'] ?? '',
          timestamp: DateTime.parse(row['invoice_date'] ?? DateTime.now().toIso8601String()),
          items: items,
          customerName: row['customer_name'] ?? 'Walk-in Customer',
          customerPhone: row['customer_phone'] ?? '',
          customerGstin: row['customer_gstin'] as String?,
          doctorName: row['doctor_name'] as String?,
          doctorMciNo: row['doctor_mci_no'] as String?,
          paymentMode: _parsePaymentMode(row['payment_mode']),
          isSynced: (row['is_synced'] as bool?) ?? true,
          branch: 'Main Store', // Default branch
          billingType: row['billing_type'] ?? 'retail',
          discountAmount: (row['invoice_discount'] as num?)?.toDouble() ?? 0.0,
        );
      }).toList();
      
      // CRITICAL FIX: Clear before adding to avoid duplicates
      _salesInvoices.clear();
      _salesInvoices.addAll(invoices);
      notifyListeners();
      debugPrint('✅ [Accounting] Loaded ${invoices.length} invoices with ${invoices.fold(0, (sum, inv) => sum + inv.items.length)} items from database');
    } catch (e, stackTrace) {
      debugPrint('❌ [Accounting] Error loading sales from database: $e');
      debugPrint('Stack trace: $stackTrace');
      // Non-fatal - app can continue with empty dashboard
    }
  }

  PaymentMode _parsePaymentMode(String? mode) {
    if (mode == null) return PaymentMode.cash;
    switch (mode.toLowerCase()) {
      case 'cash':
        return PaymentMode.cash;
      case 'card':
        return PaymentMode.card;
      case 'upi':
        return PaymentMode.upi;
      case 'razorpay':
        return PaymentMode.razorpay;
      case 'split':
        return PaymentMode.split;
      case 'credit':
        return PaymentMode.credit;
      default:
        return PaymentMode.cash;
    }
  }

  // Method to manually add invoices from sync service
  void loadInvoicesFromCache(List<InvoiceModel> invoices) {
    // CRITICAL FIX: Don't load cached invoices if we have tenant context
    // because _loadSalesFromDatabase() will load fresh data from Supabase.
    // Cached invoices often have empty items causing grandTotal to be 0.
    if (_tenantId != null) {
      debugPrint('[Accounting] ⚠️ Ignoring ${invoices.length} cached invoices - will load from database instead');
      return;
    }
    
    // Only load cached invoices in offline/demo mode (no tenant context)
    _salesInvoices.clear();
    _salesInvoices.addAll(invoices);
    notifyListeners();
    debugPrint('[Accounting] Loaded ${_salesInvoices.length} invoices from offline cache');
  }

  // Method to refresh data manually
  Future<void> refreshSalesData() async {
    // Don't refresh if no tenant context
    if (_tenantId == null) {
      debugPrint('⚠️ [Accounting] Cannot refresh sales: no tenant context');
      return;
    }
    
    debugPrint('🔄 [Accounting] Refreshing sales data for tenant: $_tenantId');
    
    // Clear and reload from database for a fresh view
    _salesInvoices.clear();
    await _loadSalesFromDatabase();
    
    debugPrint('✅ [Accounting] Refresh complete: ${_salesInvoices.length} total invoices');
  }

  // ── Invoice sale ──────────────────────────────────────────────────────────
  void recordInvoiceSale(InvoiceModel invoice) {
    _salesInvoices.add(invoice);
    _ledgerEntries.add(
      LedgerEntryModel(
        id: 'led_${DateTime.now().millisecondsSinceEpoch}_1',
        date: invoice.timestamp,
        accountName: 'Sales Income Account',
        description: 'POS Sale Invoice #${invoice.invoiceNumber}',
        amount: invoice.grandTotal,
        type: LedgerType.credit,
        referenceId: invoice.id,
      ),
    );
    _ledgerEntries.add(
      LedgerEntryModel(
        id: 'led_${DateTime.now().millisecondsSinceEpoch}_2',
        date: invoice.timestamp,
        accountName: 'Output GST Payable Account',
        description: 'GST Collected on Invoice #${invoice.invoiceNumber}',
        amount: invoice.totalTax,
        type: LedgerType.credit,
        referenceId: invoice.id,
      ),
    );
    notifyListeners();
    
    // Sync to Supabase (fire-and-forget but with error logging)
    // We don't await here to avoid blocking the UI, but errors are logged
    _syncSaleToSupabase(invoice).catchError((error, stackTrace) {
      debugPrint('❌ [Accounting] CRITICAL: Sale sync failed for ${invoice.invoiceNumber}');
      debugPrint('Error: $error');
      debugPrint('Stack trace: $stackTrace');
      // TODO: Queue for retry or show user notification
    });
  }
  
  /// Sync a sale to Supabase
  Future<void> _syncSaleToSupabase(InvoiceModel invoice) async {
    if (_tenantId == null || _branchId == null) {
      debugPrint('❌ [Accounting] Cannot sync sale: missing tenant/branch context (tenant: $_tenantId, branch: $_branchId)');
      return;
    }
    
    // Get current user ID from Supabase auth
    final currentUser = SupabaseService().currentUser;
    if (currentUser == null) {
      debugPrint('❌ [Accounting] Cannot sync sale: no authenticated user');
      return;
    }
    
    try {
      debugPrint('🔄 [Accounting] Starting sync for invoice ${invoice.invoiceNumber} (tenant: $_tenantId, branch: $_branchId, user: ${currentUser.id})');
      
      final saleRow = {
        'id': invoice.id,
        'tenant_id': _tenantId,
        'branch_id': _branchId,
        'invoice_number': invoice.invoiceNumber,
        'invoice_date': invoice.timestamp.toIso8601String(),
        'customer_name': invoice.customerName,
        'customer_phone': invoice.customerPhone,
        'customer_gstin': invoice.customerGstin,
        'billing_type': invoice.billingType,
        'doctor_name': invoice.doctorName,
        'doctor_mci_no': invoice.doctorMciNo,
        'prescription_id': null, // Not available in InvoiceModel
        'subtotal': invoice.subtotal,
        'item_discount_total': invoice.totalLineDiscounts,
        'invoice_discount': invoice.effectiveDiscount,
        'taxable_amount': invoice.subtotal - invoice.totalTax,
        'cgst_amount': invoice.totalTax / 2, // Split tax equally between CGST and SGST
        'sgst_amount': invoice.totalTax / 2,
        'igst_amount': 0.0,
        'total_gst': invoice.totalTax,
        'round_off': invoice.roundOff,
        'grand_total': invoice.grandTotal,
        'payment_mode': invoice.paymentMode.name,
        'payment_status': 'paid',
        'pharmacist_authorized_by': invoice.authorizedPharmacistId,
        'is_synced': invoice.isSynced,
        'created_by': currentUser.id, // ✅ FIXED: Required field was missing
        'created_at': invoice.timestamp.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      debugPrint('📝 [Accounting] Upserting sale row to database...');
      await SupabaseService().upsertSale(saleRow);
      debugPrint('✅ [Accounting] Sale row upserted successfully');
      
      // Sync sale items
      debugPrint('📦 [Accounting] Syncing ${invoice.items.length} sale items...');
      for (final item in invoice.items) {
        await _syncSaleItemToSupabase(invoice.id, item);
      }
      
      debugPrint('✅ [Accounting] Sale synced to Supabase: ${invoice.invoiceNumber}');
    } catch (e, stackTrace) {
      debugPrint('❌ [Accounting] Sale sync error: $e');
      debugPrint('Stack trace: $stackTrace');
    }
  }
  
  /// Sync a sale item to Supabase
  Future<void> _syncSaleItemToSupabase(String saleId, InvoiceItem item) async {
    try {
      final itemRow = {
        'id': 'si_${DateTime.now().millisecondsSinceEpoch}_${item.product.id.substring(0, 8)}',
        'sale_id': saleId,
        'product_id': item.product.id,
        'batch_id': item.batch.id,
        'product_name': item.product.name,
        'hsn_code': item.product.hsnCode,
        'batch_number': item.batch.batchNumber,
        'expiry_date': item.batch.expDate.toIso8601String().split('T')[0], // DATE format, not timestamp
        'quantity': item.quantity,
        'free_quantity': item.freeQuantity,
        'unit_price': item.unitPrice,
        'ptr_price': item.batch.ptrPrice, // ✅ Added PTR price from batch
        'mrp': item.batch.mrp,
        'line_discount': item.lineDiscount, // ✅ FIXED: was discount_percent
        'taxable_value': item.taxableValue, // ✅ FIXED: was missing
        'gst_percent': item.taxPercent, // ✅ FIXED: Full GST percent
        'cgst_amount': item.cgst,
        'sgst_amount': item.sgst,
        'igst_amount': 0.0,
        'line_total': item.lineTotal, // ✅ FIXED: was total_amount
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await SupabaseService().upsertSaleItem(itemRow);
      debugPrint('  ✅ [Accounting] Sale item synced: ${item.product.name}');
    } catch (e, stackTrace) {
      debugPrint('  ❌ [Accounting] Sale item sync error: $e');
      debugPrint('  Stack trace: $stackTrace');
    }
  }

  String generateGstr1Json() {
    final Map<String, dynamic> gstr1Data = {
      'gstin': '07AAAAA0000A1Z5',
      'fp': '${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().year}',
      'version': 'GST3.0.4',
      'hash': 'hash',
      'b2c': _salesInvoices.map((inv) {
        return {
          'inum': inv.invoiceNumber,
          'idt': inv.timestamp.toIso8601String().substring(0, 10),
          'val': inv.grandTotal,
          'tax': inv.totalTax,
          'pos': '07',
          'typ': 'OE',
          'itms': inv.items.map((it) => {
                'hsn': it.product.hsnCode,
                'txval': it.taxableValue,
                'rt': it.taxPercent,
                'iamt': it.taxAmount,
                'camt': it.taxAmount / 2,
                'samt': it.taxAmount / 2,
                'csamt': 0,
              }).toList(),
        };
      }).toList(),
    };
    // Use proper JSON encoding — NOT .toString()
    return const JsonEncoder.withIndent('  ').convert(gstr1Data);
  }

  // ── Credit / Debit Notes ──────────────────────────────────────────────────
  void addCreditNote({
    required String reason,
    required String referenceInvoice,
    required double amount,
  }) {
    final note = CreditDebitNote(
      id: 'cdn_${DateTime.now().millisecondsSinceEpoch}',
      noteNumber:
          'CN-${DateTime.now().year}-${(_cdNotes.length + 1).toString().padLeft(4, '0')}',
      date: DateTime.now(),
      type: 'credit',
      reason: reason,
      referenceInvoice: referenceInvoice,
      amount: amount,
    );
    _cdNotes.add(note);
    // Post reversal ledger entry
    _ledgerEntries.add(LedgerEntryModel(
      id: 'led_cn_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      accountName: 'Sales Returns Account',
      description: 'Credit Note ${note.noteNumber} — $reason',
      amount: amount,
      type: LedgerType.debit,
      referenceId: referenceInvoice,
    ));
    notifyListeners();
  }

  void addDebitNote({
    required String reason,
    required String referenceInvoice,
    required double amount,
  }) {
    final note = CreditDebitNote(
      id: 'dbn_${DateTime.now().millisecondsSinceEpoch}',
      noteNumber:
          'DN-${DateTime.now().year}-${(_cdNotes.length + 1).toString().padLeft(4, '0')}',
      date: DateTime.now(),
      type: 'debit',
      reason: reason,
      referenceInvoice: referenceInvoice,
      amount: amount,
    );
    _cdNotes.add(note);
    // Post debit note ledger entry
    _ledgerEntries.add(LedgerEntryModel(
      id: 'led_dn_${DateTime.now().millisecondsSinceEpoch}',
      date: DateTime.now(),
      accountName: 'Purchase Adjustments Account',
      description: 'Debit Note ${note.noteNumber} — $reason',
      amount: amount,
      type: LedgerType.credit,
      referenceId: referenceInvoice,
    ));
    notifyListeners();
  }

  void _seedSampleLedger() {
    _ledgerEntries.addAll([
      LedgerEntryModel(
        id: 'led_1',
        date: DateTime.now().subtract(const Duration(days: 2)),
        accountName: 'Inventory Purchase Account',
        description: 'Purchase Batch AMX-2024-09 from Lifesprout Labs',
        amount: 11250.0,
        type: LedgerType.debit,
        referenceId: 'PO-9912',
      ),
      LedgerEntryModel(
        id: 'led_2',
        date: DateTime.now().subtract(const Duration(days: 1)),
        accountName: 'Sales Income Account',
        description: 'POS Walk-in Pharmacy Sale',
        amount: 4500.0,
        type: LedgerType.credit,
        referenceId: 'INV-10022',
      ),
    ]);
  }
}
