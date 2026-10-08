import 'package:flutter/material.dart';
import '../../providers/customer_provider.dart';
import '../../config/app_theme.dart';

class RecentPurchasesWidget extends StatelessWidget {
  final CustomerProvider customer;

  const RecentPurchasesWidget({
    super.key,
    required this.customer,
  });

  @override
  Widget build(BuildContext context) {
    if (customer.purchaseHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: const Column(
          children: [
            Icon(Icons.receipt_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 12),
            Text(
              'No Recent Purchases',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
            Text(
              'Your recent purchases will appear here',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    final recentPurchases = customer.purchaseHistory.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: recentPurchases.map((purchase) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Invoice #${purchase['invoice_number']}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '₹${purchase['total_amount'].toStringAsFixed(0)}',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateTime.parse(purchase['invoice_date']).toString().split(' ')[0],
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.medication, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    '${(purchase['sale_items'] as List).length} items',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              if (purchase['sale_items'] != null && (purchase['sale_items'] as List).isNotEmpty)
                const SizedBox(height: 8),
              if (purchase['sale_items'] != null && (purchase['sale_items'] as List).isNotEmpty)
                Text(
                  (purchase['sale_items'] as List).take(2).map((item) => item['product_name']).join(', ') +
                      ((purchase['sale_items'] as List).length > 2 ? '...' : ''),
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        );
      }).toList(),
    );
  }
}