import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/invoice_model.dart';
import '../models/selling_unit_model.dart';
import '../services/pricing_calculator.dart';

class PosProvider extends ChangeNotifier {
  final List<InvoiceItem> _cartItems = [];
  String _customerName  = 'Walk-in Customer';
  String _customerPhone = '';
  String? _doctorName;
  String? _doctorMciNo;
  double _discountAmount = 0.0;
  PaymentMode _paymentMode = PaymentMode.cash;
  String _pricingTier = 'Retail';
  String _branch = 'Main Store';
  String _billingType = 'retail';
  String? _customerGstin;
  String _invoiceTemplate = 'tax_invoice'; // 'tax_invoice' or 'gst_bill'

  // ── Branch management ──────────────────────────────────────────────────────
  static const List<String> defaultBranches = [
    'Main Store',
    'Branch 1',
    'Warehouse',
    'Online',
  ];
  List<String> _branches = List.from(defaultBranches);

  List<InvoiceItem> get cartItems   => List.unmodifiable(_cartItems);
  String get customerName           => _customerName;
  String get customerPhone          => _customerPhone;
  String? get doctorName            => _doctorName;
  String? get doctorMciNo           => _doctorMciNo;
  double get discountAmount         => _discountAmount;
  String get pricingTier            => _pricingTier;
  PaymentMode get paymentMode       => _paymentMode;
  String get branch                 => _branch;
  List<String> get branches         => List.unmodifiable(_branches);

  String get billingType  => _billingType;
  String? get customerGstin => _customerGstin;
  bool get isWholesale    => _billingType == 'wholesale';
  String get invoiceTemplate => _invoiceTemplate;

  double get subtotal    => _cartItems.fold(0.0, (s, i) => s + i.lineTotal);
  double get totalTax    => _cartItems.fold(0.0, (s, i) => s + i.taxAmount);

  /// Discount never exceeds the subtotal, so the payable cannot go negative.
  double get effectiveDiscount =>
      _discountAmount > subtotal ? subtotal : _discountAmount;

  double get grandTotal  => subtotal - effectiveDiscount;

  bool get requiresPharmacistPin =>
      _cartItems.any((item) => item.product.requiresPharmacistPin);

  PosProvider() {
    _loadBranches();
  }

  // ── Setters ────────────────────────────────────────────────────────────────
  void setPricingTier(String tier) {
    _pricingTier = tier;
    _repriceCart();
    notifyListeners();
  }

  void setBranch(String b) {
    _branch = b;
    notifyListeners();
  }

  void addBranch(String name) {
    if (name.isNotEmpty && !_branches.contains(name)) {
      _branches.add(name);
      _saveBranches();
      notifyListeners();
    }
  }

  void setCustomerDetails(String name, String phone,
      {String? docName, String? docMci}) {
    _customerName  = name.isEmpty ? 'Walk-in Customer' : name;
    _customerPhone = phone;
    _doctorName    = docName;
    _doctorMciNo   = docMci;
    notifyListeners();
  }

  void setPaymentMode(PaymentMode mode) {
    _paymentMode = mode;
    notifyListeners();
  }

  void setDiscount(double amount) {
    _discountAmount = amount < 0 ? 0 : amount;
    notifyListeners();
  }

  /// Switch between retail and wholesale billing.
  ///
  /// Wholesale re-prices the existing cart at PTR rather than leaving a mix of
  /// retail-priced and wholesale-priced lines on one invoice.
  void setBillingType(String type) {
    final normalised = type == 'wholesale' ? 'wholesale' : 'retail';
    if (normalised == _billingType) return;

    _billingType = normalised;
    _pricingTier = normalised == 'wholesale' ? 'PTR' : 'Retail';
    if (normalised == 'retail') _customerGstin = null;

    _repriceCart();
    notifyListeners();
  }

  void setCustomerGstin(String? gstin) {
    final trimmed = gstin?.trim();
    _customerGstin =
        (trimmed == null || trimmed.isEmpty) ? null : trimmed.toUpperCase();
    notifyListeners();
  }

  void setInvoiceTemplate(String template) {
    if (template == 'tax_invoice' || template == 'gst_bill') {
      _invoiceTemplate = template;
      notifyListeners();
    }
  }

  void _repriceCart() {
    for (final item in _cartItems) {
      item.unitPrice = _resolvePriceTier(item.product, item.batch);
    }
  }

