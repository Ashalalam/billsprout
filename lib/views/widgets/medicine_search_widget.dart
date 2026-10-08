import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'checkout_dialog.dart';
import 'order_tracking_widget.dart';

class MedicineSearchWidget extends StatefulWidget {
  const MedicineSearchWidget({super.key});

  @override
  State<MedicineSearchWidget> createState() => _MedicineSearchWidgetState();
}

class _MedicineSearchWidgetState extends State<MedicineSearchWidget> {
  final _searchController = TextEditingController();
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _medicines = [];
  List<Map<String, dynamic>> _cart = [];
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPopularMedicines();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadPopularMedicines() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = auth.tenantId;
    
    if (tenantId == null) return;

    setState(() => _isLoading = true);

    try {
      // Load popular medicines from products table
      final response = await _supabase
          .from('products')
          .select('''
            id,
            name,
            generic_salt,
            composition,
            manufacturer,
            brand,
            category,
            dosage_form,
            packaging_type,
            pack_size,
            gst_percent,
            is_prescription_required,
            batches!inner (
              id,
              mrp,
              selling_price,
              stock_quantity,
              exp_date
            )
          ''')
          .eq('tenant_id', tenantId)
          .gt('batches.stock_quantity', 0)
          .gte('batches.exp_date', DateTime.now().toIso8601String().split('T')[0])
          .limit(20);

      setState(() {
        _medicines = (response as List).cast<Map<String, dynamic>>();
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load medicines: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _searchMedicines(String query) async {
    if (query.trim().isEmpty) {
      _loadPopularMedicines();
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final tenantId = auth.tenantId;
    
    if (tenantId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await _supabase
          .from('products')
          .select('''
            id,
            name,
            generic_salt,
            composition,
            manufacturer,
            brand,
            category,
            dosage_form,
            packaging_type,
            pack_size,
            gst_percent,
            is_prescription_required,
            batches!inner (
              id,
              mrp,
              selling_price,
              stock_quantity,
              exp_date
            )
          ''')
          .eq('tenant_id', tenantId)
          .gt('batches.stock_quantity', 0)
          .gte('batches.exp_date', DateTime.now().toIso8601String().split('T')[0])
          .or('name.ilike.%$query%,generic_salt.ilike.%$query%,brand.ilike.%$query%')
          .limit(50);

      setState(() {
        _medicines = (response as List).cast<Map<String, dynamic>>();
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Search failed: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                'Medicine Search',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Search and order medicines from our catalog',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by medicine name, salt, or brand...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _loadPopularMedicines();
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  if (value.length >= 2) {
                    _searchMedicines(value);
                  } else if (value.isEmpty) {
                    _loadPopularMedicines();
                  }
                },
              ),
              if (_cart.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_cart.length} items in cart',
                        style: const TextStyle(color: Colors.white),
                      ),
                      TextButton(
                        onPressed: _viewCart,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('View Cart'),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _buildMedicinesList(),
        ),
      ],
    );
  }

  Widget _buildMedicinesList() {
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
              onPressed: _loadPopularMedicines,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_medicines.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.medical_services_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('No medicines found', style: TextStyle(fontSize: 16, color: Colors.grey)),
            Text('Try searching with different keywords', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _medicines.length,
      itemBuilder: (context, index) {
        final medicine = _medicines[index];
        return _buildMedicineCard(medicine);
      },
    );
  }

  Widget _buildMedicineCard(Map<String, dynamic> medicine) {
    final batches = medicine['batches'] as List;
    final batch = batches.isNotEmpty ? batches.first : null;
    
    if (batch == null) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        medicine['name'],
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (medicine['generic_salt'] != null)
                        Text(
                          'Salt: ${medicine['generic_salt']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      if (medicine['manufacturer'] != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          'By ${medicine['manufacturer']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${batch['selling_price'].toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    if (batch['mrp'] != batch['selling_price'])
                      Text(
                        'MRP: ₹${batch['mrp'].toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                if (medicine['dosage_form'] != null) ...[
                  Icon(Icons.medical_services, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    medicine['dosage_form'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                ],
                if (medicine['pack_size'] != null) ...[
                  Icon(Icons.inventory_2, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    medicine['pack_size'],
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  const SizedBox(width: 16),
                ],
                Icon(Icons.store, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  '${batch['stock_quantity']} in stock',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
            if (medicine['is_prescription_required'] == true) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '⚠️ Prescription Required',
                  style: TextStyle(
                    color: Colors.orange,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () => _viewMedicineDetails(medicine),
                  icon: const Icon(Icons.info_outline, size: 16),
                  label: const Text('Details'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _addToCart(medicine, batch),
                  icon: const Icon(Icons.add_shopping_cart, size: 16),
                  label: const Text('Add to Cart'),
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

  void _addToCart(Map<String, dynamic> medicine, Map<String, dynamic> batch) {
    final existingIndex = _cart.indexWhere((item) => item['product_id'] == medicine['id']);
    
    if (existingIndex >= 0) {
      setState(() {
        _cart[existingIndex]['quantity']++;
      });
    } else {
      setState(() {
        _cart.add({
          'product_id': medicine['id'],
          'batch_id': batch['id'],
          'name': medicine['name'],
          'selling_price': batch['selling_price'],
          'mrp': batch['mrp'],
          'quantity': 1,
          'is_prescription_required': medicine['is_prescription_required'] ?? false,
        });
      });
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${medicine['name']} added to cart'),
        backgroundColor: Colors.green,
        action: SnackBarAction(
          label: 'View Cart',
          textColor: Colors.white,
          onPressed: _viewCart,
        ),
      ),
    );
  }

  void _viewMedicineDetails(Map<String, dynamic> medicine) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(medicine['name']),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (medicine['generic_salt'] != null) ...[
                const Text('Generic Salt:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(medicine['generic_salt']),
                const SizedBox(height: 8),
              ],
              if (medicine['composition'] != null) ...[
                const Text('Composition:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(medicine['composition']),
                const SizedBox(height: 8),
              ],
              if (medicine['manufacturer'] != null) ...[
                const Text('Manufacturer:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(medicine['manufacturer']),
                const SizedBox(height: 8),
              ],
              if (medicine['brand'] != null) ...[
                const Text('Brand:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(medicine['brand']),
                const SizedBox(height: 8),
              ],
              if (medicine['category'] != null) ...[
                const Text('Category:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(medicine['category']),
                const SizedBox(height: 8),
              ],
              if (medicine['dosage_form'] != null) ...[
                const Text('Dosage Form:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(medicine['dosage_form']),
                const SizedBox(height: 8),
              ],
              if (medicine['pack_size'] != null) ...[
                const Text('Pack Size:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(medicine['pack_size']),
              ],
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

  void _viewCart() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Shopping Cart',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _cart.length,
                  itemBuilder: (context, index) {
                    final item = _cart[index];
                    return Card(
                      child: ListTile(
                        title: Text(item['name']),
                        subtitle: Text('₹${item['selling_price'].toStringAsFixed(2)} each'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  if (item['quantity'] > 1) {
                                    item['quantity']--;
                                  } else {
                                    _cart.removeAt(index);
                                  }
                                });
                              },
                              icon: const Icon(Icons.remove),
                            ),
                            Text('${item['quantity']}'),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  item['quantity']++;
                                });
                              },
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  border: Border(top: BorderSide(color: Colors.grey[300]!)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text(
                          '₹${_cart.fold<double>(0, (sum, item) => sum + (item['selling_price'] * item['quantity'])).toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _cart.isEmpty ? null : _proceedToCheckout,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Proceed to Checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _proceedToCheckout() {
    Navigator.pop(context);
    _showCheckoutDialog();
  }

  void _showCheckoutDialog() {
    showDialog(
      context: context,
      isScrollControlled: true,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: CheckoutDialog(
          cart: _cart,
          onOrderPlaced: (orderId) {
            setState(() {
              _cart.clear();
            });
            _showOrderConfirmation(orderId);
          },
        ),
      ),
    );
  }

  void _showOrderConfirmation(String orderId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 32),
            const SizedBox(width: 12),
            const Text('Order Placed!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your order has been placed successfully.'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order ID: $orderId',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Save this order ID for tracking your order.',
                    style: TextStyle(fontSize: 12, color: Colors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            const Text('We\'ll contact you soon for confirmation and delivery details.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => OrderTrackingWidget(initialOrderId: orderId),
                ),
              );
            },
            child: const Text('Track Order'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}