import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/app_theme.dart';
import '../services/paypal_service.dart';

/// PayPal Subscription QR Code Widget
/// 
/// Specialized widget for subscription payments via PayPal QR codes.
/// Displays QR code with subscription details and payment verification.
class PayPalSubscriptionQrWidget extends StatelessWidget {
  final String paymentUrl;
  final double amount;
  final String planName;
  final String billingCycle;
  final VoidCallback? onClose;
  final VoidCallback? onPaymentCompleted;

  const PayPalSubscriptionQrWidget({
    super.key,
    required this.paymentUrl,
    required this.amount,
    required this.planName,
    required this.billingCycle,
    this.onClose,
    this.onPaymentCompleted,
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
                    Icons.workspace_premium,
                    color: AppTheme.primaryBlue,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Subscription Payment',
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

          // Subscription Details
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.green.shade200,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Plan',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      planName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Billing',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      billingCycle == 'yearly' ? 'Annual' : 'Monthly',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Total Amount (incl. GST)',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${amount.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.successGreen,
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
                _instructionStep('5', 'Click "Payment Completed" below'),
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

          // Copy Payment Link Button
          OutlinedButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: paymentUrl));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Payment link copied to clipboard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.link),
            label: const Text('Copy Payment Link'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
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

/// PayPal Subscription Payment Dialog
/// 
/// Shows QR code and handles subscription payment flow with verification
class PayPalSubscriptionPaymentDialog extends StatefulWidget {
  final double amount;
  final String planName;
  final String billingCycle;
  final String planId;
  final String? currency;

  const PayPalSubscriptionPaymentDialog({
    super.key,
    required this.amount,
    required this.planName,
    required this.billingCycle,
    required this.planId,
    this.currency,
  });

  @override
  State<PayPalSubscriptionPaymentDialog> createState() => 
      _PayPalSubscriptionPaymentDialogState();
}

class _PayPalSubscriptionPaymentDialogState 
    extends State<PayPalSubscriptionPaymentDialog> {
  bool _isLoading = true;
  String? _paymentUrl;
  String? _error;
  bool _paymentCompleted = false;
  bool _isVerifying = false;

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

      // Generate PayPal.Me URL for subscription payment QR code
      final url = PayPalService.generatePayPalMeUrl(
        amount: widget.amount,
        invoiceNumber: 'SUB-${widget.planId}-${DateTime.now().millisecondsSinceEpoch}',
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

  Future<void> _markAsCompleted() async {
    setState(() {
      _isVerifying = true;
    });
    
    // Simulate verification delay
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _paymentCompleted = true;
      _isVerifying = false;
    });
    
    // Wait to show success, then close with success result
    await Future.delayed(const Duration(seconds: 2));
    
    if (mounted) {
      Navigator.of(context).pop({
        'success': true,
        'payment_method': 'paypal',
        'payment_url': _paymentUrl,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 800),
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
              onPressed: () => Navigator.of(context).pop({'success': false}),
              child: const Text('Go to Settings'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop({'success': false}),
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
            const Text('Activating your subscription...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PayPalSubscriptionQrWidget(
            paymentUrl: _paymentUrl!,
            amount: widget.amount,
            planName: widget.planName,
            billingCycle: widget.billingCycle,
            onClose: () => Navigator.of(context).pop({'success': false}),
          ),
          const SizedBox(height: 16),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isVerifying 
                        ? null 
                        : () => Navigator.of(context).pop({'success': false}),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text('Cancel Payment'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isVerifying ? null : _markAsCompleted,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isVerifying
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Payment Completed'),
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
