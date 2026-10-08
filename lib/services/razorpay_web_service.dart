import 'dart:js' as js;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../utils/logger.dart';

/// Razorpay Web Service
/// Uses Razorpay Web Checkout (JavaScript integration) for Flutter Web
class RazorpayWebService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Initialize payment transaction
  Future<Map<String, dynamic>> initializePayment({
    required String tenantId,
    required Map<String, dynamic> plan,
    required String billingCycle,
    required String currency,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
  }) async {
    try {
      // Get amount based on billing cycle and currency
      final double amount;
      if (currency == 'INR') {
        amount = billingCycle == 'yearly'
            ? (plan['price_yearly'] as num).toDouble()
            : (plan['price_monthly'] as num).toDouble();
      } else {
        amount = billingCycle == 'yearly'
            ? (plan['price_yearly_usd'] as num).toDouble()
            : (plan['price_monthly_usd'] as num).toDouble();
      }

      final planId = plan['id'] as String;
      final planCode = plan['plan_code'] as String;
      final planName = plan['plan_name'] as String;

      // Create payment transaction record
      final transactionData = {
        'tenant_id': tenantId,
        'amount': amount,
        'currency': currency,
        'status': 'pending',
        'payment_gateway': 'razorpay',
        'transaction_type': 'subscription',
        'description': 'Subscription purchase - $planName ($billingCycle)',
        'metadata': {
          'plan_id': planId,
          'plan_code': planCode,
          'billing_cycle': billingCycle,
          'customer_name': customerName,
          'customer_email': customerEmail,
          'customer_phone': customerPhone,
        },
        'payment_initiated_at': DateTime.now().toIso8601String(),
      };

      String transactionId;

      try {
        final transactionResponse = await _supabase
            .from('payment_transactions')
            .insert(transactionData)
            .select()
            .single();

        transactionId = transactionResponse['id'] as String;
      } catch (e) {
        // RLS policy blocked (demo mode) - use local ID
        Logger.info('Database write blocked (demo mode), using local transaction ID');
        transactionId = 'demo_txn_${DateTime.now().millisecondsSinceEpoch}';
      }

      Logger.info('Payment transaction initialized: $transactionId');

      return {
        'success': true,
        'transaction_id': transactionId,
      };
    } catch (e) {
      Logger.error('Error initializing payment', error: e);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Create Razorpay order via Supabase edge function
  Future<Map<String, dynamic>> createRazorpayOrder({
    required double amount,
    required String currency,
    required String transactionId,
  }) async {
    try {
      // Convert amount to paise (smallest currency unit)
      final amountInPaise = (amount * 100).toInt();

      Logger.info('Creating Razorpay order: amount=$amountInPaise $currency');

      final response = await _supabase.functions.invoke(
        'create-razorpay-order',
        body: {
          'amount': amountInPaise,
          'currency': currency,
          'receipt': transactionId,
        },
      );

      // Check for error in response
      if (response.data == null) {
        throw Exception('Failed to create Razorpay order: No response data');
      }

      final data = response.data as Map<String, dynamic>;
      
      // Check if there's an error in the data
      if (data['error'] != null) {
        throw Exception('Razorpay order creation failed: ${data['error']}');
      }

      // Get order_id from response
      final orderId = data['order_id'] as String?;
      
      if (orderId == null) {
        throw Exception('No order_id in response: $data');
      }

      Logger.info('Razorpay order created: $orderId');

      return {
        'success': true,
        'order_id': orderId,
        'amount': amount,
        'currency': currency,
      };
    } catch (e) {
      Logger.error('Error creating Razorpay order', error: e);
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Open Razorpay Web Checkout
  Future<void> openCheckout({
    required String orderId,
    required double amount,
    required String currency,
    required String customerName,
    required String customerEmail,
    required String customerPhone,
    required String description,
    required Function(Map<String, dynamic>) onSuccess,
    required Function(Map<String, dynamic>) onError,
  }) async {
    try {
      final razorpayKeyId = dotenv.env['RAZORPAY_KEY_ID'];

      if (razorpayKeyId == null || razorpayKeyId.isEmpty) {
        throw Exception('Razorpay Key ID not configured');
      }

      Logger.info('Opening Razorpay Web Checkout with order: $orderId');
      Logger.info('Using Razorpay Key: ${razorpayKeyId.substring(0, 8)}...');

      // Convert amount to paise
      final amountInPaise = (amount * 100).toInt();

      // Create Razorpay options
      final options = js.JsObject.jsify({
        'key': razorpayKeyId,
        'amount': amountInPaise,
        'currency': currency,
        'name': 'LIFESPROUT Care',
        'description': description,
        'order_id': orderId,
        'prefill': {
          'name': customerName,
          'email': customerEmail,
          'contact': customerPhone,
        },
        'theme': {
          'color': '#182B68', // AppTheme.primaryBlue
        },
        'handler': js.allowInterop((response) {
          try {
            Logger.info('Razorpay handler called with response: ${response.toString()}');
            
            // Safely extract response data with null checks
            final paymentId = response['razorpay_payment_id'];
            final signature = response['razorpay_signature'];
            final responseOrderId = response['razorpay_order_id'];

            Logger.info('Payment ID: $paymentId');
            Logger.info('Order ID: $responseOrderId');
            Logger.info('Signature present: ${signature != null}');

            if (paymentId == null || signature == null || responseOrderId == null) {
              Logger.error('Razorpay success handler: Missing required fields in response');
              onError({
                'code': 'INVALID_RESPONSE',
                'description': 'Payment response is missing required fields. This might be due to test environment configuration.',
                'debug_info': {
                  'payment_id_present': paymentId != null,
                  'signature_present': signature != null,
                  'order_id_present': responseOrderId != null,
                  'full_response': response.toString(),
                }
              });
              return;
            }

            Logger.info('Razorpay payment success: $paymentId');

            onSuccess({
              'razorpay_payment_id': paymentId.toString(),
              'razorpay_order_id': responseOrderId.toString(),
              'razorpay_signature': signature.toString(),
            });
          } catch (e, stackTrace) {
            Logger.error('Razorpay success handler error: $e');
            Logger.error('Stack trace: $stackTrace');
            onError({
              'code': 'SUCCESS_HANDLER_ERROR',
              'description': 'Error processing payment success: ${e.toString().replaceAll('Instance of \'', '').replaceAll('\'', '')}',
              'debug_info': {
                'original_error': e.toString(),
                'stack_trace': stackTrace.toString(),
              }
            });
          }
        }),
        'modal': {
          'ondismiss': js.allowInterop(() {
            Logger.info('Razorpay checkout dismissed by user');
            onError({
              'code': 'USER_CANCELLED',
              'description': 'Payment cancelled by user',
            });
          }),
          'onhidden': js.allowInterop(() {
            Logger.info('Razorpay checkout modal hidden');
          }),
        }
      });

      // Verify Razorpay is available in global context
      if (js.context['Razorpay'] == null) {
        Logger.error('Razorpay SDK not found in global context');
        throw Exception('Razorpay SDK not loaded. Please check:\n1. Internet connection\n2. Refresh the page\n3. Verify web/index.html has Razorpay script');
      }

      Logger.info('Razorpay SDK found, creating checkout instance...');

      // Create and open Razorpay instance with enhanced error handling
      try {
        final razorpay = js.JsObject(js.context['Razorpay'], [options]);
        Logger.info('Razorpay instance created successfully');
        razorpay.callMethod('open', []);
        Logger.info('Razorpay checkout opened');
      } catch (jsError) {
        Logger.error('Razorpay JavaScript error details: $jsError');
        Logger.error('Error type: ${jsError.runtimeType}');
        
        // Extract meaningful error message
        String errorMessage = jsError.toString();
        if (errorMessage.contains('Instance of')) {
          errorMessage = 'Razorpay initialization failed. This is commonly caused by:\n'
                        '• Test/Live key mismatch\n'
                        '• Invalid Razorpay key format\n'
                        '• Network connectivity issues\n'
                        '• Browser security restrictions';
        }
        
        throw Exception('Failed to initialize Razorpay checkout: $errorMessage');
      }
    } catch (e, stackTrace) {
      Logger.error('Error opening Razorpay checkout: $e');
      Logger.error('Stack trace: $stackTrace');
      
      // Clean up error message for user display
      String cleanError = e.toString()
          .replaceAll('Instance of \'', '')
          .replaceAll('\'', '')
          .replaceAll('Exception: ', '');
      
      onError({
        'code': 'CHECKOUT_ERROR',
        'description': cleanError,
        'debug_info': {
          'original_error': e.toString(),
          'stack_trace': stackTrace.toString(),
          'razorpay_key_configured': dotenv.env['RAZORPAY_KEY_ID'] != null,
          'razorpay_key_length': dotenv.env['RAZORPAY_KEY_ID']?.length ?? 0,
        }
      });
    }
  }

  /// Verify payment signature via Supabase edge function
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String paymentId,
    required String signature,
  }) async {
    try {
      Logger.info('Verifying payment signature for: $paymentId');

      final response = await _supabase.functions.invoke(
        'verify-razorpay-payment',
        body: {
          'order_id': orderId,
          'payment_id': paymentId,
          'signature': signature,
        },
      );

      if (response.data == null) {
        throw Exception('Failed to verify payment: No response data');
      }

      final data = response.data as Map<String, dynamic>;
      final verified = data['verified'] as bool;

      if (verified) {
        Logger.info('Payment signature verified successfully');
      } else {
        Logger.error('Payment signature verification failed');
      }

      return {
        'verified': verified,
      };
    } catch (e) {
      Logger.error('Error verifying payment', error: e);
      return {
        'verified': false,
        'error': e.toString(),
      };
    }
  }

  /// Update transaction status
  Future<void> updateTransactionStatus({
    required String transactionId,
    required String status,
    String? razorpayOrderId,
    String? razorpayPaymentId,
    String? razorpaySignature,
    String? paymentMethod,
  }) async {
    try {
      final updateData = {
        'status': status,
        if (razorpayOrderId != null) 'razorpay_order_id': razorpayOrderId,
        if (razorpayPaymentId != null) 'razorpay_payment_id': razorpayPaymentId,
        if (razorpaySignature != null) 'razorpay_signature': razorpaySignature,
        if (paymentMethod != null) 'payment_method': paymentMethod,
        if (status == 'success') 'payment_completed_at': DateTime.now().toIso8601String(),
      };

      await _supabase
          .from('payment_transactions')
          .update(updateData)
          .eq('id', transactionId);

      Logger.info('Transaction status updated: $transactionId -> $status');
    } catch (e) {
      Logger.error('Error updating transaction status', error: e);
    }
  }

  /// Activate subscription
  Future<void> activateSubscription({
    required String tenantId,
    required String planId,
    required String billingCycle,
    required double amountPaid,
    required String currency,
    required String paymentMethod,
  }) async {
    try {
      // Calculate subscription duration
      final durationDays = billingCycle == 'monthly' ? 30 : 365;

      final subscriptionData = {
        'tenant_id': tenantId,
        'plan_id': planId,
        'status': 'active',
        'billing_cycle': billingCycle,
        'currency': currency,
        'is_renewal': false,
        'start_date': DateTime.now().toIso8601String(),
        'end_date': DateTime.now().add(Duration(days: durationDays)).toIso8601String(),
        'auto_renew': false,
      };

      final subscriptionResponse = await _supabase
          .from('subscriptions')
          .insert(subscriptionData)
          .select()
          .single();

      final subscriptionId = subscriptionResponse['id'];

      // Create payment record
      final paymentData = {
        'tenant_id': tenantId,
        'subscription_id': subscriptionId,
        'amount': amountPaid,
        'currency': currency,
        'payment_method': paymentMethod,
        'payment_status': 'completed',
      };

      await _supabase.from('payments').insert(paymentData);

      // Generate license key
      // Get plan code from plan data
      final planResponse = await _supabase
          .from('subscription_plans')
          .select('plan_code')
          .eq('id', planId)
          .single();

      final licenseType = planResponse['plan_code'] as String;

      await _supabase.rpc('create_license_key', params: {
        'p_tenant_id': tenantId,
        'p_subscription_id': subscriptionId,
        'p_license_type': licenseType,
        'p_valid_days': durationDays,
      });

      Logger.info('Subscription activated successfully for tenant: $tenantId');
    } catch (e) {
      Logger.error('Error activating subscription', error: e);
      rethrow;
    }
  }
}
