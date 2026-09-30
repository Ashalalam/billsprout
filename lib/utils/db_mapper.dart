import '../models/invoice_model.dart';

/// Utility class for mapping between Dart models (camelCase) and PostgreSQL tables (snake_case).
/// Handles conversion between application layer and database layer.
class DbMapper {
  /// Rounds to 2 decimal places (paisa). Money columns are DECIMAL(15,2), so
  /// anything finer is truncated by the database anyway; rounding here keeps the
  /// values the app displays identical to the values it stores.
  static double _round2(double v) => (v * 100).roundToDouble() / 100;

  // ── Invoice / Sales Mapping ──────────────────────────────────────────────

  /// Convert InvoiceModel to database row for 'sales' table
  static Map<String, dynamic> invoiceToSalesRow(
    InvoiceModel invoice, {
    required String tenantId,
    required String branchId,
    required String createdBy,
  }) {
    // Calculate totals
    final subtotal = invoice.items.fold<double>(0, (s, i) => s + i.grossLineTotal);
    final itemDiscountTotal = invoice.items.fold<double>(0, (s, i) => s + i.lineDiscount);
    // Round each GST half to paisa first, then derive the total from the rounded
    // halves. Summing unrounded values and rounding separately can leave the
    // invoice showing CGST + SGST that differs from the stated total by a paisa,
    // which makes the document fail reconciliation.
    final cgstAmount = _round2(invoice.items.fold<double>(0, (s, i) => s + i.cgst));
    final sgstAmount = _round2(invoice.items.fold<double>(0, (s, i) => s + i.sgst));
    final totalGst = _round2(cgstAmount + sgstAmount);

    // GST here is inclusive, so the taxable value is the payable minus the tax.
    // Deriving it from the already-rounded GST total guarantees
    // taxable_amount + total_gst == grand_total on the printed invoice.
    final grandTotal = _round2(invoice.grandTotal);
    final taxableAmount = _round2(grandTotal - totalGst);

    return {
      'id': invoice.id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'invoice_number': invoice.invoiceNumber,
      'invoice_date': invoice.timestamp.toIso8601String(),
      'customer_name': invoice.customerName,
      'customer_phone': invoice.customerPhone,
      'customer_gstin': invoice.customerGstin,
      'billing_type': invoice.billingType,
      'doctor_name': invoice.doctorName,
      'doctor_mci_no': invoice.doctorMciNo,
      'subtotal': _round2(subtotal),
      'item_discount_total': _round2(itemDiscountTotal),
      // Clamped value, so an over-entered discount cannot persist a negative
      // payable that disagrees with grand_total.
      'invoice_discount': _round2(invoice.effectiveDiscount),
      'taxable_amount': taxableAmount,
      'cgst_amount': cgstAmount,
      'sgst_amount': sgstAmount,
      'igst_amount': 0.0, // Currently only handling CGST+SGST
      'total_gst': totalGst,
      'round_off': 0.0,
      'grand_total': grandTotal,
      'payment_mode': invoice.paymentMode.name,
      'payment_status': 'paid',
      // pharmacist_authorized_by is UUID REFERENCES users(id); the human label
      // goes in pharmacist_authorized_name and the pharmacist row in
      // authorized_pharmacist_id (see migration 010). Writing the label into the
      // UUID column is a type error that fails every authorised sale.
      'authorized_pharmacist_id': invoice.authorizedPharmacistId,
      'pharmacist_authorized_name': invoice.pharmacistPinApprovedBy,
      'is_synced': invoice.isSynced,
      'created_by': createdBy,
      'created_at': invoice.timestamp.toIso8601String(),
      'updated_at': invoice.timestamp.toIso8601String(),
    };
  }

  /// Convert InvoiceItem to database row for 'sale_items' table.
  ///
  /// [tenantId] is required because migration 007 makes sale_items.tenant_id
  /// NOT NULL and the RLS policy is keyed on it; a row without it is rejected.
  static Map<String, dynamic> invoiceItemToSaleItemRow(
    String saleId,
    InvoiceItem item, {
    required String tenantId,
  }) {
    return {
      'id': '${saleId}_${item.product.id}_${item.batch.id}',
      'sale_id': saleId,
      'tenant_id': tenantId,
      'product_id': item.product.id,
      'batch_id': item.batch.id,
      'product_name': item.product.name,
      'hsn_code': item.product.hsnCode,
      'batch_number': item.batch.batchNumber,
      // expDate is the DateTime; batch.expiryDate is a display string (MM/YYYY)
      // and has no toIso8601String, so it cannot be used for the date column.
      'expiry_date': item.batch.expDate.toIso8601String(),
      'quantity': item.quantity,
      'free_quantity': item.freeQuantity,
      'unit_price': item.unitPrice,
      'ptr_price': item.batch.ptrPrice,
      'mrp': item.batch.mrp,
      'line_discount': item.lineDiscount,
      'taxable_value': item.taxableValue,
      'gst_percent': item.taxPercent,
      'cgst_amount': item.cgst,
      'sgst_amount': item.sgst,
      'igst_amount': 0.0,
      'line_total': item.lineTotal,
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Convert database sales row back to InvoiceModel (for fetching)
  static InvoiceModel salesRowToInvoice(
    Map<String, dynamic> row,
    List<Map<String, dynamic>> itemRows,
  ) {
    // This would need the full implementation when fetching invoices
    // For now, we'll use the existing fromJson which expects camelCase
    throw UnimplementedError('Fetching from database not yet implemented');
  }

  // ── Field Name Conversion Helpers ────────────────────────────────────────

  /// Convert camelCase to snake_case
  static String toSnakeCase(String camelCase) {
    return camelCase.replaceAllMapped(
      RegExp(r'[A-Z]'),
      (match) => '_${match.group(0)!.toLowerCase()}',
    );
  }

  /// Convert snake_case to camelCase
  static String toCamelCase(String snakeCase) {
    return snakeCase.replaceAllMapped(
      RegExp(r'_([a-z])'),
      (match) => match.group(1)!.toUpperCase(),
    );
  }

  /// Convert entire map from camelCase to snake_case
  static Map<String, dynamic> toSnakeCaseMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(toSnakeCase(key), value));
  }

  /// Convert entire map from snake_case to camelCase
  static Map<String, dynamic> toCamelCaseMap(Map<String, dynamic> map) {
    return map.map((key, value) => MapEntry(toCamelCase(key), value));
  }
}
