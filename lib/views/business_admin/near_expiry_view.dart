import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../providers/inventory_provider.dart';
import '../../models/batch_model.dart';
import '../../models/product_model.dart';

class NearExpiryView extends StatefulWidget {
  const NearExpiryView({super.key});

  @override
  State<NearExpiryView> createState() => _NearExpiryViewState();
}

class _NearExpiryViewState extends State<NearExpiryView> {
  int _expiryDaysThreshold = 90;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final inventoryProvider = Provider.of<InventoryProvider>(context);
    final nearExpiryItems = _getNearExpiryItems(inventoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Near Expiry Stock Management'),
        backgroundColor: AppTheme.warningAmber,
      ),
      body: Column(
        children: [
          // Summary Card
          Container(
            margin: context.pagePadding,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.warningAmber.withValues(alpha: 0.2),
                  AppTheme.errorRed.withValues(alpha: 0.1),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.warningAmber),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildSummaryCard(
                      'Critical\n(<30 days)',
                      nearExpiryItems
                          .where((item) => item['days_until_expiry'] <= 30)
                          .length
                          .toString(),
                      AppTheme.errorRed,
                      Icons.warning_amber_rounded,
                    ),
                    _buildSummaryCard(
                      'Warning\n(31-60 days)',
                      nearExpiryItems
                          .where((item) =>
                              item['days_until_expiry'] > 30 &&
                              item['days_until_expiry'] <= 60)
                          .length
                          .toString(),
                      AppTheme.warningAmber,
                      Icons.error_outline,
                    ),
                    _buildSummaryCard(
                      'Near Expiry\n(61-90 days)',
                      nearExpiryItems
                          .where((item) => item['days_until_expiry'] > 60)
                          .length
                          .toString(),
                      Colors.orange,
                      Icons.info_outline,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by product name, batch...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value.toLowerCase();
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<int>(
                      value: _expiryDaysThreshold,
                      items: const [
                        DropdownMenuItem(value: 30, child: Text('30 Days')),
                        DropdownMenuItem(value: 60, child: Text('60 Days')),
                        DropdownMenuItem(value: 90, child: Text('90 Days')),
                        DropdownMenuItem(value: 180, child: Text('180 Days')),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _expiryDaysThreshold = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // List of Near Expiry Items
          Expanded(
            child: nearExpiryItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 64, color: AppTheme.successGreen),
                        const SizedBox(height: 16),
                        Text(
                          'No items expiring within $_expiryDaysThreshold days!',
                          style: const TextStyle(
                            fontSize: 16,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: context.pagePadding,
                    itemCount: nearExpiryItems.length,
                    itemBuilder: (context, index) {
                      final item = nearExpiryItems[index];
                      return _buildNearExpiryCard(item);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
      String label, String value, Color color, IconData icon) {
    return Card(
      elevation: 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 120,
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNearExpiryCard(Map<String, dynamic> item) {
    final ProductModel product = item['product'];
    final BatchModel batch = item['batch'];
    final int daysUntilExpiry = item['days_until_expiry'];

    // Determine color based on urgency
    Color statusColor;
    String statusText;
    if (daysUntilExpiry <= 30) {
      statusColor = AppTheme.errorRed;
      statusText = 'CRITICAL';
    } else if (daysUntilExpiry <= 60) {
      statusColor = AppTheme.warningAmber;
      statusText = 'WARNING';
    } else {
      statusColor = Colors.orange;
      statusText = 'NEAR EXPIRY';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.2),
          child: Icon(Icons.medical_services, color: statusColor),
        ),
        title: Text(
          product.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              'Generic: ${product.genericSalt} | Manufacturer: ${product.manufacturer}',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$statusText - $daysUntilExpiry days left',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Stock: ${batch.stockCount}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'MRP: ₹${batch.mrp.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey.shade50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Batch Number', batch.batchNumber),
                _buildDetailRow('Expiry Date', batch.expiryDate),
                _buildDetailRow('Manufacturing Date',
                    '${batch.mfgDate.month.toString().padLeft(2, '0')}/${batch.mfgDate.year}'),
                _buildDetailRow('HSN Code', product.hsnCode),
                _buildDetailRow('PTR Price', '₹${batch.ptrPrice.toStringAsFixed(2)}'),
                _buildDetailRow('Purchase Price', '₹${batch.purchasePrice.toStringAsFixed(2)}'),
                _buildDetailRow('Wholesale Price', '₹${batch.wholesalePrice.toStringAsFixed(2)}'),
                _buildDetailRow('Rack Location', batch.rackLocation),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        // TODO: Implement supplier return
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Return to Supplier feature'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.assignment_return, size: 16),
                      label: const Text('Return to Supplier'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.errorRed,
                      ),
                      onPressed: () {
                        // TODO: Implement discount sale
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Mark for Discount Sale'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.local_offer, size: 16),
                      label: const Text('Discount Sale'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getNearExpiryItems(
      InventoryProvider inventoryProvider) {
    final items = <Map<String, dynamic>>[];
    final now = DateTime.now();

    for (final product in inventoryProvider.products) {
      for (final batch in product.batches) {
        final daysUntilExpiry = batch.expDate.difference(now).inDays;
        
        if (daysUntilExpiry >= 0 &&
            daysUntilExpiry <= _expiryDaysThreshold &&
            batch.stockCount > 0) {
          
          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            final searchMatch = product.name.toLowerCase().contains(_searchQuery) ||
                product.genericSalt.toLowerCase().contains(_searchQuery) ||
                batch.batchNumber.toLowerCase().contains(_searchQuery);
            if (!searchMatch) continue;
          }

          items.add({
            'product': product,
            'batch': batch,
            'days_until_expiry': daysUntilExpiry,
          });
        }
      }
    }

    // Sort by expiry date (most urgent first)
    items.sort((a, b) =>
        a['days_until_expiry'].compareTo(b['days_until_expiry']));

    return items;
  }
}
