import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/stock_transfer_model.dart';
import '../../providers/inventory_provider.dart';

class StockTransferView extends StatefulWidget {
  const StockTransferView({super.key});

  @override
  State<StockTransferView> createState() => _StockTransferViewState();
}

class _StockTransferViewState extends State<StockTransferView> {
  final List<StockTransferModel> _transfers = _seedDemoTransfers();

  static List<StockTransferModel> _seedDemoTransfers() => [
        StockTransferModel(
          id: 'st_001',
          transferNumber: 'TRF-2026-0091',
          sourceBranch: 'LIFESPROUT Main Branch',
          destinationBranch: 'Apex Healthcare � Zone B',
          productName: 'Amoxicillin 500mg Capsules',
          batchNumber: 'AMX-2024-09',
          quantity: 50,
          timestamp: DateTime.now().subtract(const Duration(hours: 3)),
          status: 'Received',
        ),
        StockTransferModel(
          id: 'st_002',
          transferNumber: 'TRF-2026-0092',
          sourceBranch: 'LIFESPROUT Main Branch',
          destinationBranch: 'Sprout Retail � Mall Branch',
          productName: 'Paracetamol 650mg Tablets',
          batchNumber: 'PCM-650-A',
          quantity: 200,
          timestamp: DateTime.now().subtract(const Duration(hours: 1)),
          status: 'In Transit',
        ),
        StockTransferModel(
          id: 'st_003',
          transferNumber: 'TRF-2026-0093',
          sourceBranch: 'Apex Healthcare � Zone B',
          destinationBranch: 'LIFESPROUT Main Branch',
          productName: 'Digital Blood Pressure Monitor',
          batchNumber: 'BPM-2024-X',
          quantity: 5,
          timestamp: DateTime.now().subtract(const Duration(minutes: 20)),
          status: 'Pending',
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final inventory = Provider.of<InventoryProvider>(context);

    return Scaffold(
      body: Padding(
        padding: context.pagePadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Inter-Branch Stock Transfers',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    Text(
                      'Move inventory between stores � Real-time transfer tracking',
                      style: TextStyle(
                          color: AppTheme.textMuted, fontSize: 13),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue),
                  onPressed: () =>
                      _showNewTransferDialog(context, inventory),
                  icon: const Icon(Icons.swap_horiz),
                  label: const Text('New Stock Transfer'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // KPI row � responsive
            KpiRow(kpis: [
                _kpiWidget('Total Transfers', '${_transfers.length}',
                    Icons.compare_arrows, AppTheme.primaryBlue),
                const SizedBox(width: 12),
                _kpiWidget(
                    'In Transit',
                    '${_transfers.where((t) => t.status == 'In Transit').length}',
                    Icons.local_shipping,
                    AppTheme.warningAmber),
                const SizedBox(width: 12),
                _kpiWidget(
                    'Received',
                    '${_transfers.where((t) => t.status == 'Received').length}',
                    Icons.check_circle,
                    AppTheme.successGreen),
                const SizedBox(width: 12),
                _kpiWidget(
                    'Pending',
                    '${_transfers.where((t) => t.status == 'Pending').length}',
                    Icons.hourglass_top,
                    AppTheme.errorRed),
              ],
            ),
            const SizedBox(height: 16),

            // Transfer list
            Expanded(
              child: Card(
                child: _transfers.isEmpty
                    ? const Center(
                        child: Text('No transfers recorded yet.',
                            style:
                                TextStyle(color: AppTheme.textMuted)))
                    : ListView.separated(
                        itemCount: _transfers.length,
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1),
                        itemBuilder: (context, index) {
                          // Show newest first
                          final t = _transfers[
                              _transfers.length - 1 - index];
                          return _TransferTile(
                            transfer: t,
                            onStatusUpdate: (newStatus) {
                              setState(() {
                                final idx = _transfers
                                    .indexWhere((x) => x.id == t.id);
                                if (idx >= 0) {
                                  _transfers[idx] =
                                      StockTransferModel(
                                    id: t.id,
                                    transferNumber: t.transferNumber,
                                    sourceBranch: t.sourceBranch,
                                    destinationBranch:
                                        t.destinationBranch,
                                    productName: t.productName,
                                    batchNumber: t.batchNumber,
                                    quantity: t.quantity,
                                    timestamp: t.timestamp,
                                    status: newStatus,
                                  );
                                }
                              });
                            },
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showNewTransferDialog(
      BuildContext context, InventoryProvider inventory) {
    final fromCtrl = TextEditingController(
        text: 'LIFESPROUT Main Branch');
    final toCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    String? selectedProductId;
    String? selectedBatchNumber;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.swap_horiz, color: AppTheme.primaryBlue),
              SizedBox(width: 10),
              Text('New Inter-Branch Transfer'),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: fromCtrl,
                            decoration: const InputDecoration(
                                labelText: 'From Branch *'))),
                    const SizedBox(width: 12),
                    const Icon(Icons.arrow_forward,
                        color: AppTheme.primaryBlue),
                    const SizedBox(width: 12),
                    Expanded(
                        child: TextField(
                            controller: toCtrl,
                            decoration: const InputDecoration(
                                labelText: 'To Branch *'))),
                  ]),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: selectedProductId,
                    decoration: const InputDecoration(
                        labelText: 'Select Product *'),
                    items: inventory.products
                        .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name,
                                style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      setDlg(() {
                        selectedProductId = val;
                        // Auto-select FEFO batch
                        if (val != null) {
                          final product = inventory.products
                              .firstWhere((p) => p.id == val);
                          selectedBatchNumber =
                              product.fefoBatch?.batchNumber ?? '';
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  if (selectedProductId != null)
                    DropdownButtonFormField<String>(
                      value: selectedBatchNumber,
                      decoration: const InputDecoration(
                          labelText: 'Batch Number'),
                      items: inventory.products
                          .firstWhere(
                              (p) => p.id == selectedProductId)
                          .batches
                          .map((b) => DropdownMenuItem(
                              value: b.batchNumber,
                              child: Text(
                                  '${b.batchNumber} � Stock: ${b.stockCount}',
                                  style:
                                      const TextStyle(fontSize: 13))))
                          .toList(),
                      onChanged: (val) =>
                          setDlg(() => selectedBatchNumber = val),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qtyCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                        labelText: 'Transfer Quantity *'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            ElevatedButton.icon(
              onPressed: () {
                if (fromCtrl.text.isEmpty ||
                    toCtrl.text.isEmpty ||
                    selectedProductId == null ||
                    qtyCtrl.text.isEmpty) {
                  return;
                }
                final product = inventory.products
                    .firstWhere((p) => p.id == selectedProductId);
                final newTransfer = StockTransferModel(
                  id: 'st_${DateTime.now().millisecondsSinceEpoch}',
                  transferNumber:
                      'TRF-${DateTime.now().year}-${(1000 + _transfers.length).toString()}',
                  sourceBranch: fromCtrl.text.trim(),
                  destinationBranch: toCtrl.text.trim(),
                  productName: product.name,
                  batchNumber:
                      selectedBatchNumber ?? product.fefoBatch?.batchNumber ?? '',
                  quantity: int.tryParse(qtyCtrl.text) ?? 0,
                  timestamp: DateTime.now(),
                  status: 'Pending',
                );
                setState(() => _transfers.add(newTransfer));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                        'Transfer ${newTransfer.transferNumber} created!'),
                    backgroundColor: AppTheme.successGreen,
                  ),
                );
              },
              icon: const Icon(Icons.send),
              label: const Text('Initiate Transfer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpiWidget(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: color.withOpacity(0.12),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.textMuted)),
                  Text(value,
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: color)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  final StockTransferModel transfer;
  final void Function(String) onStatusUpdate;

  const _TransferTile({
    required this.transfer,
    required this.onStatusUpdate,
  });

  @override
  Widget build(BuildContext context) {
    Color statusColor;
    IconData statusIcon;
    switch (transfer.status) {
      case 'Received':
        statusColor = AppTheme.successGreen;
        statusIcon = Icons.check_circle;
        break;
      case 'In Transit':
        statusColor = AppTheme.warningAmber;
        statusIcon = Icons.local_shipping;
        break;
      default:
        statusColor = AppTheme.errorRed;
        statusIcon = Icons.hourglass_top;
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: statusColor.withOpacity(0.12),
        child: Icon(statusIcon, color: statusColor),
      ),
      title: Text(
        '${transfer.transferNumber} � ${transfer.productName}',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '${transfer.sourceBranch}  →  ${transfer.destinationBranch}\n'
        'Batch: ${transfer.batchNumber}  �  Qty: ${transfer.quantity}  �  '
        '${transfer.timestamp.day}/${transfer.timestamp.month}/${transfer.timestamp.year}',
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(
              transfer.status,
              style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold),
            ),
            backgroundColor: statusColor.withOpacity(0.1),
            side: BorderSide(color: statusColor.withOpacity(0.4)),
          ),
          const SizedBox(width: 8),
          if (transfer.status == 'Pending')
            TextButton(
              onPressed: () => onStatusUpdate('In Transit'),
              child: const Text('Dispatch'),
            )
          else if (transfer.status == 'In Transit')
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.successGreen),
              onPressed: () => onStatusUpdate('Received'),
              child: const Text('Mark Received'),
            ),
        ],
      ),
    );
  }
}
