import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/invoice_model.dart';
import '../../models/product_model.dart';
import '../../models/selling_unit_model.dart';
import '../../models/customer_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/accounting_provider.dart';
import '../../providers/company_profile_provider.dart';
import '../../providers/customer_provider.dart';
import '../../services/sync_service.dart';
import '../../services/razorpay_web_service.dart';
import 'inventory_view.dart';
import '../../services/printing_service.dart';
import '../../services/support_service.dart';
import '../common/pharmacist_pin_dialog.dart';
import '../common/barcode_scanner_modal.dart';
import '../../utils/logger.dart';

class PosBillingView extends StatefulWidget {
  const PosBillingView({super.key});

  @override
  State<PosBillingView> createState() => _PosBillingViewState();
}

class _PosBillingViewState extends State<PosBillingView> with WidgetsBindingObserver {
  final _searchCtrl   = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _custNameCtrl  = TextEditingController(text: 'Walk-in Customer');
  final _custPhoneCtrl = TextEditingController(text: '+447747571513');
  final _custEmailCtrl = TextEditingController();
  final _custAddressCtrl = TextEditingController();
  final _custDlCtrl = TextEditingController();
  final _custGstinCtrl = TextEditingController();
  final _docNameCtrl   = TextEditingController(text: 'Dr. A. Smith');
  final _docMciCtrl    = TextEditingController(text: 'MCI-88492');
  String _searchQuery  = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    _custEmailCtrl.dispose();
    _custAddressCtrl.dispose();
    _custDlCtrl.dispose();
    _custGstinCtrl.dispose();
    _docNameCtrl.dispose();
    _docMciCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh inventory when app resumes (helps with new medicines availability)
    if (state == AppLifecycleState.resumed) {
      final inventory = Provider.of<InventoryProvider>(context, listen: false);
      inventory.refreshFromDatabase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context);
    final pos       = Provider.of<PosProvider>(context);
    final products  = inventory.searchProducts(_searchQuery);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        if (constraints.maxWidth < Bp.mobile) {
          return _mobilLayout(ctx, inventory, pos, products);
        }
        return _desktopLayout(ctx, inventory, pos, products);
      },
    );
  }

  // ── Desktop: catalog | cart side-by-side ─────────────────────────────────
  Widget _desktopLayout(BuildContext ctx, InventoryProvider inv,
      PosProvider pos, List products) {
    return Row(
      children: [
        Expanded(
          flex: 6,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _searchBar(ctx, inv),
                const SizedBox(height: 14),
                Expanded(child: _productGrid(ctx, products, pos)),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 4,
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: SingleChildScrollView(
              child: _cartPanel(ctx, pos),
            ),
          ),
        ),
      ],
    );
  }

  // ── Mobile: catalog → cart bottom sheet ──────────────────────────────────
  Widget _mobilLayout(BuildContext ctx, InventoryProvider inv,
      PosProvider pos, List products) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          child: _searchBar(ctx, inv),
        ),
        Expanded(child: _productGrid(ctx, products, pos)),
        _MobileCartBar(
          posProvider: pos,
          onTap: () => _showCartSheet(ctx, pos),
        ),
      ],
    );
  }

  void _showCartSheet(BuildContext context, PosProvider pos) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, sc) => Padding(
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  controller: sc,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: _cartPanel(ctx, pos),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Search bar ────────────────────────────────────────────────────────────
  Widget _searchBar(BuildContext context, InventoryProvider inv) {
    return Row(
      children: [
        // Refresh button to reload inventory from database
        IconButton(
          icon: inv.isSyncing 
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh, color: AppTheme.primaryBlue),
          tooltip: 'Refresh inventory from database',
          onPressed: inv.isSyncing ? null : () async {
            // Force reload from Supabase
            await inv.refreshFromDatabase();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('? Inventory refreshed: ${inv.products.length} products loaded'),
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          },
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _searchCtrl,
            autofocus: !context.isMobile,
            decoration: InputDecoration(
              hintText: 'Search product / salt / barcode...',
              prefixIcon:
                  const Icon(Icons.qr_code_scanner, color: AppTheme.primaryBlue),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      })
                  : null,
            ),
            onChanged: (v) => setState(() => _searchQuery = v),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          ),
          onPressed: () async {
            final code = await BarcodeScannerModal.show(context);
            if (code == null || !mounted) return;
            final scanned = code.trim();
            if (scanned.isEmpty) return;

            _searchCtrl.text = scanned;
            setState(() => _searchQuery = scanned);

            // A scan that matches nothing in the catalogue almost always means
            // the medicine has not been added yet. Offer to create it with the
            // barcode already filled in, instead of leaving an empty grid.
            final known = inv.products.any((p) =>
                p.barcode.trim().toLowerCase() == scanned.toLowerCase());
            if (!known) _promptAddUnknownBarcode(scanned);
          },
          icon: const Icon(Icons.camera_alt, size: 18),
          label: const Text('Scan'),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: DropdownButton<String>(
            value: context.watch<PosProvider>().pricingTier,
            isDense: true,
            items: ['Retail', 'PTR', 'Wholesale', 'Distributor', 'Loyalty']
                .map((t) => DropdownMenuItem(
                    value: t,
                    child: Text(t, style: const TextStyle(fontSize: 12))))
                .toList(),
            // Writes to PosProvider, which is what actually resolves line
            // prices. It previously set InventoryProvider.pricingTier, which no
            // pricing path reads, so changing the tier did nothing to the cart.
            onChanged: (t) {
              if (t == null) return;
              context.read<PosProvider>().setPricingTier(t);
              inv.setPricingTier(t);
            },
          ),
        ),
      ],
    );
  }

  /// Unknown barcode -> offer to add the medicine with the code prefilled.
  void _promptAddUnknownBarcode(String barcode) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 6),
        backgroundColor: AppTheme.warningAmber,
        content: Text('No product matches barcode $barcode.'),
        action: SnackBarAction(
          label: 'Add Medicine',
          textColor: Colors.white,
          onPressed: () {
            // Hand the scanned code to Inventory so the operator does not have
            // to retype a 13 digit number.
            InventoryView.pendingBarcode = barcode;
            Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const InventoryView()),
            ).then((_) {
              // Auto-refresh inventory when returning from Add Medicine
              final inventory = Provider.of<InventoryProvider>(context, listen: false);
              inventory.refreshFromDatabase().then((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('🔄 Inventory refreshed: ${inventory.products.length} medicines available'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppTheme.successGreen,
                    ),
                  );
                }
              });
            });
          },
        ),
      ),
    );
  }

  // -- Retail / wholesale mode switch -----------------------------------------
  Widget _billingModeBar(BuildContext context, PosProvider pos) {
    final profile = context.watch<CompanyProfileProvider>().profile;
    // A retail-only pharmacy has no use for the wholesale switch.
    final wholesaleAllowed =
        profile.businessType.toLowerCase() != 'retail';

    if (!wholesaleAllowed) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'retail',
                label: Text('Retail', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.storefront, size: 14),
              ),
              ButtonSegment(
                value: 'wholesale',
                label: Text('Wholesale', style: TextStyle(fontSize: 12)),
                icon: Icon(Icons.warehouse, size: 14),
              ),
            ],
            selected: {pos.billingType},
            onSelectionChanged: (s) => pos.setBillingType(s.first),
          ),
          if (pos.isWholesale) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _custGstinCtrl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                isDense: true,
                labelText: 'Buyer GSTIN (required for wholesale)',
                prefixIcon: Icon(Icons.badge_outlined, size: 18),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: pos.setCustomerGstin,
            ),
            const SizedBox(height: 4),
            const Text(
              'Wholesale lines are priced at PTR.',
              style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  // ── Product grid � adaptive columns ───────────────────────────────────────
  Widget _productGrid(
      BuildContext context, List products, PosProvider pos) {
    if (products.isEmpty) {
      return const Center(
        child: Text('No matching medicines found.',
            style: TextStyle(color: AppTheme.textMuted)),
      );
    }
    return LayoutBuilder(
      builder: (ctx, constraints) {
        final cols = (constraints.maxWidth / 180).floor().clamp(1, 4);
        return GridView.builder(
          padding: const EdgeInsets.only(bottom: 12),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: 1.35,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: products.length,
          itemBuilder: (ctx, i) {
            final product = products[i];
            final batch = product.fefoBatch;
            final outOfStock = batch == null || batch.stockCount <= 0;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: product.requiresPharmacistPin
                      ? AppTheme.errorRed.withOpacity(0.4)
                      : Colors.grey.shade300,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(product.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (product.isScheduleH || product.isScheduleH1)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color:
                                  AppTheme.errorRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              product.isScheduleH1 ? 'H1' : 'H',
                              style: const TextStyle(
                                  color: AppTheme.errorRed,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                    Text(product.genericSalt,
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    // Manufacturer/Brand display
                    if (product.manufacturer.isNotEmpty)
                      Text('Mfg: ${product.manufacturer}',
                          style: const TextStyle(
                              fontSize: 9, 
                              color: AppTheme.primaryBlue,
                              fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    if (batch != null)
                      Text(
                        'FEFO: ${batch.batchNumber}  '
                        'Exp: ${batch.expDate.month}/${batch.expDate.year}',
                        style: const TextStyle(
                            fontSize: 10, color: AppTheme.successGreen),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('₹${batch?.sellingPrice.toStringAsFixed(0) ?? '0'}',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryBlue)),
                              Text('Stock: ${product.totalStock}',
                                  style: TextStyle(
                                      fontSize: 10,
                                      color: outOfStock
                                          ? AppTheme.errorRed
                                          : AppTheme.textMuted)),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: outOfStock
                                ? Colors.grey
                                : AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: const Size(36, 28),
                          ),
                          onPressed:
                              outOfStock ? null : () => _showQuantityDialog(context, product, pos),
                          child: const Icon(Icons.add, size: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // -- Cart panel (desktop inline + mobile sheet) --
  Widget _cartPanel(BuildContext context, PosProvider pos) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Branch selector
        Row(
          children: [
            const Icon(Icons.store_outlined, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            const Text('Branch:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: pos.branch,
                isDense: true,
                isExpanded: true,
                items: pos.branches.map((b) =>
                  DropdownMenuItem(value: b, child: Text(b, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: (b) { if (b != null) pos.setBranch(b); },
              ),
            ),
          ],
        ),
        const Divider(height: 10),
        _billingModeBar(context, pos),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Billing Cart',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
            if (pos.cartItems.isNotEmpty)
              TextButton.icon(
                onPressed: pos.clearCart,
                icon: const Icon(Icons.delete_outline, size: 16, color: AppTheme.errorRed),
                label: const Text('Clear', style: TextStyle(color: AppTheme.errorRed, fontSize: 11)),
              ),
          ],
        ),
        const Divider(height: 12),
        
        // Customer Selection Section
        Row(
          children: [
            const Icon(Icons.person, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            const Text('Customer:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const Spacer(),
            if (pos.selectedCustomer != null)
              TextButton.icon(
                onPressed: () => _showCustomerSelector(context, pos),
                icon: const Icon(Icons.edit, size: 14),
                label: const Text('Change', style: TextStyle(fontSize: 11)),
              )
            else
              TextButton.icon(
                onPressed: () => _showCustomerSelector(context, pos),
                icon: const Icon(Icons.person_search, size: 14),
                label: const Text('Select Customer', style: TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        
        // Customer Details Input
        Row(children: [
          Expanded(child: TextField(controller: _custNameCtrl,
              decoration: const InputDecoration(labelText: 'Customer Name', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(v, _custPhoneCtrl.text,
                email: _custEmailCtrl.text, address: _custAddressCtrl.text, dlNo: _custDlCtrl.text))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _custPhoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, v,
                email: _custEmailCtrl.text, address: _custAddressCtrl.text, dlNo: _custDlCtrl.text))),
        ]),
        const SizedBox(height: 8),
        
        // Enhanced Customer Details (Email & Address)
        Row(children: [
          Expanded(child: TextField(controller: _custEmailCtrl,
              decoration: const InputDecoration(labelText: 'Email (Optional)', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, _custPhoneCtrl.text,
                email: v, address: _custAddressCtrl.text, dlNo: _custDlCtrl.text))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _custAddressCtrl,
              decoration: const InputDecoration(labelText: 'Address (Optional)', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, _custPhoneCtrl.text,
                email: _custEmailCtrl.text, address: v, dlNo: _custDlCtrl.text))),
        ]),
        const SizedBox(height: 8),
        
        // DL Number (Optional for retail customers)
        TextField(controller: _custDlCtrl,
            decoration: const InputDecoration(
              labelText: 'Drug License (Optional for Retail)', 
              isDense: true,
              helperText: 'Required only for wholesale customers',
              helperStyle: TextStyle(fontSize: 10, color: AppTheme.textMuted),
            ),
            onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, _custPhoneCtrl.text,
              email: _custEmailCtrl.text, address: _custAddressCtrl.text, dlNo: v)),
        const SizedBox(height: 8),
        
        // Doctor Information
        Row(children: [
          Expanded(child: TextField(controller: _docNameCtrl,
              decoration: const InputDecoration(labelText: 'Doctor Name', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, _custPhoneCtrl.text, 
                docName: v, docMci: _docMciCtrl.text,
                email: _custEmailCtrl.text, address: _custAddressCtrl.text, dlNo: _custDlCtrl.text))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _docMciCtrl,
              decoration: const InputDecoration(labelText: 'MCI No', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, _custPhoneCtrl.text, 
                docName: _docNameCtrl.text, docMci: v,
                email: _custEmailCtrl.text, address: _custAddressCtrl.text, dlNo: _custDlCtrl.text))),
        ]),
        const SizedBox(height: 12),
        // Cart items with free qty + item discount
        if (pos.cartItems.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Cart is empty.', style: TextStyle(fontSize: 12, color: AppTheme.textMuted))),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pos.cartItems.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = pos.cartItems[index];
              final allowsLoose = item.product.allowLooseSales;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Row(children: [
                      Expanded(child: Text(item.product.name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                      if (item.product.requiresPharmacistPin)
                        Container(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(color: AppTheme.errorRed.withOpacity(0.1), borderRadius: BorderRadius.circular(3)),
                          child: const Text('PIN', style: TextStyle(fontSize: 9, color: AppTheme.errorRed, fontWeight: FontWeight.bold))),
                      if (allowsLoose)
                        Container(
                          margin: const EdgeInsets.only(left: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppTheme.successGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: const Text('LOOSE', 
                            style: TextStyle(fontSize: 9, color: AppTheme.successGreen, fontWeight: FontWeight.bold)),
                        ),
                    ]),
                    subtitle: Text(
                      'Mfg: ${item.product.manufacturer ?? 'N/A'}  |  HSN: ${item.product.hsnCode}  |  Batch: ${item.batch.batchNumber}  |  '
                      'GST: ${item.taxPercent.toStringAsFixed(0)}%  |  ${item.product.packagingLabel}',
                      style: const TextStyle(fontSize: 10)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(icon: const Icon(Icons.remove_circle_outline, size: 18),
                          onPressed: () => pos.updateQuantity(item, item.quantity - 1)),
                      Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      IconButton(icon: const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: () => pos.updateQuantity(item, item.quantity + 1)),
                      Text(' =Rs.${item.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    ]),
                  ),
                  
                  // Loose unit controls (if enabled)
                  if (allowsLoose) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                      child: Row(
                        children: [
                          const Icon(Icons.medical_services, size: 13, color: AppTheme.primaryBlue),
                          const SizedBox(width: 4),
                          const Text('Unit:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 2,
                            child: DropdownButton<SellingUnit>(
                              value: item.sellingUnit ?? SellingUnit.pack,
                              isDense: true,
                              isExpanded: true,
                              items: [
                                DropdownMenuItem(
                                  value: SellingUnit.pack,
                                  child: Text(item.product.packagingLabel, 
                                    style: const TextStyle(fontSize: 11)),
                                ),
                                DropdownMenuItem(
                                  value: SellingUnit.strip,
                                  child: Text('Strip', style: const TextStyle(fontSize: 11)),
                                ),
                                DropdownMenuItem(
                                  value: SellingUnit.tablet,
                                  child: Text('Tablet', style: const TextStyle(fontSize: 11)),
                                ),
                                DropdownMenuItem(
                                  value: SellingUnit.capsule,
                                  child: Text('Capsule', style: const TextStyle(fontSize: 11)),
                                ),
                                DropdownMenuItem(
                                  value: SellingUnit.ml,
                                  child: Text('ML', style: const TextStyle(fontSize: 11)),
                                ),
                                DropdownMenuItem(
                                  value: SellingUnit.vial,
                                  child: Text('Vial', style: const TextStyle(fontSize: 11)),
                                ),
                              ],
                              onChanged: (unit) {
                                if (unit != null) pos.updateSellingUnit(item, unit);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text('Loose:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 4),
                          SizedBox(
                            width: 50,
                            child: TextField(
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                isDense: true,
                                hintText: '0',
                                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                suffixText: item.product.baseUnit?.label ?? 'U',
                                suffixStyle: const TextStyle(fontSize: 9, color: AppTheme.textMuted),
                              ),
                              style: const TextStyle(fontSize: 11),
                              controller: TextEditingController(text: '${item.looseUnits ?? 0}'),
                              onChanged: (v) {
                                final loose = int.tryParse(v) ?? 0;
                                pos.updateLooseQuantity(item, loose);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.looseUnits != null && item.looseUnits! > 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(
                          '  ?? ${item.quantity} ${item.sellingUnit?.label ?? 'pack'}${item.quantity != 1 ? 's' : ''} + ${item.looseUnits} loose ${item.product.baseUnit?.label ?? 'units'}',
                          style: const TextStyle(fontSize: 10, color: AppTheme.successGreen, fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                  
                  // Free qty + item-level discount row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                    child: Row(children: [
                      const Icon(Icons.card_giftcard, size: 13, color: AppTheme.successGreen),
                      const SizedBox(width: 3),
                      const Text('Free:', style: TextStyle(fontSize: 11, color: AppTheme.successGreen)),
                      const SizedBox(width: 4),
                      SizedBox(width: 46, child: TextField(
                        controller: TextEditingController(text: item.freeQuantity.toString()),
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, hintText: '0',
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                        style: const TextStyle(fontSize: 11),
                        onChanged: (v) => pos.updateFreeQuantity(item, int.tryParse(v) ?? 0))),
                      // Show scheme indicator if active
                      if (item.product.hasActiveScheme) ...[
                        const SizedBox(width: 4),
                        Tooltip(
                          message: item.product.schemeDisplay,
                          child: const Icon(Icons.local_offer, size: 12, color: AppTheme.primaryBlue),
                        ),
                      ],
                      const SizedBox(width: 10),
                      const Icon(Icons.local_offer, size: 13, color: AppTheme.accentOrange),
                      const SizedBox(width: 3),
                      const Text('Disc(Rs.):', style: TextStyle(fontSize: 11, color: AppTheme.accentOrange)),
                      const SizedBox(width: 4),
                      SizedBox(width: 56, child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, hintText: '0.00',
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                        style: const TextStyle(fontSize: 11),
                        onChanged: (v) => pos.updateLineDiscount(item, double.tryParse(v) ?? 0))),
                      const Spacer(),
                      Text('Net: Rs.${item.lineTotal.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                    ]),
                  ),
                ],
              );
            },
          ),
        const Divider(height: 12),
        // Totals
        _totalRow('Subtotal (Gross):',
            'Rs.${(pos.subtotal + pos.effectiveDiscount + pos.cartItems.fold<double>(0, (s, i) => s + i.lineDiscount)).toStringAsFixed(2)}', bold: false),
        if (pos.cartItems.any((i) => i.lineDiscount > 0))
          _totalRow('Item Discounts:', '-Rs.${pos.cartItems.fold<double>(0, (s, i) => s + i.lineDiscount).toStringAsFixed(2)}',
              bold: false, valueColor: AppTheme.accentOrange),
        _totalRow('Total GST:', 'Rs.${pos.totalTax.toStringAsFixed(2)}', bold: false, valueColor: AppTheme.textMuted),
        const SizedBox(height: 6),
        // Invoice-level discount
        Row(children: [
          const Icon(Icons.discount_outlined, size: 14, color: AppTheme.accentOrange),
          const SizedBox(width: 4),
          const Text('Invoice Disc (Rs.):', style: TextStyle(fontSize: 12, color: AppTheme.accentOrange)),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _discountCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(isDense: true, hintText: '0.00'),
              onChanged: (v) => pos.setDiscount(double.tryParse(v) ?? 0))),
        ]),
        if (pos.effectiveDiscount > 0)
          Padding(padding: const EdgeInsets.only(top: 4),
            child: _totalRow('Invoice Discount:', '-Rs.${pos.effectiveDiscount.toStringAsFixed(2)}',
                bold: false, valueColor: AppTheme.accentOrange)),
        if (pos.discountAmount > pos.subtotal && pos.subtotal > 0)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              'Discount capped at the subtotal (Rs.${pos.subtotal.toStringAsFixed(2)}).',
              style: const TextStyle(fontSize: 11, color: AppTheme.errorRed),
            ),
          ),
        const SizedBox(height: 8),
        
        // Round-off display (only if there's a difference)
        if (pos.roundOff != 0) 
          _totalRow('Round Off:', 'Rs.${pos.roundOff.toStringAsFixed(2)}', 
              bold: false, valueColor: pos.roundOff > 0 ? AppTheme.successGreen : AppTheme.errorRed),
        
        // Grand total and payable amount
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withOpacity(0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
          ),
          child: Column(
            children: [
              // Grand Total (exact calculation)
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('GRAND TOTAL',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                Text('Rs.${pos.grandTotal.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
              ]),
              
              // Payable Amount (rounded for cash transactions)
              if (pos.roundOff != 0) ...[
                const Divider(height: 8, color: AppTheme.primaryBlue),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('PAYABLE AMOUNT',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                  Text('Rs.${pos.payableTotal.toStringAsFixed(0)}',
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                ]),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // Payment chips - Cash and Razorpay
        Wrap(spacing: 4, runSpacing: 4, children: [
          PaymentMode.cash,
          PaymentMode.razorpay,
        ].map((mode) {
          final sel = pos.paymentMode == mode;
          return ChoiceChip(
            label: Text(mode.name.toUpperCase()),
            selected: sel,
            selectedColor: AppTheme.primaryBlue,
            labelStyle: TextStyle(color: sel ? Colors.white : Colors.black87, fontSize: 10),
            onSelected: (_) => pos.setPaymentMode(mode),
          );
        }).toList()),
        const SizedBox(height: 12),
        // Invoice Template Selector
        Row(
          children: [
            const Icon(Icons.description_outlined, size: 16, color: AppTheme.primaryBlue),
            const SizedBox(width: 6),
            const Text('Invoice Type:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(width: 8),
            Expanded(
              child: DropdownButton<String>(
                value: pos.invoiceTemplate,
                isDense: true,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: 'tax_invoice',
                    child: Text('TAX INVOICE (Customer)', style: TextStyle(fontSize: 12)),
                  ),
                  DropdownMenuItem(
                    value: 'gst_bill',
                    child: Text('GST BILL (B2B Detailed)', style: TextStyle(fontSize: 12)),
                  ),
                ],
                onChanged: (template) {
                  if (template != null) pos.setInvoiceTemplate(template);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // PIN warning
        if (pos.requiresPharmacistPin)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withOpacity(0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.errorRed.withOpacity(0.4)),
            ),
            child: Row(children: const [
              Icon(Icons.security, color: AppTheme.errorRed, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Contains Schedule H/H1 / Narcotic medicines.\nAuthorised Pharmacist PIN required at checkout.',
                style: TextStyle(fontSize: 11, color: AppTheme.errorRed, height: 1.4))),
            ]),
          ),
        // Checkout button
        SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: pos.requiresPharmacistPin ? AppTheme.errorRed : AppTheme.primaryBlue),
            onPressed: pos.cartItems.isEmpty ? null : () => _handleCheckout(context, pos),
            icon: Icon(pos.requiresPharmacistPin ? Icons.security : Icons.check_circle, size: 18),
            label: Text(
              pos.requiresPharmacistPin ? 'Authorise & Complete Sale' : 'Complete Sale & Print',
              style: const TextStyle(fontSize: 13)),
          ),
        ),
      ],
    );
  }
  Widget _totalRow(
    String label,
    String value, {
    bool bold = true,
    double labelSize = 12,
    double valueSize = 12,
    Color? valueColor,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: labelSize,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                color: bold ? AppTheme.primaryBlue : null)),
        Text(value,
            style: TextStyle(
                fontSize: valueSize,
                fontWeight:
                    bold ? FontWeight.bold : FontWeight.normal,
                color: valueColor ??
                    (bold ? AppTheme.primaryBlue : null))),
      ],
    );
  }

  // ── Checkout logic ────────────────────────────────────────────────────────
  Future<void> _handleCheckout(
      BuildContext context, PosProvider pos) async {
    final sync       = Provider.of<SyncService>(context, listen: false);
    final accounting = Provider.of<AccountingProvider>(context, listen: false);
    // A wholesale tax invoice without the buyer's GSTIN is not filable, so the
    // sale is blocked here rather than persisted and corrected later.
    if (pos.isWholesale &&
        (pos.customerGstin == null || pos.customerGstin!.length != 15)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter the buyer 15 character GSTIN for a wholesale sale.'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    String? pinBy;
    String? pharmacistId;
    if (pos.requiresPharmacistPin) {
      // Records who actually authorised. The old value wrote the demo PIN onto
      // the Schedule H register, which leaked the secret and was useless as an
      // audit trail.
      final result = await PharmacistPinDialog.show(context);
      if (!result.approved) return;
      pinBy = result.pharmacistName;
      pharmacistId = result.pharmacistId;
    }

    // Handle Razorpay payment (online payment gateway)
    if (pos.paymentMode == PaymentMode.razorpay) {
      final paymentCompleted = await _handleRazorpayPayment(context, pos);
      if (!paymentCompleted) return; // User cancelled or payment failed
    }

    final invoice = pos.checkout(
      isOnline: sync.isOnline,
      pinApprovedBy: pinBy,
      authorizedPharmacistId: pharmacistId,
    );
    
    // Update inventory stock counts to reflect the sale
    final inventory = Provider.of<InventoryProvider>(context, listen: false);
    for (final item in invoice.items) {
      final totalDispensed = item.quantity + item.freeQuantity;
      inventory.reduceStockForSale(
        productId: item.product.id,
        batchId: item.batch.id,
        quantity: totalDispensed,
      );
    }
    
    sync.queueInvoiceForSync(invoice);
    accounting.recordInvoiceSale(invoice);
    _discountCtrl.clear();
    _custGstinCtrl.clear();

    if (!mounted) return;
    // ignore: use_build_context_synchronously
    _showSuccessDialog(this.context, invoice);
  }

  void _showSuccessDialog(BuildContext context, InvoiceModel invoice) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen, size: 28),
            SizedBox(width: 10),
            Flexible(child: Text('Invoice Billed!')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Invoice: ${invoice.invoiceNumber}',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
            Text('${invoice.customerName} � ${invoice.customerPhone}'),
            Text('Total: ?${invoice.grandTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 14),
            const Text('Distribute receipt:',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppTheme.primaryBlue),
            tooltip: 'Print PDF',
            onPressed: () {
              final provider = context.read<PosProvider>();
              PrintingService.printInvoice(
                invoice,
                profile: context.read<CompanyProfileProvider>().profile,
                templateType: provider.invoiceTemplate,
              );
            },
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366)),
            onPressed: () => SupportService.shareInvoiceWhatsApp(invoice),
            icon: const Icon(Icons.send),
            label: const Text('WhatsApp'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Next Sale'),
          ),
        ],
      ),
    );
  }

  /// Handle Razorpay payment (reuses existing subscription integration)
  Future<bool> _handleRazorpayPayment(BuildContext context, PosProvider pos) async {
    try {
      if (!mounted) return false;
      
      final razorpayService = RazorpayWebService();
      final amount = pos.payableTotal; // Amount in rupees (rounded for payment)
      
      // Validate amount
      if (amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid payment amount'),
              backgroundColor: AppTheme.errorRed,
            ),
          );
        }
        return false;
      }
      
      // Show loading dialog
      if (!mounted) return false;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Step 1: Create Razorpay order
      Logger.info('POS: Creating Razorpay order for ₹$amount');
      final orderResult = await razorpayService.createRazorpayOrder(
        amount: amount,
        currency: 'INR',
        transactionId: 'pos_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (!mounted) return false;
      Navigator.pop(context); // Close loading dialog
      
      if (!orderResult['success']) {
        final error = orderResult['error'] ?? 'Failed to create order';
        Logger.error('POS: Razorpay order creation failed', error: error);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment setup failed: $error'),
              backgroundColor: AppTheme.errorRed,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return false;
      }
      
      final orderId = orderResult['order_id'] as String;
      Logger.info('POS: Razorpay order created: $orderId');
      
      // Step 2: Open Razorpay Web Checkout
      bool paymentSuccess = false;
      String? paymentId;
      String? signature;
      String? lastError;
      
      await razorpayService.openCheckout(
        orderId: orderId,
        amount: amount,
        currency: 'INR',
        customerName: pos.customerName.isEmpty ? 'Customer' : pos.customerName,
        customerEmail: 'customer@pharmacy.com', // Generic email for POS
        customerPhone: pos.customerPhone.isEmpty ? '9999999999' : pos.customerPhone,
        description: 'Pharmacy POS Payment - Invoice Total: ₹${amount.toStringAsFixed(2)}',
        onSuccess: (response) async {
          try {
            paymentId = response['razorpay_payment_id'] as String?;
            signature = response['razorpay_signature'] as String?;
            Logger.info('POS: Razorpay payment success - $paymentId');
            
            if (paymentId == null || signature == null) {
              lastError = 'Payment response missing required fields';
              paymentSuccess = false;
              return;
            }
            
            // Step 3: Verify payment signature (CRITICAL - Server-side verification)
            final verifyResult = await razorpayService.verifyPayment(
              orderId: orderId,
              paymentId: paymentId!,
              signature: signature!,
            );
            
            if (verifyResult['verified'] == true) {
              Logger.info('POS: Payment signature verified successfully');
              paymentSuccess = true;
            } else {
              Logger.error('POS: Payment signature verification FAILED - PAYMENT NOT AUTHORIZED');
              lastError = 'Payment verification failed. Transaction not authorized.';
              paymentSuccess = false;
            }
          } catch (e) {
            Logger.error('POS: Error in payment success handler: $e');
            lastError = 'Error processing payment success: $e';
            paymentSuccess = false;
          }
        },
        onError: (error) {
          final errorCode = error['code'] ?? 'UNKNOWN';
          final errorDesc = error['description'] ?? 'Payment failed';
          lastError = '$errorCode: $errorDesc';
          Logger.error('POS: Razorpay payment error', error: lastError);
          paymentSuccess = false;
        },
      );
      
      // Wait briefly for async handlers to complete
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (paymentSuccess) {
        Logger.info('POS: Payment verified - proceeding with sale');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment successful! Payment ID: ${paymentId?.substring(0, 12)}...'),
              backgroundColor: AppTheme.successGreen,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return true;
      } else {
        Logger.info('POS: Payment not completed or verification failed: $lastError');
        if (mounted && lastError != null && !lastError!.contains('USER_CANCELLED')) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Payment failed: $lastError'),
              backgroundColor: AppTheme.errorRed,
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return false;
      }
      
    } catch (e) {
      Logger.error('POS: Razorpay payment exception', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment system error: ${e.toString().replaceAll('Instance of \'', '').replaceAll('\'', '')}'),
            backgroundColor: AppTheme.errorRed,
            duration: const Duration(seconds: 5),
          ),
        );
      }
      return false;
    }
  }
  
  /// Show dialog to enter strips + loose tablets quantity
  void _showQuantityDialog(BuildContext context, ProductModel product, PosProvider pos) {
    final stripsCtrl = TextEditingController(text: '0');
    final looseCtrl = TextEditingController(text: '1');
    
    // Get pack configuration
    final baseUnitsPerPack = product.baseUnitsPerPack ?? 10;
    final packLabel = product.packagingConfig?.label ?? '1�$baseUnitsPerPack';
    final batch = product.fefoBatch;
    
    if (batch == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No available batch for this product')),
      );
      return;
    }
    
    final stripPrice = batch.mrp;
    final tabletPrice = stripPrice / baseUnitsPerPack;
    
    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Calculate totals
            final strips = int.tryParse(stripsCtrl.text) ?? 0;
            final loose = int.tryParse(looseCtrl.text) ?? 0;
            
            // Auto-normalize if loose >= baseUnitsPerPack
            int normalizedStrips = strips;
            int normalizedLoose = loose;
            if (loose >= baseUnitsPerPack) {
              normalizedStrips = strips + (loose ~/ baseUnitsPerPack);
              normalizedLoose = loose % baseUnitsPerPack;
            }
            
            final totalTablets = (normalizedStrips * baseUnitsPerPack) + normalizedLoose;
            final stripAmount = normalizedStrips * stripPrice;
            final looseAmount = normalizedLoose * tabletPrice;
            final totalAmount = stripAmount + looseAmount;
            
            // Check stock
            final availableTablets = batch.totalAvailableUnits(baseUnitsPerPack);
            final isStockSufficient = totalTablets <= availableTablets;
            
            return AlertDialog(
              title: Text(product.name),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pack info
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pack: $packLabel', style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('Strip MRP: ?${stripPrice.toStringAsFixed(2)}'),
                          Text('Per Tablet: ?${tabletPrice.toStringAsFixed(2)}'),
                          Text('Available: $availableTablets tablets', 
                            style: TextStyle(
                              color: isStockSufficient ? Colors.green : Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    
                    // Strips input
                    TextField(
                      controller: stripsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Strips',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 12),
                    
                    // Loose tablets input
                    TextField(
                      controller: looseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Loose Tablets',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.medication),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    const SizedBox(height: 16),
                    
                    // Calculation display
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (normalizedStrips != strips || normalizedLoose != loose)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                'Normalized: $normalizedStrips Strips + $normalizedLoose Tablets',
                                style: TextStyle(color: Colors.orange.shade700, fontSize: 12),
                              ),
                            ),
                          Text(
                            'Total: $totalTablets Tablets',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const Divider(),
                          if (normalizedStrips > 0)
                            Text('$normalizedStrips Strips � ?${stripPrice.toStringAsFixed(2)} = ?${stripAmount.toStringAsFixed(2)}'),
                          if (normalizedLoose > 0)
                            Text('$normalizedLoose Tablets � ?${tabletPrice.toStringAsFixed(2)} = ?${looseAmount.toStringAsFixed(2)}'),
                          const Divider(),
                          Text(
                            'Amount: ?${totalAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryBlue),
                          ),
                          if (!isStockSufficient)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                'INSUFFICIENT STOCK!',
                                style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.bold),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: !isStockSufficient || totalTablets == 0 ? null : () {
                    // Add to cart with mixed quantity
                    final saleQty = SaleQuantity.mixed(
                      packs: normalizedStrips,
                      loose: normalizedLoose,
                      sellingUnit: SellingUnit.tablet,
                    );
                    pos.addToCartWithQuantity(product, saleQty);
                    Navigator.pop(context);
                  },
                  child: const Text('Add to Cart'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show customer selector dialog
  void _showCustomerSelector(BuildContext context, PosProvider pos) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Customer'),
        content: SizedBox(
          width: 500,
          height: 400,
          child: Consumer<CustomerProvider>(
            builder: (context, customerProvider, child) {
              if (customerProvider.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }
              
              final customers = customerProvider.allCustomers;
              
              return Column(
                children: [
                  // Walk-in Customer Option
                  ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: const Text('Walk-in Customer'),
                    subtitle: const Text('No customer details required'),
                    selected: pos.selectedCustomer == null,
                    onTap: () {
                      pos.setSelectedCustomer(null);
                      _updateCustomerFields(pos);
                      Navigator.pop(ctx);
                    },
                  ),
                  const Divider(),
                  
                  // Existing Customers List
                  Expanded(
                    child: customers.isEmpty
                        ? const Center(
                            child: Text('No customers found. Add customers in Customer Management.'),
                          )
                        : ListView.builder(
                            itemCount: customers.length,
                            itemBuilder: (context, index) {
                              final customer = customers[index];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: _getCustomerTypeColor(customer.customerType).withOpacity(0.1),
                                  child: Icon(
                                    _getCustomerTypeIcon(customer.customerType),
                                    color: _getCustomerTypeColor(customer.customerType),
                                  ),
                                ),
                                title: Text(customer.name),
                                subtitle: Text(
                                  '${customer.phone} • ${customer.email}\n${customer.customerType.label}',
                                ),
                                isThreeLine: true,
                                selected: pos.selectedCustomer?.id == customer.id,
                                onTap: () {
                                  pos.setSelectedCustomer(customer);
                                  _updateCustomerFields(pos);
                                  Navigator.pop(ctx);
                                },
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Update customer input fields based on selected customer
  void _updateCustomerFields(PosProvider pos) {
    if (pos.selectedCustomer != null) {
      final customer = pos.selectedCustomer!;
      _custNameCtrl.text = customer.name;
      _custPhoneCtrl.text = customer.phone;
      _custEmailCtrl.text = customer.email;
      _custAddressCtrl.text = customer.fullAddress;
      _custDlCtrl.text = customer.drugLicenseNo ?? '';
      if (customer.gstin != null) {
        _custGstinCtrl.text = customer.gstin!;
      }
    } else {
      // Reset to walk-in customer
      _custNameCtrl.text = 'Walk-in Customer';
      _custPhoneCtrl.text = '';
      _custEmailCtrl.text = '';
      _custAddressCtrl.text = '';
      _custDlCtrl.text = '';
      _custGstinCtrl.text = '';
    }
  }

  /// Get customer type icon
  IconData _getCustomerTypeIcon(CustomerType type) {
    switch (type) {
      case CustomerType.retail:
        return Icons.shopping_cart;
      case CustomerType.wholesale:
        return Icons.business;
      case CustomerType.distributor:
        return Icons.local_shipping;
    }
  }

  /// Get customer type color
  Color _getCustomerTypeColor(CustomerType type) {
    switch (type) {
      case CustomerType.retail:
        return AppTheme.successGreen;
      case CustomerType.wholesale:
        return AppTheme.accentOrange;
      case CustomerType.distributor:
        return AppTheme.primaryBlue;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mobile cart bottom bar
// ─────────────────────────────────────────────────────────────────────────────
class _MobileCartBar extends StatelessWidget {
  final PosProvider posProvider;
  final VoidCallback onTap;

  const _MobileCartBar(
      {required this.posProvider, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final count = posProvider.cartItems
        .fold<int>(0, (s, i) => s + i.quantity);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: posProvider.requiresPharmacistPin
            ? AppTheme.errorRed
            : AppTheme.primaryBlue,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  const Icon(Icons.shopping_cart,
                      color: Colors.white, size: 26),
                  if (count > 0)
                    Positioned(
                      right: -6,
                      top: -6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: AppTheme.accentOrange,
                            shape: BoxShape.circle),
                        child: Text('$count',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  count == 0
                      ? 'Cart is empty � tap to open'
                      : '$count item${count == 1 ? '' : 's'}  �  '
                          '?${posProvider.payableTotal.toStringAsFixed(0)}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
              ),
              const Icon(Icons.keyboard_arrow_up, color: Colors.white70),
            ],
          ),
        ),
      ),
    );
  }
}
