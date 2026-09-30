import 'package:flutter_test/flutter_test.dart';
import 'package:billsprout/models/batch_model.dart';
import 'package:billsprout/models/invoice_model.dart';
import 'package:billsprout/models/product_model.dart';
import 'package:billsprout/utils/db_mapper.dart';

BatchModel _batch({
  String id = 'b1',
  double mrp = 100,
  double ptr = 80,
  double wholesale = 85,
  int stock = 50,
}) =>
    BatchModel(
      id: id,
      batchNumber: 'BN-$id',
      mfgDate: DateTime(2024, 1, 1),
      expDate: DateTime(2027, 1, 1),
      mrp: mrp,
      purchasePrice: 70,
      wholesalePrice: wholesale,
      ptrPrice: ptr,
      stockCount: stock,
      rackLocation: 'A1',
    );

ProductModel _product({
  String id = 'p1',
  double tax = 12,
  List<BatchModel>? batches,
}) =>
    ProductModel(
      id: id,
      name: 'Paracetamol 500',
      genericSalt: 'Paracetamol',
      barcode: '890000000001',
      hsnCode: '30049099',
      taxPercent: tax,
      manufacturer: 'Acme Pharma',
      batches: batches ?? [_batch()],
    );

InvoiceItem _item({
  int qty = 2,
  int free = 0,
  double unitPrice = 100,
  double tax = 12,
  double lineDiscount = 0,
}) {
  final batch = _batch();
  return InvoiceItem(
    product: _product(tax: tax, batches: [batch]),
    batch: batch,
    quantity: qty,
    freeQuantity: free,
    unitPrice: unitPrice,
    taxPercent: tax,
    lineDiscount: lineDiscount,
  );
}

InvoiceModel _invoice({
  required List<InvoiceItem> items,
  double discount = 0,
  String billingType = 'retail',
  String? gstin,
}) =>
    InvoiceModel(
      id: 'inv1',
      invoiceNumber: 'INV-1',
      timestamp: DateTime(2025, 6, 1, 10, 30),
      customerName: 'Test Customer',
      customerPhone: '9999999999',
      items: items,
      discountAmount: discount,
      paymentMode: PaymentMode.cash,
      billingType: billingType,
      customerGstin: gstin,
    );

