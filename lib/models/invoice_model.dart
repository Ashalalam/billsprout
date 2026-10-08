import 'product_model.dart';
import 'batch_model.dart';
import 'selling_unit_model.dart';

enum PaymentMode { cash, card, upi, razorpay, split, credit }

class InvoiceItem {
  final ProductModel product;
  final BatchModel batch;
  int quantity;              // Number of packs (strips, bottles, boxes)
  int freeQuantity;          // Free packs / schemes (not charged)
  double unitPrice;          // Price per pack (for pack sales)
  double taxPercent;
  double lineDiscount;       // Item-level discount amount (₹)
  
  // Compound quantity fields for loose-unit sales
  int looseUnits;            // Number of loose units (tablets, capsules, ml)
  int freeLooseUnits;        // Free loose units
  SellingUnit sellingUnit;   // Unit being sold (strip, tablet, capsule, ml, etc.)
  double? pricePerUnit;      // Price per base unit (for loose sales)
  int packsOpened;           // Number of packs opened to fulfill loose units
  
  // Legacy field for display compatibility
  final String unit;         // Deprecated: Use sellingUnit instead
  double discountPercent;    // Discount as percentage (for display on GST bills)

  InvoiceItem({
    required this.product,
    required this.batch,
    required this.quantity,
    this.freeQuantity = 0,
    required this.unitPrice,
    required this.taxPercent,
    this.lineDiscount = 0.0,
    this.looseUnits = 0,
    this.freeLooseUnits = 0,
    this.sellingUnit = SellingUnit.strip,
    this.pricePerUnit,
    this.packsOpened = 0,
    this.unit = 'Unit',
    this.discountPercent = 0.0,
  });
  
  /// Create InvoiceItem from SaleQuantity (new approach)
  factory InvoiceItem.fromSaleQuantity({
    required ProductModel product,
    required BatchModel batch,
    required SaleQuantity saleQty,
    required double packPrice,
    double? unitPrice,
    required double taxPercent,
    double lineDiscount = 0.0,
    double discountPercent = 0.0,
  }) {
    return InvoiceItem(
      product: product,
      batch: batch,
      quantity: saleQty.packQuantity,
      freeQuantity: saleQty.freePackQuantity,
      looseUnits: saleQty.looseQuantity,
      freeLooseUnits: saleQty.freeLooseQuantity,
      sellingUnit: saleQty.sellingUnit,
      unitPrice: packPrice,
      pricePerUnit: unitPrice,
      taxPercent: taxPercent,
      lineDiscount: lineDiscount,
      discountPercent: discountPercent,
      unit: saleQty.sellingUnit.label, // For legacy compatibility
    );
  }

  /// Billed quantity only (free qty is not charged)
  int get billedQuantity => quantity;
  
  /// Billed loose units only
  int get billedLooseUnits => looseUnits;
  
  /// Whether this sale includes loose units
  bool get hasLooseUnits => looseUnits > 0 || freeLooseUnits > 0;
  
  /// Whether this is a mixed sale (packs + loose)
  bool get isMixedSale => quantity > 0 && looseUnits > 0;
  
  /// Total quantity sold (for stock deduction)
  int get totalQuantitySold => quantity + freeQuantity;
  
  /// Total loose units sold (for stock deduction)
  int get totalLooseUnitsSold => looseUnits + freeLooseUnits;
  
  /// Convert to SaleQuantity for processing
  SaleQuantity toSaleQuantity() {
    return SaleQuantity(
      packQuantity: quantity,
      looseQuantity: looseUnits,
      sellingUnit: sellingUnit,
      freePackQuantity: freeQuantity,
      freeLooseQuantity: freeLooseUnits,
    );
  }

  /// Calculate gross line total (before any discounts)
  double get grossLineTotal {
    double packTotal = quantity * unitPrice;
    double looseTotal = 0.0;
    
    if (hasLooseUnits && pricePerUnit != null) {
      looseTotal = looseUnits * pricePerUnit!;
    }
    
    return packTotal + looseTotal;
  }
  
  /// Net line total after item-level discounts (before tax calculation)
  double get lineTotal => grossLineTotal - lineDiscount;
  
  /// Tax amount - GST is typically inclusive in Indian pharmacy pricing
  /// Formula: Tax = LineTotal * (TaxPercent / (100 + TaxPercent))
  double get taxAmount => lineTotal * (taxPercent / (100 + taxPercent));
  
  /// Taxable value (line total excluding tax)
  double get taxableValue => lineTotal - taxAmount;
  
  /// CGST amount (half of total tax for intra-state transactions)
  double get cgst => taxAmount / 2;
  
  /// SGST amount (half of total tax for intra-state transactions) 
  double get sgst => taxAmount / 2;

