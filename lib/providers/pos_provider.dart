import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/product_model.dart';
import '../models/batch_model.dart';
import '../models/invoice_model.dart';

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

  void _repriceCart() {
    for (final item in _cartItems) {
      item.unitPrice = _resolvePriceTier(item.product, item.batch);
    }
  }

  // ── Cart operations ────────────────────────────────────────────────────────
  void addToCart(ProductModel product, {BatchModel? selectedBatch}) {
    final batchToUse = selectedBatch ?? product.fefoBatch;
    if (batchToUse == null) return;

    final unitPrice = _resolvePriceTier(product, batchToUse);

    final idx = _cartItems.indexWhere(
        (i) => i.product.id == product.id && i.batch.id == batchToUse.id);

    if (idx >= 0) {
      if (_cartItems[idx].quantity < batchToUse.stockCount) {
        _cartItems[idx].quantity++;
      }
    } else {
      _cartItems.add(InvoiceItem(
        product: product,
        batch: batchToUse,
        quantity: 1,
        freeQuantity: 0,
        unitPrice: unitPrice,
        taxPercent: product.taxPercent,
      ));
    }
    notifyListeners();
  }

  void updateQuantity(InvoiceItem item, int newQty) {
    if (newQty <= 0) {
      _cartItems.remove(item);
    } else if (newQty <= item.batch.stockCount) {
      item.quantity = newQty;
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
      id: 'inv_${DateTime.now().millisecondsSinceEpoch}',
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
    // reflects the sale immediately. Free units are included because they are
    // physically dispensed.
    //
    // Note: the authoritative deduction happens server-side in the
    // update_stock_on_sale trigger. When the invoice syncs, the batch row is
    // refreshed from Supabase, so this local adjustment is a display update and
    // not a second deduction against the same stock.
    for (final item in _cartItems) {
      final totalDispensed = item.quantity + item.freeQuantity;
      item.batch.stockCount =
          (item.batch.stockCount - totalDispensed).clamp(0, item.batch.stockCount);
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
