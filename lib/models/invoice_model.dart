import 'product_model.dart';
import 'batch_model.dart';

enum PaymentMode { cash, card, upi, split, credit }

class InvoiceItem {
  final ProductModel product;
  final BatchModel batch;
  int quantity;
  int freeQuantity;       // Free goods / schemes (not charged)
  double unitPrice;
  double taxPercent;
  double lineDiscount;    // Item-level discount amount (₹)
  
  // NEW FIELDS for enhanced invoicing
  final String unit;      // Unit of measurement: 'Tablets', 'Capsules', 'ml', 'gm', etc.
  double discountPercent; // Discount as percentage (for display on GST bills)

  InvoiceItem({
    required this.product,
    required this.batch,
    required this.quantity,
    this.freeQuantity = 0,
    required this.unitPrice,
    required this.taxPercent,
    this.lineDiscount = 0.0,
    this.unit = 'Unit',
    this.discountPercent = 0.0,
  });

  /// Billed quantity only (free qty is not charged)
  int get billedQuantity => quantity;

  double get grossLineTotal  => quantity * unitPrice;
  double get lineTotal       => grossLineTotal - lineDiscount;
  double get taxAmount       => lineTotal * (taxPercent / (100 + taxPercent));
  double get taxableValue    => lineTotal - taxAmount;
  double get cgst            => taxAmount / 2;
  double get sgst            => taxAmount / 2;

