import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_theme.dart';
import '../../models/demo_request_model.dart';
import '../../services/supabase_service.dart';

/// Public lead capture form. Unauthenticated: the `demo_requests` table grants
/// INSERT to the anon role and nothing else, so a visitor can submit a lead but
/// cannot read anyone else's.
class DemoRequestForm extends StatefulWidget {
  const DemoRequestForm({super.key});

  @override
  State<DemoRequestForm> createState() => _DemoRequestFormState();
}

class _DemoRequestFormState extends State<DemoRequestForm> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _businessName = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _city = TextEditingController();
  final _pincode = TextEditingController();
  final _message = TextEditingController();

  String _businessType = 'Pharmacy / Medical';
  int _numBranches = 1;
  bool _submitting = false;
  bool _submitted = false;
  String? _error;

  static const _businessTypes = [
    'Pharmacy / Medical',
    'Wholesale Distribution',
    'Retail Supermarket',
    'FMCG & Manufacturing',
    'Restaurant & Hospitality',
  ];

  @override
  void dispose() {
    for (final c in [
      _name,
      _businessName,
      _mobile,
      _email,
      _city,
      _pincode,
      _message,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _requiredField(String? v, String label) =>
      (v == null || v.trim().isEmpty) ? '$label is required' : null;

  String? _validateMobile(String? v) {
    final base = _requiredField(v, 'Mobile number');
    if (base != null) return base;
    final digits = v!.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 10 ? null : 'Enter a valid mobile number';
  }

  String? _validateEmail(String? v) {
    // Optional, but must be well formed when supplied.
    if (v == null || v.trim().isEmpty) return null;
    final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v.trim());
    return ok ? null : 'Enter a valid email address';
  }

  String? _validatePincode(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return RegExp(r'^[1-9][0-9]{5}$').hasMatch(v.trim())
        ? null
        : 'Pincode must be 6 digits';
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    final request = DemoRequestModel(
      id: const Uuid().v4(),
      name: _name.text.trim(),
      businessName: _businessName.text.trim().isEmpty
          ? null
          : _businessName.text.trim(),
      mobile: _mobile.text.trim(),
      email: _email.text.trim().isEmpty ? null : _email.text.trim(),
      city: _city.text.trim().isEmpty ? null : _city.text.trim(),
      pincode: _pincode.text.trim().isEmpty ? null : _pincode.text.trim(),
      businessType: _businessType,
      numBranches: _numBranches,
      message: _message.text.trim().isEmpty ? null : _message.text.trim(),
      createdAt: DateTime.now(),
    );

    try {
      // Save to database
      await SupabaseService().insertDemoRequest(request.toJson());
      
      // Send notification email to arifsheik@lifesproutcare.com
      await _sendDemoNotification(request);
      
      // Send confirmation email to requester (optional)
      if (request.email != null && request.email!.isNotEmpty) {
        _sendDemoConfirmationEmail(request);
      }
      
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _submitted = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = SupabaseService.describeError(e);
      });
    }
  }

  Future<void> _sendDemoNotification(DemoRequestModel request) async {
    try {
      final supabase = Supabase.instance.client;
      
      // Call notify-demo-request edge function
      final response = await supabase.functions.invoke(
        'notify-demo-request',
        body: {
          'name': request.name,
          'email': request.email,
          'mobile': request.mobile,
          'businessName': request.businessName,
          'city': request.city,
          'pincode': request.pincode,
          'businessType': request.businessType,
          'numBranches': request.numBranches,
          'message': request.message,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to send demo notification');
      }
      
      debugPrint('Demo notification sent to arifsheik@lifesproutcare.com');
    } catch (e) {
      // Log error but don't fail the submission
      debugPrint('Failed to send demo notification: $e');
      // Rethrow so user knows the notification failed
      rethrow;
    }
  }

  Future<void> _sendDemoConfirmationEmail(DemoRequestModel request) async {
    try {
      if (request.email == null || request.email!.isEmpty) return;
      
      await SupabaseService().sendEmail(
        to: request.email!,
        subject: 'Demo Request Confirmation - LifeSprout',
        template: 'demo_request_confirmation',
        templateData: {
          'name': request.name,
          'email': request.email,
          'phone': request.mobile,
          'business_name': request.businessName,
        },
      );
    } catch (e) {
      // Don't fail the submission if email fails
      debugPrint('Failed to send demo confirmation email: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _confirmation();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Request a Demo',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tell us about your business and we will set up a walkthrough.',
                style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 20),

              if (_error != null)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.errorRed.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppTheme.errorRed.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppTheme.errorRed, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.errorRed)),
                      ),
                    ],
                  ),
                ),

              _field(_name, 'Your Name *',
                  validator: (v) => _requiredField(v, 'Name')),
              _field(_businessName, 'Business Name'),
              Row(children: [
                Expanded(
                  child: _field(_mobile, 'Mobile Number *',
                      keyboardType: TextInputType.phone,
                      validator: _validateMobile),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_email, 'Email',
                      keyboardType: TextInputType.emailAddress,
                      validator: _validateEmail),
                ),
              ]),
              Row(children: [
                Expanded(child: _field(_city, 'City')),
                const SizedBox(width: 12),
                Expanded(
                  child: _field(_pincode, 'Pincode',
                      keyboardType: TextInputType.number,
                      validator: _validatePincode),
                ),
              ]),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _businessType,
                    decoration: const InputDecoration(
                        labelText: 'Business Type',
                        border: OutlineInputBorder(),
                        isDense: true),
                    items: _businessTypes
                        .map((t) =>
                            DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _businessType = v ?? _businessType),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _numBranches,
                    decoration: const InputDecoration(
                        labelText: 'Branches',
                        border: OutlineInputBorder(),
                        isDense: true),
                    items: const [1, 2, 3, 5, 10, 25]
                        .map((n) =>
                            DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _numBranches = v ?? _numBranches),
                  ),
                ),
              ]),
              const SizedBox(height: 10),
              _field(_message, 'Anything specific you want to see?',
                  maxLines: 3),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _submitting ? null : _submit,
                  icon: _submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.send),
                  label: Text(_submitting ? 'Sending...' : 'Request Demo'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _confirmation() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle,
                color: AppTheme.successGreen, size: 56),
            const SizedBox(height: 16),
            const Text(
              'Request received',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Thanks ${_name.text.trim()}. Our team will reach you on '
              '${_mobile.text.trim()} shortly.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => setState(() {
                _submitted = false;
                _formKey.currentState?.reset();
                for (final c in [
                  _name,
                  _businessName,
                  _mobile,
                  _email,
                  _city,
                  _pincode,
                  _message,
                ]) {
                  c.clear();
                }
              }),
              child: const Text('Submit another request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