void main() {
  group('InvoiceItem', () {
    test('free quantity is not charged', () {
      final item = _item(qty: 3, free: 1, unitPrice: 100);
      expect(item.grossLineTotal, 300);
      expect(item.billedQuantity, 3);
    });

    test('line discount reduces the line total', () {
      final item = _item(qty: 2, unitPrice: 100, lineDiscount: 50);
      expect(item.lineTotal, 150);
    });

    test('tax is extracted from the inclusive line total', () {
      final item = _item(qty: 1, unitPrice: 112, tax: 12);
      // 112 inclusive of 12% = 100 taxable + 12 tax
      expect(item.taxAmount, closeTo(12, 0.01));
      expect(item.taxableValue, closeTo(100, 0.01));
      expect(item.cgst + item.sgst, closeTo(item.taxAmount, 0.0001));
    });

    test('quantityDisplay shows free units', () {
      expect(_item(qty: 3, free: 1).quantityDisplay, '3 + 1 Free');
      expect(_item(qty: 3).quantityDisplay, '3');
    });
  });

  group('InvoiceModel discount', () {
    test('grand total subtracts the invoice discount', () {
      final inv = _invoice(items: [_item(qty: 2, unitPrice: 100)], discount: 50);
      expect(inv.subtotal, 200);
      expect(inv.grandTotal, 150);
    });

    test('discount larger than the subtotal is clamped, never negative', () {
      final inv =
          _invoice(items: [_item(qty: 1, unitPrice: 100)], discount: 500);
      expect(inv.effectiveDiscount, 100);
      expect(inv.grandTotal, 0);
    });

    test('zero discount leaves the subtotal intact', () {
      final inv = _invoice(items: [_item(qty: 2, unitPrice: 100)]);
      expect(inv.grandTotal, inv.subtotal);
    });

    test('line and invoice discounts both apply', () {
      final inv = _invoice(
        items: [_item(qty: 2, unitPrice: 100, lineDiscount: 20)],
        discount: 30,
      );
      expect(inv.subtotal, 180);
      expect(inv.totalLineDiscounts, 20);
      expect(inv.grandTotal, 150);
    });
  });

  group('DbMapper sales row', () {
    test('persists the clamped discount and the grand total agrees', () {
      final inv =
          _invoice(items: [_item(qty: 1, unitPrice: 100)], discount: 500);
      final row = DbMapper.invoiceToSalesRow(
        inv,
        tenantId: 't1',
        branchId: 'br1',
        createdBy: 'u1',
      );

      expect(row['invoice_discount'], 100);
      expect(row['grand_total'], 0);
      expect(row['tenant_id'], 't1');
      expect(row['branch_id'], 'br1');
    });

    test('carries billing type and customer gstin', () {
      final inv = _invoice(
        items: [_item()],
        billingType: 'wholesale',
        gstin: '07ABCDE1234F1Z5',
      );
      final row = DbMapper.invoiceToSalesRow(
        inv,
        tenantId: 't1',
        branchId: 'br1',
        createdBy: 'u1',
      );

      expect(row['billing_type'], 'wholesale');
      expect(row['customer_gstin'], '07ABCDE1234F1Z5');
      expect(inv.isWholesale, isTrue);
    });

    test('defaults to retail billing with no gstin', () {
      final row = DbMapper.invoiceToSalesRow(
        _invoice(items: [_item()]),
        tenantId: 't1',
        branchId: 'br1',
        createdBy: 'u1',
      );
      expect(row['billing_type'], 'retail');
      expect(row['customer_gstin'], isNull);
    });

    test('sale item row carries tenant id and hsn code', () {
      final item = _item();
      final row = DbMapper.invoiceItemToSaleItemRow(
        'inv1',
        item,
        tenantId: 't1',
      );

      expect(row['tenant_id'], 't1');
      expect(row['hsn_code'], '30049099');
      expect(row['free_quantity'], item.freeQuantity);
      // Must be a parseable timestamp, not the MM/YYYY display string.
      expect(DateTime.parse(row['expiry_date'] as String), item.batch.expDate);
    });
  });

  group('InvoiceModel round trip', () {
    test('json round trip preserves billing fields', () {
      final original = _invoice(
        items: [_item(qty: 2, free: 1, unitPrice: 90)],
        discount: 25,
        billingType: 'wholesale',
        gstin: '07ABCDE1234F1Z5',
      );

      final restored = InvoiceModel.fromJson(original.toJson());

      expect(restored.billingType, 'wholesale');
      expect(restored.customerGstin, '07ABCDE1234F1Z5');
      expect(restored.discountAmount, 25);
      expect(restored.items.single.freeQuantity, 1);
      expect(restored.grandTotal, original.grandTotal);
    });
  });

  group('Round off and amount in words', () {
    test('round off settles to the nearest rupee', () {
      // 3 x 33.33 = 99.99 -> payable 100.00, round off +0.01
      final inv = _invoice(items: [_item(qty: 3, unitPrice: 33.33)]);
      expect(inv.grandTotal, closeTo(99.99, 0.001));
      expect(inv.payableTotal, 100.0);
      expect(inv.roundOff, closeTo(0.01, 0.001));
    });

    test('round off is zero on an exact amount', () {
      final inv = _invoice(items: [_item(qty: 2, unitPrice: 50)]);
      expect(inv.payableTotal, 100.0);
      expect(inv.roundOff, 0.0);
    });

    test('round off can be negative when rounding down', () {
      // 1 x 100.40 -> payable 100, round off -0.40
      final inv = _invoice(items: [_item(qty: 1, unitPrice: 100.40)]);
      expect(inv.payableTotal, 100.0);
      expect(inv.roundOff, closeTo(-0.40, 0.001));
    });

    test('amount in words uses Indian numbering', () {
      String words(double unit, int qty) =>
          _invoice(items: [_item(qty: qty, unitPrice: unit)]).amountInWords;

      expect(words(100, 1), 'One Hundred Rupees Only');
      expect(words(1, 1), 'One Rupees Only');
      expect(words(1000, 1), 'One Thousand Rupees Only');
      expect(words(100000, 1), 'One Lakh Rupees Only');
      expect(words(10000000, 1), 'One Crore Rupees Only');
      expect(words(1250, 1), 'One Thousand Two Hundred Fifty Rupees Only');
      expect(words(19, 1), 'Nineteen Rupees Only');
      expect(words(45, 1), 'Forty Five Rupees Only');
    });

    test('zero invoice reads as zero', () {
      final inv =
          _invoice(items: [_item(qty: 1, unitPrice: 100)], discount: 100);
      expect(inv.payableTotal, 0.0);
      expect(inv.amountInWords, 'Zero Rupees Only');
    });
  });

  group('GST reconciliation in the persisted row', () {
    test('taxable + total_gst equals grand_total exactly', () {
      // 10 x 100 inclusive of 12% with a 100 discount.
      final inv =
          _invoice(items: [_item(qty: 10, unitPrice: 100, tax: 12)], discount: 100);
      final row = DbMapper.invoiceToSalesRow(
        inv, tenantId: 't', branchId: 'b', createdBy: 'u',
      );

      final taxable = row['taxable_amount'] as double;
      final gst = row['total_gst'] as double;
      final grand = row['grand_total'] as double;

      expect(double.parse((taxable + gst).toStringAsFixed(2)), grand);
    });

    test('cgst + sgst equals total_gst exactly', () {
      final inv = _invoice(
        items: [_item(qty: 3, unitPrice: 33.33, tax: 12)],
      );
      final row = DbMapper.invoiceToSalesRow(
        inv, tenantId: 't', branchId: 'b', createdBy: 'u',
      );
      final cgst = row['cgst_amount'] as double;
      final sgst = row['sgst_amount'] as double;
      expect(double.parse((cgst + sgst).toStringAsFixed(2)), row['total_gst']);
    });

    test('pharmacist identity goes to the right columns', () {
      final inv = InvoiceModel(
        id: 'i', invoiceNumber: 'N', timestamp: DateTime(2025, 1, 1),
        customerName: 'C', customerPhone: '9', items: [_item()],
        paymentMode: PaymentMode.cash,
        pharmacistPinApprovedBy: 'Dr Rao',
        authorizedPharmacistId: 'ph-uuid-1',
      );
      final row = DbMapper.invoiceToSalesRow(
        inv, tenantId: 't', branchId: 'b', createdBy: 'u',
      );
      // The UUID column must never receive the display label.
      expect(row['authorized_pharmacist_id'], 'ph-uuid-1');
      expect(row['pharmacist_authorized_name'], 'Dr Rao');
      expect(row.containsKey('pharmacist_authorized_by'), isFalse);
    });
  });
}
