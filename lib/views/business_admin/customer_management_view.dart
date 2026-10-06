import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_theme.dart';
import '../../config/responsive_layout.dart';
import '../../models/customer_model.dart';
import '../../providers/customer_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/logger.dart';

/// Customer Management View - Add, Edit, View Customers
class CustomerManagementView extends StatefulWidget {
  const CustomerManagementView({super.key});

  @override
  State<CustomerManagementView> createState() => _CustomerManagementViewState();
}

class _CustomerManagementViewState extends State<CustomerManagementView> {
  String _searchQuery = '';
  CustomerType? _filterType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomers();
    });
  }

  Future<void> _loadCustomers() async {
    final provider = context.read<CustomerProvider>();
    final auth = context.read<AuthProvider>();
    
    if (auth.currentUser?.tenantId != null) {
      await provider.fetchAllCustomers(auth.currentUser!.tenantId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerProvider = Provider.of<CustomerProvider>(context);
    final customers = customerProvider.allCustomers
        .where((c) =>
            (_filterType == null || c.customerType == _filterType) &&
            (c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                c.phone.contains(_searchQuery) ||
                c.email.toLowerCase().contains(_searchQuery.toLowerCase())))
        .toList();

    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            padding: context.pagePadding,
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people, color: AppTheme.primaryBlue, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Customer Management',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showAddCustomerDialog(),
                      icon: const Icon(Icons.person_add),
                      label: const Text('Add Customer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: InputDecoration(
                          hintText: 'Search by name, phone, or email...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {
                            _searchQuery = value;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<CustomerType?>(
                      value: _filterType,
                      hint: const Text('Filter by Type'),
                      items: [
                        const DropdownMenuItem(value: null, child: Text('All Customers')),
                        ...CustomerType.values.map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type.label),
                          );
                        }),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _filterType = value;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Customer Stats
          Container(
            padding: const EdgeInsets.all(16),
            color: AppTheme.primaryBlue.withValues(alpha: 0.05),
            child: Row(
              children: [
                Expanded(
                  child: _statCard(
                    'Total Customers',
                    '${customerProvider.allCustomers.length}',
                    Icons.people,
                    AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Retail',
                    '${customerProvider.allCustomers.where((c) => c.customerType == CustomerType.retail).length}',
                    Icons.shopping_cart,
                    AppTheme.successGreen,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    'Wholesale',
                    '${customerProvider.allCustomers.where((c) => c.customerType == CustomerType.wholesale).length}',
                    Icons.business,
                    AppTheme.accentOrange,
                  ),
                ),
              ],
            ),
          ),

          // Customer List
          Expanded(
            child: customerProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : customers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 80,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No customers yet'
                                  : 'No customers found',
                              style: const TextStyle(
                                fontSize: 16,
                                color: AppTheme.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => _showAddCustomerDialog(),
                              icon: const Icon(Icons.person_add),
                              label: const Text('Add First Customer'),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: context.pagePadding,
                        itemCount: customers.length,
                        itemBuilder: (context, index) {
                          final customer = customers[index];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: _getCustomerColor(customer.customerType)
                                    .withValues(alpha: 0.1),
                                child: Icon(
                                  _getCustomerIcon(customer.customerType),
                                  color: _getCustomerColor(customer.customerType),
                                ),
                              ),
                              title: Text(
                                customer.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${customer.phone}  •  ${customer.email}'),
                                  if (customer.gstin != null)
                                    Text(
                                      'GSTIN: ${customer.gstin}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getCustomerColor(customer.customerType)
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      customer.customerType.label,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: _getCustomerColor(customer.customerType),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showEditCustomerDialog(customer),
                                  ),
                                ],
                              ),
                              onTap: () => _showCustomerDetails(customer),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
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
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCustomerIcon(CustomerType type) {
    switch (type) {
      case CustomerType.retail:
        return Icons.shopping_cart;
      case CustomerType.wholesale:
        return Icons.business;
      case CustomerType.distributor:
        return Icons.local_shipping;
    }
  }

  Color _getCustomerColor(CustomerType type) {
    switch (type) {
      case CustomerType.retail:
        return AppTheme.successGreen;
      case CustomerType.wholesale:
        return AppTheme.accentOrange;
      case CustomerType.distributor:
        return AppTheme.primaryBlue;
    }
  }

  void _showAddCustomerDialog() {
    _showCustomerForm(null);
  }

  void _showEditCustomerDialog(CustomerModel customer) {
    _showCustomerForm(customer);
  }

  void _showCustomerForm(CustomerModel? customer) {
    final nameCtrl = TextEditingController(text: customer?.name ?? '');
    final phoneCtrl = TextEditingController(text: customer?.phone ?? '');
    final emailCtrl = TextEditingController(text: customer?.email ?? '');
    final addressCtrl = TextEditingController(text: customer?.address ?? '');
    final cityCtrl = TextEditingController(text: customer?.city ?? '');
    final stateCtrl = TextEditingController(text: customer?.state ?? '');
    final pincodeCtrl = TextEditingController(text: customer?.pincode ?? '');
    final gstinCtrl = TextEditingController(text: customer?.gstin ?? '');
    final drugLicenseCtrl = TextEditingController(text: customer?.drugLicenseNo ?? '');
    CustomerType selectedType = customer?.customerType ?? CustomerType.retail;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(customer == null ? 'Add New Customer' : 'Edit Customer'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 500,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<CustomerType>(
                    value: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Customer Type *',
                      border: OutlineInputBorder(),
                    ),
                    items: CustomerType.values.map((type) {
                      return DropdownMenuItem(
                        value: type,
                        child: Text(type.label),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedType = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name *',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: phoneCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Email *',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: addressCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: cityCtrl,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: stateCtrl,
                          decoration: const InputDecoration(
                            labelText: 'State',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pincodeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Pincode',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  // Show GST and DL fields ONLY for Retail Customer
                  if (selectedType == CustomerType.retail) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: gstinCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GST Number (Optional)',
                        border: OutlineInputBorder(),
                        helperText: 'Optional for retail customers',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: drugLicenseCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Drug Licence / DL Number (Optional)',
                        border: OutlineInputBorder(),
                        helperText: 'Optional for retail customers',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameCtrl.text.isEmpty ||
                    phoneCtrl.text.isEmpty ||
                    emailCtrl.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please fill all required fields'),
                      backgroundColor: AppTheme.errorRed,
                    ),
                  );
                  return;
                }

                final auth = context.read<AuthProvider>();
                final customerProvider = context.read<CustomerProvider>();

                // Generate a valid tenant ID if missing (for demo mode)
                final tenantId = auth.currentUser?.tenantId ?? const Uuid().v4();

                // Only save GST and DL if customer type is retail
                final gstinValue = selectedType == CustomerType.retail && gstinCtrl.text.isNotEmpty
                    ? gstinCtrl.text
                    : null;
                final drugLicenseValue = selectedType == CustomerType.retail && drugLicenseCtrl.text.isNotEmpty
                    ? drugLicenseCtrl.text
                    : null;

                final newCustomer = CustomerModel(
                  id: customer?.id ?? const Uuid().v4(),
                  tenantId: tenantId,
                  name: nameCtrl.text,
                  phone: phoneCtrl.text,
                  email: emailCtrl.text,
                  address: addressCtrl.text,
                  city: cityCtrl.text,
                  state: stateCtrl.text,
                  pincode: pincodeCtrl.text,
                  gstin: gstinValue,
                  drugLicenseNo: drugLicenseValue,
                  customerType: selectedType,
                  createdAt: customer?.createdAt ?? DateTime.now(),
                  updatedAt: DateTime.now(),
                );

                try {
                  await customerProvider.saveCustomer(newCustomer);
                  
                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(customer == null
                            ? 'Customer added successfully'
                            : 'Customer updated successfully'),
                        backgroundColor: AppTheme.successGreen,
                      ),
                    );
                    _loadCustomers();
                  }
                } catch (e) {
                  Logger.error('Error saving customer', error: e);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: AppTheme.errorRed,
                      ),
                    );
                  }
                }
              },
              child: Text(customer == null ? 'Add Customer' : 'Update Customer'),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomerDetails(CustomerModel customer) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(_getCustomerIcon(customer.customerType),
                color: _getCustomerColor(customer.customerType)),
            const SizedBox(width: 12),
            Text(customer.name),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailRow('Type', customer.customerType.label),
              _detailRow('Phone', customer.phone),
              _detailRow('Email', customer.email),
              if (customer.address.isNotEmpty)
                _detailRow('Address', customer.fullAddress),
              if (customer.gstin != null) _detailRow('GSTIN', customer.gstin!),
              if (customer.drugLicenseNo != null)
                _detailRow('Drug License', customer.drugLicenseNo!),
              const Divider(),
              _detailRow('Credit Limit',
                  '₹${customer.creditLimit.toStringAsFixed(2)}'),
              _detailRow('Outstanding',
                  '₹${customer.outstandingAmount.toStringAsFixed(2)}'),
              _detailRow('Available Credit',
                  '₹${customer.availableCredit.toStringAsFixed(2)}'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              _showEditCustomerDialog(customer);
            },
            icon: const Icon(Icons.edit),
            label: const Text('Edit'),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
