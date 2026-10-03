import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/supabase_service.dart';

/// Tenant (Pharmacy) Registration View
/// 
/// Allows new pharmacies to sign up and create their business account.
/// Creates tenant, branch, and admin user in Supabase.
class TenantRegistrationView extends StatefulWidget {
  const TenantRegistrationView({super.key});

  @override
  State<TenantRegistrationView> createState() => _TenantRegistrationViewState();
}

class _TenantRegistrationViewState extends State<TenantRegistrationView> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  int _currentStep = 0;

  // Pharmacy details
  final _pharmacyNameCtrl = TextEditingController();
  final _pharmacyLicenseCtrl = TextEditingController();
  final _pharmacyAddressCtrl = TextEditingController();
  final _pharmacyCityCtrl = TextEditingController();
  final _pharmacyStateCtrl = TextEditingController();
  final _pharmacyPinCodeCtrl = TextEditingController();
  final _pharmacyPhoneCtrl = TextEditingController();
  final _pharmacyGstinCtrl = TextEditingController();

  // Admin user details
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _adminPhoneCtrl = TextEditingController();
  final _adminPasswordCtrl = TextEditingController();
  final _adminConfirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _pharmacyNameCtrl.dispose();
    _pharmacyLicenseCtrl.dispose();
    _pharmacyAddressCtrl.dispose();
    _pharmacyCityCtrl.dispose();
    _pharmacyStateCtrl.dispose();
    _pharmacyPinCodeCtrl.dispose();
    _pharmacyPhoneCtrl.dispose();
    _pharmacyGstinCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _adminPhoneCtrl.dispose();
    _adminPasswordCtrl.dispose();
    _adminConfirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Your Pharmacy'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        const Text(
                          'Start Your Free Trial',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryBlue,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Complete the registration to set up your pharmacy account',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Step indicator
                        _buildStepIndicator(),
                        const SizedBox(height: 32),

                        // Form content
                        if (_currentStep == 0)
                          _buildPharmacyDetailsForm()
                        else
                          _buildAdminDetailsForm(),

                        const SizedBox(height: 24),

                        // Error message
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.errorRed.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppTheme.errorRed),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: AppTheme.errorRed),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.errorRed,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Navigation buttons
                        Row(
                          children: [
                            if (_currentStep > 0)
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () {
                                    setState(() {
                                      _currentStep = 0;
                                      _errorMessage = null;
                                    });
                                  },
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                  ),
                                  child: const Text('Back'),
                                ),
                              ),
                            if (_currentStep > 0) const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: _currentStep == 0
                                    ? _nextStep
                                    : _submitRegistration,
                                style: ElevatedButton.styleFrom(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  backgroundColor: AppTheme.successGreen,
                                ),
                                child: Text(
                                  _currentStep == 0
                                      ? 'Continue'
                                      : 'Complete Registration',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _stepCircle(1, 'Pharmacy Details', _currentStep >= 0),
        Expanded(
          child: Container(
            height: 2,
            color: _currentStep >= 1
                ? AppTheme.successGreen
                : Colors.grey.shade300,
          ),
        ),
        _stepCircle(2, 'Admin Account', _currentStep >= 1),
      ],
    );
  }

  Widget _stepCircle(int step, String label, bool isActive) {
    return Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: isActive ? AppTheme.successGreen : Colors.grey.shade300,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              step.toString(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isActive ? AppTheme.primaryBlue : AppTheme.textMuted,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPharmacyDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pharmacy Information',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _pharmacyNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Pharmacy Name *',
            hintText: 'e.g. MediCare Pharmacy',
            prefixIcon: Icon(Icons.store),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter pharmacy name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pharmacyLicenseCtrl,
          decoration: const InputDecoration(
            labelText: 'Drug License Number *',
            hintText: 'e.g. DL/21B/2024/001234',
            prefixIcon: Icon(Icons.badge),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter drug license number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pharmacyGstinCtrl,
          decoration: const InputDecoration(
            labelText: 'GSTIN (Optional)',
            hintText: 'e.g. 27AABCT1234C1Z5',
            prefixIcon: Icon(Icons.receipt_long),
          ),
          textCapitalization: TextCapitalization.characters,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _pharmacyAddressCtrl,
          decoration: const InputDecoration(
            labelText: 'Address *',
            hintText: 'Street address',
            prefixIcon: Icon(Icons.location_on),
          ),
          maxLines: 2,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter pharmacy address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _pharmacyCityCtrl,
                decoration: const InputDecoration(
                  labelText: 'City *',
                  prefixIcon: Icon(Icons.location_city),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _pharmacyStateCtrl,
                decoration: const InputDecoration(
                  labelText: 'State *',
                  prefixIcon: Icon(Icons.map),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _pharmacyPinCodeCtrl,
                decoration: const InputDecoration(
                  labelText: 'PIN Code *',
                  prefixIcon: Icon(Icons.pin_drop),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _pharmacyPhoneCtrl,
                decoration: const InputDecoration(
                  labelText: 'Phone *',
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Required';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAdminDetailsForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Admin Account',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'This will be the primary administrator account for your pharmacy',
          style: TextStyle(
            fontSize: 14,
            color: AppTheme.textMuted,
          ),
        ),
        const SizedBox(height: 20),
        TextFormField(
          controller: _adminNameCtrl,
          decoration: const InputDecoration(
            labelText: 'Full Name *',
            hintText: 'e.g. Dr. John Doe',
            prefixIcon: Icon(Icons.person),
          ),
          textCapitalization: TextCapitalization.words,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter your full name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _adminEmailCtrl,
          decoration: const InputDecoration(
            labelText: 'Email Address *',
            hintText: 'admin@pharmacy.com',
            prefixIcon: Icon(Icons.email),
          ),
          keyboardType: TextInputType.emailAddress,
          validator: (value) {
            if (value == null || value.trim().isEmpty || !value.contains('@')) {
              return 'Please enter a valid email address';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _adminPhoneCtrl,
          decoration: const InputDecoration(
            labelText: 'Phone Number *',
            hintText: '+91 9876543210',
            prefixIcon: Icon(Icons.phone),
          ),
          keyboardType: TextInputType.phone,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter phone number';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _adminPasswordCtrl,
          obscureText: _obscurePassword,
          decoration: InputDecoration(
            labelText: 'Password *',
            hintText: 'Minimum 6 characters',
            prefixIcon: const Icon(Icons.lock),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() => _obscurePassword = !_obscurePassword);
              },
            ),
          ),
          validator: (value) {
            if (value == null || value.length < 6) {
              return 'Password must be at least 6 characters';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _adminConfirmPasswordCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirm Password *',
            hintText: 'Re-enter your password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _obscureConfirm
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () {
                setState(() => _obscureConfirm = !_obscureConfirm);
              },
            ),
          ),
          validator: (value) {
            if (value != _adminPasswordCtrl.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'You will need to confirm your email address after registration',
                  style: TextStyle(fontSize: 12, color: Colors.blue),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _nextStep() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _currentStep = 1;
        _errorMessage = null;
      });
    }
  }

  Future<void> _submitRegistration() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Step 1: Create auth user in Supabase Auth
      final supabase = SupabaseService();
      final authResponse = await supabase.signUp(
        email: _adminEmailCtrl.text.trim(),
        password: _adminPasswordCtrl.text,
        data: {
          'name': _adminNameCtrl.text.trim(),
          'phone': _adminPhoneCtrl.text.trim(),
          'role': 'businessAdmin',
        },
      );

      if (authResponse.user == null) {
        throw Exception(
            'Registration successful! Please check your email to verify your account.');
      }

      final userId = authResponse.user!.id;
      const uuid = Uuid();
      final tenantId = uuid.v4();
      final branchId = uuid.v4();

      // Step 2: Create tenant (company) record
      await supabase.client.from('tenants').insert({
        'id': tenantId,
        'company_name': _pharmacyNameCtrl.text.trim(),
        'drug_license_no': _pharmacyLicenseCtrl.text.trim(),
        'gstin': _pharmacyGstinCtrl.text.trim().isEmpty
            ? null
            : _pharmacyGstinCtrl.text.trim(),
        'address': _pharmacyAddressCtrl.text.trim(),
        'city': _pharmacyCityCtrl.text.trim(),
        'state': _pharmacyStateCtrl.text.trim(),
        'pin_code': _pharmacyPinCodeCtrl.text.trim(),
        'phone': _pharmacyPhoneCtrl.text.trim(),
        'status': 'active',
        'subscription_status': 'trial',
        'trial_ends_at':
            DateTime.now().add(const Duration(days: 14)).toIso8601String(),
      });

      // Step 3: Create main branch
      await supabase.client.from('branches').insert({
        'id': branchId,
        'tenant_id': tenantId,
        'branch_name': 'Main Branch',
        'branch_code': 'MAIN',
        'address': _pharmacyAddressCtrl.text.trim(),
        'city': _pharmacyCityCtrl.text.trim(),
        'state': _pharmacyStateCtrl.text.trim(),
        'pin_code': _pharmacyPinCodeCtrl.text.trim(),
        'phone': _pharmacyPhoneCtrl.text.trim(),
        'is_main_branch': true,
        'status': 'active',
      });

      // Step 4: Create user profile with tenant/branch association
      await supabase.client.from('users').insert({
        'id': userId,
        'tenant_id': tenantId,
        'branch_id': branchId,
        'name': _adminNameCtrl.text.trim(),
        'email': _adminEmailCtrl.text.trim(),
        'phone': _adminPhoneCtrl.text.trim(),
        'role': 'businessAdmin',
        'status': 'active',
      });

      // Step 5: Update user metadata with tenant/branch IDs
      await supabase.client.auth.updateUser(
        UserAttributes(
          data: {
            'tenant_id': tenantId,
            'branch_id': branchId,
            'name': _adminNameCtrl.text.trim(),
            'phone': _adminPhoneCtrl.text.trim(),
            'role': 'businessAdmin',
          },
        ),
      );

      // Success! Navigate to login or show success message
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successGreen, size: 32),
                SizedBox(width: 12),
                Text('Registration Successful!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your pharmacy account has been created successfully.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Text(
                  'Pharmacy: ${_pharmacyNameCtrl.text}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Admin: ${_adminNameCtrl.text}',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.email, color: Colors.blue, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Please check your email to verify your account before signing in.',
                          style: TextStyle(fontSize: 12, color: Colors.blue),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop(); // Go back to login
                },
                child: const Text('Go to Sign In'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceAll('Exception: ', '');
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}
