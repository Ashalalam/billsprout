import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/address_service.dart';

class AddressSelectionWidget extends StatefulWidget {
  final Map<String, dynamic>? selectedAddress;
  final Function(Map<String, dynamic>) onAddressSelected;

  const AddressSelectionWidget({
    super.key,
    this.selectedAddress,
    required this.onAddressSelected,
  });

  @override
  State<AddressSelectionWidget> createState() => _AddressSelectionWidgetState();
}

class _AddressSelectionWidgetState extends State<AddressSelectionWidget> {
  final _addressService = AddressService();
  List<Map<String, dynamic>> _savedAddresses = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSavedAddresses();
  }

  Future<void> _loadSavedAddresses() async {
    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      if (auth.tenantId != null && auth.currentUser != null) {
        final addresses = await _addressService.getCustomerAddresses(
          tenantId: auth.tenantId!,
          customerPhone: auth.currentUser!.phone,
        );
        setState(() {
          _savedAddresses = addresses;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.red),
        ),
        child: Text(
          'Error loading addresses: $_error',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Select Address',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextButton.icon(
              onPressed: _showAddAddressDialog,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Add New'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        if (_savedAddresses.isEmpty)
          _buildEmptyState()
        else
          _buildAddressList(),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        children: [
          const Icon(Icons.location_off, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'No saved addresses',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add a delivery address to proceed',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _showAddAddressDialog,
            icon: const Icon(Icons.add),
            label: const Text('Add Address'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAddressList() {
    return Column(
      children: _savedAddresses.map((address) {
        final isSelected = widget.selectedAddress?['id'] == address['id'];
        
        return GestureDetector(
          onTap: () => widget.onAddressSelected(address),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.primaryBlue.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? AppTheme.primaryBlue : Colors.grey[300]!,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: address['id'],
                  groupValue: widget.selectedAddress?['id'],
                  onChanged: (value) {
                    if (value != null) {
                      widget.onAddressSelected(address);
                    }
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            address['label'] ?? 'Address',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (address['is_default'] == true) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'Default',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        address['full_address'] ?? '',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      if (address['landmark'] != null && address['landmark'].isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Landmark: ${address['landmark']}',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) {
                    switch (value) {
                      case 'edit':
                        _showEditAddressDialog(address);
                        break;
                      case 'delete':
                        _deleteAddress(address);
                        break;
                      case 'default':
                        _setDefaultAddress(address);
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit, size: 16),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (address['is_default'] != true)
                      const PopupMenuItem(
                        value: 'default',
                        child: Row(
                          children: [
                            Icon(Icons.star, size: 16),
                            SizedBox(width: 8),
                            Text('Set as Default'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showAddAddressDialog() {
    _showAddressFormDialog(null);
  }

  void _showEditAddressDialog(Map<String, dynamic> address) {
    _showAddressFormDialog(address);
  }

  void _showAddressFormDialog(Map<String, dynamic>? existingAddress) {
    showDialog(
      context: context,
      builder: (context) => AddressFormDialog(
        existingAddress: existingAddress,
        onSaved: (savedAddress) {
          setState(() {
            if (existingAddress != null) {
              // Update existing
              final index = _savedAddresses.indexWhere((a) => a['id'] == existingAddress['id']);
              if (index >= 0) {
                _savedAddresses[index] = savedAddress;
              }
            } else {
              // Add new
              _savedAddresses.add(savedAddress);
            }
          });
        },
      ),
    );
  }

  Future<void> _deleteAddress(Map<String, dynamic> address) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Address'),
        content: const Text('Are you sure you want to delete this address?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _addressService.deleteAddress(address['id']);
        setState(() {
          _savedAddresses.removeWhere((a) => a['id'] == address['id']);
          if (widget.selectedAddress?['id'] == address['id']) {
            widget.onAddressSelected({});
          }
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Address deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete address: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _setDefaultAddress(Map<String, dynamic> address) async {
    try {
      await _addressService.setDefaultAddress(address['id']);
      setState(() {
        // Update all addresses to unset default
        for (var addr in _savedAddresses) {
          addr['is_default'] = false;
        }
        // Set the selected one as default
        final index = _savedAddresses.indexWhere((a) => a['id'] == address['id']);
        if (index >= 0) {
          _savedAddresses[index]['is_default'] = true;
        }
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Default address updated'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update default address: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class AddressFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existingAddress;
  final Function(Map<String, dynamic>) onSaved;

  const AddressFormDialog({
    super.key,
    this.existingAddress,
    required this.onSaved,
  });

  @override
  State<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<AddressFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _labelController = TextEditingController();
  final _addressController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _cityController = TextEditingController();
  final _pincodeController = TextEditingController();
  bool _isDefault = false;
  bool _isLoading = false;

  final _addressService = AddressService();

  @override
  void initState() {
    super.initState();
    if (widget.existingAddress != null) {
      final addr = widget.existingAddress!;
      _labelController.text = addr['label'] ?? '';
      _addressController.text = addr['address'] ?? '';
      _landmarkController.text = addr['landmark'] ?? '';
      _cityController.text = addr['city'] ?? '';
      _pincodeController.text = addr['pincode'] ?? '';
      _isDefault = addr['is_default'] ?? false;
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    _cityController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: double.maxFinite,
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.existingAddress != null ? 'Edit Address' : 'Add New Address',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _labelController,
                decoration: const InputDecoration(
                  labelText: 'Address Label (e.g., Home, Office)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter an address label';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Complete Address',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter the address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _landmarkController,
                decoration: const InputDecoration(
                  labelText: 'Landmark (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cityController,
                      decoration: const InputDecoration(
                        labelText: 'City',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter city';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _pincodeController,
                      decoration: const InputDecoration(
                        labelText: 'Pincode',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Please enter pincode';
                        }
                        if (value.trim().length != 6) {
                          return 'Please enter valid pincode';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              CheckboxListTile(
                title: const Text('Set as default address'),
                value: _isDefault,
                onChanged: (value) {
                  setState(() {
                    _isDefault = value ?? false;
                  });
                },
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 24),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isLoading ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveAddress() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final auth = Provider.of<AuthProvider>(context, listen: false);
      final fullAddress = '${_addressController.text}, ${_cityController.text}, ${_pincodeController.text}';
      
      final addressData = {
        'tenant_id': auth.tenantId,
        'customer_phone': auth.currentUser?.phone ?? '',
        'label': _labelController.text.trim(),
        'address': _addressController.text.trim(),
        'landmark': _landmarkController.text.trim(),
        'city': _cityController.text.trim(),
        'pincode': _pincodeController.text.trim(),
        'full_address': fullAddress,
        'is_default': _isDefault,
      };

      Map<String, dynamic> savedAddress;
      if (widget.existingAddress != null) {
        savedAddress = await _addressService.updateAddress(widget.existingAddress!['id'], addressData);
      } else {
        savedAddress = await _addressService.saveAddress(addressData);
      }

      widget.onSaved(savedAddress);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Address ${widget.existingAddress != null ? 'updated' : 'saved'} successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save address: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}