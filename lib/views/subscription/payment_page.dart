import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';

/// Payment page with PayPal QR code and payment link
/// Shows plan details, amount, and generates PayPal.Me QR code
class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> plan;

  const PaymentPage({super.key, required this.plan});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _paymentUrl;

  @override
  void initState() {
    super.initState();
    _generatePaymentUrl();
  }

  void _generatePaymentUrl() {
    // Get PayPal.Me username from environment
    // For web builds, use --dart-define=PAYPAL_ME_USERNAME=YourUsername
    const paypalUsername = String.fromEnvironment('PAYPAL_ME_USERNAME',
        defaultValue: 'LifeSproutCare');

    // Get plan details
    final planId = widget.plan['id'] as String;
    final planName = widget.plan['plan_name'] as String;
    final priceMonthly = widget.plan['price_monthly'] as num;
    final currency = widget.plan['currency'] as String? ?? 'INR';

    // Generate PayPal.Me URL with amount
    // Format: https://paypal.me/USERNAME/AMOUNT
    // For INR, PayPal.Me doesn't support it directly, so we'll use USD equivalent or direct link
    
    if (currency == 'INR') {
      // Convert INR to USD (approximate)
      final usdAmount = (priceMonthly / 83).toStringAsFixed(2);
      _paymentUrl = 'https://paypal.me/$paypalUsername/$usdAmount';
    } else {
      _paymentUrl = 'https://paypal.me/$paypalUsername/${priceMonthly.toStringAsFixed(2)}';
    }

    setState(() {});
  }

  Future<void> _openPaymentLink() async {
    if (_paymentUrl == null) return;

    final uri = Uri.parse(_paymentUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      setState(() {
        _errorMessage = 'Could not open payment link';
      });
    }
  }

  void _copyPaymentLink() {
    if (_paymentUrl == null) return;

    Clipboard.setData(ClipboardData(text: _paymentUrl!));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Payment link copied to clipboard!')),
    );
  }

  Future<void> _confirmPayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      // Get user's tenant_id
      final userResponse = await supabase
          .from('users')
          .select('tenant_id')
          .eq('id', userId)
          .single();

      final tenantId = userResponse['tenant_id'];

      // Create subscription record
      final planId = widget.plan['id'] as String;
      final priceMonthly = widget.plan['price_monthly'] as num;
      
      final subscriptionData = {
        'tenant_id': tenantId,
        'plan_id': planId,
        'status': 'active',
        'billing_cycle': 'monthly',
        'start_date': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
        'auto_renew': true,
      };

      final subscriptionResponse = await supabase
          .from('subscriptions')
          .insert(subscriptionData)
          .select()
          .single();

      final subscriptionId = subscriptionResponse['id'];

      // Create payment record (pending verification)
      final paymentData = {
        'tenant_id': tenantId,
        'subscription_id': subscriptionId,
        'amount': priceMonthly,
        'currency': widget.plan['currency'] ?? 'INR',
        'payment_method': 'paypal',
        'payment_status': 'pending',
      };

      await supabase.from('payments').insert(paymentData);

      // Generate license key
      final licenseType = widget.plan['plan_code'] as String;
      await supabase.rpc('create_license_key', params: {
        'p_tenant_id': tenantId,
        'p_subscription_id': subscriptionId,
        'p_license_type': licenseType,
        'p_valid_days': 365,
      });

      if (mounted) {
        // Show success dialog
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.successGreen, size: 32),
                SizedBox(width: 12),
                Text('Payment Confirmed!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your subscription is now active! 🎉',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Your license key has been generated and is ready to use.',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.1),
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
                      Text('1. View your license key', style: TextStyle(fontSize: 12)),
                      Text('2. Download BillSprout software', style: TextStyle(fontSize: 12)),
                      Text('3. Activate with your license', style: TextStyle(fontSize: 12)),
                      Text('4. Start managing your pharmacy!', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pushReplacementNamed('/my-license');
                },
                child: const Text('View My License'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final planName = widget.plan['plan_name'] as String;
    final priceMonthly = widget.plan['price_monthly'] as num;
    final currency = widget.plan['currency'] as String? ?? 'INR';
    final features = widget.plan['features'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Plan Summary
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '$planName Plan',
                              style: const TextStyle(fontSize: 16),
                            ),
                            Text(
                              '${currency == 'INR' ? '₹' : '\$'}${priceMonthly.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Billed monthly',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Includes:',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...features.take(3).map((feature) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  const Icon(Icons.check,
                                      size: 16, color: AppTheme.successGreen),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      feature.toString(),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // PayPal QR Code
                if (_paymentUrl != null) ...[
                  const Text(
                    'Scan QR Code to Pay',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          QrImageView(
                            data: _paymentUrl!,
                            version: QrVersions.auto,
                            size: 250.0,
                            backgroundColor: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Scan with your phone camera or PayPal app',
                            style: TextStyle(fontSize: 14),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Or Pay Online Button
                  const Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openPaymentLink,
                      icon: const Icon(Icons.account_balance_wallet, size: 24),
                      label: const Text(
                        'Pay with PayPal',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0070BA), // PayPal blue
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Copy Link Button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _copyPaymentLink,
                      icon: const Icon(Icons.copy, size: 20),
                      label: const Text('Copy Payment Link'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 32),
                const Divider(),
                const SizedBox(height: 16),

                // After Payment Instructions
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'After Payment',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Once you complete the payment:',
                        style: TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 8),
                      const Text('1. Click "I Have Paid" button below',
                          style: TextStyle(fontSize: 13)),
                      const Text('2. Your license will be activated',
                          style: TextStyle(fontSize: 13)),
                      const Text('3. Download and install BillSprout',
                          style: TextStyle(fontSize: 13)),
                      const Text('4. Use your license key to activate',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Error Message
                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: TextStyle(color: Colors.red[700]),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Confirm Payment Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isProcessing ? null : _confirmPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.successGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'I Have Paid - Activate License',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
