import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/product_model.dart';
import '../../models/batch_model.dart';
import '../../models/selling_unit_model.dart';
import '../../providers/inventory_provider.dart';
import '../../widgets/medicine_scanner_dialog.dart';
import '../../services/medicine_data_extractor.dart';

class InventoryView extends StatefulWidget {
  const InventoryView({super.key});

  /// Barcode captured by a POS scan that matched no product. Inventory opens the
  /// Add Medicine form with this prefilled, then clears it so it applies once.
  static String? pendingBarcode;

  @override
  State<InventoryView> createState() => _InventoryViewState();
}

class _InventoryViewState extends State<InventoryView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Open Add Medicine automatically when arriving from an unmatched scan.
    final scanned = InventoryView.pendingBarcode;
    if (scanned != null) {
      InventoryView.pendingBarcode = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showAddMedicineDialog(
          context,
          Provider.of<InventoryProvider>(context, listen: false),
          prefilledBarcode: scanned,
        );
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = Provider.of<InventoryProvider>(context);

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppTheme.primaryBlue,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppTheme.primaryBlue,
            tabs: const [
              Tab(icon: Icon(Icons.inventory_2), text: 'FEFO Stock & Batches'),
              Tab(icon: Icon(Icons.assignment_return), text: 'Return To Vendor (RTV)'),
              Tab(icon: Icon(Icons.swap_horiz), text: 'Inter-Branch Transfers'),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Stock & Batches
          _buildStockTab(context, inventoryProvider),
          // Tab 2: RTV Debit Notes
          _buildRtvTab(context, inventoryProvider),
          // Tab 3: Stock Transfers
          _buildTransfersTab(context, inventoryProvider),
        ],
      ),
    );
  }

  Widget _buildStockTab(BuildContext context, InventoryProvider inventoryProvider) {
    return Padding(
      padding: context.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FEFO Inventory & Batch Register',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
              Row(
                children: [
                  // ── Add New Medicine ──────────────────────────────
                  // Scan Medicine (Camera/Photo)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue),
                    onPressed: () => _handleScanMedicine(context, inventoryProvider),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Scan Medicine'),
                  ),
                  const SizedBox(width: 8),
                  // Add New Medicine
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.successGreen),
                    onPressed: () =>
                        _showAddMedicineDialog(context, inventoryProvider),
                    icon: const Icon(Icons.add_circle),
                    label: const Text('Add New Medicine'),
                  ),
                  const SizedBox(width: 8),
                  // ── Add Stock to existing product ─────────────────
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue),
                    onPressed: () =>
                        _showAddStockDialog(context, inventoryProvider),
                    icon: const Icon(Icons.add_box),
                    label: const Text('Add Stock / New Batch'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.warningAmber),
                    onPressed: () =>
                        _showCreateRtvModal(context, inventoryProvider),
                    icon: const Icon(Icons.assignment_return),
                    label: const Text('Return to Vendor'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue),
                    onPressed: () =>
                        _showStockTransferModal(context, inventoryProvider),
                    icon: const Icon(Icons.swap_horiz),
                    label: const Text('Inter-Branch Transfer'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Expiry Alert Banner
          Builder(builder: (context) {
            final nearExpiryList = inventoryProvider.getNearExpiryBatches();
            if (nearExpiryList.isEmpty) return const SizedBox.shrink();
            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.warningAmber),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppTheme.warningAmber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'FEFO WARNING: ${nearExpiryList.length} medicine batch(es) are nearing expiry within 90 days. Prioritize these batches for fast POS dispatching.',
                      style: const TextStyle(color: Color(0xFFE65100), fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ],
              ),
            );
          }),

          // Table of Stock & FEFO Batches
          Expanded(
            child: Card(
              child: ListView.separated(
                itemCount: inventoryProvider.products.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final product = inventoryProvider.products[index];
                  return ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      child: const Icon(Icons.medication, color: AppTheme.primaryBlue),
                    ),
                    title: Text(
                      product.name,
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Generic Salt: ${product.genericSalt} | HSN: ${product.hsnCode} | GST: ${product.taxPercent}% | Total Stock: ${product.totalStock}',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                        if (product.allowLooseSales) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.successGreen.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.medical_services, size: 10, color: AppTheme.successGreen),
                                const SizedBox(width: 3),
                                Text(
                                  'LOOSE: ${product.baseUnitsPerPack ?? 10} ${product.baseUnit?.label ?? 'units'}/pack',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: AppTheme.successGreen,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (product.isScheduleH || product.isScheduleH1)
                          Chip(
                            label: Text(product.isScheduleH1 ? 'SCH H1' : 'SCH H'),
                            backgroundColor: AppTheme.errorRed.withValues(alpha: 0.15),
                            labelStyle: const TextStyle(color: AppTheme.errorRed, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        const SizedBox(width: 4),
                        // Delete product button
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppTheme.errorRed, size: 20),
                          tooltip: 'Delete Medicine',
                          onPressed: () => _confirmDeleteProduct(context, inventoryProvider, product),
                        ),
                        const SizedBox(width: 4),
                        // Quick add stock button per product
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline,
                              color: AppTheme.successGreen),
                          tooltip: 'Add Stock / New Batch',
                          onPressed: () => _showAddStockDialog(
                              context, inventoryProvider,
                              preselectedProductId: product.id),
                        ),
                        const Icon(Icons.keyboard_arrow_down),
                      ],
                    ),
                    children: [
                      Container(
                        color: Colors.grey.shade50,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Batches (FEFO Sorted):',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryBlue),
                            ),
                            const SizedBox(height: 8),
                            Table(
                              border: TableBorder.all(color: Colors.grey.shade300),
                              columnWidths: const {
                                0: FlexColumnWidth(2),
                                1: FlexColumnWidth(1.5),
                                2: FlexColumnWidth(1.5),
                                3: FlexColumnWidth(1),
                                4: FlexColumnWidth(1.5),
                                5: FlexColumnWidth(1.5),
                              },
                              children: [
                                const TableRow(
                                  decoration: BoxDecoration(color: Color(0xFFECEFF1)),
                                  children: [
                                    Padding(padding: EdgeInsets.all(6), child: Text('Batch No', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(6), child: Text('Mfg Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(6), child: Text('Exp Date', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(6), child: Text('MRP', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(6), child: Text('Stock', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                    Padding(padding: EdgeInsets.all(6), child: Text('Rack Map', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12))),
                                  ],
                                ),
                                ...product.batches.map((batch) {
                                  final expText = '${batch.expDate.month}/${batch.expDate.year}';
                                  // Show stock with loose units breakdown if product allows loose sales
                                  String stockDisplay = '${batch.stockCount}';
                                  if (product.allowLooseSales && batch.looseUnits != null && batch.looseUnits! > 0) {
                                    final totalUnits = batch.totalAvailableUnits(product.baseUnitsPerPack ?? 10);
                                    stockDisplay = '${batch.stockCount} packs\n+ ${batch.looseUnits} loose\n(${totalUnits} ${product.baseUnit?.label ?? 'units'})';
                                  }
                                  
                                  return TableRow(
                                    children: [
                                      Padding(padding: EdgeInsets.all(6), child: Text(batch.batchNumber, style: TextStyle(fontSize: 12))),
                                      Padding(padding: EdgeInsets.all(6), child: Text('${batch.mfgDate.month}/${batch.mfgDate.year}', style: TextStyle(fontSize: 12))),
                                      Padding(
                                        padding: const EdgeInsets.all(6),
                                        child: Text(
                                          expText,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: batch.isNearExpiry ? AppTheme.errorRed : Colors.black87,
                                            fontWeight: batch.isNearExpiry ? FontWeight.bold : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Padding(padding: EdgeInsets.all(6), child: Text('?${batch.mrp}', style: TextStyle(fontSize: 12))),
                                      Padding(
                                        padding: EdgeInsets.all(6),
                                        child: Text(
                                          stockDisplay,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: product.allowLooseSales && batch.looseUnits != null && batch.looseUnits! > 0 
                                                ? AppTheme.successGreen 
                                                : Colors.black87,
                                            fontWeight: product.allowLooseSales && batch.looseUnits != null && batch.looseUnits! > 0
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                      ),
                                      Padding(padding: EdgeInsets.all(6), child: Text(batch.rackLocation, style: TextStyle(fontSize: 12))),
                                    ],
                                  );
                                }),
                              ],
                            ),
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

  Widget _buildRtvTab(BuildContext context, InventoryProvider inventoryProvider) {
    return Padding(
      padding: context.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Return to Vendor (RTV) Debit Notes',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.warningAmber),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningAmber),
                onPressed: () => _showCreateRtvModal(context, inventoryProvider),
                icon: const Icon(Icons.add),
                label: const Text('+ Issue RTV Debit Note'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: inventoryProvider.rtvNotes.isEmpty
                ? const Center(
                    child: Text('No Return to Vendor debit notes issued yet.'),
                  )
                : Card(
                    child: ListView.separated(
                      itemCount: inventoryProvider.rtvNotes.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final rtv = inventoryProvider.rtvNotes[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFF3E0),
                            child: Icon(Icons.assignment_return, color: AppTheme.warningAmber),
                          ),
                          title: Text('${rtv.rtvNumber} � ${rtv.productName}'),
                          subtitle: Text(
                            'Supplier: ${rtv.supplierName} | Batch: ${rtv.batchNumber}\nQty Returned: ${rtv.quantity} | Reason: ${rtv.reason}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Text(
                            '?${rtv.totalRefundAmount.toStringAsFixed(2)}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.warningAmber),
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

  Widget _buildTransfersTab(BuildContext context, InventoryProvider inventoryProvider) {
    return Padding(
      padding: context.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Inter-Branch Stock Movement Register',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                onPressed: () => _showStockTransferModal(context, inventoryProvider),
                icon: const Icon(Icons.add),
                label: const Text('+ Create Branch Transfer'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: inventoryProvider.transfers.isEmpty
                ? const Center(
                    child: Text('No inter-branch stock transfers logged.'),
                  )
                : Card(
                    child: ListView.separated(
                      itemCount: inventoryProvider.transfers.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final trf = inventoryProvider.transfers[index];
                        return ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFE3F2FD),
                            child: Icon(Icons.swap_horiz, color: AppTheme.primaryBlue),
                          ),
                          title: Text('${trf.transferNumber} � ${trf.productName}'),
                          subtitle: Text(
                            'From: ${trf.sourceBranch} ➔ To: ${trf.destinationBranch}\nBatch: ${trf.batchNumber} | Qty: ${trf.quantity}',
                            style: TextStyle(fontSize: 12),
                          ),
                          trailing: Chip(
                            label: Text(trf.status),
                            backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                            labelStyle: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold, fontSize: 11),
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

  void _showCreateRtvModal(BuildContext context, InventoryProvider inventoryProvider) {
    if (inventoryProvider.products.isEmpty) return;
    ProductModel selectedProduct = inventoryProvider.products.first;
    BatchModel? selectedBatch = selectedProduct.fefoBatch;
    final qtyCtrl = TextEditingController(text: '10');
    final supplierCtrl = TextEditingController(text: 'Lifesprout Wholesale Depot');
    final reasonCtrl = TextEditingController(text: 'Nearing Expiry / Return Request');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: const Text('Issue Return to Vendor (RTV) Debit Note'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<ProductModel>(
                  isExpanded: true,
                  value: selectedProduct,
                  items: inventoryProvider.products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (p) {
                    if (p != null) {
                      setModalState(() {
                        selectedProduct = p;
                        selectedBatch = p.fefoBatch;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (selectedProduct.batches.isNotEmpty)
                  DropdownButton<BatchModel>(
                    isExpanded: true,
                    value: selectedBatch ?? selectedProduct.batches.first,
                    items: selectedProduct.batches.map((b) => DropdownMenuItem(value: b, child: Text('Batch: ${b.batchNumber} (Stock: ${b.stockCount})'))).toList(),
                    onChanged: (b) => setModalState(() => selectedBatch = b),
                  ),
                const SizedBox(height: 8),
                TextField(controller: supplierCtrl, decoration: const InputDecoration(labelText: 'Supplier Vendor Name')),
                const SizedBox(height: 8),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity to Return')),
                const SizedBox(height: 8),
                TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Return Reason')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.warningAmber),
                onPressed: () {
                  if (selectedBatch != null) {
                    inventoryProvider.createRtvNote(
                      supplierName: supplierCtrl.text,
                      product: selectedProduct,
                      batch: selectedBatch!,
                      quantity: int.tryParse(qtyCtrl.text) ?? 1,
                      reason: reasonCtrl.text,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Issue Debit Note'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showStockTransferModal(BuildContext context, InventoryProvider inventoryProvider) {
    if (inventoryProvider.products.isEmpty) return;
    ProductModel selectedProduct = inventoryProvider.products.first;
    BatchModel? selectedBatch = selectedProduct.fefoBatch;
    final qtyCtrl = TextEditingController(text: '20');
    final branchCtrl = TextEditingController(text: 'Lifesprout Branch #2 - Downtown Sector');

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return AlertDialog(
            title: const Text('Create Inter-Branch Stock Transfer Pass'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<ProductModel>(
                  isExpanded: true,
                  value: selectedProduct,
                  items: inventoryProvider.products.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                  onChanged: (p) {
                    if (p != null) {
                      setModalState(() {
                        selectedProduct = p;
                        selectedBatch = p.fefoBatch;
                      });
                    }
                  },
                ),
                const SizedBox(height: 8),
                if (selectedProduct.batches.isNotEmpty)
                  DropdownButton<BatchModel>(
                    isExpanded: true,
                    value: selectedBatch ?? selectedProduct.batches.first,
                    items: selectedProduct.batches.map((b) => DropdownMenuItem(value: b, child: Text('Batch: ${b.batchNumber} (Stock: ${b.stockCount})'))).toList(),
                    onChanged: (b) => setModalState(() => selectedBatch = b),
                  ),
                const SizedBox(height: 8),
                TextField(controller: branchCtrl, decoration: const InputDecoration(labelText: 'Destination Branch Store')),
                const SizedBox(height: 8),
                TextField(controller: qtyCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Quantity to Transfer')),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  if (selectedBatch != null) {
                    inventoryProvider.createStockTransfer(
                      destinationBranch: branchCtrl.text,
                      product: selectedProduct,
                      batch: selectedBatch!,
                      quantity: int.tryParse(qtyCtrl.text) ?? 1,
                    );
                    Navigator.pop(ctx);
                  }
                },
                child: const Text('Dispatch Stock Pass'),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD NEW MEDICINE DIALOG
  // Creates a brand-new product entry with its first batch
  // ─────────────────────────────────────────────────────────────────────────
  void _showAddMedicineDialog(
      BuildContext context, InventoryProvider inventoryProvider,
      {String? prefilledBarcode, Map<String, dynamic>? prefilledData}) {
    // ── Product fields ──
    final nameCtrl         = TextEditingController();
    final saltCtrl         = TextEditingController();
    // Prefilled when the operator scanned a code that matched no product.
    final barcodeCtrl      = TextEditingController(text: prefilledBarcode ?? '');
    final hsnCtrl          = TextEditingController(text: '30049099');
    final manufacturerCtrl = TextEditingController();
    double taxPercent      = 12.0;
    bool isScheduleH       = false;
    bool isScheduleH1      = false;
    bool isNarcotic        = false;

    // ── First batch fields ──
    final batchNoCtrl  = TextEditingController();
    final mrpCtrl      = TextEditingController();
    final wsCtrl       = TextEditingController();
    final ppCtrl       = TextEditingController();
    final ptrCtrl      = TextEditingController();
    final stockCtrl    = TextEditingController();
    final rackCtrl     = TextEditingController();
    final mfgCtrl      = TextEditingController(
        text: '${DateTime.now().month}/${DateTime.now().year}');
    final expCtrl      = TextEditingController();
    DoseType doseType = DoseType.tablet;
    PackagingConfig? packagingConfig = PackagingConfig.strip10x10;
    
    // Pre-fill from scanned data if available
    if (prefilledData != null) {
      if (prefilledData.containsKey('name')) {
        nameCtrl.text = prefilledData['name'].toString();
      }
      if (prefilledData.containsKey('genericSalt')) {
        saltCtrl.text = prefilledData['genericSalt'].toString();
      }
      if (prefilledData.containsKey('barcode')) {
        barcodeCtrl.text = prefilledData['barcode'].toString();
      }
      if (prefilledData.containsKey('manufacturer')) {
        manufacturerCtrl.text = prefilledData['manufacturer'].toString();
      }
      if (prefilledData.containsKey('doseType')) {
        doseType = prefilledData['doseType'] as DoseType;
        // Update packaging config based on dose type
        final presets = PackagingConfig.presetsFor(doseType);
        if (presets.isNotEmpty) {
          packagingConfig = presets.first;
        }
      }
      // Pre-fill batch information if available
      if (prefilledData.containsKey('batchInfo')) {
        final batchInfo = prefilledData['batchInfo'] as Map<String, dynamic>;
        if (batchInfo.containsKey('batchNumber')) {
          batchNoCtrl.text = batchInfo['batchNumber'].toString();
        }
        if (batchInfo.containsKey('mrp')) {
          mrpCtrl.text = batchInfo['mrp'].toString();
        }
        if (batchInfo.containsKey('expiryDate')) {
          expCtrl.text = batchInfo['expiryDate'].toString();
        }
        if (batchInfo.containsKey('mfgDate')) {
          mfgCtrl.text = batchInfo['mfgDate'].toString();
        }
      }
    }
    
    // �"��"� Loose-unit sales configuration �"��"�
    bool allowLooseSales = false;
    final baseUnitsPerPackCtrl = TextEditingController(text: '10');
    final pricePerBaseUnitCtrl = TextEditingController();
    SellingUnit minSaleUnit = SellingUnit.strip;
    SellingUnit baseUnit = SellingUnit.tablet;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.add_circle, color: AppTheme.successGreen, size: 28),
              SizedBox(width: 10),
              Text('Add New Medicine / Product'),
            ],
          ),
          content: SizedBox(
            width: 560,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─ Section: Product Details ─────────────────────────────
                  _sectionHeader('Product Details'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Medicine / Product Name *',
                      hintText: 'e.g. Amoxicillin 500mg Capsules',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: saltCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Generic Salt / Composition *',
                      hintText: 'e.g. Amoxicillin Trihydrate',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: barcodeCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Barcode / SKU',
                            hintText: '8901234567890'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: hsnCtrl,
                        decoration: const InputDecoration(
                            labelText: 'HSN Code'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  TextField(
                    controller: manufacturerCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Manufacturer Name'),
                  ),
                  const SizedBox(height: 10),

                  // Dose type
                  StatefulBuilder(builder: (ctx2, setLocal) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<DoseType>(
                          initialValue: doseType,
                          decoration: const InputDecoration(labelText: 'Dose Type / Form *'),
                          items: DoseType.values.map((d) =>
                            DropdownMenuItem(value: d, child: Text(d.label, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              doseType = v;
                              packagingConfig = PackagingConfig.presetsFor(v).first;
                              setDlg(() {});
                            }
                          },
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: packagingConfig?.label,
                          decoration: const InputDecoration(labelText: 'Packaging Configuration'),
                          items: PackagingConfig.presetsFor(doseType).map((p) =>
                            DropdownMenuItem(value: p.label, child: Text(p.label, style: const TextStyle(fontSize: 13)))).toList(),
                          onChanged: (v) {
                            if (v != null) {
                              packagingConfig = PackagingConfig.presetsFor(doseType)
                                  .firstWhere((p) => p.label == v, orElse: () => PackagingConfig.presetsFor(doseType).first);
                              setDlg(() {});
                            }
                          },
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 10),
                  // GST tax slab
                  DropdownButtonFormField<double>(
                    initialValue: taxPercent,
                    decoration:
                        const InputDecoration(labelText: 'GST Tax Slab'),
                    items: [0.0, 5.0, 12.0, 18.0, 28.0]
                        .map((t) => DropdownMenuItem(
                            value: t,
                            child: Text('${t.toInt()}% GST')))
                        .toList(),
                    onChanged: (v) =>
                        setDlg(() => taxPercent = v ?? taxPercent),
                  ),
                  const SizedBox(height: 12),
                  
                  // �"� Loose-Unit Sales Configuration �"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"��"�
                  _sectionHeader('Loose-Unit Sales Configuration'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    title: const Text('Enable Loose-Unit Sales', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    subtitle: const Text('Allow selling individual tablets, capsules, or ml instead of full packs', style: TextStyle(fontSize: 11)),
                    value: allowLooseSales,
                    activeColor: AppTheme.successGreen,
                    onChanged: (v) => setDlg(() => allowLooseSales = v),
                  ),
                  
                  if (allowLooseSales) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: baseUnitsPerPackCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Base Units per Pack *',
                                  hintText: '10',
                                  helperText: 'e.g., 10 tablets per strip',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<SellingUnit>(
                                value: baseUnit,
                                decoration: const InputDecoration(labelText: 'Base Unit *'),
                                items: [SellingUnit.tablet, SellingUnit.capsule, SellingUnit.ml, SellingUnit.gm, SellingUnit.unit]
                                    .map((u) => DropdownMenuItem(value: u, child: Text(u.label, style: const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setDlg(() => baseUnit = v ?? baseUnit),
                              ),
                            ),
                          ]),
                          const SizedBox(height: 10),
                          Row(children: [
                            Expanded(
                              child: TextField(
                                controller: pricePerBaseUnitCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'Price per Base Unit (?)',
                                  hintText: '5.50',
                                  helperText: 'Leave empty to auto-calculate from MRP',
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: DropdownButtonFormField<SellingUnit>(
                                value: minSaleUnit,
                                decoration: const InputDecoration(labelText: 'Minimum Sale Unit'),
                                items: [SellingUnit.strip, SellingUnit.tablet, SellingUnit.capsule, SellingUnit.ml]
                                    .map((u) => DropdownMenuItem(value: u, child: Text(u.label, style: const TextStyle(fontSize: 13))))
                                    .toList(),
                                onChanged: (v) => setDlg(() => minSaleUnit = v ?? minSaleUnit),
                              ),
                            ),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.successGreen.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppTheme.successGreen.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.info_outline, color: AppTheme.successGreen, size: 14),
                          SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Loose-unit sales allow flexible dispensing (e.g., "2 strips + 5 tablets"). The system auto-opens packs when needed.',
                              style: TextStyle(fontSize: 10, color: AppTheme.successGreen, height: 1.3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),

                  // Schedule / Narcotic flags
                  _sectionHeader('Regulatory Classification'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Schedule H'),
                        selected: isScheduleH,
                        selectedColor:
                            AppTheme.errorRed.withValues(alpha: 0.15),
                        onSelected: (v) =>
                            setDlg(() => isScheduleH = v),
                      ),
                      FilterChip(
                        label: const Text('Schedule H1'),
                        selected: isScheduleH1,
                        selectedColor:
                            AppTheme.errorRed.withValues(alpha: 0.15),
                        onSelected: (v) =>
                            setDlg(() => isScheduleH1 = v),
                      ),
                      FilterChip(
                        label: const Text('Narcotic / Psychotropic'),
                        selected: isNarcotic,
                        selectedColor:
                            AppTheme.errorRed.withValues(alpha: 0.15),
                        onSelected: (v) =>
                            setDlg(() => isNarcotic = v),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  // ─ Section: First Batch / Opening Stock ─────────────────
                  _sectionHeader('Opening Stock Batch'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: batchNoCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Batch Number *',
                          hintText: 'e.g. BT-2026-001',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: stockCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Opening Stock Qty *'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: mfgCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Mfg Date (MM/YYYY)',
                          hintText: '01/2026',
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: expCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Expiry Date (MM/YYYY) *',
                          hintText: '12/2028',
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: mrpCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'MRP per unit (?) *'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: ppCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Purchase Price (?)'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: wsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                            labelText: 'Wholesale Price (Rs.)'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  // PTR field
                  TextField(
                    controller: ptrCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'PTR � Price to Retailer (Rs.)',
                      hintText: 'e.g. 95.00',
                      prefixIcon: Icon(Icons.storefront),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: rackCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Rack / Storage Location',
                        hintText: 'e.g. Rack A-1'),
                  ),
                  const SizedBox(height: 12),

                  // Info box
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.successGreen.withValues(alpha: 0.07),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color:
                              AppTheme.successGreen.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline,
                            color: AppTheme.successGreen, size: 16),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'FEFO will auto-select this batch for POS billing based on expiry date. '
                            'You can add more batches later using the + button on the product row.',
                            style: TextStyle(
                                fontSize: 11,
                                color: AppTheme.successGreen,
                                height: 1.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen),
              onPressed: () async {
                // ── Validation ────────────────────────────────────────────
                if (nameCtrl.text.trim().isEmpty) {
                  _showSnack(context, 'Enter medicine name.', isError: true);
                  return;
                }
                if (saltCtrl.text.trim().isEmpty) {
                  _showSnack(context, 'Enter generic salt / composition.',
                      isError: true);
                  return;
                }
                if (batchNoCtrl.text.trim().isEmpty ||
                    mrpCtrl.text.trim().isEmpty ||
                    stockCtrl.text.trim().isEmpty ||
                    expCtrl.text.trim().isEmpty) {
                  _showSnack(context,
                      'Fill all required batch fields (Batch No, MRP, Stock, Expiry).',
                      isError: true);
                  return;
                }

                // -- Loose-sales validation ------------------------------------
                if (allowLooseSales) {
                  final baseUnits = int.tryParse(baseUnitsPerPackCtrl.text);
                  if (baseUnits == null || baseUnits <= 0) {
                    _showSnack(context,
                        'Base units per pack must be a positive number.',
                        isError: true);
                    return;
                  }
                  if (pricePerBaseUnitCtrl.text.isNotEmpty) {
                    final pricePerUnit = double.tryParse(pricePerBaseUnitCtrl.text);
                    if (pricePerUnit == null || pricePerUnit <= 0) {
                      _showSnack(context,
                          'Price per base unit must be a positive number.',
                          isError: true);
                      return;
                    }
                  }
                }

                // ── Parse dates ───────────────────────────────────────────
                DateTime? expDate;
                DateTime? mfgDate;
                try {
                  final ep = expCtrl.text.trim().split('/');
                  expDate = DateTime(int.parse(ep[1]), int.parse(ep[0]));
                  final mp = mfgCtrl.text.trim().split('/');
                  mfgDate = DateTime(int.parse(mp[1]), int.parse(mp[0]));
                } catch (_) {
                  _showSnack(context, 'Invalid date format. Use MM/YYYY.',
                      isError: true);
                  return;
                }

                // ── Build batch ────────────────────────────────────────────
                final batch = BatchModel(
                  id: const Uuid().v4(), // ✅ FIXED: Use proper UUID instead of timestamp
                  batchNumber: batchNoCtrl.text.trim(),
                  mfgDate: mfgDate,
                  expDate: expDate,
                  mrp: double.tryParse(mrpCtrl.text) ?? 0,
                  purchasePrice: double.tryParse(ppCtrl.text) ?? 0,
                  wholesalePrice: double.tryParse(wsCtrl.text) ?? 0,
                  ptrPrice: double.tryParse(ptrCtrl.text) ?? 0,
                  stockCount: int.tryParse(stockCtrl.text) ?? 0,
                  rackLocation: rackCtrl.text.trim().isEmpty
                      ? 'General Shelf'
                      : rackCtrl.text.trim(),
                );

                // ── Build product ──────────────────────────────────────────
                final product = ProductModel(
                  id: const Uuid().v4(),
                  name: nameCtrl.text.trim(),
                  genericSalt: saltCtrl.text.trim(),
                  barcode: barcodeCtrl.text.trim().isEmpty
                      ? 'BARCODE-${DateTime.now().millisecondsSinceEpoch}'
                      : barcodeCtrl.text.trim(),
                  hsnCode: hsnCtrl.text.trim().isEmpty
                      ? '30049099'
                      : hsnCtrl.text.trim(),
                  taxPercent: taxPercent,
                  manufacturer: manufacturerCtrl.text.trim().isEmpty
                      ? 'Unknown Manufacturer'
                      : manufacturerCtrl.text.trim(),
                  isScheduleH: isScheduleH,
                  isScheduleH1: isScheduleH1,
                  isNarcotic: isNarcotic,
                  batches: [batch],
                  doseType: doseType,
                  packagingConfig: packagingConfig,
                  // Loose-unit sales fields
                  allowLooseSales: allowLooseSales,
                  baseUnitsPerPack: allowLooseSales ? (int.tryParse(baseUnitsPerPackCtrl.text) ?? 10) : 10,
                  pricePerBaseUnit: allowLooseSales && pricePerBaseUnitCtrl.text.isNotEmpty 
                      ? double.tryParse(pricePerBaseUnitCtrl.text) 
                      : null,
                  minSaleUnit: allowLooseSales ? minSaleUnit : SellingUnit.strip,
                  baseUnit: allowLooseSales ? baseUnit : SellingUnit.tablet,
                );

                // ── Save to database FIRST, then update UI ────────────────
                try {
                  await inventoryProvider.addProduct(product);
                  
                  // Only close dialog and show success if database save succeeded
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _showSnack(
                        context,
                        '✅ ${product.name} added to inventory with '
                        '${batch.stockCount} units in batch ${batch.batchNumber}.');
                  }
                } catch (e) {
                  // Show actual error if database save fails
                  if (ctx.mounted) {
                    _showSnack(
                        context,
                        '❌ Failed to save medicine: ${e.toString()}',
                        isError: true);
                  }
                }
              },
              icon: const Icon(Icons.save),
              label: const Text('Save New Medicine'),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADD STOCK / NEW BATCH TO EXISTING PRODUCT DIALOG
  // ─────────────────────────────────────────────────────────────────────────
  void _showAddStockDialog(
    BuildContext context,
    InventoryProvider inventoryProvider, {
    String? preselectedProductId,
  }) {
    if (inventoryProvider.products.isEmpty) {
      _showSnack(context,
          'No medicines in inventory yet. Add a new medicine first.',
          isError: true);
      return;
    }

    String? selectedProductId = preselectedProductId ??
        inventoryProvider.products.first.id;

    final batchNoCtrl = TextEditingController();
    final mrpCtrl     = TextEditingController();
    final wsCtrl      = TextEditingController();
    final ppCtrl      = TextEditingController();
    final stockCtrl   = TextEditingController();
    final rackCtrl    = TextEditingController();
    final mfgCtrl     = TextEditingController(
        text: '${DateTime.now().month}/${DateTime.now().year}');
    final expCtrl     = TextEditingController();
    bool addNewBatch  = true;  // toggle: new batch vs top-up existing

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          final selectedProduct = inventoryProvider.products
              .firstWhere((p) => p.id == selectedProductId,
                  orElse: () => inventoryProvider.products.first);

          return AlertDialog(
            title: Row(
              children: const [
                Icon(Icons.add_box, color: AppTheme.primaryBlue, size: 28),
                SizedBox(width: 10),
                Text('Add Stock / New Batch'),
              ],
            ),
            content: SizedBox(
              width: 520,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product selector
                    DropdownButtonFormField<String>(
                      initialValue: selectedProductId,
                      decoration: const InputDecoration(
                          labelText: 'Select Medicine *'),
                      items: inventoryProvider.products
                          .map((p) => DropdownMenuItem(
                              value: p.id,
                              child: Text(
                                '${p.name}  (Stock: ${p.totalStock})',
                                style: const TextStyle(fontSize: 13),
                              )))
                          .toList(),
                      onChanged: (v) =>
                          setDlg(() => selectedProductId = v),
                    ),
                    const SizedBox(height: 12),

                    // New batch vs top-up toggle
                    Row(
                      children: [
                        Expanded(
                          child: _toggleButton(
                            label: 'New Batch',
                            icon: Icons.new_releases_outlined,
                            active: addNewBatch,
                            color: AppTheme.primaryBlue,
                            onTap: () =>
                                setDlg(() => addNewBatch = true),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _toggleButton(
                            label: 'Top-Up Existing Batch',
                            icon: Icons.add_shopping_cart,
                            active: !addNewBatch,
                            color: AppTheme.successGreen,
                            onTap: () =>
                                setDlg(() => addNewBatch = false),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    if (addNewBatch) ...[
                      // ── New batch fields ──────────────────────────────
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: batchNoCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Batch Number *',
                              hintText: 'e.g. BT-2026-002',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Quantity Received *'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: mfgCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Mfg Date (MM/YYYY)',
                              hintText: '01/2026',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: expCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Expiry Date (MM/YYYY) *',
                              hintText: '12/2028',
                            ),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: mrpCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'MRP per unit (?) *'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: ppCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Purchase Price (?)'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            controller: wsCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Wholesale Price (?)'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 10),
                      TextField(
                        controller: rackCtrl,
                        decoration: const InputDecoration(
                            labelText: 'Rack / Storage Location',
                            hintText: 'e.g. Rack A-1'),
                      ),
                    ] else ...[
                      // ── Top-up existing batch ─────────────────────────
                      if (selectedProduct.batches.isEmpty)
                        const Text(
                          'No batches found for this product. Add a new batch instead.',
                          style:
                              TextStyle(color: AppTheme.textMuted),
                        )
                      else
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Select batch to top-up:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13),
                            ),
                            const SizedBox(height: 8),
                            ...selectedProduct.batches.map((b) {
                              return Container(
                                margin: const EdgeInsets.only(bottom: 6),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                      color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                  color: b.isExpired
                                      ? Colors.grey.shade100
                                      : Colors.white,
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            b.batchNumber,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13),
                                          ),
                                          Text(
                                            'MRP: ?${b.mrp}  �  '
                                            'Exp: ${b.expDate.month}/${b.expDate.year}  �  '
                                            'Stock: ${b.stockCount}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!b.isExpired)
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppTheme.successGreen,
                                          padding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 6),
                                        ),
                                        onPressed: () =>
                                            _showTopUpQtyDialog(
                                                context,
                                                inventoryProvider,
                                                selectedProduct.id,
                                                b),
                                        icon: const Icon(Icons.add, size: 16),
                                        label: const Text('Add Stock',
                                            style:
                                                TextStyle(fontSize: 12)),
                                      )
                                    else
                                      const Chip(
                                        label: Text('Expired'),
                                        backgroundColor: Color(0xFFEEEEEE),
                                        labelStyle: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.textMuted),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
              if (addNewBatch)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue),
                  onPressed: () {
                    if (selectedProductId == null ||
                        batchNoCtrl.text.trim().isEmpty ||
                        mrpCtrl.text.trim().isEmpty ||
                        stockCtrl.text.trim().isEmpty ||
                        expCtrl.text.trim().isEmpty) {
                      _showSnack(context,
                          'Fill all required fields (Batch No, MRP, Stock, Expiry).',
                          isError: true);
                      return;
                    }

                    DateTime? expDate;
                    DateTime? mfgDate;
                    try {
                      final ep = expCtrl.text.trim().split('/');
                      expDate =
                          DateTime(int.parse(ep[1]), int.parse(ep[0]));
                      final mp = mfgCtrl.text.trim().split('/');
                      mfgDate =
                          DateTime(int.parse(mp[1]), int.parse(mp[0]));
                    } catch (_) {
                      _showSnack(context,
                          'Invalid date format. Use MM/YYYY.',
                          isError: true);
                      return;
                    }

                    final newBatch = BatchModel(
                      id: 'b_${DateTime.now().millisecondsSinceEpoch}',
                      batchNumber: batchNoCtrl.text.trim(),
                      mfgDate: mfgDate,
                      expDate: expDate,
                      mrp: double.tryParse(mrpCtrl.text) ?? 0,
                      purchasePrice: double.tryParse(ppCtrl.text) ?? 0,
                      wholesalePrice: double.tryParse(wsCtrl.text) ?? 0,
                      stockCount: int.tryParse(stockCtrl.text) ?? 0,
                      rackLocation: rackCtrl.text.trim().isEmpty
                          ? 'General Shelf'
                          : rackCtrl.text.trim(),
                    );

                    inventoryProvider.addBatchToProduct(
                        selectedProductId!, newBatch);
                    Navigator.pop(ctx);
                    _showSnack(
                        context,
                        '✅ Batch ${newBatch.batchNumber} added � '
                        '${newBatch.stockCount} units stocked in.');
                  },
                  icon: const Icon(Icons.save),
                  label: const Text('Save New Batch'),
                ),
            ],
          );
        },
      ),
    );
  }

  // Quick top-up qty popup
  void _showTopUpQtyDialog(
    BuildContext context,
    InventoryProvider inv,
    String productId,
    BatchModel batch,
  ) {
    final qtyCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Top-Up Batch ${batch.batchNumber}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Current stock: ${batch.stockCount} units\n'
              'MRP: ?${batch.mrp}  �  '
              'Exp: ${batch.expDate.month}/${batch.expDate.year}',
              style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Units to add *',
                hintText: 'e.g. 100',
                prefixIcon: Icon(Icons.add),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.successGreen),
            onPressed: () {
              final qty = int.tryParse(qtyCtrl.text.trim());
              if (qty == null || qty <= 0) {
                _showSnack(context, 'Enter a valid quantity.',
                    isError: true);
                return;
              }
              inv.addStockToBatch(
                  productId: productId,
                  batchId: batch.id,
                  additionalQty: qty);
              Navigator.pop(ctx); // close top-up dialog
              Navigator.pop(context); // close add-stock dialog
              _showSnack(context,
                  '✅ $qty units added to batch ${batch.batchNumber}. '
                  'New stock: ${batch.stockCount} units.');
            },
            child: const Text('Confirm Add Stock'),
          ),
        ],
      ),
    );
  }

  // ── Shared helpers ────────────────────────────────────────────────────────
  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: AppTheme.primaryBlue,
      ),
    );
  }

  Widget _toggleButton({
    required String label,
    required IconData icon,
    required bool active,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: active ? color : Colors.grey.shade300,
            width: active ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? color : Colors.grey, size: 18),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      active ? FontWeight.bold : FontWeight.normal,
                  color: active ? color : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteProduct(BuildContext context, InventoryProvider inv, ProductModel product) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.errorRed),
            SizedBox(width: 8),
            Text('Delete Medicine?'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete this medicine?',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorRed.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Total Stock: ${product.totalStock} units',
                    style: const TextStyle(fontSize: 12),
                  ),
                  Text(
                    'Batches: ${product.batches.length}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              '?? This action cannot be undone. All batches and stock data will be permanently deleted.',
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.errorRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorRed,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await inv.deleteProduct(product.id);
              if (context.mounted) {
                _showSnack(
                  context,
                  '? ${product.name} deleted successfully',
                );
              }
            },
            child: const Text('Delete Medicine'),
          ),
        ],
      ),
    );
  }

  void _showSnack(BuildContext context, String msg,
      {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor:
            isError ? AppTheme.errorRed : AppTheme.successGreen,
        duration: Duration(seconds: isError ? 3 : 4),
      ),
    );
  }


  // MEDICINE SCANNING METHODS
  Future<void> _handleScanMedicine(
      BuildContext context, InventoryProvider inventoryProvider) async {
    try {
      // Show scanner dialog
      final scannedData = await showMedicineScannerDialog(context);
      
      if (scannedData == null || !mounted) return;

      // Extract and validate product data
      final dataExtractor = MedicineDataExtractor();
      final productData = dataExtractor.extractProductData(scannedData);
      
      // Validate extracted data
      final errors = dataExtractor.validateExtractedData(productData);
      if (errors.isNotEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Validation errors:\n${errors.join('\n')}'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Show review/confirmation dialog
      if (!mounted) return;
      final confirmed = await _showScanReviewDialog(context, productData, dataExtractor);
      
      if (confirmed == true && mounted) {
        // User confirmed, pre-fill the add medicine dialog
        _showAddMedicineDialog(
          context,
          inventoryProvider,
          prefilledData: productData,
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Scanning failed: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<bool?> _showScanReviewDialog(
      BuildContext context,
      Map<String, dynamic> productData,
      MedicineDataExtractor dataExtractor) async {
    final displayData = dataExtractor.formatForDisplay(productData);

    if (displayData.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No data was extracted from the image'),
          backgroundColor: Colors.orange,
        ),
      );
      return false;
    }

    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.preview, color: AppTheme.primaryBlue, size: 28),
            SizedBox(width: 10),
            Text('Review Scanned Data'),
          ],
        ),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Please review the extracted information before proceeding:',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ...displayData.entries.map((entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              '${entry.key}:',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    )),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.info_outline, color: Colors.blue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You can edit all fields in the next step',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.check),
            label: const Text('Continue to Form'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successGreen,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
