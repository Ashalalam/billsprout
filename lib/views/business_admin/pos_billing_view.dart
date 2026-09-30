import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/invoice_model.dart';
import '../../providers/inventory_provider.dart';
import '../../providers/pos_provider.dart';
import '../../providers/accounting_provider.dart';
import '../../providers/company_profile_provider.dart';
import '../../services/sync_service.dart';
import 'inventory_view.dart';
import '../../services/printing_service.dart';
import '../../services/support_service.dart';
import '../common/pharmacist_pin_dialog.dart';
import '../common/barcode_scanner_modal.dart';

class PosBillingView extends StatefulWidget {
  const PosBillingView({super.key});

  @override
  State<PosBillingView> createState() => _PosBillingViewState();
}

class _PosBillingViewState extends State<PosBillingView> {
  final _searchCtrl   = TextEditingController();
  final _discountCtrl = TextEditingController();
  final _custNameCtrl  = TextEditingController(text: 'Walk-in Customer');
  final _custPhoneCtrl = TextEditingController(text: '+447747571513');
  final _custGstinCtrl = TextEditingController();
  final _docNameCtrl   = TextEditingController(text: 'Dr. A. Smith');
  final _docMciCtrl    = TextEditingController(text: 'MCI-88492');
  String _searchQuery  = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    _discountCtrl.dispose();
    _custNameCtrl.dispose();
    _custPhoneCtrl.dispose();
    _custGstinCtrl.dispose();
    _docNameCtrl.dispose();
    _docMciCtrl.dispose();
    super.dispose();
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

  // â”€â”€ Desktop: catalog | cart side-by-side â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Mobile: catalog â†’ cart bottom sheet â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

  // â”€â”€ Search bar â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _searchBar(BuildContext context, InventoryProvider inv) {
    return Row(
      children: [
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
            );
          },
        ),
      ),
    );
  }

  // ── Retail / wholesale mode switch ─────────────────────────────────────────
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

  // â”€â”€ Product grid â€” adaptive columns â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                      ? AppTheme.errorRed.withValues(alpha: 0.4)
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
                                  AppTheme.errorRed.withValues(alpha: 0.1),
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
                              Text('â‚¹${batch?.mrp.toStringAsFixed(0) ?? '0'}',
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
                              outOfStock ? null : () => pos.addToCart(product),
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
        Row(children: [
          Expanded(child: TextField(controller: _custNameCtrl,
              decoration: const InputDecoration(labelText: 'Customer Name', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(v, _custPhoneCtrl.text))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _custPhoneCtrl,
              decoration: const InputDecoration(labelText: 'Phone', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, v))),
        ]),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: TextField(controller: _docNameCtrl,
              decoration: const InputDecoration(labelText: 'Doctor Name', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, _custPhoneCtrl.text, docName: v, docMci: _docMciCtrl.text))),
          const SizedBox(width: 8),
          Expanded(child: TextField(controller: _docMciCtrl,
              decoration: const InputDecoration(labelText: 'MCI No', isDense: true),
              onChanged: (v) => pos.setCustomerDetails(_custNameCtrl.text, _custPhoneCtrl.text, docName: _docNameCtrl.text, docMci: v))),
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
                          decoration: BoxDecoration(color: AppTheme.errorRed.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(3)),
                          child: const Text('PIN', style: TextStyle(fontSize: 9, color: AppTheme.errorRed, fontWeight: FontWeight.bold))),
                    ]),
                    subtitle: Text(
                      'HSN: ${item.product.hsnCode}  |  Batch: ${item.batch.batchNumber}  |  '
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
                  // Free qty + item-level discount row
                  Padding(
                    padding: const EdgeInsets.fromLTRB(0, 0, 0, 8),
                    child: Row(children: [
                      const Icon(Icons.card_giftcard, size: 13, color: AppTheme.successGreen),
                      const SizedBox(width: 3),
                      const Text('Free:', style: TextStyle(fontSize: 11, color: AppTheme.successGreen)),
                      const SizedBox(width: 4),
                      SizedBox(width: 46, child: TextField(
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(isDense: true, hintText: '0',
                            contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4)),
                        style: const TextStyle(fontSize: 11),
                        onChanged: (v) => pos.updateFreeQuantity(item, int.tryParse(v) ?? 0))),
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
        // Grand total
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.primaryBlue.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('GRAND TOTAL',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
            Text('Rs.${pos.grandTotal.toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
          ]),
        ),
        const SizedBox(height: 10),
        // Payment chips
        Wrap(spacing: 4, runSpacing: 4, children: PaymentMode.values.map((mode) {
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
        // PIN warning
        if (pos.requiresPharmacistPin)
          Container(
            padding: const EdgeInsets.all(10),
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(
              color: AppTheme.errorRed.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.4)),
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

  // â”€â”€ Checkout logic â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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

    final invoice = pos.checkout(
      isOnline: sync.isOnline,
      pinApprovedBy: pinBy,
      authorizedPharmacistId: pharmacistId,
    );
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
            Text('${invoice.customerName} â€” ${invoice.customerPhone}'),
            Text('Total: â‚¹${invoice.grandTotal.toStringAsFixed(2)}'),
            const SizedBox(height: 14),
            const Text('Distribute receipt:',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.print, color: AppTheme.primaryBlue),
            tooltip: 'Print PDF',
            onPressed: () => PrintingService.printInvoice(
              invoice,
              profile: context.read<CompanyProfileProvider>().profile,
            ),
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
}

// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
// Mobile cart bottom bar
// â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
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
                      ? 'Cart is empty â€” tap to open'
                      : '$count item${count == 1 ? '' : 's'}  â€¢  '
                          'â‚¹${posProvider.grandTotal.toStringAsFixed(2)}',
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
