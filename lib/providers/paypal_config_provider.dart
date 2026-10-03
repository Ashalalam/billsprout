import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Provider for PayPal configuration
/// Loads PayPal credentials from environment variables
class PayPalConfigProvider with ChangeNotifier {
  String _paypalMeUsername = '';
  String _paypalClientId = '';
  String _paypalSecretKey = '';
  bool _isSandbox = true;

  PayPalConfigProvider() {
    _loadConfig();
  }

  String get paypalMeUsername => _paypalMeUsername;
  String get paypalClientId => _paypalClientId;
  String get paypalSecretKey => _paypalSecretKey;
  bool get isSandbox => _isSandbox;

  /// Load PayPal configuration from .env file
  void _loadConfig() {
    try {
      _paypalMeUsername = dotenv.env['PAYPAL_ME_USERNAME'] ?? '';
      _paypalClientId = dotenv.env['PAYPAL_CLIENT_ID'] ?? '';
      _paypalSecretKey = dotenv.env['PAYPAL_SECRET_KEY'] ?? '';
      _isSandbox = dotenv.env['PAYPAL_SANDBOX']?.toLowerCase() == 'true';
      
      if (kDebugMode) {
        print('[PayPal Config] Loaded: Username=${_paypalMeUsername.isNotEmpty ? "✓" : "✗"}, '
            'ClientID=${_paypalClientId.isNotEmpty ? "✓" : "✗"}, '
            'Sandbox=$_isSandbox');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[PayPal Config] Error loading config: $e');
      }
    }
  }

  /// Generate PayPal.Me link for given amount
  String generatePayPalMeLink(double amount) {
    if (_paypalMeUsername.isEmpty) {
      return 'https://www.paypal.com/paypalme';
    }
    return 'https://paypal.me/$_paypalMeUsername/${amount.toStringAsFixed(2)}';
  }

  /// Generate PayPal payment URL
  String generatePaymentUrl(double amount, String currency) {
    if (_paypalMeUsername.isNotEmpty) {
      return generatePayPalMeLink(amount);
    }
    // Fallback to PayPal Send Money
    return 'https://www.paypal.com/paypalme';
  }

  /// Update PayPal.Me username
  void updatePayPalMeUsername(String username) {
    _paypalMeUsername = username;
    notifyListeners();
  }

  /// Update PayPal API credentials
  void updateApiCredentials({
    required String clientId,
    required String secretKey,
    required bool sandbox,
  }) {
    _paypalClientId = clientId;
    _paypalSecretKey = secretKey;
    _isSandbox = sandbox;
    notifyListeners();
  }
}
