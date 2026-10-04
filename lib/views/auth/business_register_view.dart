import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/auth_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BusinessRegisterView extends StatefulWidget {
  const BusinessRegisterView({super.key});

  @override
  State<BusinessRegisterView> createState() => _BusinessRegisterViewState();
}

class _BusinessRegisterViewState extends State<BusinessRegisterView> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;
  int _currentStep = 0;

  // Step 1: Business Information
  final _businessNameCtrl = TextEditingController();
  final _licenseNoCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  
  // Step 2: Contact Information
  final _ownerNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  
  // Step 3: Account Credentials
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;

  @override
  void dispose() {
    _businessNameCtrl.dispose();
    _licenseNoCtrl.dispose();
    _gstinCtrl.dispose();
    _ownerNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleRegistration() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_agreeToTerms) {
      setState(() => _errorMessage = 'Please accept the Terms & Conditions');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final email = _emailCtrl.text.trim();
      final password = _passwordCtrl.text;
      
      // Step 1: Create auth user and automatically sign in
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (authResponse.user == null) {
        throw Exception('Failed to create account. Please try again.');
      }

      final userId = authResponse.user!.id;

      // Step 1.5: Ensure user is signed in (signUp sometimes doesn't auto-login)
      if (authResponse.session == null) {
        // Sign in to get a session
        final signInResponse = await supabase.auth.signInWithPassword(
          email: email,
          password: password,
        );
        
        if (signInResponse.session == null) {
          throw Exception('Failed to authenticate. Please try logging in.');
        }
      }

      // Step 2: Create tenant record
      final tenantData = {
        'id': userId, // Use auth user ID as tenant ID for simplicity
        'business_name': _businessNameCtrl.text.trim(),
        'owner_name': _ownerNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'drug_license_no': _licenseNoCtrl.text.trim(),
        'gstin': _gstinCtrl.text.trim().isEmpty ? null : _gstinCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'subscription_status': 'trial',
        'trial_ends_at': DateTime.now().add(const Duration(days: 7)).toIso8601String(),
        'is_active': true,
      };

      await supabase.from('tenants').insert(tenantData);

      // Step 3: Create user record
      final userData = {
        'id': userId,
        'tenant_id': userId,
        'name': _ownerNameCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'role': 'business_admin',
        'is_active': true,
        'email_verified': false,
        'registration_date': DateTime.now().toIso8601String(),
      };

      await supabase.from('users').insert(userData);

      // Step 4: Create default branch
      final branchData = {
        'id': '${userId}_main',
        'tenant_id': userId,
        'branch_name': '${_businessNameCtrl.text.trim()} - Main',
        'branch_code': 'MAIN',
        'manager_name': _ownerNameCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'city': _cityCtrl.text.trim(),
        'state': _stateCtrl.text.trim(),
        'pincode': _pincodeCtrl.text.trim(),
        'is_active': true,
      };

      await supabase.from('branches').insert(branchData);

      // Success! Show confirmation dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } on AuthException catch (e) {
      setState(() => _errorMessage = e.message);
    } on PostgrestException catch (e) {
      setState(() => _errorMessage = 'Database error: ${e.message}');
    } catch (e) {
      setState(() => _errorMessage = 'Registration failed: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
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
              'Welcome to BillSprout! 🎉',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              'Your 7-day free trial has started. '
              'We\'ve sent a verification email to ${_emailCtrl.text.trim()}.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Next Steps:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  SizedBox(height: 8),
                  Text('1. Check your email and verify your account', style: TextStyle(fontSize: 12)),
                  Text('2. Choose a subscription plan', style: TextStyle(fontSize: 12)),
                  Text('3. Download and install BillSprout', style: TextStyle(fontSize: 12)),
                  Text('4. Start managing your pharmacy!', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.pushReplacementNamed(context, '/subscription-plans');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              foregroundColor: Colors.white,
            ),
            child: const Text('Choose Your Plan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Business Registration'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
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
                    'Join hundreds of pharmacies using BillSprout. No credit card required.',
                    style: TextStyle(fontSize: 14, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 32),

                  // Stepper
                  Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppTheme.primaryBlue,
                      ),
                    ),
                    child: Stepper(
                      currentStep: _currentStep,
                      onStepContinue: () {
                        if (_currentStep < 2) {
                          setState(() => _currentStep++);
                        } else {
                          _handleRegistration();
                        }
                      },
                      onStepCancel: () {
                        if (_currentStep > 0) {
                          setState(() => _currentStep--);
                        }
                      },
                      controlsBuilder: (context, details) {
                        return Row(
                          children: [
                            ElevatedButton(
                              onPressed: _isLoading ? null : details.onStepContinue,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(_currentStep == 2 ? 'Register' : 'Continue'),
                            ),
                            if (_currentStep > 0) ...[
                              const SizedBox(width: 12),
                              TextButton(
                                onPressed: details.onStepCancel,
                                child: const Text('Back'),
                              ),
                            ],
                          ],
                        );
                      },
                      steps: [
                        // Step 1: Business Information
                        Step(
                          title: const Text('Business Information'),
                          content: Column(
                            children: [
                              TextFormField(
                                controller: _businessNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Pharmacy Name *',
                                  hintText: 'ABC Medical Store',
                                  prefixIcon: Icon(Icons.business),
                                ),
                                validator: (v) => v?.trim().isEmpty ?? true
                                    ? 'Please enter pharmacy name'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _licenseNoCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Drug License Number *',
                                  hintText: 'DL1234567890',
                                  prefixIcon: Icon(Icons.verified_user),
                                ),
                                validator: (v) => v?.trim().isEmpty ?? true
                                    ? 'Please enter license number'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _gstinCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'GSTIN (Optional)',
                                  hintText: '22AAAAA0000A1Z5',
                                  prefixIcon: Icon(Icons.receipt_long),
                                ),
                              ),
                            ],
                          ),
                          isActive: _currentStep >= 0,
                        ),

                        // Step 2: Contact Information
                        Step(
                          title: const Text('Contact Information'),
                          content: Column(
                            children: [
                              TextFormField(
                                controller: _ownerNameCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'Owner Name *',
                                  hintText: 'John Doe',
                                  prefixIcon: Icon(Icons.person),
                                ),
                                validator: (v) => v?.trim().isEmpty ?? true
                                    ? 'Please enter owner name'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _emailCtrl,
                                keyboardType: TextInputType.emailAddress,
                                decoration: const InputDecoration(
                                  labelText: 'Email Address *',
                                  hintText: 'owner@pharmacy.com',
                                  prefixIcon: Icon(Icons.email),
                                ),
                                validator: (v) {
                                  if (v?.trim().isEmpty ?? true) return 'Please enter email';
                                  if (!v!.contains('@')) return 'Invalid email';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _phoneCtrl,
                                keyboardType: TextInputType.phone,
                                decoration: const InputDecoration(
                                  labelText: 'Phone Number *',
                                  hintText: '+91 98765 43210',
                                  prefixIcon: Icon(Icons.phone),
                                ),
                                validator: (v) => v?.trim().isEmpty ?? true
                                    ? 'Please enter phone number'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _addressCtrl,
                                maxLines: 2,
                                decoration: const InputDecoration(
                                  labelText: 'Address *',
                                  hintText: 'Street, Area',
                                  prefixIcon: Icon(Icons.location_on),
                                ),
                                validator: (v) => v?.trim().isEmpty ?? true
                                    ? 'Please enter address'
                                    : null,
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextFormField(
                                      controller: _cityCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'City *',
                                        hintText: 'Mumbai',
                                      ),
                                      validator: (v) => v?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _stateCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'State *',
                                        hintText: 'Maharashtra',
                                      ),
                                      validator: (v) => v?.trim().isEmpty ?? true
                                          ? 'Required'
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _pincodeCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                decoration: const InputDecoration(
                                  labelText: 'Pincode *',
                                  hintText: '400001',
                                  prefixIcon: Icon(Icons.pin_drop),
                                ),
                                validator: (v) {
                                  if (v?.trim().isEmpty ?? true) return 'Required';
                                  if (v!.length != 6) return 'Invalid pincode';
                                  return null;
                                },
                              ),
                            ],
                          ),
                          isActive: _currentStep >= 1,
                        ),

                        // Step 3: Account Credentials
                        Step(
                          title: const Text('Create Password'),
                          content: Column(
                            children: [
                              TextFormField(
                                controller: _passwordCtrl,
                                obscureText: _obscurePassword,
                                decoration: InputDecoration(
                                  labelText: 'Password *',
                                  hintText: 'Min 8 characters',
                                  prefixIcon: const Icon(Icons.lock),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscurePassword
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword),
                                  ),
                                ),
                                validator: (v) {
                                  if (v?.isEmpty ?? true) return 'Please enter password';
                                  if (v!.length < 8) return 'Min 8 characters required';
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),
                              TextFormField(
                                controller: _confirmPasswordCtrl,
                                obscureText: _obscureConfirm,
                                decoration: InputDecoration(
                                  labelText: 'Confirm Password *',
                                  hintText: 'Re-enter password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: IconButton(
                                    icon: Icon(_obscureConfirm
                                        ? Icons.visibility_off
                                        : Icons.visibility),
                                    onPressed: () => setState(
                                        () => _obscureConfirm = !_obscureConfirm),
                                  ),
                                ),
                                validator: (v) {
                                  if (v != _passwordCtrl.text) {
                                    return 'Passwords do not match';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),
                              CheckboxListTile(
                                value: _agreeToTerms,
                                onChanged: (val) => setState(() => _agreeToTerms = val ?? false),
                                title: const Text(
                                  'I agree to the Terms & Conditions and Privacy Policy',
                                  style: TextStyle(fontSize: 13),
                                ),
                                controlAffinity: ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                          isActive: _currentStep >= 2,
                        ),
                      ],
                    ),
                  ),

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.errorRed),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(color: AppTheme.errorRed, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 24),
                  
                  // Already have account
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Already have an account? Sign In'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