  // ── Cart operations ────────────────────────────────────────────────────────
  
  /// Add product to cart (pack-based, legacy behavior)
  void addToCart(ProductModel product, {BatchModel? selectedBatch}) {
    final batchToUse = selectedBatch ?? product.fefoBatch;
    if (batchToUse == null) return;

    final unitPrice = _resolvePriceTier(product, batchToUse);

    final idx = _cartItems.indexWhere(
        (i) => i.product.id == product.id && i.batch.id == batchToUse.id);

    if (idx >= 0) {
      if (_cartItems[idx].quantity < batchToUse.stockCount) {
        _cartItems[idx].quantity++;
        
        // Calculate and update free quantity based on scheme
        if (product.hasActiveScheme) {
          final scheme = product.activeScheme!;
          final newFreeQty = scheme.calculateFreeQuantity(_cartItems[idx].quantity);
          _cartItems[idx].freeQuantity = newFreeQty;
          debugPrint('[POS SCHEME] ${product.name}: Updated to ${_cartItems[idx].quantity} paid + $newFreeQty free');
        }
      }
    } else {
      // Calculate free quantity for first item
      int freeQty = 0;
      if (product.hasActiveScheme) {
        final scheme = product.activeScheme!;
        freeQty = scheme.calculateFreeQuantity(1);
        if (freeQty > 0) {
          debugPrint('[POS SCHEME] ${product.name}: Buy 1 Get $freeQty Free');
        }
      }
      
      _cartItems.add(InvoiceItem(
        product: product,
        batch: batchToUse,
        quantity: 1,
        freeQuantity: freeQty,
        unitPrice: unitPrice,
        taxPercent: product.taxPercent,
        sellingUnit: product.minSaleUnit,
      ));
    }
    notifyListeners();
  }
  
  /// Add product to cart with flexible quantity (NEW: supports loose units)
  void addToCartWithQuantity(
    ProductModel product, 
    SaleQuantity quantity, {
    BatchModel? selectedBatch,
  }) {
    final batchToUse = selectedBatch ?? _selectBestBatch(product, quantity);
    if (batchToUse == null) {
      debugPrint('No suitable batch found for ${product.name}');
      return;
    }
    
    // Calculate free quantity based on active scheme
    SaleQuantity finalQuantity = quantity;
    if (product.hasActiveScheme) {
      final scheme = product.activeScheme!;
      final paidQty = quantity.packQuantity;
      final freeQty = scheme.calculateFreeQuantity(paidQty);
      
      if (freeQty > 0) {
        debugPrint('[POS SCHEME] ${product.name}: Buy $paidQty Get $freeQty Free (${scheme.schemeUnit.label})');
        
        // Add free quantity to the sale
        finalQuantity = SaleQuantity(
          packQuantity: quantity.packQuantity,
          looseQuantity: quantity.looseQuantity,
          freePackQuantity: freeQty,
          freeLooseQuantity: 0,
          sellingUnit: quantity.sellingUnit,
        );
      }
    }
    
    // Validate stock availability (including free quantity)
    final validation = PricingCalculator.validateStock(
      product: product,
      batch: batchToUse,
      quantity: finalQuantity,
    );
    
    if (!validation.isValid) {
      debugPrint('Stock validation failed: ${validation.errorMessage}');
      return;
    }
    
    // Calculate prices
    final tier = _convertPricingTier(_pricingTier);
    final packPrice = PricingCalculator.getPackPrice(batch: batchToUse, tier: tier);
    final unitPrice = PricingCalculator.getUnitPrice(
      product: product,
      batch: batchToUse,
      tier: tier,
    );
    
    // Check if item already exists in cart
    final idx = _cartItems.indexWhere(
        (i) => i.product.id == product.id && 
               i.batch.id == batchToUse.id &&
               i.sellingUnit == finalQuantity.sellingUnit);
    
    if (idx >= 0) {
      // Update existing item
      final existing = _cartItems[idx];
      existing.quantity += finalQuantity.packQuantity;
      existing.looseUnits += finalQuantity.looseQuantity;
      existing.freeQuantity += finalQuantity.freePackQuantity;
      existing.freeLooseUnits += finalQuantity.freeLooseQuantity;
    } else {
      // Add new item
      _cartItems.add(InvoiceItem.fromSaleQuantity(
        product: product,
        batch: batchToUse,
        saleQty: finalQuantity,
        packPrice: packPrice,
        unitPrice: unitPrice,
        taxPercent: product.taxPercent,
      ));
    }
    
    notifyListeners();
  }
  
