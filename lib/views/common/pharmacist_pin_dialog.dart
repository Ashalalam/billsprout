import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_theme.dart';
import '../../models/pharmacist_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/pharmacist_provider.dart';

/// Result of a Schedule H authorisation attempt.
class PharmacistAuthResult {
  final bool approved;

  /// pharmacists.id of the authoriser, when a real pharmacist record matched.
  final String? pharmacistId;

  /// Display name recorded on the invoice and the Schedule H register.
  final String? pharmacistName;

  const PharmacistAuthResult({
    required this.approved,
    this.pharmacistId,
    this.pharmacistName,
  });

  static const denied = PharmacistAuthResult(approved: false);
}

class PharmacistPinDialog extends StatefulWidget {
  final VoidCallback? onApproved;

  const PharmacistPinDialog({super.key, this.onApproved});

  /// Shows the dialog and returns who authorised the sale.
  static Future<PharmacistAuthResult> show(BuildContext context) async {
    final result = await showDialog<PharmacistAuthResult>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const PharmacistPinDialog(),
    );
    return result ?? PharmacistAuthResult.denied;
  }

  @override
  State<PharmacistPinDialog> createState() => _PharmacistPinDialogState();
}

class _PharmacistPinDialogState extends State<PharmacistPinDialog> {
  final TextEditingController _pinController = TextEditingController();
  String? _errorMessage;
  int _attempts = 0;

  static const _maxAttempts = 5;

  bool get _locked => _attempts >= _maxAttempts;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  void _verifyPin() {
    if (_locked) return;

    final pharmacists = context.read<PharmacistProvider>();
    final entered = _pinController.text.trim();

    // Preferred path: the PIN identifies a real pharmacist record, so the
    // Schedule H register names an accountable person.
    final PharmacistModel? match = pharmacists.authorise(entered);
    if (match != null) {
      widget.onApproved?.call();
      Navigator.of(context).pop(PharmacistAuthResult(
        approved: true,
        pharmacistId: match.id,
        pharmacistName: match.name,
      ));
      return;
    }

    // Fallback for tenants that have not yet enrolled any pharmacist: the
    // device-level PIN still gates the sale, and the logged-in user is recorded
    // as the authoriser. Once a pharmacist is enrolled this path stops applying.
    if (!pharmacists.hasAuthorisablePharmacist) {
      final auth = context.read<AuthProvider>();
      if (auth.verifyPharmacistPin(entered)) {
        final who = auth.currentUser?.name ?? auth.currentUser?.email;
        widget.onApproved?.call();
        Navigator.of(context).pop(PharmacistAuthResult(
          approved: true,
          pharmacistName: who == null ? 'Pharmacist (PIN verified)' : '$who (PIN verified)',
        ));
        return;
      }
    }

    setState(() {
      _attempts++;
      _pinController.clear();
      final left = _maxAttempts - _attempts;
      // No hint about the correct value, and the attempt cap stops a 4 digit
      // secret being walked through at the counter.
      _errorMessage = left > 0
          ? 'Incorrect PIN. $left ${left == 1 ? 'attempt' : 'attempts'} remaining.'
          : 'Too many incorrect attempts. Cancel and ask a pharmacist.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final pharmacists = context.watch<PharmacistProvider>();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Row(
        children: [
          Icon(Icons.verified_user, color: AppTheme.errorRed, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Pharmacist Authorization',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFCDD2)),
            ),
            child: const Text(
              'RESTRICTED DRUG WARNING\nThis transaction contains Schedule H / H1 / '
              'Narcotic medication. An authorised pharmacist PIN is legally '
              'required to approve dispensing.',
              style: TextStyle(
                  fontSize: 12, color: AppTheme.errorRed, height: 1.4),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            obscureText: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            autofocus: true,
            enabled: !_locked,
            decoration: InputDecoration(
              labelText: 'Enter Pharmacist Security PIN',
              prefixIcon: const Icon(Icons.lock),
              errorText: _errorMessage,
              counterText: '',
            ),
            onSubmitted: (_) => _verifyPin(),
          ),
          if (!pharmacists.hasAuthorisablePharmacist)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'No pharmacist is enrolled for this pharmacy yet. Add one under '
                'Settings so the Schedule H register names a real person.',
                style: TextStyle(fontSize: 11, color: AppTheme.warningAmber),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(PharmacistAuthResult.denied),
          child: const Text('Cancel Transaction'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
          onPressed: _locked ? null : _verifyPin,
          child: const Text('Authorize & Dispense'),
        ),
      ],
    );
  }
}
