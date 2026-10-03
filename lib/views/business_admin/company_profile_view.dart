import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/company_profile_provider.dart';

class CompanyProfileView extends StatefulWidget {
  /// When true, shown as a first-run wizard overlay
  final bool isFirstRun;
  const CompanyProfileView({super.key, this.isFirstRun = false});

  @override
  State<CompanyProfileView> createState() => _CompanyProfileViewState();
}

class _CompanyProfileViewState extends State<CompanyProfileView> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameCtrl;
  late TextEditingController _ownerCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _cityCtrl;
  late TextEditingController _stateCtrl;
  late TextEditingController _pinCtrl;
  late TextEditingController _gstinCtrl;
  late TextEditingController _dlCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _altPhoneCtrl;
  late TextEditingController _emailCtrl;
  late TextEditingController _stateCodeCtrl;
  late TextEditingController _bankCtrl;
  late TextEditingController _acNoCtrl;
  late TextEditingController _ifscCtrl;
  late TextEditingController _whatsappCtrl;
  late TextEditingController _panCtrl;
  late TextEditingController _bankBranchCtrl;
  late TextEditingController _termsCtrl;
  late TextEditingController _signatoryCtrl;
  late TextEditingController _logoPathCtrl;
  String _businessType = 'Retail';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p =
        Provider.of<CompanyProfileProvider>(context, listen: false).profile;
    _nameCtrl      = TextEditingController(text: p.pharmacyName == 'LifeSprout Care' ? '' : p.pharmacyName);
    _ownerCtrl     = TextEditingController(text: p.ownerName);
    _addressCtrl   = TextEditingController(text: p.address);
    _cityCtrl      = TextEditingController(text: p.city);
    _stateCtrl     = TextEditingController(text: p.state);
    _pinCtrl       = TextEditingController(text: p.pinCode);
    _gstinCtrl     = TextEditingController(text: p.gstin);
    _dlCtrl        = TextEditingController(text: p.drugLicenseNo);
    _phoneCtrl     = TextEditingController(text: p.phone);
    _altPhoneCtrl  = TextEditingController(text: p.altPhone);
    _emailCtrl     = TextEditingController(text: p.email);
    _stateCodeCtrl = TextEditingController(text: p.stateCode);
    _bankCtrl      = TextEditingController(text: p.bankName);
    _acNoCtrl      = TextEditingController(text: p.accountNumber);
    _ifscCtrl      = TextEditingController(text: p.ifscCode);
    _whatsappCtrl  = TextEditingController(text: p.whatsappNumber);
    _panCtrl       = TextEditingController(text: p.panNumber);
    _bankBranchCtrl = TextEditingController(text: p.bankBranch);
    _termsCtrl     = TextEditingController(text: p.termsAndConditions);
    _signatoryCtrl = TextEditingController(text: p.authorizedSignatory);
    _logoPathCtrl  = TextEditingController(text: p.logoPath);
    _businessType  = p.businessType;
  }

  @override
  void dispose() {
    for (final c in [_nameCtrl, _ownerCtrl, _addressCtrl, _cityCtrl,
        _stateCtrl, _pinCtrl, _gstinCtrl, _dlCtrl, _phoneCtrl,
        _altPhoneCtrl, _emailCtrl, _stateCodeCtrl, _bankCtrl,
        _acNoCtrl, _ifscCtrl, _whatsappCtrl, _panCtrl, _bankBranchCtrl,
        _termsCtrl, _signatoryCtrl, _logoPathCtrl]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final provider =
        Provider.of<CompanyProfileProvider>(context, listen: false);
    await provider.save(CompanyProfile(
      pharmacyName:  _nameCtrl.text.trim(),
      ownerName:     _ownerCtrl.text.trim(),
      address:       _addressCtrl.text.trim(),
      city:          _cityCtrl.text.trim(),
      state:         _stateCtrl.text.trim(),
      pinCode:       _pinCtrl.text.trim(),
      gstin:         _gstinCtrl.text.trim().toUpperCase(),
      drugLicenseNo: _dlCtrl.text.trim(),
      phone:         _phoneCtrl.text.trim(),
      altPhone:      _altPhoneCtrl.text.trim(),
      email:         _emailCtrl.text.trim(),
      stateCode:     _stateCodeCtrl.text.trim(),
      businessType:  _businessType,
      bankName:      _bankCtrl.text.trim(),
      accountNumber: _acNoCtrl.text.trim(),
      ifscCode:      _ifscCtrl.text.trim().toUpperCase(),
      whatsappNumber: _whatsappCtrl.text.trim(),
      panNumber:     _panCtrl.text.trim().toUpperCase(),
      bankBranch:    _bankBranchCtrl.text.trim(),
      termsAndConditions: _termsCtrl.text.trim(),
      authorizedSignatory: _signatoryCtrl.text.trim(),
      logoPath:      _logoPathCtrl.text.trim(),
    ));

    if (!mounted) return;
    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            '✅ Pharmacy profile saved — invoices will now show ${_nameCtrl.text.trim()}'),
        backgroundColor: AppTheme.successGreen,
      ),
    );

    if (widget.isFirstRun) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: widget.isFirstRun
          ? AppBar(
              title: const Text('Setup Your Pharmacy Profile'),
              automaticallyImplyLeading: false,
            )
          : null,
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!widget.isFirstRun) ...[
                const Text(
                  'Pharmacy / Company Profile',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue),
                ),
                const SizedBox(height: 4),
                const Text(
                  'This information appears on all invoices (retail & wholesale).',
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 20),
              ],

              if (widget.isFirstRun)
                Container(
                  padding: const EdgeInsets.all(14),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.local_pharmacy, color: AppTheme.primaryBlue),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Welcome! Set up your pharmacy details once — '
                          'they appear on every invoice you print.',
                          style: TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),

              _section('Pharmacy / Store Details'),
              _field(_nameCtrl,  'Pharmacy / Store Name *',  Icons.local_pharmacy, required: true),
              _field(_ownerCtrl, 'Owner / Proprietor Name', Icons.person),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _businessType,
                decoration: const InputDecoration(
                  labelText: 'Business Type',
                  prefixIcon: Icon(Icons.business_center),
                ),
                items: ['Retail', 'Wholesale', 'Both (Retail + Wholesale)']
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (v) => setState(() => _businessType = v ?? _businessType),
              ),
              const SizedBox(height: 20),

              _section('Address'),
              _field(_addressCtrl, 'Street / Door No *', Icons.home, required: true),
              Row(children: [
                Expanded(child: _field(_cityCtrl,  'City *',    Icons.location_city, required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_stateCtrl, 'State *',   Icons.map, required: true)),
              ]),
              Row(children: [
                Expanded(child: _field(_pinCtrl,       'PIN Code', Icons.pin)),
                const SizedBox(width: 10),
                Expanded(child: _field(_stateCodeCtrl, 'State GST Code (e.g. 36)', Icons.tag)),
              ]),
              const SizedBox(height: 20),

              _section('Legal & Regulatory'),
              _field(_gstinCtrl, 'GSTIN *', Icons.receipt_long,
                  required: true,
                  hint: 'e.g. 36AABCD1234A1Z5',
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'GSTIN is required';
                    if (v.trim().length != 15) return 'GSTIN must be 15 characters';
                    return null;
                  }),
              _field(_dlCtrl, 'Drug License Number *', Icons.verified,
                  required: true, hint: 'e.g. DL-KA-2024-98123'),
              const SizedBox(height: 20),

              _section('Contact'),
              Row(children: [
                Expanded(child: _field(_phoneCtrl,    'Phone *', Icons.phone, required: true)),
                const SizedBox(width: 10),
                Expanded(child: _field(_whatsappCtrl, 'WhatsApp Number', Icons.whatsapp)),
              ]),
              _field(_emailCtrl, 'Email Address', Icons.email,
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 20),

              _section('Invoice & Bill Configuration'),
              _field(_logoPathCtrl, 'Logo Path (optional)', Icons.image,
                  hint: 'e.g. C:\\Users\\YourName\\Documents\\logo.png'),
              const Text(
                'Tip: Save your logo image file and paste the full path here. '
                'The logo will appear on printed invoices and bills.',
                style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
              const SizedBox(height: 12),
              _field(_panCtrl, 'PAN Number', Icons.credit_card,
                  hint: 'e.g. AABCP1234C'),
              _field(_signatoryCtrl, 'Authorized Signatory Name', Icons.person_outline,
                  hint: 'Name to appear on invoices (default: Authorised Signatory)'),
              _field(_termsCtrl, 'Terms & Conditions', Icons.description,
                  hint: 'E.g.: Goods once sold are not returnable. Payment due within 7 days.',
                  maxLines: 3),
              const SizedBox(height: 20),

              _section('Bank Details (for invoices)'),
              _field(_bankCtrl,  'Bank Name',       Icons.account_balance),
              Row(children: [
                Expanded(child: _field(_acNoCtrl,  'Account Number', Icons.numbers)),
                const SizedBox(width: 10),
                Expanded(child: _field(_ifscCtrl,  'IFSC Code',      Icons.code)),
              ]),
              _field(_bankBranchCtrl, 'Branch Name', Icons.location_on,
                  hint: 'e.g. Main Branch, Mumbai');
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save),
                  label: Text(
                    widget.isFirstRun
                        ? 'Save & Continue to BillSprout'
                        : 'Save Company Profile',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: AppTheme.primaryBlue),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    bool required = false,
    String? hint,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextFormField(
        controller: ctrl,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: Icon(icon),
          alignLabelWithHint: maxLines > 1,
        ),
        validator: validator ??
            (required
                ? (v) => (v == null || v.trim().isEmpty)
                    ? '$label is required'
                    : null
                : null),
      ),
    );
  }
}
