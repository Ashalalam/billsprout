/// PayPal Transaction Model
/// 
/// Tracks PayPal payment transactions for auditing and reconciliation.
class PayPalTransaction {
  final String id;
  final String invoiceNumber;
  final double amount;
  final String currency;
  final PayPalTransactionStatus status;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? paypalOrderId;
  final String? paypalTransactionId;
  final String? payerEmail;
  final String? payerName;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  PayPalTransaction({
    required this.id,
    required this.invoiceNumber,
    required this.amount,
    this.currency = 'USD',
    required this.status,
    required this.createdAt,
    this.completedAt,
    this.paypalOrderId,
    this.paypalTransactionId,
    this.payerEmail,
    this.payerName,
    this.errorMessage,
    this.metadata,
  });

  /// Create a pending transaction
  factory PayPalTransaction.pending({
    required String invoiceNumber,
    required double amount,
    String currency = 'USD',
  }) {
    return PayPalTransaction(
      id: 'pptxn_${DateTime.now().millisecondsSinceEpoch}',
      invoiceNumber: invoiceNumber,
      amount: amount,
      currency: currency,
      status: PayPalTransactionStatus.pending,
      createdAt: DateTime.now(),
    );
  }

  /// Mark transaction as completed
  PayPalTransaction markCompleted({
    String? paypalOrderId,
    String? paypalTransactionId,
    String? payerEmail,
    String? payerName,
  }) {
    return PayPalTransaction(
      id: id,
      invoiceNumber: invoiceNumber,
      amount: amount,
      currency: currency,
      status: PayPalTransactionStatus.completed,
      createdAt: createdAt,
      completedAt: DateTime.now(),
      paypalOrderId: paypalOrderId ?? this.paypalOrderId,
      paypalTransactionId: paypalTransactionId ?? this.paypalTransactionId,
      payerEmail: payerEmail ?? this.payerEmail,
      payerName: payerName ?? this.payerName,
      metadata: metadata,
    );
  }

  /// Mark transaction as failed
  PayPalTransaction markFailed(String errorMessage) {
    return PayPalTransaction(
      id: id,
      invoiceNumber: invoiceNumber,
      amount: amount,
      currency: currency,
      status: PayPalTransactionStatus.failed,
      createdAt: createdAt,
      completedAt: DateTime.now(),
      paypalOrderId: paypalOrderId,
      paypalTransactionId: paypalTransactionId,
      payerEmail: payerEmail,
      payerName: payerName,
      errorMessage: errorMessage,
      metadata: metadata,
    );
  }

  /// Mark transaction as cancelled
  PayPalTransaction markCancelled() {
    return PayPalTransaction(
      id: id,
      invoiceNumber: invoiceNumber,
      amount: amount,
      currency: currency,
      status: PayPalTransactionStatus.cancelled,
      createdAt: createdAt,
      completedAt: DateTime.now(),
      paypalOrderId: paypalOrderId,
      paypalTransactionId: paypalTransactionId,
      payerEmail: payerEmail,
      payerName: payerName,
      metadata: metadata,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'invoice_number': invoiceNumber,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'created_at': createdAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'paypal_order_id': paypalOrderId,
      'paypal_transaction_id': paypalTransactionId,
      'payer_email': payerEmail,
      'payer_name': payerName,
      'error_message': errorMessage,
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory PayPalTransaction.fromJson(Map<String, dynamic> json) {
    return PayPalTransaction(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'USD',
      status: PayPalTransactionStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => PayPalTransactionStatus.pending,
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      paypalOrderId: json['paypal_order_id'] as String?,
      paypalTransactionId: json['paypal_transaction_id'] as String?,
      payerEmail: json['payer_email'] as String?,
      payerName: json['payer_name'] as String?,
      errorMessage: json['error_message'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'PayPalTransaction(id: $id, invoice: $invoiceNumber, amount: $amount, status: ${status.name})';
  }
}

/// PayPal Transaction Status
enum PayPalTransactionStatus {
  pending,    // Payment initiated, waiting for customer
  completed,  // Payment successful
  failed,     // Payment failed
  cancelled,  // Payment cancelled by user
  refunded;   // Payment refunded (future use)

  String get displayName {
    switch (this) {
      case pending:
        return 'Pending';
      case completed:
        return 'Completed';
      case failed:
        return 'Failed';
      case cancelled:
        return 'Cancelled';
      case refunded:
        return 'Refunded';
    }
  }

  bool get isSuccessful => this == completed;
  bool get isFinal => this == completed || this == failed || this == cancelled;
}
