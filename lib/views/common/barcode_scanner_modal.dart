import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../config/app_theme.dart';

// mobile_scanner is not supported on web – conditionally import only on native
import 'barcode_scanner_stub.dart'
    if (dart.library.io) 'barcode_scanner_native.dart';

/// Full-screen barcode scanner modal.
/// On web: shows a text-input fallback (type/paste barcode).
/// On mobile/desktop: opens camera via mobile_scanner.
class BarcodeScannerModal extends StatefulWidget {
  const BarcodeScannerModal({super.key});

  /// Show the scanner and return the scanned value (or null).
  static Future<String?> show(BuildContext context) {
    if (kIsWeb) {
      return _showWebFallback(context);
    }
    return showDialog<String>(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => const BarcodeScannerModal(),
    );
  }

  static Future<String?> _showWebFallback(BuildContext context) {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.qr_code_scanner, color: AppTheme.primaryBlue),
            SizedBox(width: 10),
            Text('Enter Barcode'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Camera scanner is not available on web.\n'
              'Type or paste the barcode / product code below.',
              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: ctrl,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Barcode / Product Code',
                prefixIcon: Icon(Icons.qr_code),
              ),
              onSubmitted: (val) => Navigator.of(ctx).pop(val.trim()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            icon: const Icon(Icons.search),
            label: const Text('Search Product'),
          ),
        ],
      ),
    );
  }

  @override
  State<BarcodeScannerModal> createState() => _BarcodeScannerModalState();
}

class _BarcodeScannerModalState extends State<BarcodeScannerModal> {
  @override
  Widget build(BuildContext context) {
    // On web this widget is never instantiated (show() redirects to fallback)
    // On native: delegate to the platform-specific implementation
    return buildNativeScanner(context);
  }
}
