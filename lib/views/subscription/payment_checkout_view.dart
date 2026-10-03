import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:uuid/uuid.dart';
import '../../models/subscription_plan_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../services/payment_service.dart';
import '../../utils/logger.dart';
import '../../widgets/common/custom_button.dart';

/// Payment checkout view for completing subscription purchase
class PaymentCheckoutView extends StatefulWidget {
  final SubscriptionPlan plan;
  final String billingCycle;

  const PaymentCheckoutView({
    super.key,
    required this.plan,
    required this.billingCycle,
  });

  @override
  State<PaymentCheckoutView> createState() => _PaymentCheckoutViewState();
}

class _PaymentCheckoutViewState extends State<PaymentCheckoutView> {
  late PaymentService _paymentService;
  bool _isProcessing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializePayment();
  }

  void _initializePayment() {
    _paymentService = PaymentService();
    
    // Set payment callbacks
    _paymentService.onPaymentSuccess = _handlePaymentSuccess;
    _paymentService.onPaymentError = _handlePaymentError;
    _paymentService.onExternalWallet = _handleExternalWallet;
  }

  @override
  void dispose() {
    _paymentService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.billingCycle == 'yearly'
        ? widget.plan.priceYearly
        : widget.plan.priceMonthly;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order summary
            _buildOrderSummary(price),
            
            const SizedBox(height: 24),
            
            // Payment details
            _buildPaymentDetails(),
            
            const SizedBox(height: 24),
            
            // Error message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            
            if (_errorMessage != null) const SizedBox(height: 24),
            
            // Pay button
            SizedBox(
              width: double.infinity,
              child: CustomButton(
                text: _isProcessing
                    ? 'Processing...'
                    : 'Pay ₹${price.toStringAsFixed(2)}',
                onPressed: _isProcessing ? null : _initiatePayment,
                isLoading: _isProcessing,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Security info
            _buildSecurityInfo(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderSummary(double price) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),
            
            // Plan details
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.workspace_premium, color: Colors.green),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.plan.planName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.billingCycle == 'yearly' ? 'Annual' : 'Monthly'} Subscription',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const Divider(height: 32),
            
            // Price breakdown
            _buildPriceRow('Subtotal', price),
            const SizedBox(height: 8),
            _buildPriceRow('GST (18%)', price * 0.18),
            
            const Divider(height: 24),
            
            _buildPriceRow(
              'Total Amount',
              price * 1.18,
              isTotal: true,
            ),
            
            if (widget.billingCycle == 'yearly' && widget.plan.yearlySavings > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.savings, color: Colors.green, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'You save ₹${widget.plan.yearlySavings.toStringAsFixed(0)} with annual billing',
                        style: const TextStyle(
                          color: Colors.green,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Text(
          '₹${amount.toStringAsFixed(2)}',
          style: TextStyle(
            fontSize: isTotal ? 20 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Method',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Payment options
            _buildPaymentOption(
              icon: Icons.credit_card,
              title: 'Credit / Debit Card',
              subtitle: 'Visa, Mastercard, RuPay',
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              icon: Icons.account_balance,
              title: 'Net Banking',
              subtitle: 'All major banks supported',
            ),
            const SizedBox(height: 12),
            _buildPaymentOption(
              icon: Icons.account_balance_wallet,
              title: 'UPI / Wallets',
              subtitle: 'PhonePe, GPay, Paytm, etc.',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentOption({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.green),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your payment information is secure and encrypted',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _initiatePayment() async {
    setState(() {
      _isProcessing = true;
      _errorMessage = null;
    });

    try {
      final authProvider = context.read<AuthProvider>();
      final currentUser = authProvider.currentUser;

      if (currentUser == null) {
        throw Exception('User not authenticated. Please login first.');
      }

      // Use actual tenantId or generate a valid UUID v4 for demo/testing
      String effectiveTenantId;
      if (currentUser.tenantId != null && currentUser.tenantId!.isNotEmpty) {
        effectiveTenantId = currentUser.tenantId!;
      } else {
        // Generate a proper UUID v4 for demo mode
        const uuid = Uuid();
        effectiveTenantId = uuid.v4();
        debugPrint('[Payment] Using demo tenant ID: $effectiveTenantId');
      }

      final price = widget.billingCycle == 'yearly'
          ? widget.plan.priceYearly
          : widget.plan.priceMonthly;

      final totalAmount = price * 1.18; // Including GST

      // Process subscription purchase
      final result = await _paymentService.processSubscriptionPurchase(
        tenantId: effectiveTenantId,
        plan: widget.plan,
        billingCycle: widget.billingCycle,
        customerName: currentUser.name,
        customerEmail: currentUser.email,
        customerPhone: currentUser.phone ?? '',
      );

      if (!result['success']) {
        throw Exception(result['error'] ?? 'Failed to initiate payment');
      }

      final orderId = result['order_id'] as String;
      final transactionId = result['transaction_id'] as String;

      // Store transaction ID for later use
      _currentTransactionId = transactionId;

      // Open Razorpay checkout
      await _paymentService.openCheckout(
        orderId: orderId,
        amount: totalAmount,
        name: currentUser.name,
        description: '${widget.plan.planName} - ${widget.billingCycle} subscription',
        email: currentUser.email,
        contact: currentUser.phone,
        notes: {
          'plan_id': widget.plan.id,
          'billing_cycle': widget.billingCycle,
        },
      );
    } catch (e) {
      Logger.error('Payment initiation error', error: e);
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }

  String? _currentTransactionId;

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    Logger.info('Payment successful: ${response.paymentId}');

    try {
      final authProvider = context.read<AuthProvider>();
      final subscriptionProvider = context.read<SubscriptionProvider>();
      final currentUser = authProvider.currentUser;

      if (_currentTransactionId == null || currentUser == null) {
        throw Exception('Missing transaction or user information');
      }

      // Use actual tenantId or generate a proper UUID v4 for demo mode
      String effectiveTenantId;
      if (currentUser.tenantId != null && currentUser.tenantId!.isNotEmpty) {
        effectiveTenantId = currentUser.tenantId!;
      } else {
        const uuid = Uuid();
        effectiveTenantId = uuid.v4();
      }

      // Complete payment
      final orderId = response.orderId;
      final paymentId = response.paymentId;
      final signature = response.signature;
      
      if (orderId == null || paymentId == null || signature == null) {
        throw Exception('Incomplete payment response from Razorpay');
      }
      
      final completed = await _paymentService.completePayment(
        transactionId: _currentTransactionId!,
        orderId: orderId,
        paymentId: paymentId,
        signature: signature,
      );

      if (!completed) {
        throw Exception('Payment verification failed');
      }

      // Activate subscription
      final price = widget.billingCycle == 'yearly'
          ? widget.plan.priceYearly
          : widget.plan.priceMonthly;

      await _paymentService.activateSubscription(
        tenantId: effectiveTenantId,
        planId: widget.plan.id,
        billingCycle: widget.billingCycle,
        amountPaid: price * 1.18,
      );

      // Refresh subscription data
      await subscriptionProvider.fetchCurrentSubscription(effectiveTenantId);

      // Show success dialog
      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      Logger.error('Payment completion error', error: e);
      if (mounted) {
        setState(() {
          _errorMessage = 'Payment completed but activation failed. Please contact support.';
        });
      }
    }
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    Logger.error('Payment failed: ${response.code} - ${response.message}');
    setState(() {
      _errorMessage = response.message ?? 'Payment failed. Please try again.';
    });
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    Logger.info('External wallet selected: ${response.walletName}');
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Payment Successful!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Your subscription has been activated successfully.'),
            const SizedBox(height: 16),
            Text(
              'Plan: ${widget.plan.planName}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'Billing: ${widget.billingCycle == 'yearly' ? 'Annual' : 'Monthly'}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Navigator.of(context).pop(); // Close checkout
              Navigator.of(context).pop(); // Close plans view
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
