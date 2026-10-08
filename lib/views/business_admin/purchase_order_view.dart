import 'package:flutter/material.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/rtv_model.dart';

// ─── Lightweight PO model (local only until Supabase is wired) ───────────────
class PurchaseOrderModel {
  final String id;
  final String poNumber;
  final String vendorName;
  final String vendorGstin;
  final DateTime orderDate;
  final List<PoLineItem> items;
  String status; // Draft, Sent, Received, Closed

  PurchaseOrderModel({
    required this.id,
    required this.poNumber,
    required this.vendorName,
    required this.vendorGstin,
    required this.orderDate,
    required this.items,
    this.status = 'Draft',
  });

  double get totalAmount =>
      items.fold(0, (s, i) => s + i.totalCost);
}

class PoLineItem {
  final String medicineName;
  final String hsnCode;
  final int quantity;
  final double purchasePrice;
  final double taxPercent;

  PoLineItem({
    required this.medicineName,
    required this.hsnCode,
    required this.quantity,
    required this.purchasePrice,
    required this.taxPercent,
  });

  double get totalCost => quantity * purchasePrice * (1 + taxPercent / 100);
}

// ─── Vendor model ─────────────────────────────────────────────────────────────
class VendorModel {
  final String id;
  String name;
  String gstin;
  String phone;
  String email;
  String address;
  String drugLicenseNo;

  VendorModel({
    required this.id,
    required this.name,
    required this.gstin,
    required this.phone,
    required this.email,
    required this.address,
    required this.drugLicenseNo,
  });
}

// ─── Main View ────────────────────────────────────────────────────────────────
class PurchaseOrderView extends StatefulWidget {
  const PurchaseOrderView({super.key});

  @override
  State<PurchaseOrderView> createState() => _PurchaseOrderViewState();
}

