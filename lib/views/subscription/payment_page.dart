import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_config.dart';
import '../../config/app_theme.dart';
import '../../widgets/app_footer.dart';
import '../../services/razorpay_web_service.dart';
import '../../utils/logger.dart';

/// Payment page with Razorpay and PayPal options
/// Shows plan details, amount, and payment method selection
class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> plan;
  final String currency; // 'INR' or 'USD'
  final String billingCycle; // 'monthly' or 'yearly'

  const PaymentPage({
    super.key,
    required this.plan,
    required this.currency,
    required this.billingCycle,
  });

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  bool _isProcessing = false;
  String? _errorMessage;
  String? _paymentUrl;
  String _selectedPaymentMethod = 'razorpay'; // 'razorpay' or 'paypal'
  late RazorpayWebService _razorpayService;
  String? _transactionId;
  String? _razorpayOrderId;

  @override
  void initState() {
    super.initState();
    // Use web service for Razorpay
    _razorpayService = RazorpayWebService();
    _generatePaymentUrl();
  }

  @override
  void dispose() {
    // No dispose needed for web service
    super.dispose();
  }

  void _generatePaymentUrl() {
    // Get PayPal.Me username from environment
    const paypalUsername = String.fromEnvironment('PAYPAL_ME_USERNAME',
        defaultValue: 'LifeSproutCare');

    // Get plan code for pricing lookup
    final planCode = widget.plan['plan_code'] as String;
    
    // Get price based on selected currency and billing cycle
    double amount;
    if (widget.currency == 'INR') {
      amount = widget.billingCycle == 'monthly'
          ? (widget.plan['price_monthly'] as num).toDouble()
          : (widget.plan['price_yearly'] as num).toDouble();
    } else {
      amount = widget.billingCycle == 'monthly'
          ? (widget.plan['price_monthly_usd'] as num).toDouble()
          : (widget.plan['price_yearly_usd'] as num).toDouble();
    }

    // Generate PayPal.Me URL with amount
    if (widget.currency == 'INR') {
      // Convert INR to USD for PayPal (approximate)
      final usdAmount = (amount / 83).toStringAsFixed(2);
      _paymentUrl = 'https://paypal.me/$paypalUsername/$usdAmount';
    } else {
      _paymentUrl = 'https://paypal.me/$paypalUsername/${amount.toStringAsFixed(2)}';
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

  /// Process Razorpay payment
  Future<void> _processRazorpayPayment() async {
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

      // Get user's tenant_id and profile info
      final userResponse = await supabase
          .from('users')
          .select('tenant_id, name, phone')
          .eq('id', userId)
          .single();

      final tenantId = userResponse['tenant_id'];
      final customerName = userResponse['name'] ?? 'Customer';
      final customerEmail = supabase.auth.currentUser?.email ?? '';
      final customerPhone = userResponse['phone'] ?? '';

      // Get plan details
      final planId = widget.plan['id'] as String;
      final planName = widget.plan['plan_name'] as String;
      
      // Get correct price based on currency and billing cycle
      double amount;
      if (widget.currency == 'INR') {
        amount = widget.billingCycle == 'monthly'
            ? (widget.plan['price_monthly'] as num).toDouble()
            : (widget.plan['price_yearly'] as num).toDouble();
      } else {
        amount = widget.billingCycle == 'monthly'
            ? (widget.plan['price_monthly_usd'] as num).toDouble()
            : (widget.plan['price_yearly_usd'] as num).toDouble();
      }

      // IMPORTANT: Razorpay only supports INR in test mode
      // For USD, we need to use INR equivalent or switch to live mode
      String paymentCurrency = widget.currency;
      double paymentAmount = amount;
      
      if (widget.currency == 'USD') {
        // Convert USD to INR for Razorpay (approximate rate: 1 USD = 83 INR)
        paymentAmount = amount * 83;
        paymentCurrency = 'INR';
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment will be processed in INR (₹${paymentAmount.toStringAsFixed(2)})'),
            duration: const Duration(seconds: 3),
          ),
        );
      }

      // Step 1: Initialize payment transaction
      final initResult = await _razorpayService.initializePayment(
        tenantId: tenantId,
        plan: widget.plan,
        billingCycle: widget.billingCycle,
        currency: widget.currency,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      );

      if (initResult['success'] != true) {
        throw Exception(initResult['error'] ?? 'Failed to initialize payment');
      }

      _transactionId = initResult['transaction_id'];

      // Step 2: Create Razorpay order via edge function
      final orderResult = await _razorpayService.createRazorpayOrder(
        amount: paymentAmount,
        currency: paymentCurrency,
        transactionId: _transactionId!,
      );

      if (orderResult['success'] != true) {
        throw Exception(orderResult['error'] ?? 'Failed to create order');
      }

      _razorpayOrderId = orderResult['order_id'];

      // Step 3: Open Razorpay checkout
      await _razorpayService.openCheckout(
        orderId: _razorpayOrderId!,
        amount: paymentAmount,
        currency: paymentCurrency,
        customerName: customerName,
        customerEmail: customerEmail,
        customerPhone: customerPhone,
        description: '$planName - ${widget.billingCycle} subscription',
        onSuccess: (response) => _handleRazorpaySuccess(response, amount),
        onError: _handleRazorpayError,
      );

      setState(() {
        _isProcessing = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isProcessing = false;
      });
      Logger.error('Error processing Razorpay payment', error: e);
    }
  }

  /// Handle Razorpay payment success
  Future<void> _handleRazorpaySuccess(
    Map<String, dynamic> response,
    double originalAmount,
  ) async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      // Step 4: Verify payment signature via edge function
      final verifyResult = await _razorpayService.verifyPayment(
        orderId: response['razorpay_order_id'] ?? _razorpayOrderId!,
        paymentId: response['razorpay_payment_id'] ?? '',
        signature: response['razorpay_signature'] ?? '',
      );

      if (verifyResult['verified'] != true) {
        throw Exception('Payment verification failed. Please contact support.');
      }

      // Step 5: Update transaction status
      await _razorpayService.updateTransactionStatus(
        transactionId: _transactionId!,
        status: 'success',
        razorpayOrderId: response['razorpay_order_id'] ?? _razorpayOrderId,
        razorpayPaymentId: response['razorpay_payment_id'],
        razorpaySignature: response['razorpay_signature'],
        paymentMethod: 'razorpay',
      );

      // Step 6: Activate subscription
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;
      final userResponse = await supabase
          .from('users')
          .select('tenant_id')
          .eq('id', userId!)
          .single();

      final tenantId = userResponse['tenant_id'];
      final planId = widget.plan['id'] as String;

      await _razorpayService.activateSubscription(
        tenantId: tenantId,
        planId: planId,
        billingCycle: widget.billingCycle,
        amountPaid: originalAmount,
        currency: widget.currency,
        paymentMethod: 'razorpay',
      );

      // Show success dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Payment verification failed: ${e.toString()}';
        _isProcessing = false;
      });
      Logger.error('Error handling Razorpay success', error: e);
    }
  }

  /// Handle Razorpay payment error
  void _handleRazorpayError(Map<String, dynamic> response) {
    setState(() {
      _errorMessage = 'Payment failed: ${response['description'] ?? "Unknown error"}';
      _isProcessing = false;
    });

    // Update transaction status to failed
    if (_transactionId != null) {
      _razorpayService.updateTransactionStatus(
        transactionId: _transactionId!,
        status: 'failed',
        razorpayOrderId: _razorpayOrderId,
      );
    }
  }

  /// Show success dialog
  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: AppTheme.successGreen, size: 32),
            SizedBox(width: 12),
            Text('Payment Successful!'),
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

  /// Confirm PayPal payment (existing method)
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

      // Create subscription record with currency and billing cycle
      final planId = widget.plan['id'] as String;
      
      // Get correct price based on currency and billing cycle
      double amount;
      if (widget.currency == 'INR') {
        amount = widget.billingCycle == 'monthly'
            ? (widget.plan['price_monthly'] as num).toDouble()
            : (widget.plan['price_yearly'] as num).toDouble();
      } else {
        amount = widget.billingCycle == 'monthly'
            ? (widget.plan['price_monthly_usd'] as num).toDouble()
            : (widget.plan['price_yearly_usd'] as num).toDouble();
      }
      
      // Calculate subscription duration
      final durationDays = widget.billingCycle == 'monthly' ? 30 : 365;
      
      final subscriptionData = {
        'tenant_id': tenantId,
        'plan_id': planId,
        'status': 'active',
        'billing_cycle': widget.billingCycle,
        'currency': widget.currency,
        'is_renewal': false, // First time purchase
        'start_date': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().add(Duration(days: durationDays)).toIso8601String(),
        'auto_renew': false, // Manual renewal only
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
        'amount': amount,
        'currency': widget.currency,
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
        'p_valid_days': durationDays,
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
    final features = widget.plan['features'] as List<dynamic>? ?? [];
    
    // Get price based on selected currency and billing cycle
    double displayAmount;
    double renewalAmount = 0;
    
    if (widget.currency == 'INR') {
      displayAmount = widget.billingCycle == 'monthly'
          ? (widget.plan['price_monthly'] as num).toDouble()
          : (widget.plan['price_yearly'] as num).toDouble();
      if (widget.billingCycle == 'yearly') {
        renewalAmount = (widget.plan['renewal_yearly'] as num?)?.toDouble() ?? 0;
      }
    } else {
      displayAmount = widget.billingCycle == 'monthly'
          ? (widget.plan['price_monthly_usd'] as num).toDouble()
          : (widget.plan['price_yearly_usd'] as num).toDouble();
      if (widget.billingCycle == 'yearly') {
        renewalAmount = (widget.plan['renewal_yearly_usd'] as num?)?.toDouble() ?? 0;
      }
    }
    
    final currencySymbol = widget.currency == 'INR' ? '₹' : '\$';
    final billingText = widget.billingCycle == 'monthly' ? 'monthly' : 'annually';
    final perMonthEquivalent = widget.billingCycle == 'yearly' ? displayAmount / 12 : displayAmount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Payment'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                              '$currencySymbol${displayAmount.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Billed $billingText',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        if (widget.billingCycle == 'yearly') ...[
                          const SizedBox(height: 4),
                          Text(
                            '$currencySymbol${perMonthEquivalent.toStringAsFixed(0)}/month equivalent',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                        if (renewalAmount > 0) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.green[50],
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.green[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.autorenew, size: 16, color: Colors.green[700]),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Renewal: $currencySymbol${renewalAmount.toStringAsFixed(0)}/year (50% OFF)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.green[900],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
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

                // Payment Method Selection
                const Text(
                  'Select Payment Method',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Razorpay Option
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedPaymentMethod == 'razorpay'
                          ? AppTheme.primaryBlue
                          : Colors.grey.shade300,
                      width: _selectedPaymentMethod == 'razorpay' ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedPaymentMethod = 'razorpay'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'razorpay',
                            groupValue: _selectedPaymentMethod,
                            onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Razorpay',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Credit/Debit Card, UPI, Net Banking, Wallets',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.credit_card, color: AppTheme.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // PayPal Option
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: _selectedPaymentMethod == 'paypal'
                          ? const Color(0xFF0070BA)
                          : Colors.grey.shade300,
                      width: _selectedPaymentMethod == 'paypal' ? 2 : 1,
                    ),
                  ),
                  child: InkWell(
                    onTap: () => setState(() => _selectedPaymentMethod = 'paypal'),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Radio<String>(
                            value: 'paypal',
                            groupValue: _selectedPaymentMethod,
                            onChanged: (value) => setState(() => _selectedPaymentMethod = value!),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'PayPal',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Pay with PayPal account',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.account_balance_wallet, color: Color(0xFF0070BA)),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 32),

                // Primary Payment Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing
                        ? null
                        : (_selectedPaymentMethod == 'razorpay'
                            ? _processRazorpayPayment
                            : null),
                    icon: _isProcessing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(
                            _selectedPaymentMethod == 'razorpay'
                                ? Icons.payment
                                : Icons.account_balance_wallet,
                          ),
                    label: Text(
                      _isProcessing
                          ? 'Processing...'
                          : (_selectedPaymentMethod == 'razorpay'
                              ? 'Pay $currencySymbol${displayAmount.toStringAsFixed(0)}'
                              : 'Continue to PayPal'),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _selectedPaymentMethod == 'razorpay'
                          ? AppTheme.primaryBlue
                          : const Color(0xFF0070BA),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey.shade300,
                    ),
                  ),
                ),

                // PayPal QR Code and Manual Payment (only shown when PayPal is selected)
                if (_selectedPaymentMethod == 'paypal' && _paymentUrl != null) ...[
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 16),

                  const SizedBox(height: 16),
                  
                  const Text(
                    'OR Scan QR Code / Use Payment Link',
                    style: TextStyle(
                      fontSize: 18,
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

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _openPaymentLink,
                      icon: const Icon(Icons.open_in_new, size: 24),
                      label: const Text(
                        'Open PayPal Payment Link',
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

                const SizedBox(height: 24),

                // PayPal "I Have Paid" button (only shown when PayPal is selected)
                if (_selectedPaymentMethod == 'paypal') ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
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
                        SizedBox(height: 12),
                        Text(
                          'Once you complete the PayPal payment:',
                          style: TextStyle(fontSize: 14),
                        ),
                        SizedBox(height: 8),
                        Text('1. Click "I Have Paid" button below',
                            style: TextStyle(fontSize: 13)),
                        Text('2. Your license will be activated',
                            style: TextStyle(fontSize: 13)),
                        Text('3. Download and install BillSprout',
                            style: TextStyle(fontSize: 13)),
                        Text('4. Use your license key to activate',
                            style: TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

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

                // Error Message
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
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
                ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Footer at bottom
          const AppFooter(),
        ],
      ),
    );
  }
}
