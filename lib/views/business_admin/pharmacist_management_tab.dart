import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/pharmacist_model.dart';
import '../../providers/pharmacist_provider.dart';
import '../../utils/pin_hasher.dart';

/// Business Admin -> Pharmacist Management.
///
/// PINs are write-only: they can be set and reset but never displayed, because
/// only a salted hash is stored. Schedule H authorisation resolves to one of
/// these records, so the register names an accountable person.
class PharmacistManagementTab extends StatefulWidget {
  const PharmacistManagementTab({super.key});

  @override
  State<PharmacistManagementTab> createState() =>
      _PharmacistManagementTabState();
}

class _PharmacistManagementTabState extends State<PharmacistManagementTab> {
  @override
  void initState() {
    super.initState();
    // Fetch after the first frame so the provider is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PharmacistProvider>().fetchPharmacists();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PharmacistProvider>();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPharmacistDialog(context),
        icon: const Icon(Icons.person_add),
        label: const Text('Add Pharmacist'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Registered Pharmacists',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryBlue),
                  ),
                ),
                IconButton(
                  tooltip: 'Reload',
                  icon: provider.isLoading
                      ? const SizedBox(
                          width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  onPressed: provider.isLoading
                      ? null
                      : () => provider.fetchPharmacists(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Only an active pharmacist with a PIN can authorise Schedule H, '
              'H1 and narcotic dispensing. PINs are stored as salted hashes and '
              'cannot be viewed.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 12),

            if (provider.error != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
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
                      child: Text(provider.error!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.errorRed)),
                    ),
                    TextButton(
                      onPressed: () => provider.fetchPharmacists(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),

            if (!provider.hasAuthorisablePharmacist && !provider.isLoading)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningAmber.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: AppTheme.warningAmber.withOpacity(0.4)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        color: AppTheme.warningAmber, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'No pharmacist with a PIN is enrolled. Restricted sales '
                        'will fall back to the device PIN and the register will '
                        'not name a pharmacist.',
                        style: TextStyle(
                            fontSize: 12, color: AppTheme.warningAmber),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: provider.isLoading && provider.pharmacists.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : provider.pharmacists.isEmpty
                      ? const Center(
                          child: Text('No pharmacists added yet.',
                              style: TextStyle(color: AppTheme.textMuted)),
                        )
                      : Card(
                          child: ListView.separated(
                            itemCount: provider.pharmacists.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) =>
                                _tile(context, provider.pharmacists[i], provider),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, PharmacistModel p,
      PharmacistProvider provider) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: p.isActive
            ? AppTheme.successGreen.withOpacity(0.15)
            : Colors.grey.shade200,
        child: Icon(Icons.local_pharmacy,
            color: p.isActive ? AppTheme.successGreen : Colors.grey),
      ),
      title: Text(p.name,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      subtitle: Text(
        'Reg: ${p.registrationNo?.isNotEmpty == true ? p.registrationNo : 'not set'}'
        '  •  Licence: ${p.licenseNo?.isNotEmpty == true ? p.licenseNo : 'not set'}\n'
        '${p.email}  •  ${p.phone}',
        style: const TextStyle(fontSize: 12, height: 1.4),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Chip(
            label: Text(
              p.pinHash.isEmpty ? 'No PIN' : 'PIN set',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: p.pinHash.isEmpty ? Colors.black87 : Colors.white,
              ),
            ),
            backgroundColor:
                p.pinHash.isEmpty ? Colors.amber : AppTheme.successGreen,
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Reset PIN',
            icon: const Icon(Icons.password, size: 20),
            onPressed: () => _showResetPinDialog(context, p),
          ),
          Switch(
            value: p.isActive,
            onChanged: (v) => provider.setActive(p.id, v),
          ),
        ],
      ),
    );
  }

  Future<void> _showPharmacistDialog(BuildContext context) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final phone = TextEditingController();
    final licence = TextEditingController();
    final registration = TextEditingController();
    final pin = TextEditingController();
    final confirmPin = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var saving = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: const Text('Add Pharmacist'),
          content: SizedBox(
            width: 420,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _f(name, 'Full Name *',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Name is required' : null),
                    _f(email, 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$')
                                  .hasMatch(v.trim())
                              ? null : 'Enter a valid email';
                        }),
                    _f(phone, 'Mobile',
                        keyboardType: TextInputType.phone,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          return v.replaceAll(RegExp(r'\D'), '').length == 10
                              ? null : 'Enter a 10 digit mobile';
                        }),
                    _f(registration, 'Pharmacy Council Registration No. *',
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Registration number is required' : null),
                    _f(licence, 'Licence No.'),
                    _f(pin, 'Authorisation PIN (4-6 digits) *',
                        obscure: true,
                        keyboardType: TextInputType.number,
                        validator: (v) => PinHasher.validateFormat(v ?? '')),
                    _f(confirmPin, 'Confirm PIN *',
                        obscure: true,
                        keyboardType: TextInputType.number,
                        validator: (v) =>
                            v == pin.text ? null : 'PINs do not match'),
                    const SizedBox(height: 6),
                    const Text(
                      'The PIN is stored as a salted hash. It cannot be recovered, '
                      'only reset.',
                      style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!(formKey.currentState?.validate() ?? false)) return;
                      setDlg(() => saving = true);
                      final provider = ctx.read<PharmacistProvider>();
                      final id = await provider.addPharmacist(
                        name: name.text,
                        email: email.text,
                        phone: phone.text,
                        licenseNo: licence.text,
                        registrationNo: registration.text,
                        pin: pin.text,
                      );
                      if (!ctx.mounted) return;
                      setDlg(() => saving = false);
                      if (id != null) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text('Pharmacist ${name.text} added'),
                          backgroundColor: AppTheme.successGreen,
                        ));
                      } else {
                        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                          content: Text(provider.error ?? 'Could not save'),
                          backgroundColor: AppTheme.errorRed,
                        ));
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Save'),
            ),
          ],
        ),
      ),
    );

    for (final c in [name, email, phone, licence, registration, pin, confirmPin]) {
      c.dispose();
    }
  }

  Future<void> _showResetPinDialog(
      BuildContext context, PharmacistModel p) async {
    final pin = TextEditingController();
    final confirm = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reset PIN — ${p.name}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _f(pin, 'New PIN (4-6 digits)',
                  obscure: true,
                  keyboardType: TextInputType.number,
                  validator: (v) => PinHasher.validateFormat(v ?? '')),
              _f(confirm, 'Confirm New PIN',
                  obscure: true,
                  keyboardType: TextInputType.number,
                  validator: (v) => v == pin.text ? null : 'PINs do not match'),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (!(formKey.currentState?.validate() ?? false)) return;
              final provider = ctx.read<PharmacistProvider>();
              final ok = await provider.resetPin(
                  pharmacistId: p.id, newPin: pin.text);
              if (!ctx.mounted) return;
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(ok
                    ? 'PIN reset for ${p.name}'
                    : provider.error ?? 'Could not reset PIN'),
                backgroundColor: ok ? AppTheme.successGreen : AppTheme.errorRed,
              ));
            },
            child: const Text('Reset PIN'),
          ),
        ],
      ),
    );

    pin.dispose();
    confirm.dispose();
  }

  Widget _f(
    TextEditingController c,
    String label, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscure = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextFormField(
          controller: c,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscure,
          maxLength: obscure ? 6 : null,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            isDense: true,
            counterText: '',
          ),
        ),
      );
}