  /// Select best batch considering loose units availability (Enhanced FEFO)
  BatchModel? _selectBestBatch(ProductModel product, SaleQuantity quantity) {
    if (product.batches.isEmpty) return null;
    
    // Filter valid batches (not expired, has stock)
    final validBatches = product.batches.where((b) {
      if (b.isExpired) return false;
      
      // Check if batch can fulfill request
      final available = AvailableStock(
        packStock: b.stockCount,
        looseUnits: b.looseUnits,
        baseUnitsPerPack: product.baseUnitsPerPack,
      );
      
      return available.canFulfill(quantity);
    }).toList();
    
    if (validBatches.isEmpty) return null;
    
    // Sort by:
    // 1. Batches with existing loose units (prefer using opened packs)
    // 2. Earliest expiry (FEFO)
    validBatches.sort((a, b) {
      // Prefer batches with loose units if we're selling loose units
      if (quantity.hasLooseUnits) {
        if (a.looseUnits > 0 && b.looseUnits == 0) return -1;
        if (b.looseUnits > 0 && a.looseUnits == 0) return 1;
      }
      
      // Then by expiry date (FEFO)
      return a.expDate.compareTo(b.expDate);
    });
    
    return validBatches.first;
  }

  void updateQuantity(InvoiceItem item, int newQty) {
    if (newQty <= 0) {
      _cartItems.remove(item);
    } else {
      // Validate against available stock
      final totalUnits = item.batch.totalAvailableUnits(item.product.baseUnitsPerPack);
      final requestedUnits = newQty * item.product.baseUnitsPerPack;
      
      if (requestedUnits <= totalUnits) {
        item.quantity = newQty;
      } else {
        debugPrint('Insufficient stock: requested $requestedUnits, available $totalUnits');
      }
    }
    notifyListeners();
  }
  
  /// Update loose quantity (NEW)
  void updateLooseQuantity(InvoiceItem item, int newLooseQty) {
    if (newLooseQty < 0) {
      item.looseUnits = 0;
    } else {
      // Validate stock
      final available = AvailableStock(
        packStock: item.batch.stockCount,
        looseUnits: item.batch.looseUnits,
        baseUnitsPerPack: item.product.baseUnitsPerPack,
      );
      
      final requestedQty = SaleQuantity(
        packQuantity: item.quantity,
        looseQuantity: newLooseQty,
        sellingUnit: item.sellingUnit,
      );
      
      if (available.canFulfill(requestedQty)) {
        item.looseUnits = newLooseQty;
        
        // Recalculate price if unit price is set
        if (item.pricePerUnit != null) {
          // Price will be recalculated via grossLineTotal getter
        }
      }
    }
    notifyListeners();
  }
  
  /// Update selling unit for an item (NEW: switch between strip/tablet/capsule)
  void updateSellingUnit(InvoiceItem item, SellingUnit newUnit) {
    if (!item.product.availableSellingUnits.contains(newUnit)) {
      debugPrint('Selling unit $newUnit not available for ${item.product.name}');
      return;
    }
    
    item.sellingUnit = newUnit;
    
    // Recalculate unit price
    final tier = _convertPricingTier(_pricingTier);
    if (newUnit.isLooseUnit) {
      item.pricePerUnit = PricingCalculator.getUnitPrice(
        product: item.product,
        batch: item.batch,
        tier: tier,
      );
    } else {
      item.unitPrice = PricingCalculator.getPackPrice(
        batch: item.batch,
        tier: tier,
      );
    }
    
    notifyListeners();
  }

  void updateFreeQuantity(InvoiceItem item, int freeQty) {
    item.freeQuantity = freeQty < 0 ? 0 : freeQty;
    notifyListeners();
  }

  void updateLineDiscount(InvoiceItem item, double discount) {
    item.lineDiscount = discount < 0 ? 0 : discount;
    notifyListeners();
  }

  void removeFromCart(InvoiceItem item) {
    _cartItems.remove(item);
    notifyListeners();
  }

