import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../config/app_theme.dart';
import '../../models/company_model.dart';
import '../../providers/super_admin_provider.dart';

/// Full tenant provisioning form.
///
/// Every non-nullable field on [CompanyModel] is captured here. The previous
/// inline dialog only asked for four fields and hardcoded GSTIN, drug licence
/// and address, which meant every tenant landed in the database with the same
/// placeholder compliance data.
class AddTenantDialog extends StatefulWidget {
  const AddTenantDialog({super.key});

  @override
  State<AddTenantDialog> createState() => _AddTenantDialogState();
}

class _AddTenantDialogState extends State<AddTenantDialog> {
  final _formKey = GlobalKey<FormState>();

  final _businessName = TextEditingController();
  final _ownerName = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _gstin = TextEditingController();
  final _drugLicenseNo = TextEditingController();
  final _address = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _pincode = TextEditingController();
  final _adminPassword = TextEditingController();

  DateTime? _drugLicenseExpiry;
  IndustryType _industryType = IndustryType.pharmacy;
  BusinessMode _businessMode = BusinessMode.retail;
  String _subscriptionPlan = 'Gold Edition';
  int _maxBranches = 1;
  bool _submitting = false;

  static const _plans = ['Basic Plan', 'Professional Plan', 'Gold Edition'];

  @override
  void dispose() {
    for (final c in [
      _businessName,
      _ownerName,
      _email,
      _phone,
      _gstin,
      _drugLicenseNo,
      _address,
      _city,
      _state,
      _pincode,
      _adminPassword,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v, String label) {
    if (v == null || v.trim().isEmpty) return '$label is required';
    return null;
  }

  String? _validateEmail(String? v) {
    final base = _required(v, 'Email');
    if (base != null) return base;
    final ok = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(v!.trim());
    return ok ? null : 'Enter a valid email address';
  }

  String? _validatePhone(String? v) {
    final base = _required(v, 'Phone');
    if (base != null) return base;
    final digits = v!.replaceAll(RegExp(r'\D'), '');
    return digits.length == 10 ? null : 'Enter a 10 digit mobile number';
  }

  String? _validateGstin(String? v) {
    final base = _required(v, 'GSTIN');
    if (base != null) return base;
    final ok = RegExp(r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z]{1}[1-9A-Z]{1}Z[0-9A-Z]{1}$')
        .hasMatch(v!.trim().toUpperCase());
    return ok ? null : 'GSTIN must be 15 characters, e.g. 07ABCDE1234F1Z5';
  }

  String? _validatePincode(String? v) {
    final base = _required(v, 'Pincode');
    if (base != null) return base;
    final ok = RegExp(r'^[1-9][0-9]{5}$').hasMatch(v!.trim());
    return ok ? null : 'Pincode must be 6 digits';
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Admin password is required';
    if (v.length < 8) return 'Use at least 8 characters';
    return null;
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _drugLicenseExpiry ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
      helpText: 'Drug licence expiry date',
    );
    if (picked != null) setState(() => _drugLicenseExpiry = picked);
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_drugLicenseExpiry == null) {
      _toast('Select the drug licence expiry date', AppTheme.errorRed);
      return;
    }

    setState(() => _submitting = true);

    final now = DateTime.now();
    final company = CompanyModel(
      id: const Uuid().v4(),
      businessName: _businessName.text.trim(),
      ownerName: _ownerName.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      gstin: _gstin.text.trim().toUpperCase(),
      drugLicenseNo: _drugLicenseNo.text.trim(),
      drugLicenseExpiry: _drugLicenseExpiry,
      address: _address.text.trim(),
      city: _city.text.trim(),
      state: _state.text.trim(),
      pincode: _pincode.text.trim(),
      industryType: _industryType,
      businessMode: _businessMode,
      subscriptionPlan: _subscriptionPlan,
      maxBranches: _maxBranches,
      createdAt: now,
      updatedAt: now,
    );

    final provider = context.read<SuperAdminProvider>();
    final ok = await provider.addCompanyTenant(
      company,
      adminPassword: _adminPassword.text,
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (ok) {
      Navigator.pop(context);
      _toast(
        'Tenant "${company.businessName}" provisioned. Admin login: ${company.email}',
        AppTheme.successGreen,
      );
    } else {
      _toast(
        provider.error ?? 'Could not provision the tenant',
        AppTheme.errorRed,
      );
    }
  }

  void _toast(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.add_business, color: AppTheme.primaryBlue),
          SizedBox(width: 10),
          Expanded(child: Text('Create New Business Tenant Account')),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel('Business identity'),
                _field(_businessName, 'Company / Store Name',
                    validator: (v) => _required(v, 'Company name')),
                _field(_ownerName, 'Owner / MD Name',
                    validator: (v) => _required(v, 'Owner name')),
                Row(children: [
                  Expanded(
                    child: _field(_email, 'Store Email (admin login)',
                        keyboardType: TextInputType.emailAddress,
                        validator: _validateEmail),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_phone, 'WhatsApp Phone',
                        keyboardType: TextInputType.phone,
                        validator: _validatePhone),
                  ),
                ]),

