import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ledger_entry_model.dart';
import '../models/invoice_model.dart';
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
    _loadSalesFromDatabase();
  }
  
  /// Set tenant context for validation
  void setTenantContext(String? tenantId, String? branchId) {
    if (_tenantId != tenantId || _branchId != branchId) {
      _tenantId = tenantId;
      _branchId = branchId;
      // Clear data when tenant context changes
      _salesInvoices.clear();
      _loadSalesFromDatabase();
    }
  }

  // ── Load sales from database ──────────────────────────────────────────────
  Future<void> _loadSalesFromDatabase() async {
    // Don't load if no tenant context
    if (_tenantId == null) {
      debugPrint('⚠️ Cannot load sales: no tenant context');
      return;
    }
    
    try {
      final supabase = Supabase.instance.client;
      
      // Load from 'sales' table with tenant filter
      final response = await supabase
          .from('sales')
          .select('id, invoice_number, invoice_date, customer_name, customer_phone, payment_mode, grand_total')
          .eq('tenant_id', _tenantId!)
          .order('invoice_date', ascending: false)
          .limit(100);
      
      // Convert to simple invoices for dashboard display
      final invoices = (response as List).map<InvoiceModel>((row) {
        return InvoiceModel(
          id: row['id'] ?? '',
          invoiceNumber: row['invoice_number'] ?? '',
          timestamp: DateTime.parse(row['invoice_date'] ?? DateTime.now().toIso8601String()),
          items: [], // Empty - dashboard only needs totals
          customerName: row['customer_name'] ?? 'Walk-in Customer',
          customerPhone: row['customer_phone'] ?? '',
          paymentMode: _parsePaymentMode(row['payment_mode']),
          discountAmount: 0.0, // Not in database, use default
        );
      }).toList();
      
      _salesInvoices.addAll(invoices);
      notifyListeners();
      debugPrint('✅ Loaded ${invoices.length} invoices from database for tenant $_tenantId');
    } catch (e) {
      debugPrint('⚠️ Error loading sales from database: $e');
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
      case 'paypal':
        return PaymentMode.paypal;
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
    _salesInvoices.clear();
    _salesInvoices.addAll(invoices);
    notifyListeners();
    debugPrint('Loaded ${_salesInvoices.length} invoices into accounting provider');
  }

  // Method to refresh data manually
  Future<void> refreshSalesData() async {
    // Don't refresh if no tenant context
    if (_tenantId == null) {
      debugPrint('⚠️ Cannot refresh sales: no tenant context');
      return;
    }
    
    // Don't clear existing invoices - just reload from database and merge
    try {
      final supabase = Supabase.instance.client;
      
      // Load from 'sales' table with tenant filter
      final response = await supabase
          .from('sales')
          .select('id, invoice_number, invoice_date, customer_name, customer_phone, payment_mode, grand_total')
          .eq('tenant_id', _tenantId!)
          .order('invoice_date', ascending: false)
          .limit(100);
      
      // Convert to invoices
      final dbInvoices = (response as List).map<InvoiceModel>((row) {
        return InvoiceModel(
          id: row['id'] ?? '',
          invoiceNumber: row['invoice_number'] ?? '',
          timestamp: DateTime.parse(row['invoice_date'] ?? DateTime.now().toIso8601String()),
          items: [],
          customerName: row['customer_name'] ?? 'Walk-in Customer',
          customerPhone: row['customer_phone'] ?? '',
          paymentMode: _parsePaymentMode(row['payment_mode']),
          discountAmount: 0.0,
        );
      }).toList();
      
      // Merge: Keep existing in-memory invoices, add database ones that aren't already there
      final existingIds = _salesInvoices.map((inv) => inv.id).toSet();
      for (final dbInv in dbInvoices) {
        if (!existingIds.contains(dbInv.id)) {
          _salesInvoices.add(dbInv);
        }
      }
      
      notifyListeners();
      debugPrint('✅ Refreshed dashboard: ${_salesInvoices.length} total invoices (${dbInvoices.length} from database)');
    } catch (e) {
      debugPrint('⚠️ Error refreshing sales data: $e');
      // Keep existing in-memory data even if database load fails
    }
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
    
    // Sync to Supabase in background
    _syncSaleToSupabase(invoice);
  }
  
  /// Sync a sale to Supabase
  Future<void> _syncSaleToSupabase(InvoiceModel invoice) async {
    if (_tenantId == null || _branchId == null) {
      debugPrint('[Accounting] Cannot sync sale: missing tenant/branch context');
      return;
    }
    
    try {
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
        'cgst_amount': invoice.totalTax / 2, // Split tax equally between CGST and SGST
        'sgst_amount': invoice.totalTax / 2,
        'igst_amount': 0.0,
        'total_gst': invoice.totalTax,
        'round_off': invoice.roundOff,
        'grand_total': invoice.grandTotal,
        'payment_mode': invoice.paymentMode.name,
        'payment_status': 'completed',
        'pharmacist_authorized_by': invoice.pharmacistPinApprovedBy,
        'authorized_pharmacist_id': invoice.authorizedPharmacistId,
        'is_synced': invoice.isSynced,
        'created_at': invoice.timestamp.toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      await SupabaseService().upsertSale(saleRow);
      
      // Sync sale items
      for (final item in invoice.items) {
        await _syncSaleItemToSupabase(invoice.id, item);
      }
      
      debugPrint('[Accounting] Sale synced to Supabase: ${invoice.invoiceNumber}');
    } catch (e) {
      debugPrint('[Accounting] Sale sync error: $e');
    }
  }
  
  /// Sync a sale item to Supabase
  Future<void> _syncSaleItemToSupabase(String saleId, InvoiceItem item) async {
    if (_tenantId == null) {
      debugPrint('[Accounting] Cannot sync sale item: missing tenant context');
      return;
    }
    
    try {
      final itemRow = {
        'id': 'si_${DateTime.now().millisecondsSinceEpoch}_${item.product.id.substring(0, 8)}',
        'sale_id': saleId,
        'tenant_id': _tenantId,
        'product_id': item.product.id,
        'batch_id': item.batch.id,
        'product_name': item.product.name,
        'batch_number': item.batch.batchNumber,
        'quantity': item.quantity,
        'free_quantity': item.freeQuantity,
        'unit_price': item.unitPrice,
        'mrp': item.batch.mrp,
        'discount_percent': item.discountPercent,
        'cgst_percent': item.taxPercent / 2,
        'sgst_percent': item.taxPercent / 2,
        'igst_percent': 0.0,
        'cgst_amount': item.cgst,
        'sgst_amount': item.sgst,
        'igst_amount': 0.0,
        'total_amount': item.lineTotal,
        'exp_date': item.batch.expDate.toIso8601String(),
        'hsn_code': item.product.hsnCode,
        'created_at': DateTime.now().toIso8601String(),
      };
      
      await SupabaseService().upsertSaleItem(itemRow);
      debugPrint('[Accounting] Sale item synced: ${item.product.name}');
    } catch (e) {
      debugPrint('[Accounting] Sale item sync error: $e');
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