  void clearCart() {
    _cartItems.clear();
    _discountAmount  = 0.0;
    _customerName    = 'Walk-in Customer';
    _customerPhone   = '';
    _doctorName      = null;
    _doctorMciNo     = null;
    _customerGstin   = null;
    notifyListeners();
  }

  // ── Checkout ───────────────────────────────────────────────────────────────
  InvoiceModel checkout({
    required bool isOnline,
    String? pinApprovedBy,
    String? authorizedPharmacistId,
  }) {
    final invoiceNum =
        'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';

    final invoice = InvoiceModel(
      id: const Uuid().v4(),  // Use proper UUID instead of timestamp
      invoiceNumber: invoiceNum,
      timestamp: DateTime.now(),
      customerName: _customerName,
      customerPhone: _customerPhone,
      doctorName: _doctorName,
      doctorMciNo: _doctorMciNo,
      items: List.from(_cartItems),
      discountAmount: effectiveDiscount,
      paymentMode: _paymentMode,
      isSynced: isOnline,
      pharmacistPinApprovedBy: pinApprovedBy,
      branch: _branch,
      billingType: _billingType,
      customerGstin: _customerGstin,
      authorizedPharmacistId: authorizedPharmacistId,
    );

    // Local (in-memory / offline) stock is decremented here so the POS grid
    // reflects the sale immediately. This handles both pack and loose quantities.
    //
    // Note: the authoritative deduction happens server-side in the
    // update_stock_on_sale_with_loose_units trigger. When the invoice syncs, 
    // the batch row is refreshed from Supabase, so this local adjustment is a 
    // display update and not a second deduction against the same stock.
    for (final item in _cartItems) {
      // Deduct packs (including free packs)
      final totalPacksDispensed = item.quantity + item.freeQuantity;
      
      // Deduct loose units (including free loose)
      final totalLooseDispensed = item.looseUnits + item.freeLooseUnits;
      
      // Calculate packs to open for loose units
      final available = AvailableStock(
        packStock: item.batch.stockCount,
        looseUnits: item.batch.looseUnits,
        baseUnitsPerPack: item.product.baseUnitsPerPack,
      );
      
      final packsToOpen = available.packsToOpen(totalLooseDispensed);
      
      // Update batch stock
      item.batch.stockCount = (item.batch.stockCount - totalPacksDispensed - packsToOpen)
          .clamp(0, item.batch.stockCount);
      
      // Update loose units
      if (totalLooseDispensed <= item.batch.looseUnits) {
        // Sufficient loose units available
        item.batch.looseUnits = item.batch.looseUnits - totalLooseDispensed;
      } else {
        // Opened packs to fulfill
        final remainingLoose = (packsToOpen * item.product.baseUnitsPerPack) - 
                              (totalLooseDispensed - item.batch.looseUnits);
        item.batch.looseUnits = remainingLoose.clamp(0, remainingLoose);
      }
    }

    clearCart();
    return invoice;
  }

  // ── Internal ───────────────────────────────────────────────────────────────
  double _resolvePriceTier(ProductModel product, BatchModel batch) {
    switch (_pricingTier) {
      case 'PTR':
        return batch.ptrPrice > 0 ? batch.ptrPrice : batch.mrp;
      case 'Wholesale':
        return batch.wholesalePrice > 0 ? batch.wholesalePrice : batch.mrp;
      case 'Distributor':
        final ws = batch.wholesalePrice > 0 ? batch.wholesalePrice : batch.mrp;
        return ws * 0.90;
      case 'Loyalty':
        return batch.mrp * 0.95;
      case 'Retail':
      default:
        return batch.mrp;
    }
  }
  
  /// Convert pricing tier string to PricingTier enum
  PricingTier _convertPricingTier(String tierString) {
    switch (tierString) {
      case 'PTR':
        return PricingTier.ptr;
      case 'Wholesale':
        return PricingTier.wholesale;
      case 'Distributor':
        return PricingTier.distributor;
      case 'Loyalty':
        return PricingTier.loyalty;
      case 'Retail':
      default:
        return PricingTier.retail;
    }
  }

  Future<void> _loadBranches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList('pos_branches');
      if (saved != null && saved.isNotEmpty) {
        _branches = saved;
        if (!_branches.contains(_branch)) _branch = _branches.first;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> _saveBranches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('pos_branches', _branches);
    } catch (_) {}
  }
}
