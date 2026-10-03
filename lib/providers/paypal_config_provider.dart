import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/paypal_config.dart';

/// PayPal Configuration Provider
/// 
/// Loads PayPal credentials from .env file only (production mode).
/// Credentials are read-only and cannot be changed via UI.
class PayPalConfigProvider extends ChangeNotifier {
  String _clientId = '';
  String _clientSecret = '';
  String _paypalMeUsername = '';
  String _merchantId = '';
  bool _isSandboxMode = true;
  bool _isLoading = true;

  // Getters
  String get clientId => _clientId;
  String get clientSecret => _clientSecret;
  String get paypalMeUsername => _paypalMeUsername;
  String get merchantId => _merchantId;
  bool get isSandboxMode => _isSandboxMode;
  bool get isLoading => _isLoading;

  bool get isConfigured => 
      _clientId.isNotEmpty && 
      _clientSecret.isNotEmpty;

  bool get isPayPalMeConfigured => _paypalMeUsername.isNotEmpty;

  String get environmentName => _isSandboxMode ? 'Sandbox (Testing)' : 'Production (Live)';

  PayPalConfigProvider() {
    _loadConfiguration();
  }

  /// Load PayPal configuration from .env file only
  Future<void> _loadConfiguration() async {
    try {
      _isLoading = true;
      notifyListeners();

      // Load from .env file
      if (dotenv.env.isNotEmpty) {
        _clientId = dotenv.env['PAYPAL_CLIENT_ID'] ?? '';
        _clientSecret = dotenv.env['PAYPAL_CLIENT_SECRET'] ?? '';
        _paypalMeUsername = dotenv.env['PAYPAL_ME_USERNAME'] ?? '';
        _merchantId = dotenv.env['PAYPAL_MERCHANT_ID'] ?? '';
        _isSandboxMode = dotenv.env['PAYPAL_SANDBOX_MODE']?.toLowerCase() == 'true';

        if (_clientId.isNotEmpty && _clientSecret.isNotEmpty) {
          debugPrint('[PayPal] Loaded credentials from .env file');
          debugPrint('[PayPal] Mode: ${_isSandboxMode ? "Sandbox (Testing)" : "Production (Live)"}');
        } else {
          debugPrint('[PayPal] WARNING: Credentials not found in .env file');
        }
      }

      // Update static config
      if (isConfigured) {
        PayPalConfig.setCredentials(
          clientId: _clientId,
          clientSecret: _clientSecret,
          paypalMeUsername: _paypalMeUsername,
          merchantId: _merchantId,
          sandboxMode: _isSandboxMode,
        );
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      debugPrint('[PayPal] Error loading configuration: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Get masked client ID for display (security)
  String get maskedClientId {
    if (_clientId.isEmpty) return 'Not configured';
    if (_clientId.length <= 8) return '••••••••';
    return '${_clientId.substring(0, 4)}••••${_clientId.substring(_clientId.length - 4)}';
  }

  /// Get masked client secret for display (security)
  String get maskedClientSecret {
    if (_clientSecret.isEmpty) return 'Not configured';
    return '••••••••••••••••';
  }
}
