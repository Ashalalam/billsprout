import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/paypal_config.dart';
import '../models/invoice_model.dart';

/// PayPal Service
/// 
/// Handles PayPal REST API integration for payment processing.
/// Supports both sandbox (testing) and production environments.
class PayPalService {
  static String? _accessToken;
  static DateTime? _tokenExpiry;

  /// Check if PayPal is configured and ready
  static bool get isConfigured => PayPalConfig.isConfigured;

  /// Get or refresh access token
  static Future<String?> _getAccessToken() async {
    try {
      // Check if we have a valid token
      if (_accessToken != null && 
          _tokenExpiry != null && 
          DateTime.now().isBefore(_tokenExpiry!)) {
        return _accessToken;
      }

      // Request new access token
      final response = await http.post(
        Uri.parse(PayPalConfig.tokenUrl),
        headers: {
          'Authorization': PayPalConfig.getBasicAuthHeader(),
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: 'grant_type=client_credentials',
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        
        // Token expires in seconds, store expiry time
        final expiresIn = data['expires_in'] as int? ?? 3600;
        _tokenExpiry = DateTime.now().add(Duration(seconds: expiresIn - 60));
        
        debugPrint('[PayPal] Access token obtained successfully');
        return _accessToken;
      } else {
        debugPrint('[PayPal] Token error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[PayPal] Error getting access token: $e');
      return null;
    }
  }

  /// Create PayPal order for payment
  static Future<Map<String, dynamic>?> createOrder({
    required double amount,
    required String currency,
    required String invoiceNumber,
    String? description,
  }) async {
    try {
      if (!isConfigured) {
        throw Exception('PayPal not configured. Please add credentials in Settings.');
      }

      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('Failed to obtain PayPal access token');
      }

      final orderData = {
        'intent': 'CAPTURE',
        'purchase_units': [
          {
            'reference_id': invoiceNumber,
            'description': description ?? 'Pharmacy Purchase - Invoice $invoiceNumber',
            'amount': {
              'currency_code': currency,
              'value': amount.toStringAsFixed(2),
            },
            'invoice_id': invoiceNumber,
          }
        ],
        'payment_source': {
          'paypal': {
            'experience_context': {
              'payment_method_preference': 'IMMEDIATE_PAYMENT_REQUIRED',
              'brand_name': 'BillSprout Pharmacy',
              'locale': 'en-US',
              'landing_page': 'NO_PREFERENCE',
              'shipping_preference': 'NO_SHIPPING',
              'user_action': 'PAY_NOW',
            }
          }
        }
      };

      final response = await http.post(
        Uri.parse(PayPalConfig.ordersUrl),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: json.encode(orderData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        debugPrint('[PayPal] Order created: ${data['id']}');
        return data;
      } else {
        debugPrint('[PayPal] Create order error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[PayPal] Error creating order: $e');
      return null;
    }
  }

  /// Capture payment for an order
  static Future<Map<String, dynamic>?> captureOrder(String orderId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('Failed to obtain PayPal access token');
      }

      final response = await http.post(
        Uri.parse('${PayPalConfig.ordersUrl}/$orderId/capture'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = json.decode(response.body);
        debugPrint('[PayPal] Order captured: $orderId');
        return data;
      } else {
        debugPrint('[PayPal] Capture order error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[PayPal] Error capturing order: $e');
      return null;
    }
  }

  /// Get order details
  static Future<Map<String, dynamic>?> getOrderDetails(String orderId) async {
    try {
      final token = await _getAccessToken();
      if (token == null) {
        throw Exception('Failed to obtain PayPal access token');
      }

      final response = await http.get(
        Uri.parse('${PayPalConfig.ordersUrl}/$orderId'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else {
        debugPrint('[PayPal] Get order error: ${response.statusCode} - ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('[PayPal] Error getting order details: $e');
      return null;
    }
  }

  /// Process payment for invoice
  static Future<PayPalPaymentResult> processPayment({
    required InvoiceModel invoice,
    String currency = 'USD',
  }) async {
    try {
      if (!isConfigured) {
        return PayPalPaymentResult(
          success: false,
          message: 'PayPal not configured. Please add credentials in Settings.',
        );
      }

      // Create order
      final order = await createOrder(
        amount: invoice.payableTotal,
        currency: currency,
        invoiceNumber: invoice.invoiceNumber,
        description: 'Pharmacy Purchase - ${invoice.customerName}',
      );

      if (order == null) {
        return PayPalPaymentResult(
          success: false,
          message: 'Failed to create PayPal order. Please try again.',
        );
      }

      final orderId = order['id'] as String;
      
      // Get approval URL for customer
      String? approvalUrl;
      final links = order['links'] as List?;
      if (links != null) {
        for (var link in links) {
          if (link['rel'] == 'approve') {
            approvalUrl = link['href'];
            break;
          }
        }
      }

      return PayPalPaymentResult(
        success: true,
        orderId: orderId,
        approvalUrl: approvalUrl,
        message: 'PayPal order created successfully',
      );
    } catch (e) {
      debugPrint('[PayPal] Payment processing error: $e');
      return PayPalPaymentResult(
        success: false,
        message: 'Error processing payment: $e',
      );
    }
  }

  /// Verify payment status
  static Future<bool> verifyPayment(String orderId) async {
    try {
      final order = await getOrderDetails(orderId);
      if (order == null) return false;

      final status = order['status'] as String?;
      return status == 'COMPLETED' || status == 'APPROVED';
    } catch (e) {
      debugPrint('[PayPal] Error verifying payment: $e');
      return false;
    }
  }

  /// Generate PayPal.Me QR code data or general PayPal payment link
  static String generatePayPalMeUrl({
    required double amount,
    required String invoiceNumber,
  }) {
    // If PayPal.Me username is configured, use it for QR code
    if (PayPalConfig.isPayPalMeConfigured) {
      final note = 'Invoice: $invoiceNumber';
      return PayPalConfig.getPayPalMeUrl(amount, note: note);
    }
    
    // If only Client ID/Secret available, return generic PayPal payment link
    // User will need to log in to PayPal to complete payment
    final amountStr = amount.toStringAsFixed(2);
    final encodedNote = Uri.encodeComponent('Invoice: $invoiceNumber');
    return 'https://www.paypal.com/cgi-bin/webscr?cmd=_xclick&business=&amount=$amountStr&item_name=$encodedNote';
  }

  /// Clear access token (for logout/credential change)
  static void clearSession() {
    _accessToken = null;
    _tokenExpiry = null;
    debugPrint('[PayPal] Session cleared');
  }
}

/// PayPal Payment Result
class PayPalPaymentResult {
  final bool success;
  final String? orderId;
  final String? approvalUrl;
  final String? transactionId;
  final String message;

  PayPalPaymentResult({
    required this.success,
    this.orderId,
    this.approvalUrl,
    this.transactionId,
    required this.message,
  });

  @override
  String toString() {
    return 'PayPalPaymentResult(success: $success, orderId: $orderId, message: $message)';
  }
}

/// PayPal Payment Status
enum PayPalPaymentStatus {
  pending,
  approved,
  completed,
  failed,
  cancelled,
  unknown;

  static PayPalPaymentStatus fromString(String? status) {
    if (status == null) return unknown;
    
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'CREATED':
        return pending;
      case 'APPROVED':
        return approved;
      case 'COMPLETED':
        return completed;
      case 'VOIDED':
      case 'FAILED':
        return failed;
      case 'CANCELLED':
        return cancelled;
      default:
        return unknown;
    }
  }

  String get displayName {
    switch (this) {
      case pending:
        return 'Pending';
      case approved:
        return 'Approved';
      case completed:
        return 'Completed';
      case failed:
        return 'Failed';
      case cancelled:
        return 'Cancelled';
      case unknown:
        return 'Unknown';
    }
  }

  bool get isSuccessful => this == completed || this == approved;
}