  /// Display string for quantity
  /// Examples:
  /// - "3" (packs only)
  /// - "3 + 2 Free" (packs with free items)
  /// - "5 Tablets" (loose only)
  /// - "1 Strip + 3 Tablets" (mixed)
  /// - "2 Strips + 5 Tablets (+ 2 free)" (mixed with free items)
  String get quantityDisplay {
    if (hasLooseUnits) {
      // Use SaleQuantity display logic for loose/mixed sales
      final saleQty = toSaleQuantity();
      return saleQty.displayText(showFree: freeQuantity > 0 || freeLooseUnits > 0);
    }
    
    // Legacy pack-only display
    if (freeQuantity > 0) return '$quantity + $freeQuantity Free';
    return '$quantity';
  }
  
  /// Compact display for printing/small spaces
  String get compactQuantityDisplay {
    if (hasLooseUnits) {
      return toSaleQuantity().compactDisplay();
    }
    return '$quantity';
  }
  
  /// Unit display for invoice line (e.g., "Strip", "Tablets", "ml")
  String get unitDisplay {
    if (hasLooseUnits && !isMixedSale) {
      // Loose-only: show loose unit
      return looseUnits == 1 
          ? _getLooseUnit().label 
          : _getLooseUnit().pluralLabel;
    } else if (isMixedSale) {
      // Mixed: show "Mixed"
      return 'Mixed';
    } else {
      // Pack-only: show pack unit
      return quantity == 1 
          ? sellingUnit.label 
          : sellingUnit.pluralLabel;
    }
  }
  
  /// Get appropriate loose unit based on selling unit
  SellingUnit _getLooseUnit() {
    switch (sellingUnit) {
      case SellingUnit.strip:
      case SellingUnit.tablet:
        return SellingUnit.tablet;
      case SellingUnit.capsule:
        return SellingUnit.capsule;
      case SellingUnit.bottle:
      case SellingUnit.ml:
        return SellingUnit.ml;
      case SellingUnit.tube:
      case SellingUnit.gm:
        return SellingUnit.gm;
      default:
        return SellingUnit.unit;
    }
  }

  Map<String, dynamic> toJson() => {
        'product': product.toJson(),
        'batch': batch.toJson(),
        'quantity': quantity,
        'freeQuantity': freeQuantity,
        'unitPrice': unitPrice,
        'taxPercent': taxPercent,
        'lineDiscount': lineDiscount,
        'looseUnits': looseUnits,
        'freeLooseUnits': freeLooseUnits,
        'sellingUnit': sellingUnit.dbValue,
        'pricePerUnit': pricePerUnit,
        'packsOpened': packsOpened,
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
        looseUnits: json['looseUnits'] ?? 0,
        freeLooseUnits: json['freeLooseUnits'] ?? 0,
        sellingUnit: json['sellingUnit'] != null 
            ? _parseSellingUnit(json['sellingUnit']) 
            : SellingUnit.strip,
        pricePerUnit: json['pricePerUnit'] != null 
            ? (json['pricePerUnit'] as num).toDouble() 
            : null,
        packsOpened: json['packsOpened'] ?? 0,
        unit: json['unit'] ?? 'Unit',
        discountPercent: (json['discountPercent'] as num? ?? 0).toDouble(),
      );
  
  /// Helper to parse SellingUnit from string
  static SellingUnit _parseSellingUnit(dynamic value) {
    if (value == null) return SellingUnit.unit;
    final str = value.toString().toLowerCase();
    return SellingUnit.values.firstWhere(
      (e) => e.name == str,
      orElse: () => SellingUnit.unit,
    );
  }
}

class InvoiceModel {
  final String id;
  final String invoiceNumber;
  final DateTime timestamp;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;     // Added customer email
  final String? customerAddress;   // Added customer address
  final String? customerGstin;     // Added customer GSTIN
  final String? customerDlNo;      // Added customer Drug License
  final String? doctorName;
  final String? doctorMciNo;
  final List<InvoiceItem> items;
  final double discountAmount;   // Invoice-level discount (₹)
  final PaymentMode paymentMode;
  final bool isSynced;
  final String? pharmacistPinApprovedBy;
  final String branch;           // Dispensing branch name
  final String billingType;      // 'retail' | 'wholesale'

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
    this.customerEmail,
    this.customerAddress,
    this.customerGstin,
    this.customerDlNo,
    this.doctorName,
    this.doctorMciNo,
    required this.items,
    this.discountAmount = 0.0,
    required this.paymentMode,
    this.isSynced = false,
    this.pharmacistPinApprovedBy,
    this.branch = 'Main Store',
    this.billingType = 'retail',
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
        'customerEmail': customerEmail,
        'customerAddress': customerAddress,
        'customerGstin': customerGstin,
        'customerDlNo': customerDlNo,
        'doctorName': doctorName,
        'doctorMciNo': doctorMciNo,
        'items': items.map((i) => i.toJson()).toList(),
        'discountAmount': discountAmount,
        'paymentMode': paymentMode.name,
        'isSynced': isSynced,
        'pharmacistPinApprovedBy': pharmacistPinApprovedBy,
        'branch': branch,
        'billingType': billingType,
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
        customerEmail: json['customerEmail'],
        customerAddress: json['customerAddress'],
        customerGstin: json['customerGstin'],
        customerDlNo: json['customerDlNo'],
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
