import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/app_theme.dart';
import '../../providers/paypal_config_provider.dart';
import '../../providers/paypal_transaction_provider.dart';

/// PayPal Settings View
/// 
/// Allows users to configure PayPal credentials and settings securely.
class PayPalSettingsView extends StatefulWidget {
  const PayPalSettingsView({super.key});

  @override
  State<PayPalSettingsView> createState() => _PayPalSettingsViewState();
}

class _PayPalSettingsViewState extends State<PayPalSettingsView> {
  final _formKey = GlobalKey<FormState>();
  final _clientIdCtrl = TextEditingController();
  final _clientSecretCtrl = TextEditingController();
  final _paypalMeCtrl = TextEditingController();
  final _merchantIdCtrl = TextEditingController();
  
  bool _obscureSecret = true;
  bool _isSandboxMode = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  void _loadCurrentConfig() {
    final provider = Provider.of<PayPalConfigProvider>(context, listen: false);
    _clientIdCtrl.text = provider.clientId;
    _clientSecretCtrl.text = provider.clientSecret;
    _paypalMeCtrl.text = provider.paypalMeUsername;
    _merchantIdCtrl.text = provider.merchantId;
    _isSandboxMode = provider.isSandboxMode;
  }

  @override
  void dispose() {
    _clientIdCtrl.dispose();
    _clientSecretCtrl.dispose();
    _paypalMeCtrl.dispose();
    _merchantIdCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveConfiguration() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final provider = Provider.of<PayPalConfigProvider>(context, listen: false);
    final success = await provider.saveConfiguration(
      clientId: _clientIdCtrl.text.trim(),
      clientSecret: _clientSecretCtrl.text.trim(),
      paypalMeUsername: _paypalMeCtrl.text.trim(),
      merchantId: _merchantIdCtrl.text.trim(),
      sandboxMode: _isSandboxMode,
    );

    setState(() => _saving = false);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ PayPal configuration saved securely'),
          backgroundColor: AppTheme.successGreen,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Failed to save configuration'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
    }
  }

  Future<void> _clearConfiguration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear PayPal Configuration?'),
        content: const Text(
          'This will remove all PayPal credentials from this device. '
          'You can add them again later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.errorRed),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final provider = Provider.of<PayPalConfigProvider>(context, listen: false);
      await provider.clearConfiguration();
      
      _clientIdCtrl.clear();
      _clientSecretCtrl.clear();
      _paypalMeCtrl.clear();
      _merchantIdCtrl.clear();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PayPal configuration cleared'),
            backgroundColor: AppTheme.textMuted,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.lightBackground,
      appBar: AppBar(
        title: const Text('PayPal Configuration'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: Consumer<PayPalConfigProvider>(
        builder: (context, config, _) {
          if (config.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Card
                  _buildStatusCard(config),
                  const SizedBox(height: 24),

                  // Info Card
                  _buildInfoCard(),
                  const SizedBox(height: 24),

                  // Environment Toggle
                  _buildEnvironmentToggle(),
                  const SizedBox(height: 24),

                  // Credentials Section
                  _buildSection('PayPal API Credentials'),
                  _buildTextField(
                    controller: _clientIdCtrl,
                    label: 'Client ID',
                    icon: Icons.vpn_key,
                    hint: 'Enter your PayPal Client ID',
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Client ID is required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _clientSecretCtrl,
                    label: 'Client Secret',
                    icon: Icons.lock,
                    hint: 'Enter your PayPal Client Secret',
                    obscureText: _obscureSecret,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureSecret ? Icons.visibility : Icons.visibility_off,
                      ),
                      onPressed: () => setState(() => _obscureSecret = !_obscureSecret),
                    ),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Client Secret is required'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  // PayPal.Me Section
                  _buildSection('PayPal.Me (for QR Code Payments)'),
                  _buildTextField(
                    controller: _paypalMeCtrl,
                    label: 'PayPal.Me Username',
                    icon: Icons.person_outline,
                    hint: 'e.g., YourPharmacy',
                    helperText: 'Used to generate QR codes for customer payments',
                  ),
                  const SizedBox(height: 24),

                  // Merchant ID (Optional)
                  _buildSection('Additional Settings (Optional)'),
                  _buildTextField(
                    controller: _merchantIdCtrl,
                    label: 'Merchant ID',
                    icon: Icons.business,
                    hint: 'Optional - for advanced features',
                  ),
                  const SizedBox(height: 32),

                  // Transaction Statistics
                  _buildTransactionStats(),
                  const SizedBox(height: 32),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _saving ? null : _clearConfiguration,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Clear Config'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.errorRed,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _saving ? null : _saveConfiguration,
                          icon: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(_saving ? 'Saving...' : 'Save Configuration'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Help Link
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        // Could open PAYPAL_SETUP.md or help dialog
                        _showHelpDialog();
                      },
                      icon: const Icon(Icons.help_outline),
                      label: const Text('How to get PayPal credentials?'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(PayPalConfigProvider config) {
    final isConfigured = config.isConfigured;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isConfigured ? AppTheme.successGreen.withValues(alpha: 0.1) : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isConfigured ? AppTheme.successGreen : Colors.orange.shade300,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isConfigured ? Icons.check_circle : Icons.warning_amber_rounded,
            color: isConfigured ? AppTheme.successGreen : Colors.orange.shade700,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConfigured ? 'PayPal Configured' : 'PayPal Not Configured',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isConfigured ? AppTheme.successGreen : Colors.orange.shade900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isConfigured
                      ? 'Environment: ${config.environmentName}'
                      : 'Add your PayPal credentials to accept payments',
                  style: TextStyle(
                    fontSize: 13,
                    color: isConfigured ? AppTheme.textMuted : Colors.orange.shade800,
                  ),
                ),
                if (isConfigured) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Client ID: ${config.maskedClientId}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: AppTheme.primaryBlue),
              const SizedBox(width: 8),
              const Text(
                'Configuration Options',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '📝 Option 1: Configure here (stored encrypted on device)\n'
            '🔧 Option 2: Use .env file (recommended for production)\n'
            '🔒 Your credentials are never shared or uploaded\n'
            '📖 See PAYPAL_SETUP.md for detailed setup guide',
            style: TextStyle(fontSize: 12, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEnvironmentToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PayPal Environment',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _EnvironmentChip(
                  label: 'Sandbox (Testing)',
                  icon: Icons.science_outlined,
                  isSelected: _isSandboxMode,
                  onTap: () => setState(() => _isSandboxMode = true),
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _EnvironmentChip(
                  label: 'Production (Live)',
                  icon: Icons.rocket_launch,
                  isSelected: !_isSandboxMode,
                  onTap: () => setState(() => _isSandboxMode = false),
                  color: AppTheme.successGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isSandboxMode
                ? '⚠️ Testing mode - use sandbox credentials'
                : '🚀 Live mode - real payments will be processed',
            style: TextStyle(
              fontSize: 12,
              color: _isSandboxMode ? Colors.orange.shade700 : AppTheme.successGreen,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryBlue,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    String? helperText,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helperText,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      ),
      validator: validator,
    );
  }

  Widget _buildTransactionStats() {
    return Consumer<PayPalTransactionProvider>(
      builder: (context, txnProvider, _) {
        final stats = txnProvider.getStatistics();
        
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PayPal Transaction Statistics',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      label: 'Total',
                      value: '${stats['total_transactions']}',
                      icon: Icons.receipt_long,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Completed',
                      value: '${stats['completed']}',
                      icon: Icons.check_circle,
                      color: AppTheme.successGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      label: 'Pending',
                      value: '${stats['pending']}',
                      icon: Icons.pending,
                      color: Colors.orange,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Total Amount: \$${(stats['total_amount'] as double).toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 13, color: AppTheme.textMuted),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Getting PayPal Credentials'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: const [
              Text(
                '1. Go to developer.paypal.com',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 4),
              Text('2. Sign in with your PayPal account'),
              SizedBox(height: 4),
              Text('3. Navigate to "My Apps & Credentials"'),
              SizedBox(height: 4),
              Text('4. Create a new app (or use existing)'),
              SizedBox(height: 4),
              Text('5. Copy Client ID and Client Secret'),
              SizedBox(height: 12),
              Text(
                '⚠️ For testing: Use Sandbox credentials\n'
                '🚀 For live payments: Use Production credentials',
                style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it!'),
          ),
        ],
      ),
    );
  }
}

class _EnvironmentChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color color;

  const _EnvironmentChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: isSelected ? color : Colors.grey, size: 20),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey.shade700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
