import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_theme.dart';

/// Display and manage user's software license key
/// Shows license key, activation code, validity, and download options
class MyLicenseView extends StatefulWidget {
  const MyLicenseView({super.key});

  @override
  State<MyLicenseView> createState() => _MyLicenseViewState();
}

class _MyLicenseViewState extends State<MyLicenseView> {
  bool _isLoading = true;
  Map<String, dynamic>? _license;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLicense();
  }

  Future<void> _loadLicense() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser?.id;

      if (userId == null) {
        throw Exception('Not authenticated');
      }

      // Get user's tenant_id
      final userResponse = await supabase
          .from('users')
          .select('tenant_id')
          .eq('id', userId)
          .single();

      final tenantId = userResponse['tenant_id'];

      if (tenantId == null) {
        throw Exception('No tenant associated with user');
      }

      // Get active license for tenant
      final licenseResponse = await supabase
          .from('license_keys')
          .select('*, tenants(business_name)')
          .eq('tenant_id', tenantId)
          .eq('is_active', true)
          .single();

      setState(() {
        _license = licenseResponse;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My License'),
        backgroundColor: AppTheme.primaryBlue,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline,
                          size: 64, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Failed to load license',
                        style: TextStyle(
                            fontSize: 18, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _loadLicense,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _buildLicenseDetails(),
    );
  }

  Widget _buildLicenseDetails() {
    if (_license == null) {
      return const Center(child: Text('No license found'));
    }

    final licenseKey = _license!['license_key'] as String;
    final activationCode = _license!['activation_code'] as String;
    final licenseType = _license!['license_type'] as String;
    final validUntil = DateTime.parse(_license!['valid_until'] as String);
    final isActivated = _license!['is_activated'] as bool;
    final businessName =
        (_license!['tenants'] as Map<String, dynamic>)['business_name'] as String;

    final daysRemaining = validUntil.difference(DateTime.now()).inDays;
    final isExpired = daysRemaining < 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    isExpired
                        ? Icons.warning_amber
                        : Icons.verified_user,
                    size: 48,
                    color: isExpired
                        ? Colors.orange
                        : AppTheme.successGreen,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          businessName,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${licenseType.toUpperCase()} License',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Status Card
              Card(
                color: isExpired
                    ? Colors.orange[50]
                    : AppTheme.successGreen.withOpacity(0.1),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        isExpired ? Icons.error : Icons.check_circle,
                        color: isExpired
                            ? Colors.orange
                            : AppTheme.successGreen,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isExpired
                              ? 'License expired ${daysRemaining.abs()} days ago'
                              : 'License valid for $daysRemaining more days',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isExpired ? Colors.orange : AppTheme.successGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // License Key Section
              _buildInfoCard(
                title: 'License Key',
                icon: Icons.key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            licenseKey,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _copyToClipboard(licenseKey, 'License key'),
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy license key',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use this key to activate BillSprout software on your computer',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // Activation Code Section
              _buildInfoCard(
                title: 'Activation Code',
                icon: Icons.lock,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: SelectableText(
                            activationCode,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () =>
                              _copyToClipboard(activationCode, 'Activation code'),
                          icon: const Icon(Icons.copy),
                          tooltip: 'Copy activation code',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Use this code for offline activation',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),

              // License Details
              _buildInfoCard(
                title: 'License Details',
                icon: Icons.info,
                child: Column(
                  children: [
                    _buildDetailRow('Type', licenseType.toUpperCase()),
                    _buildDetailRow('Valid Until',
                        '${validUntil.day}/${validUntil.month}/${validUntil.year}'),
                    _buildDetailRow(
                        'Status', isActivated ? 'Activated' : 'Not Activated'),
                    _buildDetailRow('Max Users', '${_license!['max_users']}'),
                    _buildDetailRow(
                        'Max Branches', '${_license!['max_branches']}'),
                  ],
                ),
              ),

              // Download Software Button
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    // Navigate to download page
                    Navigator.pushNamed(context, '/download-software');
                  },
                  icon: const Icon(Icons.download, size: 24),
                  label: const Text(
                    'Download BillSprout Software',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              // Renew License Button (if expired)
              if (isExpired) ...[
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pushNamed(context, '/subscription-plans');
                    },
                    icon: const Icon(Icons.refresh, size: 24),
                    label: const Text(
                      'Renew License',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryBlue),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
