/// PayPal Configuration
/// 
/// This file handles PayPal credentials securely.
/// Credentials are stored in SharedPreferences (encrypted on device).
/// Never commit actual credentials to version control.
library;

class PayPalConfig {
  // PayPal API Endpoints
  static const String sandboxBaseUrl = 'https://api-m.sandbox.paypal.com';
  static const String productionBaseUrl = 'https://api-m.paypal.com';

  // Default mode (sandbox for testing)
  static bool isSandboxMode = true;

  // API Endpoints
  static String get baseUrl => isSandboxMode ? sandboxBaseUrl : productionBaseUrl;
  static String get tokenUrl => '$baseUrl/v1/oauth2/token';
  static String get ordersUrl => '$baseUrl/v2/checkout/orders';
  static String get paymentsUrl => '$baseUrl/v1/payments/payment';

  // PayPal.Me URL for QR code generation
  static String get paypalMeBaseUrl => 'https://www.paypal.me';

  // Configuration keys for SharedPreferences
  static const String keyClientId = 'paypal_client_id';
  static const String keyClientSecret = 'paypal_client_secret';
  static const String keySandboxMode = 'paypal_sandbox_mode';
  static const String keyPayPalMeUsername = 'paypal_me_username';
  static const String keyMerchantId = 'paypal_merchant_id';

  // Credentials (loaded from SharedPreferences at runtime)
  static String? _clientId;
  static String? _clientSecret;
  static String? _paypalMeUsername;
  static String? _merchantId;

  // Getters
  static String? get clientId => _clientId;
  static String? get clientSecret => _clientSecret;
  static String? get paypalMeUsername => _paypalMeUsername;
  static String? get merchantId => _merchantId;

  // Check if PayPal is configured
  static bool get isConfigured => 
      _clientId != null && 
      _clientId!.isNotEmpty && 
      _clientSecret != null && 
      _clientSecret!.isNotEmpty;

  // Check if PayPal.Me is configured (for QR code payments)
  static bool get isPayPalMeConfigured =>
      _paypalMeUsername != null && _paypalMeUsername!.isNotEmpty;

  // Setters (for runtime configuration)
  static void setCredentials({
    required String clientId,
    required String clientSecret,
    String? paypalMeUsername,
    String? merchantId,
    bool? sandboxMode,
  }) {
    _clientId = clientId;
    _clientSecret = clientSecret;
    _paypalMeUsername = paypalMeUsername;
    _merchantId = merchantId;
    if (sandboxMode != null) {
      isSandboxMode = sandboxMode;
    }
  }

  // Clear credentials (for security/logout)
  static void clearCredentials() {
    _clientId = null;
    _clientSecret = null;
    _paypalMeUsername = null;
    _merchantId = null;
  }

  // Get PayPal.Me URL for QR code
  static String getPayPalMeUrl(double amount, {String? note}) {
    if (!isPayPalMeConfigured) {
      throw Exception('PayPal.Me username not configured');
    }
    
    String url = '$paypalMeBaseUrl/$_paypalMeUsername/$amount';
    
    if (note != null && note.isNotEmpty) {
      // URL encode the note
      final encodedNote = Uri.encodeComponent(note);
      url += '?note=$encodedNote';
    }
    
    return url;
  }

  // Get authentication header (Basic Auth for OAuth)
  static String getBasicAuthHeader() {
    if (!isConfigured) {
      throw Exception('PayPal credentials not configured');
    }
    
    final credentials = '$_clientId:$_clientSecret';
    final bytes = credentials.codeUnits;
    final base64Str = base64Encode(bytes);
    
    return 'Basic $base64Str';
  }
}

// Helper function to encode base64
String base64Encode(List<int> bytes) {
  const String chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  String result = '';
  
  for (int i = 0; i < bytes.length; i += 3) {
    int b1 = bytes[i];
    int b2 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    int b3 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    
    int n = (b1 << 16) | (b2 << 8) | b3;
    
    result += chars[(n >> 18) & 0x3F];
    result += chars[(n >> 12) & 0x3F];
    result += i + 1 < bytes.length ? chars[(n >> 6) & 0x3F] : '=';
    result += i + 2 < bytes.length ? chars[n & 0x3F] : '=';
  }
  
  return result;
}
