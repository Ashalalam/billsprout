import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';

class OrderTrackingWidget extends StatefulWidget {
  final String? initialOrderId;

  const OrderTrackingWidget({
    super.key,
    this.initialOrderId,
  });

  @override
  State<OrderTrackingWidget> createState() => _OrderTrackingWidgetState();
}

class _OrderTrackingWidgetState extends State<OrderTrackingWidget> {
  final _supabase = Supabase.instance.client;
  final _orderIdController = TextEditingController();
  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    if (widget.initialOrderId != null) {
      _orderIdController.text = widget.initialOrderId!;
      _trackOrder();
    } else {
      _loadRecentOrders();
    }
  }

  @override
  void dispose() {
    _orderIdController.dispose();
    super.dispose();
  }

  Future<void> _loadRecentOrders() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = auth.tenantId;
    final userPhone = auth.currentUser?.phone;

    if (tenantId == null || userPhone == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('sales')
          .select('''
            id,
            invoice_number,
            invoice_date,
            customer_name,
            customer_phone,
            grand_total,
            payment_method,
            delivery_option,
            delivery_address,
            order_status,
            payment_status,
            notes,
            created_at
          ''')
          .eq('tenant_id', tenantId)
          .eq('customer_phone', userPhone)
          .order('created_at', ascending: false)
          .limit(10);

      setState(() {
        _orders = (response as List).cast<Map<String, dynamic>>();
        _error = null;
      });
    } catch (e) {
      setState(() => _error = 'Failed to load orders: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _trackOrder() async {
    final orderId = _orderIdController.text.trim();
    if (orderId.isEmpty) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = auth.tenantId;

    if (tenantId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('sales')
          .select('''
            id,
            invoice_number,
            invoice_date,
            customer_name,
            customer_phone,
            grand_total,
            payment_method,
            delivery_option,
            delivery_address,
            order_status,
            payment_status,
            notes,
            created_at,
            sale_items (
              product_name,
              quantity,
              unit_price,
              total_price
            )
          ''')
          .eq('tenant_id', tenantId)
          .or('id.eq.$orderId,invoice_number.eq.$orderId')
          .maybeSingle();

      if (response != null) {
        setState(() {
          _orders = [response];
          _error = null;
        });
      } else {
        setState(() {
          _orders = [];
          _error = 'Order not found. Please check the order ID.';
        });
      }
    } catch (e) {
      setState(() => _error = 'Failed to track order: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Order Tracking'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Search Section
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
                  'Track Your Orders',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your order ID or view recent orders',
                  style: TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _orderIdController,
                  decoration: InputDecoration(
                    hintText: 'Enter Order ID or Invoice Number',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.track_changes),
                      onPressed: _trackOrder,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (_) => _trackOrder(),
                ),
                const SizedBox(height: 12),
                if (widget.initialOrderId == null)
                  TextButton(
                    onPressed: _loadRecentOrders,
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('View Recent Orders'),
                  ),
              ],
            ),
          ),

          // Orders List
          Expanded(
            child: _buildOrdersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: widget.initialOrderId != null ? _trackOrder : _loadRecentOrders,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No orders found', style: TextStyle(fontSize: 16, color: Colors.grey)),
            Text('Your orders will appear here once placed', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _orders.length,
      itemBuilder: (context, index) {
        final order = _orders[index];
        return _buildOrderCard(order);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final orderStatus = order['order_status'] ?? 'pending';
    final paymentStatus = order['payment_status'] ?? 'pending';

    Color statusColor = _getStatusColor(orderStatus);
    IconData statusIcon = _getStatusIcon(orderStatus);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Order #${order['invoice_number']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      DateTime.parse(order['created_at']).toString().split(' ')[0],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 16, color: statusColor),
                      const SizedBox(width: 4),
                      Text(
                        orderStatus.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Order Details
            Row(
              children: [
                Icon(Icons.payment, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '₹${order['grand_total'].toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
                Icon(Icons.credit_card, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  order['payment_method'] == 'cash_on_delivery' ? 'COD' : 'Online',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
                const SizedBox(width: 16),
                Icon(
                  order['delivery_option'] == 'home_delivery' ? Icons.home : Icons.store,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 4),
                Text(
                  order['delivery_option'] == 'home_delivery' ? 'Delivery' : 'Pickup',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),

            if (order['delivery_address'] != null) ...[
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      order['delivery_address'],
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],

            // Order Items (if available)
            if (order['sale_items'] != null && (order['sale_items'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Items:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              ...(order['sale_items'] as List).take(3).map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    const Icon(Icons.medication, size: 14, color: AppTheme.primaryBlue),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${item['product_name']} (${item['quantity']} units)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    Text(
                      '₹${item['total_price'].toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              )).toList(),
              if ((order['sale_items'] as List).length > 3)
                Text(
                  '... and ${(order['sale_items'] as List).length - 3} more items',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
            ],

            const SizedBox(height: 12),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (orderStatus == 'pending' || orderStatus == 'processing')
                  TextButton.icon(
                    onPressed: () => _showCancelOrderDialog(order),
                    icon: const Icon(Icons.cancel_outlined, size: 16),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _showOrderDetails(order),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return Colors.green;
      case 'processing':
      case 'confirmed':
        return Colors.blue;
      case 'shipped':
      case 'out_for_delivery':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
      case 'delivered':
        return Icons.check_circle;
      case 'processing':
      case 'confirmed':
        return Icons.hourglass_empty;
      case 'shipped':
      case 'out_for_delivery':
        return Icons.local_shipping;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.schedule;
    }
  }

  void _showOrderDetails(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Order #${order['invoice_number']}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Order Date', DateTime.parse(order['created_at']).toString().split(' ')[0]),
              _buildDetailRow('Status', order['order_status'].toUpperCase()),
              _buildDetailRow('Payment', order['payment_method'] == 'cash_on_delivery' ? 'Cash on Delivery' : 'Online Payment'),
              _buildDetailRow('Total Amount', '₹${order['grand_total'].toStringAsFixed(2)}'),
              if (order['delivery_address'] != null)
                _buildDetailRow('Delivery Address', order['delivery_address']),
              if (order['notes'] != null && order['notes'].isNotEmpty)
                _buildDetailRow('Notes', order['notes']),
            ],
          ),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  void _showCancelOrderDialog(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Order'),
        content: Text('Are you sure you want to cancel order #${order['invoice_number']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cancelOrder(order['id']);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelOrder(String orderId) async {
    try {
      await _supabase
          .from('sales')
          .update({
            'order_status': 'cancelled',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Order cancelled successfully'),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh the orders list
      if (widget.initialOrderId != null) {
        _trackOrder();
      } else {
        _loadRecentOrders();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel order: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}