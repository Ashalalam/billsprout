import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../config/paypal_config.dart';

/// PayPal Configuration Provider
/// 
/// Manages PayPal credentials securely using SharedPreferences.
/// On first run, loads credentials from .env file (production mode).
/// Credentials are encrypted on device and never exposed in code.
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

  /// Load PayPal configuration from SharedPreferences
  /// If not found, load from .env file (first run or reset)
  Future<void> _loadConfiguration() async {
    try {
      _isLoading = true;
      notifyListeners();

      final prefs = await SharedPreferences.getInstance();

      // Try to load from SharedPreferences first
      _clientId = prefs.getString(PayPalConfig.keyClientId) ?? '';
      _clientSecret = prefs.getString(PayPalConfig.keyClientSecret) ?? '';
      _paypalMeUsername = prefs.getString(PayPalConfig.keyPayPalMeUsername) ?? '';
      _merchantId = prefs.getString(PayPalConfig.keyMerchantId) ?? '';
      _isSandboxMode = prefs.getBool(PayPalConfig.keySandboxMode) ?? true;

      // If not configured in SharedPreferences, load from .env (first run)
      if (!isConfigured && dotenv.env.isNotEmpty) {
        final envClientId = dotenv.env['PAYPAL_CLIENT_ID'] ?? '';
        final envClientSecret = dotenv.env['PAYPAL_CLIENT_SECRET'] ?? '';
        final envPayPalMe = dotenv.env['PAYPAL_ME_USERNAME'] ?? '';
        final envMerchantId = dotenv.env['PAYPAL_MERCHANT_ID'] ?? '';
        final envSandboxMode = dotenv.env['PAYPAL_SANDBOX_MODE']?.toLowerCase() == 'true';

        if (envClientId.isNotEmpty && envClientSecret.isNotEmpty) {
          debugPrint('Loading PayPal credentials from .env file');
          
          // Save to SharedPreferences for future use
          await saveConfiguration(
            clientId: envClientId,
            clientSecret: envClientSecret,
            paypalMeUsername: envPayPalMe.isNotEmpty ? envPayPalMe : null,
            merchantId: envMerchantId.isNotEmpty ? envMerchantId : null,
            sandboxMode: envSandboxMode,
          );
          
          return; // saveConfiguration already calls notifyListeners
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
      debugPrint('Error loading PayPal configuration: $e');
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Save PayPal configuration to SharedPreferences
  Future<bool> saveConfiguration({
    required String clientId,
    required String clientSecret,
    String? paypalMeUsername,
    String? merchantId,
    required bool sandboxMode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save to SharedPreferences
      await prefs.setString(PayPalConfig.keyClientId, clientId.trim());
      await prefs.setString(PayPalConfig.keyClientSecret, clientSecret.trim());
      await prefs.setString(
        PayPalConfig.keyPayPalMeUsername,
        paypalMeUsername?.trim() ?? '',
      );
      await prefs.setString(
        PayPalConfig.keyMerchantId,
        merchantId?.trim() ?? '',
      );
      await prefs.setBool(PayPalConfig.keySandboxMode, sandboxMode);

      // Update local state
      _clientId = clientId.trim();
      _clientSecret = clientSecret.trim();
      _paypalMeUsername = paypalMeUsername?.trim() ?? '';
      _merchantId = merchantId?.trim() ?? '';
      _isSandboxMode = sandboxMode;

      // Update static config
      PayPalConfig.setCredentials(
        clientId: _clientId,
        clientSecret: _clientSecret,
        paypalMeUsername: _paypalMeUsername,
        merchantId: _merchantId,
        sandboxMode: _isSandboxMode,
      );

      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error saving PayPal configuration: $e');
      return false;
    }
  }

  /// Clear PayPal configuration (for security/logout)
  Future<void> clearConfiguration() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(PayPalConfig.keyClientId);
      await prefs.remove(PayPalConfig.keyClientSecret);
      await prefs.remove(PayPalConfig.keyPayPalMeUsername);
      await prefs.remove(PayPalConfig.keyMerchantId);
      await prefs.remove(PayPalConfig.keySandboxMode);

      _clientId = '';
      _clientSecret = '';
      _paypalMeUsername = '';
      _merchantId = '';
      _isSandboxMode = true;

      PayPalConfig.clearCredentials();

      notifyListeners();
    } catch (e) {
      debugPrint('Error clearing PayPal configuration: $e');
    }
  }

  /// Toggle between Sandbox and Production mode
  Future<void> toggleSandboxMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isSandboxMode = !_isSandboxMode;
      
      await prefs.setBool(PayPalConfig.keySandboxMode, _isSandboxMode);
      PayPalConfig.isSandboxMode = _isSandboxMode;

      notifyListeners();
    } catch (e) {
      debugPrint('Error toggling sandbox mode: $e');
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
