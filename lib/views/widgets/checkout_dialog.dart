import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/customer_provider.dart';

class CheckoutDialog extends StatefulWidget {
  final List<Map<String, dynamic>> cart;
  final Function(String orderId) onOrderPlaced;

  const CheckoutDialog({
    super.key,
    required this.cart,
    required this.onOrderPlaced,
  });

  @override
  State<CheckoutDialog> createState() => _CheckoutDialogState();
}

class _CheckoutDialogState extends State<CheckoutDialog> {
  final _supabase = Supabase.instance.client;
  String _selectedPaymentMethod = 'cash_on_delivery';
  String _selectedDeliveryOption = 'home_delivery';
  final _addressController = TextEditingController(text: 'Default Address - Update in Profile');
  bool _isProcessing = false;
  String? _error;

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  double get _itemsTotal => widget.cart.fold<double>(
      0, (sum, item) => sum + (item['selling_price'] * item['quantity']));

  double get _deliveryCharge => _selectedDeliveryOption == 'home_delivery' ? 50.0 : 0.0;

  double get _grandTotal => _itemsTotal + _deliveryCharge;

  bool get _prescriptionRequired => 
      widget.cart.any((item) => item['is_prescription_required'] == true);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.9,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: AppTheme.primaryBlue,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Checkout',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),

          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Prescription Warning
                  if (_prescriptionRequired) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning, color: Colors.orange, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Prescription Required',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange,
                                  ),
                                ),
                                const Text(
                                  'Some items require a valid prescription. Our pharmacist will verify before delivery.',
                                  style: TextStyle(fontSize: 12, color: Colors.orange),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // Order Items
                  const Text(
                    'Order Items',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ...widget.cart.map((item) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['name'],
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                'Qty: ${item['quantity']} × ₹${item['selling_price'].toStringAsFixed(2)}',
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                              if (item['is_prescription_required'] == true)
                                const Text(
                                  'Prescription Required',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '₹${(item['quantity'] * item['selling_price']).toStringAsFixed(2)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  )).toList(),

                  const SizedBox(height: 16),

                  // Delivery Options
                  const Text(
                    'Delivery Options',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'home_delivery',
                          groupValue: _selectedDeliveryOption,
                          onChanged: (value) => setState(() => _selectedDeliveryOption = value!),
                          title: const Text('Home Delivery'),
                          subtitle: const Text('₹50 - Delivered within 2 hours'),
                        ),
                        RadioListTile<String>(
                          value: 'store_pickup',
                          groupValue: _selectedDeliveryOption,
                          onChanged: (value) => setState(() => _selectedDeliveryOption = value!),
                          title: const Text('Store Pickup'),
                          subtitle: const Text('Free - Pickup from store'),
                        ),
                      ],
                    ),
                  ),

                  if (_selectedDeliveryOption == 'home_delivery') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Delivery Address',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _addressController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Enter delivery address',
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Payment Methods
                  const Text(
                    'Payment Method',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        RadioListTile<String>(
                          value: 'cash_on_delivery',
                          groupValue: _selectedPaymentMethod,
                          onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                          title: const Text('Cash on Delivery'),
                          subtitle: const Text('Pay when you receive'),
                          leading: const Icon(Icons.money, color: Colors.green),
                        ),
                        RadioListTile<String>(
                          value: 'online_payment',
                          groupValue: _selectedPaymentMethod,
                          onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                          title: const Text('Online Payment'),
                          subtitle: const Text('UPI / Card / Net Banking'),
                          leading: const Icon(Icons.payment, color: Colors.blue),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Bill Summary
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Bill Summary',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Items Total:'),
                            Text('₹${_itemsTotal.toStringAsFixed(2)}'),
                          ],
                        ),
                        if (_selectedDeliveryOption == 'home_delivery') ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Delivery Charge:'),
                              Text('₹${_deliveryCharge.toStringAsFixed(2)}'),
                            ],
                          ),
                        ],
                        const SizedBox(height: 8),
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Grand Total:',
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '₹${_grandTotal.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Place Order Button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _placeOrder() async {
    setState(() {
      _isProcessing = true;
      _error = null;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final customer = Provider.of<CustomerProvider>(context, listen: false);
      final tenantId = auth.tenantId;
      final userId = auth.currentUser?.id;

      if (tenantId == null || userId == null) {
        throw Exception('Authentication required');
      }

      // Generate order ID
      final orderId = 'ORD-${DateTime.now().millisecondsSinceEpoch}';
      final invoiceNumber = 'INV-${DateTime.now().millisecondsSinceEpoch}';

      // Prepare sale data
      final saleData = {
        'id': orderId,
        'tenant_id': tenantId,
        'invoice_number': invoiceNumber,
        'invoice_date': DateTime.now().toIso8601String().split('T')[0],
        'customer_id': customer.currentCustomer?.id,
        'customer_name': auth.currentUser?.name ?? 'Patient',
        'customer_phone': auth.currentUser?.phone ?? '',
        'total_amount': _itemsTotal,
        'discount_amount': 0.0,
        'tax_amount': 0.0,
        'grand_total': _grandTotal,
        'payment_method': _selectedPaymentMethod,
        'delivery_option': _selectedDeliveryOption,
        'delivery_address': _selectedDeliveryOption == 'home_delivery' ? _addressController.text : null,
        'delivery_charge': _deliveryCharge,
        'order_status': 'pending',
        'payment_status': _selectedPaymentMethod == 'cash_on_delivery' ? 'pending' : 'paid',
        'notes': 'Patient portal order',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Prepare sale items
      final saleItems = widget.cart.map((item) => {
        'id': 'SI-${DateTime.now().millisecondsSinceEpoch}-${item['product_id']}',
        'sale_id': orderId,
        'tenant_id': tenantId,
        'product_id': item['product_id'],
        'batch_id': item['batch_id'],
        'product_name': item['name'],
        'quantity': item['quantity'],
        'unit_price': item['selling_price'],
        'total_price': item['quantity'] * item['selling_price'],
        'created_at': DateTime.now().toIso8601String(),
      }).toList();

      // Insert sale record
      await _supabase.from('sales').insert(saleData);

      // Insert sale items
      await _supabase.from('sale_items').insert(saleItems);

      // If online payment is selected, simulate payment processing
      if (_selectedPaymentMethod == 'online_payment') {
        await _simulatePaymentProcessing();
      }

      // Update customer purchase history
      await customer.load();

      // Close dialog and show confirmation
      Navigator.pop(context);
      widget.onOrderPlaced(orderId);

    } catch (e) {
      setState(() {
        _error = 'Failed to place order: ${e.toString()}';
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  Future<void> _simulatePaymentProcessing() async {
    // Simulate payment gateway processing delay
    await Future.delayed(const Duration(seconds: 2));
    
    // In a real app, this would integrate with actual payment gateways
    // For now, we'll assume payment succeeds
  }
}