                _sectionLabel('Compliance'),
                Row(children: [
                  Expanded(
                    child: _field(_gstin, 'GSTIN',
                        textCapitalization: TextCapitalization.characters,
                        validator: _validateGstin),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_drugLicenseNo, 'Drug Licence No.',
                        validator: (v) => _required(v, 'Drug licence number')),
                  ),
                ]),
                const SizedBox(height: 10),
                InkWell(
                  onTap: _pickExpiry,
                  borderRadius: BorderRadius.circular(6),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Drug Licence Expiry',
                      border: const OutlineInputBorder(),
                      errorText: _drugLicenseExpiry == null ? null : null,
                      suffixIcon: const Icon(Icons.calendar_today, size: 18),
                    ),
                    child: Text(
                      _drugLicenseExpiry == null
                          ? 'Select a date'
                          : '${_drugLicenseExpiry!.day.toString().padLeft(2, '0')}'
                              '/${_drugLicenseExpiry!.month.toString().padLeft(2, '0')}'
                              '/${_drugLicenseExpiry!.year}',
                      style: TextStyle(
                        color: _drugLicenseExpiry == null
                            ? AppTheme.textMuted
                            : null,
                      ),
                    ),
                  ),
                ),

                _sectionLabel('Registered address'),
                _field(_address, 'Address',
                    maxLines: 2,
                    validator: (v) => _required(v, 'Address')),
                Row(children: [
                  Expanded(
                    child: _field(_city, 'City',
                        validator: (v) => _required(v, 'City')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_state, 'State',
                        validator: (v) => _required(v, 'State')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _field(_pincode, 'Pincode',
                        keyboardType: TextInputType.number,
                        validator: _validatePincode),
                  ),
                ]),

                _sectionLabel('Plan & operating mode'),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<IndustryType>(
                      value: _industryType,
                      decoration: const InputDecoration(
                          labelText: 'Industry Type',
                          border: OutlineInputBorder()),
                      items: IndustryType.values
                          .map((t) => DropdownMenuItem(
                              value: t, child: Text(t.label)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _industryType = v ?? _industryType),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<BusinessMode>(
                      value: _businessMode,
                      decoration: const InputDecoration(
                          labelText: 'Billing Mode',
                          border: OutlineInputBorder()),
                      items: BusinessMode.values
                          .map((m) => DropdownMenuItem(
                              value: m, child: Text(m.label)))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _businessMode = v ?? _businessMode),
                    ),
                  ),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _subscriptionPlan,
                      decoration: const InputDecoration(
                          labelText: 'Subscription Plan',
                          border: OutlineInputBorder()),
                      items: _plans
                          .map((p) =>
                              DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (v) => setState(
                          () => _subscriptionPlan = v ?? _subscriptionPlan),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      value: _maxBranches,
                      decoration: const InputDecoration(
                          labelText: 'Max Branches',
                          border: OutlineInputBorder()),
                      items: const [1, 2, 5, 10, 25, 50]
                          .map((n) => DropdownMenuItem(
                              value: n, child: Text('$n')))
                          .toList(),
                      onChanged: (v) =>
                          setState(() => _maxBranches = v ?? _maxBranches),
                    ),
                  ),
                ]),

                _sectionLabel('Initial admin credentials'),
                _field(_adminPassword, 'Temporary Admin Password',
                    obscure: true, validator: _validatePassword),
                const SizedBox(height: 6),
                const Text(
                  'A business_admin auth user is created with the store email '
                  'above and linked to this tenant. Ask the owner to change '
                  'the password on first login.',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check),
          label: Text(_submitting ? 'Provisioning...' : 'Provision Tenant'),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
            color: AppTheme.primaryBlue,
          ),
        ),
      );

  Widget _field(
    TextEditingController controller,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool obscure = false,
    int maxLines = 1,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          obscureText: obscure,
          maxLines: obscure ? 1 : maxLines,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
        ),
      );
}
