import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_plan_model.dart';
import '../utils/logger.dart';

class SubscriptionProvider with ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  
  List<SubscriptionPlan> _plans = [];
  TenantSubscription? _currentSubscription;
  List<PaymentTransaction> _transactions = [];
  
  bool _isLoading = false;
  String? _error;

  // Getters
  List<SubscriptionPlan> get plans => _plans;
  TenantSubscription? get currentSubscription => _currentSubscription;
  List<PaymentTransaction> get transactions => _transactions;
  bool get isLoading => _isLoading;
  String? get error => _error;
  
  bool get hasActiveSubscription => 
      _currentSubscription?.isActive ?? false;

  /// Fetch all available subscription plans
  Future<void> fetchPlans() async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('subscription_plans')
          .select()
          .eq('is_active', true)
          .order('display_order', ascending: true);

      _plans = (response as List)
          .map((json) => SubscriptionPlan.fromJson(json))
          .toList();

      Logger.info('Fetched ${_plans.length} subscription plans');
    } catch (e) {
      _error = 'Failed to load subscription plans: $e';
      Logger.error('Error fetching plans', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch current tenant's subscription
  Future<void> fetchCurrentSubscription(String tenantId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('tenant_subscriptions')
          .select('*, subscription_plans(*)')
          .eq('tenant_id', tenantId)
          .eq('status', 'active')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        _currentSubscription = TenantSubscription.fromJson(response);
        Logger.info('Fetched current subscription: ${_currentSubscription?.plan?.planName}');
      } else {
        _currentSubscription = null;
        Logger.info('No active subscription found for tenant');
      }
    } catch (e) {
      _error = 'Failed to load subscription: $e';
      Logger.error('Error fetching subscription', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch payment transactions for current tenant
  Future<void> fetchTransactions(String tenantId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final response = await _supabase
          .from('payment_transactions')
          .select()
          .eq('tenant_id', tenantId)
          .order('created_at', ascending: false);

      _transactions = (response as List)
          .map((json) => PaymentTransaction.fromJson(json))
          .toList();

      Logger.info('Fetched ${_transactions.length} payment transactions');
    } catch (e) {
      _error = 'Failed to load transactions: $e';
      Logger.error('Error fetching transactions', error: e);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Create a payment transaction record
  Future<PaymentTransaction?> createPaymentTransaction({
    required String tenantId,
    required String planId,
    required double amount,
    required String billingCycle,
    String? razorpayOrderId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final transactionData = {
        'tenant_id': tenantId,
        'amount': amount,
        'currency': 'INR',
        'status': 'pending',
        'payment_gateway': 'razorpay',
        'razorpay_order_id': razorpayOrderId,
        'transaction_type': 'subscription',
        'description': 'Subscription purchase',
        'metadata': {
          'plan_id': planId,
          'billing_cycle': billingCycle,
        },
        'payment_initiated_at': DateTime.now().toIso8601String(),
      };

      final response = await _supabase
          .from('payment_transactions')
          .insert(transactionData)
          .select()
          .single();

      final transaction = PaymentTransaction.fromJson(response);
      Logger.info('Created payment transaction: ${transaction.id}');
      
      return transaction;
    } catch (e) {
      _error = 'Failed to create payment transaction: $e';
      Logger.error('Error creating payment transaction', error: e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Update payment transaction status (called after payment verification)
  Future<bool> updatePaymentTransaction({
    required String transactionId,
    required String status,
    String? razorpayPaymentId,
    String? razorpaySignature,
    String? paymentMethod,
  }) async {
    try {
      final updateData = {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (razorpayPaymentId != null) {
        updateData['razorpay_payment_id'] = razorpayPaymentId;
      }
      if (razorpaySignature != null) {
        updateData['razorpay_signature'] = razorpaySignature;
      }
      if (paymentMethod != null) {
        updateData['payment_method'] = paymentMethod;
      }
      if (status == 'success') {
        updateData['payment_completed_at'] = DateTime.now().toIso8601String();
      }

      await _supabase
          .from('payment_transactions')
          .update(updateData)
          .eq('id', transactionId);

      Logger.info('Updated payment transaction $transactionId to $status');
      return true;
    } catch (e) {
      _error = 'Failed to update payment transaction: $e';
      Logger.error('Error updating payment transaction', error: e);
      return false;
    }
  }

  /// Create tenant subscription after successful payment
  Future<TenantSubscription?> createTenantSubscription({
    required String tenantId,
    required String planId,
    required String billingCycle,
    required double amountPaid,
    String? paymentMethod,
    String? razorpaySubscriptionId,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final startDate = DateTime.now();
      final endDate = billingCycle == 'yearly'
          ? startDate.add(const Duration(days: 365))
          : startDate.add(const Duration(days: 30));

      final subscriptionData = {
        'tenant_id': tenantId,
        'plan_id': planId,
        'billing_cycle': billingCycle,
        'status': 'active',
        'amount_paid': amountPaid,
        'payment_method': paymentMethod,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'auto_renew': true,
        'razorpay_subscription_id': razorpaySubscriptionId,
      };

      final response = await _supabase
          .from('tenant_subscriptions')
          .insert(subscriptionData)
          .select('*, subscription_plans(*)')
          .single();

      _currentSubscription = TenantSubscription.fromJson(response);
      Logger.info('Created tenant subscription: ${_currentSubscription?.id}');

      return _currentSubscription;
    } catch (e) {
      _error = 'Failed to create subscription: $e';
      Logger.error('Error creating subscription', error: e);
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Cancel subscription
  Future<bool> cancelSubscription(String subscriptionId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _supabase
          .from('tenant_subscriptions')
          .update({
            'status': 'cancelled',
            'auto_renew': false,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId);

      Logger.info('Cancelled subscription: $subscriptionId');
      return true;
    } catch (e) {
      _error = 'Failed to cancel subscription: $e';
      Logger.error('Error cancelling subscription', error: e);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get plan by ID
  SubscriptionPlan? getPlanById(String planId) {
    try {
      return _plans.firstWhere((plan) => plan.id == planId);
    } catch (e) {
      return null;
    }
  }

  /// Get plan by code
  SubscriptionPlan? getPlanByCode(String planCode) {
    try {
      return _plans.firstWhere((plan) => plan.planCode == planCode);
    } catch (e) {
      return null;
    }
  }

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset provider
  void reset() {
    _plans = [];
    _currentSubscription = null;
    _transactions = [];
    _isLoading = false;
    _error = null;
    notifyListeners();
  }
}
