import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/customer_provider.dart';
import '../../models/customer_model.dart';

class RefillRequestsWidget extends StatefulWidget {
  const RefillRequestsWidget({super.key});

  @override
  State<RefillRequestsWidget> createState() => _RefillRequestsWidgetState();
}

class _RefillRequestsWidgetState extends State<RefillRequestsWidget> {
  @override
  void initState() {
    super.initState();
    // Load chronic refills when widget initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final customerProvider = Provider.of<CustomerProvider>(context, listen: false);
      if (customerProvider.chronicRefills.isEmpty) {
        customerProvider.load();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, customer, child) {
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: AppTheme.primaryBlue,
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Refill Requests',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Manage your chronic medication refills',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  // Quick stats
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatCard(
                          'Total Refills',
                          customer.chronicRefills.length.toString(),
                          Icons.refresh,
                          Colors.white.withOpacity(0.2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildStatCard(
                          'Due Soon',
                          customer.refillsDueSoon.length.toString(),
                          Icons.schedule,
                          Colors.orange.withOpacity(0.3),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _buildRefillsList(customer),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRefillsList(CustomerProvider customer) {
    if (customer.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (customer.error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(customer.error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => customer.load(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (customer.chronicRefills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            const Text(
              'No Chronic Medications',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
            const Text(
              'Your chronic medication refills will appear here based on your purchase history',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => _showAddChronicMedicationDialog(),
              icon: const Icon(Icons.add),
              label: const Text('Add Medication Reminder'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    // Sort refills: due soon first, then by next refill date
    final sortedRefills = List<ChronicRefillItem>.from(customer.chronicRefills)
      ..sort((a, b) {
        if (a.isDueSoon && !b.isDueSoon) return -1;
        if (!a.isDueSoon && b.isDueSoon) return 1;
        return a.nextRefillDueDate.compareTo(b.nextRefillDueDate);
      });

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedRefills.length,
      itemBuilder: (context, index) {
        final refill = sortedRefills[index];
        return _buildRefillCard(refill, customer);
      },
    );
  }

  Widget _buildRefillCard(ChronicRefillItem refill, CustomerProvider customer) {
    final daysUntilRefill = refill.daysUntilRefill;
    final isDueSoon = refill.isDueSoon;
    final isOverdue = daysUntilRefill < 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: isDueSoon ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isDueSoon
            ? BorderSide(
                color: isOverdue ? Colors.red : Colors.orange,
                width: 2,
              )
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medication,
                    color: AppTheme.primaryBlue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        refill.medicineName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Refill every ${refill.refillIntervalDays} days',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? Colors.red.withOpacity(0.1)
                        : isDueSoon
                            ? Colors.orange.withOpacity(0.1)
                            : Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOverdue
                        ? 'Overdue'
                        : isDueSoon
                            ? 'Due Soon'
                            : 'On Track',
                    style: TextStyle(
                      color: isOverdue
                          ? Colors.red
                          : isDueSoon
                              ? Colors.orange
                              : Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Last purchased: ${_formatDate(refill.lastPurchasedDate)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  'Next refill: ${_formatDate(refill.nextRefillDueDate)}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 8),
                Text(
                  isOverdue
                      ? '(${-daysUntilRefill} days overdue)'
                      : '(${daysUntilRefill} days remaining)',
                  style: TextStyle(
                    color: isOverdue ? Colors.red : isDueSoon ? Colors.orange : Colors.grey[600],
                    fontSize: 12,
                    fontWeight: isOverdue || isDueSoon ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _viewRefillHistory(refill),
                  icon: const Icon(Icons.history, size: 16),
                  label: const Text('History'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _requestRefill(refill, customer),
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Request Refill'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDueSoon ? Colors.orange : AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  void _viewRefillHistory(ChronicRefillItem refill) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${refill.medicineName} History'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Refill Schedule:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Every ${refill.refillIntervalDays} days'),
            const SizedBox(height: 12),
            const Text('Last Purchase:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_formatDate(refill.lastPurchasedDate)),
            const SizedBox(height: 12),
            const Text('Next Due Date:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(_formatDate(refill.nextRefillDueDate)),
            const SizedBox(height: 12),
            const Text('Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              refill.daysUntilRefill < 0
                  ? 'Overdue by ${-refill.daysUntilRefill} days'
                  : refill.isDueSoon
                      ? 'Due in ${refill.daysUntilRefill} days'
                      : 'On track',
              style: TextStyle(
                color: refill.daysUntilRefill < 0
                    ? Colors.red
                    : refill.isDueSoon
                        ? Colors.orange
                        : Colors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _requestRefill(ChronicRefillItem refill, CustomerProvider customer) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Request Refill'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Request a refill for ${refill.medicineName}?'),
            const SizedBox(height: 16),
            const Text(
              'We\'ll check availability and contact you with pricing and pickup/delivery options.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Show loading
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Sending request...'),
                    ],
                  ),
                ),
              );

              try {
                final success = await customer.requestChronicRefill(refill);
                
                Navigator.pop(context); // Close loading dialog
                
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Refill request sent for ${refill.medicineName}. We\'ll contact you soon!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(customer.error ?? 'Failed to send refill request. Please try again.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                Navigator.pop(context); // Close loading dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('Send Request'),
          ),
        ],
      ),
    );
  }

  void _showAddChronicMedicationDialog() {
    final nameController = TextEditingController();
    int intervalDays = 30;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add Medication Reminder'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Medication Name',
                  hintText: 'e.g., Metformin 500mg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Refill Interval: '),
                  DropdownButton<int>(
                    value: intervalDays,
                    items: [15, 30, 60, 90].map((days) {
                      return DropdownMenuItem(
                        value: days,
                        child: Text('$days days'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() {
                          intervalDays = value;
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Note: This is a reminder only. Actual refills are tracked automatically from your purchases.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: nameController.text.trim().isEmpty
                  ? null
                  : () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Medication reminder would be added (demo feature)'),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    },
              child: const Text('Add Reminder'),
            ),
          ],
        ),
      ),
    );
  }
}