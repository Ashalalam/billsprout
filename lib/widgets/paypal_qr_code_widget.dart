import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_theme.dart';
import '../services/paypal_service.dart';

/// PayPal QR Code Widget
/// 
/// Displays a QR code for PayPal.Me payments.
/// Customers scan the QR code to pay via PayPal app.
class PayPalQrCodeWidget extends StatelessWidget {
  final String paymentUrl;
  final double amount;
  final String invoiceNumber;
  final VoidCallback? onClose;

  const PayPalQrCodeWidget({
    super.key,
    required this.paymentUrl,
    required this.amount,
    required this.invoiceNumber,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.payment,
                    color: AppTheme.primaryBlue,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'PayPal Payment',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ],
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: onClose,
                  color: AppTheme.textMuted,
                ),
            ],
          ),
          const SizedBox(height: 24),

          // Amount Display
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.primaryBlue.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: [
                const Text(
                  'Amount to Pay',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryBlue,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Invoice: $invoiceNumber',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // QR Code
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300, width: 2),
            ),
            child: QrImageView(
              data: paymentUrl,
              version: QrVersions.auto,
              size: 280,
              backgroundColor: Colors.white,
              eyeStyle: QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: AppTheme.primaryBlue,
              ),
              dataModuleStyle: QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Instructions
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.qr_code_scanner, 
                        color: AppTheme.primaryBlue, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'How to Pay:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _instructionStep('1', 'Open PayPal app on your phone'),
                _instructionStep('2', 'Tap "Scan" or QR code icon'),
                _instructionStep('3', 'Scan this QR code'),
                _instructionStep('4', 'Confirm payment in PayPal app'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, 
                          color: Colors.orange.shade700, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Payment amount is pre-filled. Just confirm!',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Alternative: Manual Payment Link
          TextButton.icon(
            onPressed: () {
              // Copy payment URL to clipboard could be added here
            },
            icon: const Icon(Icons.link),
            label: const Text('Can\'t scan? Copy payment link'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _instructionStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// PayPal Payment Dialog
/// 
/// Shows QR code and handles payment flow
class PayPalPaymentDialog extends StatefulWidget {
  final double amount;
  final String invoiceNumber;
  final String? currency;

  const PayPalPaymentDialog({
    super.key,
    required this.amount,
    required this.invoiceNumber,
    this.currency,
  });

  @override
  State<PayPalPaymentDialog> createState() => _PayPalPaymentDialogState();
}

class _PayPalPaymentDialogState extends State<PayPalPaymentDialog> {
  bool _isLoading = true;
  String? _paymentUrl;
  String? _error;
  bool _paymentCompleted = false;

  @override
  void initState() {
    super.initState();
    _generatePaymentUrl();
  }

  Future<void> _generatePaymentUrl() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Generate PayPal.Me URL for QR code
      final url = PayPalService.generatePayPalMeUrl(
        amount: widget.amount,
        invoiceNumber: widget.invoiceNumber,
      );

      setState(() {
        _paymentUrl = url;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _markAsCompleted() {
    setState(() {
      _paymentCompleted = true;
    });
    
    // Wait a moment to show success, then close
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pop(true); // Return true for successful payment
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: _buildContent(),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('Generating payment QR code...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: AppTheme.errorRed, size: 64),
            const SizedBox(height: 16),
            const Text(
              'PayPal Setup Required',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textMuted),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Go to Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    }

    if (_paymentCompleted) {
      return Container(
        padding: const EdgeInsets.all(48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen, size: 80),
            const SizedBox(height: 16),
            const Text(
              'Payment Completed!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppTheme.successGreen,
              ),
            ),
            const SizedBox(height: 8),
            const Text('Transaction recorded successfully'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PayPalQrCodeWidget(
            paymentUrl: _paymentUrl!,
            amount: widget.amount,
            invoiceNumber: widget.invoiceNumber,
            onClose: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 16),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel Payment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _markAsCompleted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Payment Completed'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