class _PurchaseOrderViewState extends State<PurchaseOrderView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<VendorModel> _vendors = _seedVendors();
  final List<PurchaseOrderModel> _orders = _seedOrders();
  final List<RtvNoteModel> _rtvNotes = _seedRtvNotes();

  static List<VendorModel> _seedVendors() => [
        VendorModel(
          id: 'v_01',
          name: 'LIFESPROUT Pharma Labs',
          gstin: '07AAAPL1234A1Z5',
          phone: '+44 7747 571513',
          email: 'supply@lifesproutcare.com',
          address: 'Pharma Industrial Zone, Unit 7',
          drugLicenseNo: 'WB/DL/2024/9812',
        ),
        VendorModel(
          id: 'v_02',
          name: 'CareSprout Remedies',
          gstin: '27BBBCS5678B1Z2',
          phone: '+91 98765 43210',
          email: 'orders@caresprout.com',
          address: '14 Pharma Park, Mumbai',
          drugLicenseNo: 'MH/DL/2024/4411',
        ),
        VendorModel(
          id: 'v_03',
          name: 'Diabetes Care Ltd',
          gstin: '09CCCDC9012C1Z8',
          phone: '+91 90000 12345',
          email: 'supply@diabetescare.in',
          address: 'Healthcare SEZ, Delhi NCR',
          drugLicenseNo: 'DL/WB/2024/8823',
        ),
      ];

  static List<PurchaseOrderModel> _seedOrders() => [
        PurchaseOrderModel(
          id: 'po_001',
          poNumber: 'PO-2026-0041',
          vendorName: 'LIFESPROUT Pharma Labs',
          vendorGstin: '07AAAPL1234A1Z5',
          orderDate:
              DateTime.now().subtract(const Duration(days: 3)),
          status: 'Received',
          items: [
            PoLineItem(
                medicineName: 'Amoxicillin 500mg Caps',
                hsnCode: '30041010',
                quantity: 500,
                purchasePrice: 75.0,
                taxPercent: 12.0),
            PoLineItem(
                medicineName: 'Metformin 500mg SR',
                hsnCode: '30049080',
                quantity: 300,
                purchasePrice: 32.0,
                taxPercent: 12.0),
          ],
        ),
        PurchaseOrderModel(
          id: 'po_002',
          poNumber: 'PO-2026-0042',
          vendorName: 'CareSprout Remedies',
          vendorGstin: '27BBBCS5678B1Z2',
          orderDate:
              DateTime.now().subtract(const Duration(days: 1)),
          status: 'Sent',
          items: [
            PoLineItem(
                medicineName: 'Paracetamol 650mg Tabs',
                hsnCode: '30049060',
                quantity: 1000,
                purchasePrice: 18.0,
                taxPercent: 12.0),
          ],
        ),
      ];

  static List<RtvNoteModel> _seedRtvNotes() => [
        RtvNoteModel(
          id: 'rtv_001',
          rtvNumber: 'RTV-2026-0011',
          supplierName: 'LIFESPROUT Pharma Labs',
          productName: 'Amoxicillin 500mg',
          batchNumber: 'AMX-2024-03',
          quantity: 10,
          returnUnitPrice: 75.0,
          reason: 'Near Expiry',
          date: DateTime.now().subtract(const Duration(days: 2)),
        ),
      ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Purchase Orders, GRN & Returns',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryBlue),
                    ),
                    Text(
                      'Vendor PO management � Goods Receipt Notes � Return to Vendor',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: AppTheme.textMuted,
            indicatorColor: AppTheme.primaryBlue,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            tabs: [
              Tab(
                  icon: const Icon(Icons.shopping_bag),
                  text: 'POs (${_orders.length})'),
              Tab(
                  icon: const Icon(Icons.people),
                  text: 'Vendors (${_vendors.length})'),
              Tab(
                  icon: const Icon(Icons.keyboard_return),
                  text: 'RTV Notes (${_rtvNotes.length})'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PurchaseOrderTab(
                    orders: _orders,
                    vendors: _vendors,
                    onAdd: (po) => setState(() => _orders.add(po))),
                _VendorTab(
                    vendors: _vendors,
                    onAdd: (v) => setState(() => _vendors.add(v)),
                    onDelete: (id) => setState(
                        () => _vendors.removeWhere((v) => v.id == id))),
                _RtvTab(
                    rtvNotes: _rtvNotes,
                    vendors: _vendors,
                    onAdd: (rtv) => setState(() => _rtvNotes.add(rtv))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 1: Purchase Orders ───────────────────────────────────────────────────
class _PurchaseOrderTab extends StatelessWidget {
  final List<PurchaseOrderModel> orders;
  final List<VendorModel> vendors;
  final void Function(PurchaseOrderModel) onAdd;

  const _PurchaseOrderTab(
      {required this.orders,
      required this.vendors,
      required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.pagePadding,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status filter chips
              Wrap(
                spacing: 8,
                children: ['All', 'Draft', 'Sent', 'Received', 'Closed']
                    .map((s) => ActionChip(
                          label: Text(s),
                          onPressed: () {},
                        ))
                    .toList(),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue),
                onPressed: () => _showNewPoDialog(context),
                icon: const Icon(Icons.add),
                label: const Text('New Purchase Order'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: orders.isEmpty
                  ? const Center(
                      child: Text('No purchase orders yet.',
                          style: TextStyle(color: AppTheme.textMuted)))
                  : ListView.separated(
                      itemCount: orders.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final po =
                            orders[orders.length - 1 - index];
                        return ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: _poStatusColor(po.status)
                                .withOpacity(0.12),
                            child: Icon(Icons.shopping_bag,
                                color: _poStatusColor(po.status)),
                          ),
                          title: Text(
                            '${po.poNumber} � ${po.vendorName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${po.orderDate.day}/${po.orderDate.month}/${po.orderDate.year}  '
                            '�  ${po.items.length} items  �  '
                            'Total: ?${po.totalAmount.toStringAsFixed(2)}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Chip(
                            label: Text(po.status,
                                style: TextStyle(
                                    color: _poStatusColor(po.status),
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                            backgroundColor: _poStatusColor(po.status)
                                .withOpacity(0.1),
                          ),
                          children: [
                            Container(
                              color: Colors.grey.shade50,
                              padding: context.pagePadding,
                              child: Table(
                                border: TableBorder.all(
                                    color: Colors.grey.shade300),
                                columnWidths: const {
                                  0: FlexColumnWidth(3),
                                  1: FlexColumnWidth(1.5),
                                  2: FlexColumnWidth(1),
                                  3: FlexColumnWidth(1.5),
                                  4: FlexColumnWidth(1.5),
                                },
                                children: [
                                  const TableRow(
                                    decoration: BoxDecoration(
                                        color: Color(0xFFECEFF1)),
                                    children: [
                                      _TH('Medicine'),
                                      _TH('HSN'),
                                      _TH('Qty'),
                                      _TH('Rate (?)'),
                                      _TH('Total (?)'),
                                    ],
                                  ),
                                  ...po.items.map((item) => TableRow(
                                        children: [
                                          _TC(item.medicineName),
                                          _TC(item.hsnCode),
                                          _TC('${item.quantity}'),
                                          _TC('?${item.purchasePrice.toStringAsFixed(2)}'),
                                          _TC('?${item.totalCost.toStringAsFixed(2)}'),
                                        ],
                                      )),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Color _poStatusColor(String status) {
    switch (status) {
      case 'Received':
        return AppTheme.successGreen;
      case 'Sent':
        return AppTheme.warningAmber;
      case 'Closed':
        return AppTheme.textMuted;
      default:
        return AppTheme.primaryBlue;
    }
  }

  void _showNewPoDialog(BuildContext context) {
    final medCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String? selectedVendorId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Create New Purchase Order'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedVendorId,
                  decoration:
                      const InputDecoration(labelText: 'Select Vendor *'),
                  items: vendors
                      .map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text(v.name,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) =>
                      setDlg(() => selectedVendorId = val),
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: medCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Medicine Name *')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Quantity *'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Purchase Rate (?) *'))),
                ]),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () {
                if (selectedVendorId == null || medCtrl.text.isEmpty) {
                  return;
                }
                final vendor = vendors
                    .firstWhere((v) => v.id == selectedVendorId);
                final po = PurchaseOrderModel(
                  id: 'po_${DateTime.now().millisecondsSinceEpoch}',
                  poNumber:
                      'PO-${DateTime.now().year}-${(1000 + vendors.length)}',
                  vendorName: vendor.name,
                  vendorGstin: vendor.gstin,
                  orderDate: DateTime.now(),
                  status: 'Draft',
                  items: [
                    PoLineItem(
                      medicineName: medCtrl.text.trim(),
                      hsnCode: '30049099',
                      quantity: int.tryParse(qtyCtrl.text) ?? 1,
                      purchasePrice:
                          double.tryParse(priceCtrl.text) ?? 0.0,
                      taxPercent: 12.0,
                    ),
                  ],
                );
                onAdd(po);
                Navigator.pop(ctx);
              },
              child: const Text('Create PO'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Tab 2: Vendor Master ─────────────────────────────────────────────────────
class _VendorTab extends StatelessWidget {
  final List<VendorModel> vendors;
  final void Function(VendorModel) onAdd;
  final void Function(String) onDelete;

  const _VendorTab(
      {required this.vendors, required this.onAdd, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: context.pagePadding,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue),
                onPressed: () => _showAddVendorDialog(context),
                icon: const Icon(Icons.person_add),
                label: const Text('Add Vendor / Supplier'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: vendors.isEmpty
                  ? const Center(
                      child: Text('No vendors added yet.',
                          style: TextStyle(color: AppTheme.textMuted)))
                  : ListView.separated(
                      itemCount: vendors.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final v = vendors[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: AppTheme.primaryBlue
                                .withOpacity(0.1),
                            child: const Icon(Icons.business,
                                color: AppTheme.primaryBlue),
                          ),
                          title: Text(v.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                          subtitle: Text(
                            'GSTIN: ${v.gstin}  �  DL: ${v.drugLicenseNo}\n'
                            '${v.phone}  �  ${v.email}',
                            style: const TextStyle(
                                fontSize: 12, height: 1.4),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit,
                                    color: AppTheme.primaryBlue),
                                onPressed: () =>
                                    _showEditVendorDialog(context, v),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    color: AppTheme.errorRed),
                                onPressed: () {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('Remove Vendor?'),
                                      content: Text(
                                          'Remove ${v.name} from vendor master?'),
                                      actions: [
                                        TextButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx),
                                            child: const Text('Cancel')),
                                        ElevatedButton(
                                          style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  AppTheme.errorRed),
                                          onPressed: () {
                                            onDelete(v.id);
                                            Navigator.pop(ctx);
                                          },
                                          child: const Text('Remove'),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddVendorDialog(BuildContext context) {
    _showVendorDialog(context, null);
  }

  void _showEditVendorDialog(BuildContext context, VendorModel v) {
    _showVendorDialog(context, v);
  }

  void _showVendorDialog(BuildContext context, VendorModel? existing) {
    final nameCtrl =
        TextEditingController(text: existing?.name ?? '');
    final gstinCtrl =
        TextEditingController(text: existing?.gstin ?? '');
    final phoneCtrl =
        TextEditingController(text: existing?.phone ?? '');
    final emailCtrl =
        TextEditingController(text: existing?.email ?? '');
    final addrCtrl =
        TextEditingController(text: existing?.address ?? '');
    final dlCtrl =
        TextEditingController(text: existing?.drugLicenseNo ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
            existing == null ? 'Add New Vendor' : 'Edit Vendor'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Vendor / Company Name *')),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: gstinCtrl,
                          decoration: const InputDecoration(
                              labelText: 'GSTIN'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: dlCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Drug License No'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: phoneCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Phone'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: emailCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Email'))),
                ]),
                const SizedBox(height: 10),
                TextField(
                    controller: addrCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Address')),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.isEmpty) return;
              if (existing != null) {
                existing.name = nameCtrl.text.trim();
                existing.gstin = gstinCtrl.text.trim();
                existing.phone = phoneCtrl.text.trim();
                existing.email = emailCtrl.text.trim();
                existing.address = addrCtrl.text.trim();
                existing.drugLicenseNo = dlCtrl.text.trim();
              } else {
                onAdd(VendorModel(
                  id: 'v_${DateTime.now().millisecondsSinceEpoch}',
                  name: nameCtrl.text.trim(),
                  gstin: gstinCtrl.text.trim(),
                  phone: phoneCtrl.text.trim(),
                  email: emailCtrl.text.trim(),
                  address: addrCtrl.text.trim(),
                  drugLicenseNo: dlCtrl.text.trim(),
                ));
              }
              Navigator.pop(ctx);
            },
            child: Text(existing == null ? 'Add Vendor' : 'Save Changes'),
          ),
        ],
      ),
    );
  }
}

// ─── Tab 3: RTV Notes ─────────────────────────────────────────────────────────
class _RtvTab extends StatelessWidget {
  final List<RtvNoteModel> rtvNotes;
  final List<VendorModel> vendors;
  final void Function(RtvNoteModel) onAdd;

  const _RtvTab(
      {required this.rtvNotes,
      required this.vendors,
      required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final totalRefund =
        rtvNotes.fold<double>(0, (s, r) => s + r.totalRefundAmount);

    return Padding(
      padding: context.pagePadding,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color:
                          AppTheme.warningAmber.withOpacity(0.4)),
                ),
                child: Text(
                  'Total Pending Refunds: ?${totalRefund.toStringAsFixed(2)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.warningAmber),
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.warningAmber),
                onPressed: () => _showNewRtvDialog(context),
                icon: const Icon(Icons.keyboard_return),
                label: const Text('New RTV Note'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Card(
              child: rtvNotes.isEmpty
                  ? const Center(
                      child: Text('No RTV notes recorded.',
                          style: TextStyle(color: AppTheme.textMuted)))
                  : ListView.separated(
                      itemCount: rtvNotes.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final rtv = rtvNotes[
                            rtvNotes.length - 1 - index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF3E0),
                            child: Icon(Icons.keyboard_return,
                                color: AppTheme.warningAmber),
                          ),
                          title: Text(
                            '${rtv.rtvNumber} � ${rtv.productName}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            'Supplier: ${rtv.supplierName}  �  Batch: ${rtv.batchNumber}\n'
                            'Reason: ${rtv.reason}  �  Qty: ${rtv.quantity}  �  '
                            '${rtv.date.day}/${rtv.date.month}/${rtv.date.year}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            '?${rtv.totalRefundAmount.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppTheme.warningAmber,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _showNewRtvDialog(BuildContext context) {
    final productCtrl = TextEditingController();
    final batchCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final priceCtrl = TextEditingController();
    String reason = 'Near Expiry';
    String? selectedVendorId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('New Return to Vendor (RTV) Note'),
          content: SizedBox(
            width: 480,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: selectedVendorId,
                  decoration:
                      const InputDecoration(labelText: 'Supplier *'),
                  items: vendors
                      .map((v) => DropdownMenuItem(
                          value: v.id,
                          child: Text(v.name,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (val) =>
                      setDlg(() => selectedVendorId = val),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: productCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Product Name *'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: batchCtrl,
                          decoration: const InputDecoration(
                              labelText: 'Batch No *'))),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                      child: TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Return Qty *'))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: TextField(
                          controller: priceCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                              labelText: 'Unit Price (?) *'))),
                ]),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: reason,
                  decoration:
                      const InputDecoration(labelText: 'Reason'),
                  items: [
                    'Near Expiry',
                    'Expired',
                    'Damaged',
                    'Recall',
                    'Overstock'
                  ]
                      .map((r) => DropdownMenuItem(
                          value: r, child: Text(r)))
                      .toList(),
                  onChanged: (val) =>
                      setDlg(() => reason = val ?? reason),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.warningAmber),
              onPressed: () {
                if (selectedVendorId == null ||
                    productCtrl.text.isEmpty) {
                  return;
                }
                final vendor = vendors
                    .firstWhere((v) => v.id == selectedVendorId);
                onAdd(RtvNoteModel(
                  id: 'rtv_${DateTime.now().millisecondsSinceEpoch}',
                  rtvNumber:
                      'RTV-${DateTime.now().year}-${(1000 + rtvNotes.length)}',
                  supplierName: vendor.name,
                  productName: productCtrl.text.trim(),
                  batchNumber: batchCtrl.text.trim(),
                  quantity: int.tryParse(qtyCtrl.text) ?? 1,
                  returnUnitPrice:
                      double.tryParse(priceCtrl.text) ?? 0.0,
                  reason: reason,
                  date: DateTime.now(),
                ));
                Navigator.pop(ctx);
              },
              child: const Text('Create RTV Note'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Table helpers ────────────────────────────────────────────────────────────
class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(7),
        child: Text(text,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 12)),
      );
}

class _TC extends StatelessWidget {
  final String text;
  const _TC(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(7),
        child:
            Text(text, style: TextStyle(fontSize: 12)),
      );
}
