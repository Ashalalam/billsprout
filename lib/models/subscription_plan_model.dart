/// Subscription plan model representing pricing tiers
class SubscriptionPlan {
  final String id;
  final String planName;
  final String planCode;
  final String? description;
  final double priceMonthly;
  final double priceYearly;
  final String priceCurrency;
  final int maxBranches;
  final int maxUsers;
  final int maxProducts;
  final int maxInvoicesPerMonth;
  final List<String> features;
  final bool isActive;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  SubscriptionPlan({
    required this.id,
    required this.planName,
    required this.planCode,
    this.description,
    required this.priceMonthly,
    required this.priceYearly,
    this.priceCurrency = 'INR',
    required this.maxBranches,
    required this.maxUsers,
    required this.maxProducts,
    required this.maxInvoicesPerMonth,
    required this.features,
    this.isActive = true,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Get monthly savings when paying yearly
  double get yearlySavings {
    return (priceMonthly * 12) - priceYearly;
  }

  /// Get monthly discount percentage for yearly plan
  double get yearlyDiscountPercentage {
    if (priceMonthly == 0) return 0;
    return ((yearlySavings / (priceMonthly * 12)) * 100);
  }

  /// Get effective monthly price for yearly plan
  double get effectiveMonthlyPriceYearly {
    return priceYearly / 12;
  }

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      planName: json['plan_name'] as String,
      planCode: json['plan_code'] as String,
      description: json['description'] as String?,
      priceMonthly: (json['price_monthly'] is int)
          ? (json['price_monthly'] as int).toDouble()
          : json['price_monthly'] as double,
      priceYearly: (json['price_yearly'] is int)
          ? (json['price_yearly'] as int).toDouble()
          : json['price_yearly'] as double,
      priceCurrency: json['price_currency'] as String? ?? 'INR',
      maxBranches: json['max_branches'] as int,
      maxUsers: json['max_users'] as int,
      maxProducts: json['max_products'] as int,
      maxInvoicesPerMonth: json['max_invoices_per_month'] as int,
      features: (json['features'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
      isActive: json['is_active'] as bool? ?? true,
      displayOrder: json['display_order'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plan_name': planName,
      'plan_code': planCode,
      'description': description,
      'price_monthly': priceMonthly,
      'price_yearly': priceYearly,
      'price_currency': priceCurrency,
      'max_branches': maxBranches,
      'max_users': maxUsers,
      'max_products': maxProducts,
      'max_invoices_per_month': maxInvoicesPerMonth,
      'features': features,
      'is_active': isActive,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SubscriptionPlan copyWith({
    String? id,
    String? planName,
    String? planCode,
    String? description,
    double? priceMonthly,
    double? priceYearly,
    String? priceCurrency,
    int? maxBranches,
    int? maxUsers,
    int? maxProducts,
    int? maxInvoicesPerMonth,
    List<String>? features,
    bool? isActive,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SubscriptionPlan(
      id: id ?? this.id,
      planName: planName ?? this.planName,
      planCode: planCode ?? this.planCode,
      description: description ?? this.description,
      priceMonthly: priceMonthly ?? this.priceMonthly,
      priceYearly: priceYearly ?? this.priceYearly,
      priceCurrency: priceCurrency ?? this.priceCurrency,
      maxBranches: maxBranches ?? this.maxBranches,
      maxUsers: maxUsers ?? this.maxUsers,
      maxProducts: maxProducts ?? this.maxProducts,
      maxInvoicesPerMonth: maxInvoicesPerMonth ?? this.maxInvoicesPerMonth,
      features: features ?? this.features,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SubscriptionPlan(planName: $planName, planCode: $planCode, priceMonthly: $priceMonthly, priceYearly: $priceYearly)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SubscriptionPlan && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

/// Tenant subscription model
class TenantSubscription {
  final String id;
  final String tenantId;
  final String planId;
  final String billingCycle; // monthly, yearly, trial
  final String status; // pending, active, expired, cancelled, suspended
  final double? amountPaid;
  final String? paymentMethod;
  final DateTime startDate;
  final DateTime endDate;
  final bool autoRenew;
  final String? razorpaySubscriptionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Populated from join
  SubscriptionPlan? plan;

  TenantSubscription({
    required this.id,
    required this.tenantId,
    required this.planId,
    required this.billingCycle,
    required this.status,
    this.amountPaid,
    this.paymentMethod,
    required this.startDate,
    required this.endDate,
    this.autoRenew = true,
    this.razorpaySubscriptionId,
    required this.createdAt,
    required this.updatedAt,
    this.plan,
  });

  bool get isActive => status == 'active' && endDate.isAfter(DateTime.now());

  int get daysRemaining {
    if (!isActive) return 0;
    return endDate.difference(DateTime.now()).inDays;
  }

  factory TenantSubscription.fromJson(Map<String, dynamic> json) {
    return TenantSubscription(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      planId: json['plan_id'] as String,
      billingCycle: json['billing_cycle'] as String,
      status: json['status'] as String,
      amountPaid: json['amount_paid'] != null
          ? (json['amount_paid'] is int
              ? (json['amount_paid'] as int).toDouble()
              : json['amount_paid'] as double)
          : null,
      paymentMethod: json['payment_method'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      autoRenew: json['auto_renew'] as bool? ?? true,
      razorpaySubscriptionId: json['razorpay_subscription_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      plan: json['subscription_plans'] != null
          ? SubscriptionPlan.fromJson(
              json['subscription_plans'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'plan_id': planId,
      'billing_cycle': billingCycle,
      'status': status,
      'amount_paid': amountPaid,
      'payment_method': paymentMethod,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'auto_renew': autoRenew,
      'razorpay_subscription_id': razorpaySubscriptionId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Payment transaction model
class PaymentTransaction {
  final String id;
  final String tenantId;
  final String? subscriptionId;
  final double amount;
  final String currency;
  final String status; // pending, processing, success, failed, refunded
  final String? paymentMethod;
  final String paymentGateway;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final String? razorpaySignature;
  final String? transactionType;
  final String? description;
  final Map<String, dynamic>? metadata;
  final DateTime? paymentInitiatedAt;
  final DateTime? paymentCompletedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentTransaction({
    required this.id,
    required this.tenantId,
    this.subscriptionId,
    required this.amount,
    this.currency = 'INR',
    required this.status,
    this.paymentMethod,
    this.paymentGateway = 'razorpay',
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.razorpaySignature,
    this.transactionType,
    this.description,
    this.metadata,
    this.paymentInitiatedAt,
    this.paymentCompletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isSuccess => status == 'success';
  bool get isPending => status == 'pending' || status == 'processing';
  bool get isFailed => status == 'failed';

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      subscriptionId: json['subscription_id'] as String?,
      amount: (json['amount'] is int)
          ? (json['amount'] as int).toDouble()
          : json['amount'] as double,
      currency: json['currency'] as String? ?? 'INR',
      status: json['status'] as String,
      paymentMethod: json['payment_method'] as String?,
      paymentGateway: json['payment_gateway'] as String? ?? 'razorpay',
      razorpayOrderId: json['razorpay_order_id'] as String?,
      razorpayPaymentId: json['razorpay_payment_id'] as String?,
      razorpaySignature: json['razorpay_signature'] as String?,
      transactionType: json['transaction_type'] as String?,
      description: json['description'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      paymentInitiatedAt: json['payment_initiated_at'] != null
          ? DateTime.parse(json['payment_initiated_at'] as String)
          : null,
      paymentCompletedAt: json['payment_completed_at'] != null
          ? DateTime.parse(json['payment_completed_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'subscription_id': subscriptionId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'payment_method': paymentMethod,
      'payment_gateway': paymentGateway,
      'razorpay_order_id': razorpayOrderId,
      'razorpay_payment_id': razorpayPaymentId,
      'razorpay_signature': razorpaySignature,
      'transaction_type': transactionType,
      'description': description,
      'metadata': metadata,
      'payment_initiated_at': paymentInitiatedAt?.toIso8601String(),
      'payment_completed_at': paymentCompletedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