  /// Display string e.g. "3 strips + 1 Free"
  String get quantityDisplay {
    if (freeQuantity > 0) return '$quantity + $freeQuantity Free';
    return '$quantity';
  }

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'batch': batch.toJson(),
        'quantity': quantity,
        'freeQuantity': freeQuantity,
        'unitPrice': unitPrice,
        'taxPercent': taxPercent,
        'lineDiscount': lineDiscount,
        'unit': unit,
        'discountPercent': discountPercent,
      };

  factory InvoiceItem.fromJson(Map<String, dynamic> json) => InvoiceItem(
        product: ProductModel.fromJson(json['product']),
        batch: BatchModel.fromJson(json['batch']),
        quantity: json['quantity'],
        freeQuantity: json['freeQuantity'] ?? 0,
        unitPrice: (json['unitPrice'] as num).toDouble(),
        taxPercent: (json['taxPercent'] as num).toDouble(),
        lineDiscount: (json['lineDiscount'] as num? ?? 0).toDouble(),
        unit: json['unit'] ?? 'Unit',
        discountPercent: (json['discountPercent'] as num? ?? 0).toDouble(),
      );
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final DateTime timestamp;
  final String customerName;
  final String customerPhone;
  final String? doctorName;
  final String? doctorMciNo;
  final List<InvoiceItem> items;
  final double discountAmount;   // Invoice-level discount (₹)
  final PaymentMode paymentMode;
  final bool isSynced;
  final String? pharmacistPinApprovedBy;
  final String branch;           // Dispensing branch name
  final String billingType;      // 'retail' | 'wholesale'
  final String? customerGstin;   // Required for wholesale trade invoices

  /// pharmacists.id of the authoriser for Schedule H / H1 / narcotic sales.
  /// Separate from [pharmacistPinApprovedBy], which is the display label.
  final String? authorizedPharmacistId;

  // NEW FIELDS for enhanced invoicing
  final DateTime? dueDate;           // Payment due date (for credit sales)
  final String? lrNumber;            // Lorry Receipt Number (for transport)
  final String? transportDetails;    // Transport company/vehicle details
  final String? billingAddress;      // Separate billing address
  final String? shippingAddress;     // Delivery/shipping address
  final double cessAmount;           // Cess amount if applicable
  final double otherCharges;         // Additional charges (packaging, etc.)
  final String invoiceType;          // 'tax_invoice', 'gst_bill', 'estimate', 'purchase'

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    required this.timestamp,
    required this.customerName,
    required this.customerPhone,
    this.doctorName,
    this.doctorMciNo,
    required this.items,
    this.discountAmount = 0.0,
    required this.paymentMode,
    this.isSynced = false,
    this.pharmacistPinApprovedBy,
    this.branch = 'Main Store',
    this.billingType = 'retail',
    this.customerGstin,
    this.authorizedPharmacistId,
    // New optional fields with defaults
    this.dueDate,
    this.lrNumber,
    this.transportDetails,
    this.billingAddress,
    this.shippingAddress,
    this.cessAmount = 0.0,
    this.otherCharges = 0.0,
    this.invoiceType = 'tax_invoice',
  });

  bool get isWholesale => billingType == 'wholesale';

  double get subtotal    => items.fold(0, (s, i) => s + i.lineTotal);
  double get totalTax    => items.fold(0, (s, i) => s + i.taxAmount);
  double get totalLineDiscounts => items.fold(0, (s, i) => s + i.lineDiscount);

  /// Invoice-level discount is capped at the subtotal. Without the clamp an
  /// over-entered discount produces a negative payable, which then reaches the
  /// sales table and the GST totals.
  double get effectiveDiscount =>
      discountAmount > subtotal ? subtotal : discountAmount;

  double get grandTotal => subtotal - effectiveDiscount + cessAmount + otherCharges;

  /// Difference between the payable rupee amount and the computed total.
  /// Indian pharmacy invoices settle to the nearest rupee in cash.
  double get roundOff {
    final rounded = grandTotal.roundToDouble();
    return double.parse((rounded - grandTotal).toStringAsFixed(2));
  }

  /// Amount actually collected, after rounding to the nearest rupee.
  double get payableTotal => grandTotal.roundToDouble();

  /// Payable amount in words, for the statutory "Amount in Words" line.
  String get amountInWords => _rupeesToWords(payableTotal);

  static String _rupeesToWords(double amount) {
    final rupees = amount.floor();
    final paise = ((amount - rupees) * 100).round();

    final words = StringBuffer(_indianNumberToWords(rupees));
    words.write(' Rupees');
    if (paise > 0) {
      words.write(' and ${_indianNumberToWords(paise)} Paise');
    }
    words.write(' Only');
    return words.toString();
  }

  /// Indian numbering: crore / lakh / thousand / hundred.
  static String _indianNumberToWords(int n) {
    if (n == 0) return 'Zero';

    const units = [
      '', 'One', 'Two', 'Three', 'Four', 'Five', 'Six', 'Seven', 'Eight',
      'Nine', 'Ten', 'Eleven', 'Twelve', 'Thirteen', 'Fourteen', 'Fifteen',
      'Sixteen', 'Seventeen', 'Eighteen', 'Nineteen',
    ];
    const tens = [
      '', '', 'Twenty', 'Thirty', 'Forty', 'Fifty', 'Sixty', 'Seventy',
      'Eighty', 'Ninety',
    ];

    String twoDigits(int v) {
      if (v < 20) return units[v];
      final t = tens[v ~/ 10];
      final u = v % 10;
      return u == 0 ? t : '$t ${units[u]}';
    }

    final parts = <String>[];
    var rest = n;

    final crore = rest ~/ 10000000;
    rest %= 10000000;
    final lakh = rest ~/ 100000;
    rest %= 100000;
    final thousand = rest ~/ 1000;
    rest %= 1000;
    final hundred = rest ~/ 100;
    final remainder = rest % 100;

    if (crore > 0) parts.add('${_indianNumberToWords(crore)} Crore');
    if (lakh > 0) parts.add('${twoDigits(lakh)} Lakh');
    if (thousand > 0) parts.add('${twoDigits(thousand)} Thousand');
    if (hundred > 0) parts.add('${units[hundred]} Hundred');
    if (remainder > 0) parts.add(twoDigits(remainder));

    return parts.join(' ');
  }

  bool get containsRestrictedDrugs =>
      items.any((i) => i.product.requiresPharmacistPin);

  bool get hasFreeItems =>
      items.any((i) => i.freeQuantity > 0);

  Map<String, dynamic> toJson() => {
        'id': id,
        'invoiceNumber': invoiceNumber,
        'timestamp': timestamp.toIso8601String(),
        'customerName': customerName,
        'customerPhone': customerPhone,
        'doctorName': doctorName,
        'doctorMciNo': doctorMciNo,
        'items': items.map((i) => i.toJson()).toList(),
        'discountAmount': discountAmount,
        'paymentMode': paymentMode.name,
        'isSynced': isSynced,
        'pharmacistPinApprovedBy': pharmacistPinApprovedBy,
        'branch': branch,
        'billingType': billingType,
        'customerGstin': customerGstin,
        'authorizedPharmacistId': authorizedPharmacistId,
        'dueDate': dueDate?.toIso8601String(),
        'lrNumber': lrNumber,
        'transportDetails': transportDetails,
        'billingAddress': billingAddress,
        'shippingAddress': shippingAddress,
        'cessAmount': cessAmount,
        'otherCharges': otherCharges,
        'invoiceType': invoiceType,
      };

  factory InvoiceModel.fromJson(Map<String, dynamic> json) => InvoiceModel(
        id: json['id'],
        invoiceNumber: json['invoiceNumber'],
        timestamp: DateTime.parse(json['timestamp']),
        customerName: json['customerName'],
        customerPhone: json['customerPhone'],
        doctorName: json['doctorName'],
        doctorMciNo: json['doctorMciNo'],
        items: (json['items'] as List)
            .map((i) => InvoiceItem.fromJson(i))
            .toList(),
        discountAmount: (json['discountAmount'] as num).toDouble(),
        paymentMode: PaymentMode.values.firstWhere(
          (e) => e.name == json['paymentMode'],
          orElse: () => PaymentMode.cash,
        ),
        isSynced: json['isSynced'] ?? false,
        pharmacistPinApprovedBy: json['pharmacistPinApprovedBy'],
        branch: json['branch'] ?? 'Main Store',
        billingType: json['billingType'] ?? 'retail',
        customerGstin: json['customerGstin'],
        authorizedPharmacistId: json['authorizedPharmacistId'],
        dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
        lrNumber: json['lrNumber'],
        transportDetails: json['transportDetails'],
        billingAddress: json['billingAddress'],
        shippingAddress: json['shippingAddress'],
        cessAmount: (json['cessAmount'] as num?)?.toDouble() ?? 0.0,
        otherCharges: (json['otherCharges'] as num?)?.toDouble() ?? 0.0,
        invoiceType: json['invoiceType'] ?? 'tax_invoice',
      );
}
